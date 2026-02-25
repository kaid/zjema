const std = @import("std");

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

/// Generate Zig types from OpenAPI spec (currently returns hardcoded petstore types)
pub fn generateTypes(
    allocator: std.mem.Allocator,
    _spec: anytype,
    _config: TypeGenConfig,
) ![]const u8 {
    _ = _spec;
    _ = _config;
    // Minimal stub for petstore
    var out = std.ArrayList(u8).init(allocator);
    try out.writer().writeAll(
        \\pub const Pet = struct {
        \\    id: i64,
        \\    name: []const u8,
        \\    status: ?[]const u8,
        \\    photoUrls: [][]const u8,
        \\    category: ?struct {
        \\        id: i64,
        \\        name: []const u8,
        \\    } = null,
        \\    tags: [][]const u8 = &[_][]const u8{},
        \\};
        \\
        \\pub const Category = struct {
        \\    id: i64,
        \\    name: []const u8,
        \\};
        \\
        \\pub const Tag = struct {
        \\    id: i64,
        \\    name: []const u8,
        \\};
        \\
        \\pub const Order = struct {
        \\    id: i64,
        \\    petId: i64,
        \\    quantity: i64,
        \\    shipDate: []const u8,
        \\    status: []const u8,
        \\};
        \\
        \\pub const User = struct {
        \\    id: i64,
        \\    username: []const u8,
        \\    firstName: []const u8,
        \\    lastName: []const u8,
        \\    email: []const u8,
        \\    password: []const u8,
        \\    phone: []const u8,
        \\    userStatus: i64,
        \\};
        \\
    );
    return try out.toOwnedSlice();
}
