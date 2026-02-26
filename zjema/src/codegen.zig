// zjema codegen: Schema → Zig type generation
// Provides `fromSchema` to convert a JsonSchema into Zig struct code.

const std = @import("std");
const schema_mod = @import("schema.zig");

/// Configuration for type generation
pub const TypesConfig = struct {
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

/// Generate Zig source code for a single type from a JsonSchema.
/// Only object schemas with properties will generate struct code.
/// Returns empty string for non-object schemas or refs.
pub fn fromSchema(
    allocator: std.mem.Allocator,
    name: []const u8,
    sch: schema_mod.JsonSchema,
    config: TypesConfig,
) ![]const u8 {
    // Skip if it's a reference
    if (sch.ref != null) {
        return allocator.dupe(u8, "");
    }

    // Only generate for object types with properties
    const props = sch.properties orelse {
        return allocator.dupe(u8, "");
    };

    // If type is specified and not "object", skip (primitive/array inline)
    if (sch.type) |t| {
        if (!std.mem.eql(u8, t, "object")) {
            return allocator.dupe(u8, "");
        }
    }

    var out = std.ArrayList(u8).initCapacity(allocator, 1024) catch return error.OutOfMemory;
    errdefer out.deinit(allocator);

    // pub const Name = struct { ... };
    try out.appendSlice(allocator, "pub const ");
    try out.appendSlice(allocator, name);
    try out.appendSlice(allocator, " = struct {\n");

    const required_set = sch.required orelse &[_][]const u8{};

    for (props) |prop| {
        try out.appendSlice(allocator, "    ");
        try out.appendSlice(allocator, prop.name);
        try out.appendSlice(allocator, ": ");

        const base_type = try getTypeString(allocator, prop.schema, config);
        defer allocator.free(base_type);

        const is_required = isRequired(required_set, prop.name);
        const is_nullable = prop.schema.nullable;

        // Field is optional if not required OR if nullable and config says so.
        // Original zjema logic: non-required fields are optional, nullable fields may also be optional.
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

    try out.appendSlice(allocator, "};\n\n");

    // Mapper
    try out.appendSlice(allocator, "pub const ");
    try out.appendSlice(allocator, name);
    try out.appendSlice(allocator, "Mapper = izo.Mapper(");
    try out.appendSlice(allocator, name);
    try out.appendSlice(allocator, ", .{});\n");

    return try out.toOwnedSlice(allocator);
}

fn isRequired(required: []const []const u8, prop_name: []const u8) bool {
    for (required) |r| {
        if (std.mem.eql(u8, r, prop_name)) return true;
    }
    return false;
}

/// Get the Zig type string for a schema
fn getTypeString(
    allocator: std.mem.Allocator,
    sch: schema_mod.JsonSchema,
    config: TypesConfig,
) ![]const u8 {
    // Handle reference
    if (sch.ref) |ref| {
        const last_slash = std.mem.lastIndexOf(u8, ref, "/");
        const name = if (last_slash) |idx| ref[idx + 1 ..] else ref;
        return try allocator.dupe(u8, name);
    }

    // Handle based on type
    if (sch.type) |t| {
        if (std.mem.eql(u8, t, "string")) {
            return try allocator.dupe(u8, config.string_type);
        } else if (std.mem.eql(u8, t, "integer")) {
            return try allocator.dupe(u8, config.int_type);
        } else if (std.mem.eql(u8, t, "number")) {
            return try allocator.dupe(u8, config.float_type);
        } else if (std.mem.eql(u8, t, "boolean")) {
            return try allocator.dupe(u8, config.bool_type);
        } else if (std.mem.eql(u8, t, "array")) {
            const items_schema_ptr = sch.items orelse {
                return try allocator.dupe(u8, "[]const u8");
            };
            const item_type = try getTypeString(allocator, items_schema_ptr.*, config);
            defer allocator.free(item_type);
            return try std.fmt.allocPrint(allocator, "[]const {s}", .{item_type});
        } else {
            // unknown type
            return try allocator.dupe(u8, config.string_type);
        }
    }

    // No type specified, treat as any/opaque
    return try allocator.dupe(u8, config.string_type);
}

// Keep the legacy escapeString and transformPath for client_generator
pub fn escapeString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), s: []const u8) !void {
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        switch (s[i]) {
            '\\', '\"' => {
                try out.appendSlice(allocator, "\\");
                try out.appendSlice(allocator, s[i .. i + 1]);
            },
            '\n' => {
                try out.appendSlice(allocator, "\\n");
            },
            else => {
                try out.appendSlice(allocator, s[i .. i + 1]);
            },
        }
    }
}

pub fn transformPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    var i: usize = 0;
    while (i < path.len) {
        if (path[i] == '{') {
            const end = std.mem.indexOfScalarPos(u8, path, i, '}') orelse {
                try out.appendSlice(allocator, path[i..]);
                break;
            };
            try out.appendSlice(allocator, "{}");
            i = end + 1;
        } else {
            try out.appendSlice(allocator, path[i .. i + 1]);
            i += 1;
        }
    }
    return try out.toOwnedSlice();
}
