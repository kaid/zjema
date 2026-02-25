const std = @import("std");
const ast = @import("../openapi/ast.zig");

/// Configuration for type generation
pub const TypeGenConfig = struct {
    /// Integer type to use (default: "i64")
    int_type: []const u8 = "i64",

    /// String type to use (default: "[]const u8")
    string_type: []const u8 = "[]const u8",

    /// Float type to use (default: "f64")
    float_type: []const u8 = "f64",

    /// Boolean type (always "bool")
    bool_type: []const u8 = "bool",

    /// Use union(enum) for oneOf (default: true)
    use_unions_for_oneof: bool = true,

    /// Treat nullable as optional (?T) (default: true)
    nullable_as_optional: bool = true,
};

fn getTypeString(
    allocator: std.mem.Allocator,
    schema: ast.Schema,
    config: TypeGenConfig,
) ![]const u8 {
    if (schema == .ref) {
        const ref = schema.ref;
        const last_slash = std.mem.lastIndexOf(u8, ref, "/");
        const name = if (last_slash) |idx| ref[idx+1..] else ref;
        return try allocator.dupe(u8, name);
    } else if (schema == .object) {
        const obj = schema.object;
        const t = obj.type orelse {
            return try allocator.dupe(u8, config.string_type);
        };
        if (std.mem.eql(u8, t, "string")) {
            return try allocator.dupe(u8, config.string_type);
        } else if (std.mem.eql(u8, t, "integer")) {
            return try allocator.dupe(u8, config.int_type);
        } else if (std.mem.eql(u8, t, "number")) {
            return try allocator.dupe(u8, config.float_type);
        } else if (std.mem.eql(u8, t, "boolean")) {
            return try allocator.dupe(u8, "bool");
        } else if (std.mem.eql(u8, t, "array")) {
            const items_schema = obj.items orelse {
                return try allocator.dupe(u8, "[]const u8");
            };
            const item_type = try getTypeString(allocator, items_schema, config);
            defer allocator.free(item_type);
            return try std.fmt.allocPrint(allocator, "[]const {s}", .{item_type});
        } else {
            // Inline object or unknown -> treat as opaque
            return try allocator.dupe(u8, "[]const u8");
        }
    }
    return error.InvalidSchema;
}

fn generateSchemaType(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    name: []const u8,
    schema: ast.Schema,
    config: TypeGenConfig,
) !void {
    const schema_obj = switch (schema) {
        .ref => {
            // Should not happen for top-level; generate empty placeholder
            try out.appendSlice(allocator, "pub const ");
            try out.appendSlice(allocator, name);
            try out.appendSlice(allocator, " = struct {};\n\n");
            try out.appendSlice(allocator, "pub const ");
            try out.appendSlice(allocator, name);
            try out.appendSlice(allocator, "Mapper = izo.Mapper(");
            try out.appendSlice(allocator, name);
            try out.appendSlice(allocator, ", .{});\n\n");
            return;
        },
        .object => |obj| obj,
    };

    try out.appendSlice(allocator, "pub const ");
    try out.appendSlice(allocator, name);
    try out.appendSlice(allocator, " = struct {\n");

    if (schema_obj.properties) |props| {
        var it = props.iterator();
        var j: usize = 0;
        while (j < it.len) : (j += 1) {
            const prop_name = it.keys[j];
            const prop_schema = it.values[j];

            // Check if property is required
            var is_required = false;
            for (schema_obj.required) |req| {
                if (std.mem.eql(u8, req, prop_name)) {
                    is_required = true;
                    break;
                }
            }

            // Determine nullable flag for property (only if object)
            var is_nullable = false;
            if (prop_schema == .object) {
                is_nullable = prop_schema.object.nullable;
            }

            const base_type = try getTypeString(allocator, prop_schema, config);
            defer allocator.free(base_type);

            try out.appendSlice(allocator, "    ");
            try out.appendSlice(allocator, prop_name);
            try out.appendSlice(allocator, ": ");
            const needs_optional = !is_required or (is_nullable and config.nullable_as_optional);
            if (needs_optional) {
                try out.appendSlice(allocator, "?");
            }
            try out.appendSlice(allocator, base_type);
            if (!is_required) {
                try out.appendSlice(allocator, " = null");
            }
            try out.appendSlice(allocator, ",\n");
        }
    }

    try out.appendSlice(allocator, "};\n\n");

    try out.appendSlice(allocator, "pub const ");
    try out.appendSlice(allocator, name);
    try out.appendSlice(allocator, "Mapper = izo.Mapper(");
    try out.appendSlice(allocator, name);
    try out.appendSlice(allocator, ", .{});\n\n");
}

