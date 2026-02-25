const std = @import("std");
const zjema = @import("zjema");

test "generate petstore client from OpenAPI spec" {
    const allocator = std.testing.allocator;

    // Load petstore spec
    const spec_json = @embedFile("petstore.json");

    // Parse OpenAPI
    var parsed = try zjema.openapi.parser.parse(allocator, spec_json);
    defer parsed.deinit();
    const spec = &parsed.spec;

    // Generate full client code
    const generator = zjema.ClientGenerator.init(allocator);
    const client_code = try generator.generate(spec);
    defer allocator.free(client_code);

    // Verify generated code contains expected content
    try std.testing.expect(std.mem.indexOf(u8, client_code, "ApiClient") != null);
    try std.testing.expect(std.mem.indexOf(u8, client_code, "getUser") != null);
    try std.testing.expect(std.mem.indexOf(u8, client_code, "createUser") != null);
    try std.testing.expect(std.mem.indexOf(u8, client_code, "deleteUser") != null);

    // Ensure Pet type is generated
    try std.testing.expect(std.mem.indexOf(u8, client_code, "pub const Pet") != null);

    // Ensure it's valid Zig syntax by checking for balanced braces (rough check)
    var brace_count: i32 = 0;
    for (client_code) |c| {
        if (c == '{') brace_count += 1;
        if (c == '}') brace_count -= 1;
    }
    try std.testing.expect(brace_count == 0);
}
