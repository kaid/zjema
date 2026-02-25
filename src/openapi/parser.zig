const std = @import("std");
const ast = @import("ast.zig");

/// Parsed OpenAPI with owned memory (arena)
pub const ParsedOpenApi = struct {
    spec: ast.OpenApiSpec,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
    }
};

/// Minimal stub parser - returns a placeholder OpenApiSpec.
/// Full implementation will come in later iterations.
pub fn parse(allocator: std.mem.Allocator, _json_data: []const u8) !ParsedOpenApi {
    _ = _json_data;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_alloc = arena.allocator();

    // Build minimal OpenApiSpec
    const info = ast.Info{
        .title = "Petstore API",
        .version = "1.0.0",
    };

    const paths = std.StringArrayHashMap(ast.PathItem).init(arena_alloc);
    const components: ?ast.Components = null;
    const servers = &.{};

    const spec = ast.OpenApiSpec{
        .openapi = "3.0.0",
        .info = info,
        .paths = paths,
        .components = components,
        .servers = servers,
    };

    return ParsedOpenApi{
        .spec = spec,
        .arena = arena,
    };
}