/// Generate Zig types from OpenAPI spec
pub fn generateTypes(
    allocator: std.mem.Allocator,
    spec: anytype,
    config: TypeGenConfig,
) ![]const u8 {
    var out = std.ArrayList(u8).initCapacity(allocator, 4096) catch return error.OutOfMemory;
    errdefer out.deinit(allocator);

    // Temporary arena for intermediates
    var temp_arena = std.heap.ArenaAllocator.init(allocator);
    defer temp_arena.deinit();
    const temp_alloc = temp_arena.allocator();

    // Access components directly (spec should be *ast.OpenApiSpec or ast.OpenApiSpec)
    const comp = spec.components;
    if (comp == null) {
        return try out.toOwnedSlice(allocator);
    }
    if (comp.?.schemas.count() == 0) {
        return try out.toOwnedSlice(allocator);
    }

    // Collect all schema names
    var name_list = std.ArrayList([]const u8){};
    var it = comp.?.schemas.iterator();
    var i: usize = 0;
    while (i < it.len) : (i += 1) {
        try name_list.append(temp_alloc, it.keys[i]);
    }

    var generated = std.StringArrayHashMap(void).init(temp_alloc);
    var remaining = std.ArrayList([]const u8){};
    try remaining.appendSlice(temp_alloc, name_list.items);

    // Collect direct component $ref dependencies from a schema
    const collectRefs = struct {
        fn f(alloc: std.mem.Allocator, schema: ast.Schema, out_list: *std.ArrayList([]const u8)) !void {
            switch (schema) {
                .ref => |ref| {
                    const last_slash = std.mem.lastIndexOf(u8, ref, "/");
                    const name = if (last_slash) |idx| ref[idx+1..] else ref;
                    try out_list.append(alloc, name);
                },
                .object => |obj| {
                    if (obj.items) |items| {
                        try f(alloc, items, out_list);
                    }
                    if (obj.properties) |props| {
                        var pit = props.iterator();
                        var j: usize = 0;
                        while (j < pit.len) : (j += 1) {
                            try f(alloc, pit.values[j], out_list);
                        }
                    }
                },
            }
        }
    }.f;

    while (remaining.items.len > 0) {
        var progress = false;
        var idx: usize = 0;
        while (idx < remaining.items.len) {
            const name = remaining.items[idx];
            const schema = comp.?.schemas.get(name) orelse {
                idx += 1;
                continue;
            };
            var deps = std.ArrayList([]const u8){};
            try collectRefs(temp_alloc, schema, &deps);
            var deps_fulfilled = true;
            for (deps.items) |dep| {
                if (comp.?.schemas.contains(dep) and !generated.contains(dep)) {
                    deps_fulfilled = false;
                    break;
                }
            }
            if (deps_fulfilled) {
                try generateSchemaType(allocator, &out, name, schema, config);
                try generated.put(name, {});
                _ = remaining.swapRemove(idx);
                progress = true;
                continue;
            }
            idx += 1;
        }
        if (!progress) {
            // Cycle or missing: generate remaining in current order
            for (remaining.items) |name| {
                const schema = comp.?.schemas.get(name).?;
                try generateSchemaType(allocator, &out, name, schema, config);
            }
            break;
        }
    }

    return try out.toOwnedSlice(allocator);
}
