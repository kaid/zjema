const std = @import("std");
const sch_mod = @import("schema.zig");

/// Options for serialization
pub const SerializeOptions = struct {
    /// Pretty print with indentation (default: false)
    pretty: bool = false,
};

/// Write JsonSchema to any writer using izomorph
pub fn write(sch: sch_mod.JsonSchema, writer: anytype, options: SerializeOptions) !void {
    const encode_options: @import("izomorph").json.EncodeOptions = .{
        .pretty = options.pretty,
    };
    try @import("izomorph").json.encodeToWriter(writer, sch, sch_mod.JsonSchemaMapper, encode_options);
}

/// Convert schema to string using allocator (returns allocated string)
pub fn stringify(allocator: std.mem.Allocator, sch: sch_mod.JsonSchema, options: SerializeOptions) ![]u8 {
    const encode_options: @import("izomorph").json.EncodeOptions = .{
        .pretty = options.pretty,
    };
    return try @import("izomorph").json.encode(allocator, sch, sch_mod.JsonSchemaMapper, encode_options);
}

/// Print schema to stdout (convenience)
pub fn print(sch: sch_mod.JsonSchema, options: SerializeOptions) !void {
    const stdout_writer = std.io.getStdOut().writer();
    try write(sch, stdout_writer, options);
    _ = try stdout_writer.writeByte('\n');
}

// ==================== Tests ====================

test "serialize schema with all fields" {
    const allocator = std.testing.allocator;

    const inner = sch_mod.JsonSchema{
        .type = "string",
        .description = "A string field",
    };

    const sch = sch_mod.JsonSchema{
        .type = "object",
        .properties = &[_]sch_mod.JsonSchema.Property{
            .{ .name = "id", .schema = .{ .type = "integer", .description = "The ID" } },
            .{ .name = "name", .schema = inner },
        },
        .required = &[_][]const u8{"id"},
    };

    const json_str = try stringify(allocator, sch, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"type\":\"object\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"properties\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"id\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"required\"") != null);
}

test "serialize schema with ref" {
    const allocator = std.testing.allocator;

    const sch = sch_mod.JsonSchema{
        .ref = "#/definitions/Person",
    };

    const json_str = try stringify(allocator, sch, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"$ref\":\"#/definitions/Person\"") != null);
}

test "serialize schema with anyOf" {
    const allocator = std.testing.allocator;

    const sch = sch_mod.JsonSchema{
        .anyOf = &[_]sch_mod.JsonSchema{
            .{ .type = "string" },
            .{ .type = "null" },
        },
    };

    const json_str = try stringify(allocator, sch, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"anyOf\"") != null);
}

test "serialize schema with format and nullable" {
    const allocator = std.testing.allocator;

    const sch = sch_mod.JsonSchema{
        .type = "string",
        .format = "date-time",
        .nullable = true,
    };

    const json_str = try stringify(allocator, sch, .{});
    defer allocator.free(json_str);

    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"format\":\"date-time\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\"nullable\":true") != null);
}

test "serialize schema with pretty printing" {
    const allocator = std.testing.allocator;

    const sch = sch_mod.JsonSchema{
        .type = "object",
        .properties = &[_]sch_mod.JsonSchema.Property{
            .{ .name = "name", .schema = .{ .type = "string" } },
        },
    };

    const json_str = try stringify(allocator, sch, .{ .pretty = true });
    defer allocator.free(json_str);

    // Pretty printed should contain newlines and indentation
    try std.testing.expect(std.mem.indexOf(u8, json_str, "\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, json_str, "  ") != null);
}
