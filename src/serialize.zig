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

    if (sch.type) |t| {
        try jws.objectField("type");
        try jws.write(t);
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
