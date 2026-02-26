const std = @import("std");
const sch_mod = @import("schema.zig");

/// Options for serialization
pub const SerializeOptions = struct {
    /// Pretty print with indentation (default: false)
    pretty: bool = false,
    /// Indent string for pretty printing (default: "  ")
    indent: []const u8 = "  ",
};

/// Write JsonSchema to any writer
pub fn write(sch: sch_mod.JsonSchema, writer: anytype, options: SerializeOptions) !void {
    var jws = std.json.Stringify{ .writer = writer };
    try writeJsonSchema(&jws, sch, options);
}

fn writeJsonSchema(jws: *std.json.Stringify, sch: sch_mod.JsonSchema, options: SerializeOptions) !void {
    try jws.beginObject();

    if (sch.ref) |ref| {
        try jws.objectField("$ref");
        try jws.write(ref);
    }

    if (sch.type) |t| {
        try jws.objectField("type");
        try jws.write(t);
    }

    if (sch.format) |f| {
        try jws.objectField("format");
        try jws.write(f);
    }

    if (sch.description) |desc| {
        try jws.objectField("description");
        try jws.write(desc);
    }

    if (sch.properties) |props| {
        try jws.objectField("properties");
        try jws.beginObject();
        for (props) |prop| {
            try jws.objectField(prop.name);
            try writeJsonSchema(jws, prop.schema, options);
        }
        try jws.endObject();
    }

    if (sch.required) |req| {
        try jws.objectField("required");
        try jws.write(req);
    }

    if (sch.items) |items| {
        try jws.objectField("items");
        try writeJsonSchema(jws, items.*, options);
    }

    if (sch.@"enum") |enum_vals| {
        try jws.objectField("enum");
        try jws.write(enum_vals);
    }

    if (sch.oneOf) |variants| {
        try jws.objectField("oneOf");
        try jws.beginArray();
        for (variants) |variant| {
            try writeJsonSchema(jws, variant, options);
        }
        try jws.endArray();
    }

    if (sch.anyOf) |variants| {
        try jws.objectField("anyOf");
        try jws.beginArray();
        for (variants) |variant| {
            try writeJsonSchema(jws, variant, options);
        }
        try jws.endArray();
    }

    if (sch.allOf) |variants| {
        try jws.objectField("allOf");
        try jws.beginArray();
        for (variants) |variant| {
            try writeJsonSchema(jws, variant, options);
        }
        try jws.endArray();
    }

    if (sch.nullable) {
        try jws.objectField("nullable");
        try jws.write(true);
    }

    try jws.endObject();
}

/// Convert schema to string using allocator (returns allocated string)
pub fn stringify(allocator: std.mem.Allocator, sch: sch_mod.JsonSchema, options: SerializeOptions) ![]u8 {
    var aw = std.Io.Writer.Allocating.init(allocator);
    defer aw.deinit();
    var jws = std.json.Stringify{ .writer = &aw.writer };
    try writeJsonSchema(&jws, sch, options);
    try aw.writer.flush();
    return aw.toOwnedSlice();
}

/// Print schema to stdout (convenience)
pub fn print(sch: sch_mod.JsonSchema, options: SerializeOptions) !void {
    var stdout_writer = std.io.getStdOut().writer();
    var jws = std.json.Stringify{ .writer = &stdout_writer };
    try writeJsonSchema(&jws, sch, options);
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
