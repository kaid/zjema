const std = @import("std");
const zjema = @import("zjema");

fn expectSchema(comptime T: type, expected: []const u8) !void {
    const js = zjema.generate(T);
    const json_str = try zjema.stringify(std.testing.allocator, js, .{});
    defer std.testing.allocator.free(json_str);
    try std.testing.expectEqualStrings(expected, json_str);
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

test "generate schema for empty struct" {
    const Empty = struct {};
    try expectSchema(Empty, "{\"type\":\"object\",\"properties\":{}}");
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

test "generate schema for struct with json.Value" {
    const Args = struct {
        message: []const u8,
        extra: std.json.Value,
    };
    try expectSchema(Args, "{\"type\":\"object\",\"properties\":{\"message\":{\"type\":\"string\"},\"extra\":{}},\"required\":[\"message\",\"extra\"]}");
}

test "generate schema for json.Value field" {
    const js = zjema.generate(std.json.Value);
    const json_str = try zjema.stringify(std.testing.allocator, js, .{});
    defer std.testing.allocator.free(json_str);
    try std.testing.expectEqualStrings("{}", json_str);
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
