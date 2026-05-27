// zjema-openapi type generation: delegates to zjema.codegen.fromSchema
// This module converts OpenAPI AST schemas to zjema.JsonSchema and
// generates Zig type code by calling zjema.codegen.fromSchema.

const std = @import("std");
const zjema = @import("zjema");
const ast = @import("../openapi/ast.zig");

pub const TypeGenConfig = struct {
    /// Integer type to use (default: "i64")
    int_type: []const u8 = "i64",

    /// String type to use (default: "[]const u8")
    string_type: []const u8 = "[]const u8",

    /// Float type to use (default: "f64")
    float_type: []const u8 = "f64",

    /// Boolean type (default: "bool")
    bool_type: []const u8 = "bool",

    /// Use union(enum) for oneOf (default: true)
    use_union_for_oneof: bool = true,

    /// Treat nullable as optional (?T) (default: true)
    nullable_as_optional: bool = true,
};

/// Generate Zig type code from an OpenAPI spec by converting schemas to zjema.JsonSchema
/// and calling zjema.codegen.fromSchema for each object type.
pub fn generateTypes(
    allocator: std.mem.Allocator,
    spec: anytype,
    config: TypeGenConfig,
) ![]const u8 {
    const comp = spec.components orelse {
        // No components, no schemas to generate
        return allocator.dupe(u8, "");
    };
    if (comp.schemas.count() == 0) {
        return allocator.dupe(u8, "");
    }

    // Arena for temporary allocations during conversion
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    // Build a map of schema name -> zjema.JsonSchema
    var schema_map = try std.array_hash_map.String(zjema.schema.JsonSchema).init(arena_alloc, &.{}, &.{});
    try schema_map.ensureTotalCapacity(allocator, comp.schemas.count());

    // Convert all OpenAPI schemas to zjema.JsonSchema
    const it = comp.schemas.iterator();
    var i: usize = 0;
    while (i < it.len) : (i += 1) {
        const name = it.keys[i];
        const openapi_schema = it.values[i];
        const zjema_schema = try convertSchema(arena_alloc, openapi_schema, &schema_map);
        try schema_map.put(allocator, name, zjema_schema);
    }

    // Topological ordering: collect all schema names
    var name_list = std.ArrayList([]const u8).initCapacity(arena_alloc, 0) catch unreachable;
    const name_it = comp.schemas.iterator();
    var j: usize = 0;
    while (j < name_it.len) : (j += 1) {
        try name_list.append(arena_alloc, name_it.keys[j]);
    }

    var generated = std.StringHashMap(void).init(arena_alloc);
    var remaining = std.ArrayList([]const u8).initCapacity(arena_alloc, 0) catch unreachable;
    try remaining.appendSlice(arena_alloc, name_list.items);

    // Helper to collect referenced schema names from a JsonSchema
    const collectRefs = struct {
        fn f(alloc: std.mem.Allocator, sch: zjema.schema.JsonSchema, out: *std.ArrayList([]const u8)) !void {
            if (sch.ref) |ref| {
                const last_slash = std.mem.lastIndexOf(u8, ref, "/");
                const name = if (last_slash) |idx| ref[idx + 1 ..] else ref;
                try out.append(alloc, name);
            }
            if (sch.items) |items| {
                try f(alloc, items.*, out);
            }
            if (sch.properties) |props| {
                for (props) |prop| {
                    try f(alloc, prop.schema, out);
                }
            }
            if (sch.oneOf) |oneof| {
                for (oneof) |variant| {
                    try f(alloc, variant, out);
                }
            }
            if (sch.anyOf) |anyof| {
                for (anyof) |variant| {
                    try f(alloc, variant, out);
                }
            }
            if (sch.allOf) |allof| {
                for (allof) |variant| {
                    try f(alloc, variant, out);
                }
            }
        }
    }.f;

    var out_code = std.ArrayList(u8).initCapacity(allocator, 4096) catch return error.OutOfMemory;
    errdefer out_code.deinit(allocator);

    // Dependency resolution loop
    while (remaining.items.len > 0) {
        var progress = false;
        var idx: usize = 0;
        while (idx < remaining.items.len) {
            const name = remaining.items[idx];
            const zjema_schema = schema_map.get(name) orelse {
                idx += 1;
                continue;
            };
            var deps = std.ArrayList([]const u8).initCapacity(arena_alloc, 0) catch unreachable;
            try collectRefs(arena_alloc, zjema_schema, &deps);
            var deps_fulfilled = true;
            for (deps.items) |dep| {
                if (schema_map.contains(dep) and !generated.contains(dep)) {
                    deps_fulfilled = false;
                    break;
                }
            }
            if (deps_fulfilled) {
                const code = try zjema.codegen.fromSchema(allocator, name, zjema_schema, .{
                    .int_type = config.int_type,
                    .string_type = config.string_type,
                    .float_type = config.float_type,
                    .bool_type = config.bool_type,
                    .use_union_for_oneof = config.use_union_for_oneof,
                    .nullable_as_optional = config.nullable_as_optional,
                });
                if (code.len > 0) {
                    try out_code.appendSlice(allocator, code);
                    try out_code.appendSlice(allocator, "\n");
                }
                try generated.put(name, {});
                _ = remaining.swapRemove(idx);
                progress = true;
                continue;
            }
            idx += 1;
        }
        if (!progress) {
            // Cycle or missing dependencies: output remaining anyway
            for (remaining.items) |name| {
                const zjema_schema = schema_map.get(name).?;
                const code = try zjema.codegen.fromSchema(allocator, name, zjema_schema, .{
                    .int_type = config.int_type,
                    .string_type = config.string_type,
                    .float_type = config.float_type,
                    .bool_type = config.bool_type,
                    .use_union_for_oneof = config.use_union_for_oneof,
                    .nullable_as_optional = config.nullable_as_optional,
                });
                if (code.len > 0) {
                    try out_code.appendSlice(allocator, code);
                    try out_code.appendSlice(allocator, "\n");
                }
            }
            break;
        }
    }

    return try out_code.toOwnedSlice(allocator);
}

