const std = @import("std");
const zjema_openapi = @import("zjema_openapi");

test "client_generator produces valid client code" {
    const allocator = std.heap.page_allocator;

    // Build simple Person schema object
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

    const person_schema_obj = try allocator.create(zjema_openapi.SchemaObject);
    person_schema_obj.* = .{
        .type = "object",
        .properties = blk: {
            var map = try std.array_hash_map.String(zjema_openapi.Schema).init(allocator, &.{}, &.{});
            try map.put(allocator, "name", name_schema);
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
    var schemas = try std.array_hash_map.String(zjema_openapi.Schema).init(allocator, &.{}, &.{});
    try schemas.put(allocator, "Person", person_schema);

    const comp = zjema_openapi.Components{ .schemas = schemas };
    var paths = try std.array_hash_map.String(zjema_openapi.PathItem).init(allocator, &.{}, &.{});

    // Create response with Person
    // Add 200 response with JSON body
    const resp_200 = zjema_openapi.Response{
        .description = "User object",
        .content = blk: {
            var content_map = try std.array_hash_map.String(zjema_openapi.MediaType).init(allocator, &.{}, &.{});
            try content_map.put(allocator, "application/json", .{
                .schema = person_schema,
                .example = null,
            });
            break :blk content_map;
        },
    };
    var responses = try std.array_hash_map.String(zjema_openapi.Response).init(allocator, &.{}, &.{});
    try responses.put(allocator, "200", resp_200);

    // Create id parameter
    const id_schema_obj = try allocator.create(zjema_openapi.SchemaObject);
    id_schema_obj.* = .{
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
    const id_schema = zjema_openapi.Schema{ .object = id_schema_obj };
    const id_param = zjema_openapi.Parameter{
        .name = "id",
        .in = .path,
        .description = null,
        .required = true,
        .schema = id_schema,
    };

    // Allocate parameters array
    const parameters = try allocator.alloc(zjema_openapi.Parameter, 1);
    parameters[0] = id_param;

    const get_op = zjema_openapi.Operation{
        .operationId = "getUser",
        .summary = null,
        .description = null,
        .parameters = parameters,
        .requestBody = null,
        .responses = responses,
        .tags = &.{},
    };

    const path_item = zjema_openapi.PathItem{
        .get = get_op,
        .put = null,
        .post = null,
        .delete = null,
        .options = null,
        .head = null,
        .patch = null,
        .trace = null,
    };
    try paths.put(allocator, "/users/{id}", path_item);

    const spec = zjema_openapi.OpenApiSpec{
        .openapi = "3.0.0",
        .info = .{ .title = "Test API", .version = "1.0.0" },
        .paths = paths,
        .components = comp,
        .servers = &.{},
    };

    // Generate client code
    const gen = zjema_openapi.ClientGenerator.init(allocator);
    const code = try gen.generate(spec, .{});
    defer allocator.free(code);

    // Validate generated code
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn ApiClient(comptime Backend: type) type") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "pub fn getUser(self: *@This(), arena: std.mem.Allocator") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "backend = zjema_openapi.backend") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "return try json.decode(arena, ") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "if (resp.status_code < 200 or resp.status_code >= 300) return error.ApiError") != null);
    try std.testing.expect(std.mem.indexOf(u8, code, "PersonMapper") != null);
}
