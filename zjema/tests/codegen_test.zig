const std = @import("std");
const zjema = @import("zjema");

test "fromSchema generates simple struct" {
    const allocator = std.testing.allocator;

    // Build a simple JsonSchema: { type: "object", properties: { name: { type: "string" } }, required: ["name"] }
    const schema = zjema.schema.JsonSchema{
        .type = "object",
        .properties = &[_]zjema.schema.JsonSchema.Property{
            .{
                .name = "name",
                .schema = zjema.schema.JsonSchema{ .type = "string" },
            },
        },
        .required = &[_][]const u8{"name"},
    };

    const code = try zjema.codegen.fromSchema(allocator, "Person", schema, .{});
    defer allocator.free(code);

    // Check that the generated code contains the struct and Mapper
    try std.testing.expect(std.mem.indexOf(u8, code, "pub const Person = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "name: []const u8") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "PersonMapper = json.Mapper(") != null);
}

test "fromSchema with optional field" {
    const allocator = std.testing.allocator;

    const schema = zjema.schema.JsonSchema{
        .type = "object",
        .properties = &[_]zjema.schema.JsonSchema.Property{
            .{
                .name = "id",
                .schema = zjema.schema.JsonSchema{ .type = "integer" },
            },
            .{
                .name = "nickname",
                .schema = zjema.schema.JsonSchema{ .type = "string" },
            },
        },
        .required = &[_][]const u8{"id"},
    };

    const code = try zjema.codegen.fromSchema(allocator, "User", schema, .{});
    defer allocator.free(code);

    // id is required, nickname is optional
    try std.testing.expect(std.mem.indexOf(u8, code, "id: i64") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "nickname: ?[]const u8 = null") != null);
}