/// Convert an OpenAPI AST Schema to a zjema.JsonSchema.
/// The returned value lives on the provided arena allocator.
fn convertSchema(
    arena: std.mem.Allocator,
    openapi_schema: ast.Schema,
    schema_map: *std.array_hash_map.String(zjema.schema.JsonSchema),
) anyerror!zjema.schema.JsonSchema {
    switch (openapi_schema) {
        .ref => |ref| {
            return zjema.schema.JsonSchema{ .ref = ref };
        },
        .object => |obj| {
            // Convert properties from HashMap to slice
            var props_list = std.ArrayList(zjema.schema.JsonSchema.Property).initCapacity(arena, 0) catch unreachable;
            if (obj.properties) |props_map| {
                const pit = props_map.iterator();
                var pj: usize = 0;
                while (pj < pit.len) : (pj += 1) {
                    const prop_name = pit.keys[pj];
                    const child_openapi = pit.values[pj];
                    const child_zjema = try convertSchema(arena, child_openapi, schema_map);
                    try props_list.append(arena, .{
                        .name = prop_name,
                        .schema = child_zjema,
                    });
                }
            }

            // Convert oneOf, anyOf, allOf
            var oneof_list = std.ArrayList(zjema.schema.JsonSchema).initCapacity(arena, 0) catch unreachable;
            for (obj.oneOf) |variant| {
                try oneof_list.append(arena, try convertSchema(arena, variant, schema_map));
            }
            var anyof_list = std.ArrayList(zjema.schema.JsonSchema).initCapacity(arena, 0) catch unreachable;
            for (obj.anyOf) |variant| {
                try anyof_list.append(arena, try convertSchema(arena, variant, schema_map));
            }
            var allof_list = std.ArrayList(zjema.schema.JsonSchema).initCapacity(arena, 0) catch unreachable;
            for (obj.allOf) |variant| {
                try allof_list.append(arena, try convertSchema(arena, variant, schema_map));
            }

            // Items: allocate a separate schema on arena and assign pointer
            var items_schema_ptr: ?*zjema.schema.JsonSchema = null;
            if (obj.items) |itm| {
                const allocated = try arena.create(zjema.schema.JsonSchema);
                allocated.* = try convertSchema(arena, itm, schema_map);
                items_schema_ptr = allocated;
            }

            return zjema.schema.JsonSchema{
                .ref = null,
                .type = obj.type,
                .properties = if (props_list.items.len > 0) props_list.items else null,
                .required = obj.required,
                .items = items_schema_ptr,
                .oneOf = if (oneof_list.items.len > 0) oneof_list.items else null,
                .anyOf = if (anyof_list.items.len > 0) anyof_list.items else null,
                .allOf = if (allof_list.items.len > 0) allof_list.items else null,
                .@"enum" = null, // TODO: convert json.Value array to string array
                .format = obj.format,
                .description = obj.description,
                .nullable = obj.nullable,
            };
        },
    }
}
