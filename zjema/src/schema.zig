const std = @import("std");
const json = std.json;
const izo = @import("izomorph");

pub const JsonSchema = struct {
    ref: ?[]const u8 = null,
    type: ?[]const u8 = null,
    properties: ?[]const Property = null,
    required: ?[]const []const u8 = null,
    items: ?*const JsonSchema = null,
    @"enum": ?[]const []const u8 = null,
    anyOf: ?[]const JsonSchema = null,
    oneOf: ?[]const JsonSchema = null,
    allOf: ?[]const JsonSchema = null,
    format: ?[]const u8 = null,
    description: ?[]const u8 = null,
    nullable: bool = false,

    pub const Property = struct {
        name: []const u8,
        schema: JsonSchema,
        description: ?[]const u8 = null,
    };

    /// Serialize to JSON using izomorph
    pub fn toJson(self: JsonSchema, writer: anytype) !void {
        try izo.json.encodeToWriter(writer, self, JsonSchemaMapper, .{});
    }

    /// Serialize to JSON string (allocating)
    pub fn toJsonAlloc(self: JsonSchema, allocator: std.mem.Allocator) ![]const u8 {
        return try izo.json.encode(allocator, self, JsonSchemaMapper, .{});
    }
};

// Mappers for izomorph serialization
pub const PropertyMapper = izo.Mapper(JsonSchema.Property, .{
    .schema = .{ .alias = "schema" },
});

pub const JsonSchemaMapper = izo.Mapper(JsonSchema, .{
    .ref = .{ .alias = "$ref", .omit_null = true },
    .type = .{ .omit_null = true },
    .properties = .{ .omit_null = true },
    .required = .{ .omit_null = true },
    .items = .{ .omit_null = true },
    .@"enum" = .{ .alias = "enum", .omit_null = true },
    .anyOf = .{ .omit_null = true },
    .oneOf = .{ .omit_null = true },
    .allOf = .{ .omit_null = true },
    .format = .{ .omit_null = true },
    .description = .{ .omit_null = true },
    .nullable = .{ .omit_default = true }, // omit if false (default)
});

/// Generate JSON Schema struct from a Zig type at comptime
pub fn toSchema(comptime T: type) JsonSchema {
    if (T == json.Value) {
        return JsonSchema{};
    }

    const info = @typeInfo(T);

    return switch (info) {
        .@"struct" => generateObjectSchema(T),
        .optional => |opt| toSchema(opt.child),
        .pointer => |ptr| switch (ptr.size) {
            .slice => if (ptr.child == u8)
                JsonSchema{ .type = "string" }
            else
                JsonSchema{
                    .type = "array",
                    .items = &toSchema(ptr.child),
                },
            else => @compileError("Unsupported pointer type for schema generation"),
        },
        .array => |arr| JsonSchema{
            .type = "array",
            .items = &toSchema(arr.child),
        },
        .int => JsonSchema{ .type = "integer" },
        .float => JsonSchema{ .type = "number" },
        .bool => JsonSchema{ .type = "boolean" },
        .@"enum" => generateEnumSchema(T),
        .@"union" => generateUnionSchema(T),
        else => @compileError("Unsupported type for schema generation: " ++ @typeName(T)),
    };
}

fn generateObjectSchema(comptime T: type) JsonSchema {
    const fields = @typeInfo(T).@"struct".fields;

    if (fields.len == 0) {
        return JsonSchema{ .type = "object", .properties = &[_]JsonSchema.Property{} };
    }

    comptime var props: []const JsonSchema.Property = &[_]JsonSchema.Property{};
    comptime var required: []const []const u8 = &[_][]const u8{};

    inline for (fields) |field| {
        const field_schema = comptime toSchema(field.type);
        props = props ++ [_]JsonSchema.Property{.{ .name = field.name, .schema = field_schema }};

        const is_optional = @typeInfo(field.type) == .optional;
        const has_default = field.default_value_ptr != null;

        if (!is_optional and !has_default) {
            required = required ++ [_][]const u8{field.name};
        }
    }

    return JsonSchema{
        .type = "object",
        .properties = props,
        .required = if (required.len > 0) required else null,
    };
}

