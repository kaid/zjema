const std = @import("std");
const zjema_openapi = @import("zjema_openapi");

test "type_generator generates simple object" {
    const allocator = std.heap.page_allocator;

    // Create a simple string schema for 'name'
    const name_schema_obj = try allocator.create(zjema_openapi.SchemaObject);
    name_schema_obj.* = .{
        .type = "string",
        .properties = null,
        .required = &.{},
        .items = null,
        .oneOf = &.{},
        .anyOf = &.{},
        .allOf = &.{},
        .@"enum" = &.{},
        .format = null,
        .description = null,
        .nullable = false,
    };
    const name_schema = zjema_openapi.Schema{ .object = name_schema_obj };

    // Person schema with required 'name' property
    const person_schema_obj = try allocator.create(zjema_openapi.SchemaObject);
    person_schema_obj.* = .{
        .type = "object",
        .properties = blk: {
            var map = std.StringArrayHashMap(zjema_openapi.Schema).init(allocator);
            try map.put("name", name_schema);
            break :blk map;
        },
        .required = &[_][]const u8{"name"},
        .items = null,
        .oneOf = &.{},
        .anyOf = &.{},
        .allOf = &.{},
        .@"enum" = &.{},
        .format = null,
        .description = null,
        .nullable = false,
    };
    const person_schema = zjema_openapi.Schema{ .object = person_schema_obj };

    // Build spec with Person in components
    var schemas = std.StringArrayHashMap(zjema_openapi.Schema).init(allocator);
    try schemas.put("Person", person_schema);

    const comp = zjema_openapi.Components{ .schemas = schemas };
    const spec = zjema_openapi.OpenApiSpec{
        .openapi = "3.0.0",
        .info = .{ .title = "test", .version = "1.0.0" },
        .paths = std.StringArrayHashMap(zjema_openapi.PathItem).init(allocator),
        .components = comp,
        .servers = &.{},
    };

    // Generate types
    const types_code = try zjema_openapi.type_generator.generateTypes(allocator, spec, .{});
    defer allocator.free(types_code);

    // Verify output contains struct and mapper
    try std.testing.expect(std.mem.indexOf(u8, types_code, "pub const Person = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, types_code, "name: []const u8") != null);
    try std.testing.expect(std.mem.indexOf(u8, types_code, "PersonMapper = json.Mapper(") != null);
}

test "type_generator handles dependencies" {
    const allocator = std.heap.page_allocator;

    // Street schema (string)
    const street_obj = try allocator.create(zjema_openapi.SchemaObject);
    street_obj.* = .{
        .type = "string",
        .properties = null,
        .required = &.{},
        .items = null,
        .oneOf = &.{},
        .anyOf = &.{},
        .allOf = &.{},
        .@"enum" = &.{},
        .format = null,
        .description = null,
        .nullable = false,
    };
    const street_schema = zjema_openapi.Schema{ .object = street_obj };

    // Address schema with 'street' property
    const address_obj = try allocator.create(zjema_openapi.SchemaObject);
    address_obj.* = .{
        .type = "object",
        .properties = blk: {
            var map = std.StringArrayHashMap(zjema_openapi.Schema).init(allocator);
            try map.put("street", street_schema);
            break :blk map;
        },
        .required = &[_][]const u8{"street"},
        .items = null,
        .oneOf = &.{},
        .anyOf = &.{},
        .allOf = &.{},
        .@"enum" = &.{},
        .format = null,
        .description = null,
        .nullable = false,
    };
    const address_schema = zjema_openapi.Schema{ .object = address_obj };

    // Person schema with required 'address' ref
    const person_obj = try allocator.create(zjema_openapi.SchemaObject);
    person_obj.* = .{
        .type = "object",
        .properties = blk: {
            var map = std.StringArrayHashMap(zjema_openapi.Schema).init(allocator);
            try map.put("address", .{ .ref = "#/components/schemas/Address" });
            break :blk map;
        },
        .required = &[_][]const u8{"address"},
        .items = null,
        .oneOf = &.{},
        .anyOf = &.{},
        .allOf = &.{},
        .@"enum" = &.{},
        .format = null,
        .description = null,
        .nullable = false,
    };
    const person_schema = zjema_openapi.Schema{ .object = person_obj };

    // Build spec with both schemas
    var schemas = std.StringArrayHashMap(zjema_openapi.Schema).init(allocator);
    try schemas.put("Address", address_schema);
    try schemas.put("Person", person_schema);

    const comp = zjema_openapi.Components{ .schemas = schemas };
    const spec = zjema_openapi.OpenApiSpec{
        .openapi = "3.0.0",
        .info = .{ .title = "test", .version = "1.0.0" },
        .paths = std.StringArrayHashMap(zjema_openapi.PathItem).init(allocator),
        .components = comp,
        .servers = &.{},
    };

    const types_code = try zjema_openapi.type_generator.generateTypes(allocator, spec, .{});
    defer allocator.free(types_code);

    // Both types should be generated
    try std.testing.expect(std.mem.indexOf(u8, types_code, "pub const Person = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, types_code, "pub const Address = struct") != null);
    // address field should be a required reference (non-optional)
    try std.testing.expect(std.mem.indexOf(u8, types_code, "address: Address") != null);
}