fn generateEnumSchema(comptime T: type) JsonSchema {
    const info = @typeInfo(T).@"enum";

    comptime var values: []const []const u8 = &[_][]const u8{};

    inline for (info.fields) |field| {
        values = values ++ [_][]const u8{field.name};
    }

    return JsonSchema{
        .type = "string",
        .@"enum" = values,
    };
}

fn generateUnionSchema(comptime T: type) JsonSchema {
    const info = @typeInfo(T).@"union";

    if (info.tag_type == null) {
        @compileError("Unsupported untagged union for schema generation: " ++ @typeName(T));
    }

    comptime var variants: []const JsonSchema = &[_]JsonSchema{};

    inline for (info.fields) |field| {
        const variant_schema = toSchema(field.type);
        variants = variants ++ [_]JsonSchema{variant_schema};
    }

    return JsonSchema{
        .oneOf = variants,
    };
}

/// Schema for json.Value - accepts any JSON value
fn generateAnyValueSchema() JsonSchema {
    return .{};
}

// ==================== Tests ====================

fn expectSchema(comptime T: type, expected: []const u8) !void {
    const js = toSchema(T);
    const result = try js.toJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(expected, result);
}

test "generate schema for simple struct" {
    const Args = struct {
        message: []const u8,
    };
    try expectSchema(Args, "{\"type\":\"object\",\"properties\":{\"message\":{\"type\":\"string\"}},\"required\":[\"message\"]}");
}

test "generate schema for struct with optional" {
    const Args = struct {
        name: []const u8,
        nickname: ?[]const u8,
    };
    try expectSchema(Args, "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"nickname\":{\"type\":\"string\"}},\"required\":[\"name\"]}");
}

test "generate schema for struct with default" {
    const Args = struct {
        name: []const u8,
        count: u32 = 10,
    };
    try expectSchema(Args, "{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"count\":{\"type\":\"integer\"}},\"required\":[\"name\"]}");
}

test "generate schema for nested struct" {
    const Inner = struct {
        value: i32,
    };
    const Outer = struct {
        inner: Inner,
    };
    try expectSchema(Outer, "{\"type\":\"object\",\"properties\":{\"inner\":{\"type\":\"object\",\"properties\":{\"value\":{\"type\":\"integer\"}},\"required\":[\"value\"]}},\"required\":[\"inner\"]}");
}

test "generate schema for enum" {
    const Color = enum { red, green, blue };
    const Args = struct {
        color: Color,
    };
    try expectSchema(Args, "{\"type\":\"object\",\"properties\":{\"color\":{\"type\":\"string\",\"enum\":[\"red\",\"green\",\"blue\"]}},\"required\":[\"color\"]}");
}

test "generate schema for array" {
    const Args = struct {
        tags: []const []const u8,
    };
    try expectSchema(Args, "{\"type\":\"object\",\"properties\":{\"tags\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},\"required\":[\"tags\"]}");
}

test "generate schema for empty struct" {
    const Empty = struct {};
    try expectSchema(Empty, "{\"type\":\"object\",\"properties\":{}}");
}

test "generate schema for struct with json.Value" {
    const Args = struct {
        message: []const u8,
        extra: json.Value,
    };
    try expectSchema(Args, "{\"type\":\"object\",\"properties\":{\"message\":{\"type\":\"string\"},\"extra\":{}},\"required\":[\"message\",\"extra\"]}");
}

test "generate schema for json.Value field" {
    const js = toSchema(json.Value);
    const result = try js.toJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("{}", result);
}

test "generate schema for union type" {
    const MyUnion = union(enum) {
        int: i32,
        string: []const u8,
    };
    const Args = struct {
        value: MyUnion,
    };
    try expectSchema(Args, "{\"type\":\"object\",\"properties\":{\"value\":{\"oneOf\":[{\"type\":\"integer\"},{\"type\":\"string\"}]}},\"required\":[\"value\"]}");
}
