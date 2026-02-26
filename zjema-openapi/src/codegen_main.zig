// zjema-openapi CLI: code generation tool
// Usage: zjema-codegen <openapi.json> <output.zig> [--sse] [--no-union]
// Build: zig build codegen

const std = @import("std");
const zjema_openapi = @import("zjema_openapi");

pub fn main(init: std.process.Init) anyerror!void {
    const arena = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 3) {
        usage();
        return;
    }

    const spec_path = args[1];
    const output_path = args[2];

    // Parse options
    var enable_sse = false;
    var use_union_for_oneof = true;

    var i: usize = 3;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--sse")) {
            enable_sse = true;
        } else if (std.mem.eql(u8, args[i], "--no-union")) {
            use_union_for_oneof = false;
        } else {
            std.debug.print("Unknown option: {s}\n", .{args[i]});
            usage();
            return;
        }
    }

    // Read OpenAPI spec
    const cwd = std.Io.Dir.cwd();
    const spec_data = try cwd.readFileAlloc(io, spec_path, arena, std.Io.Limit.limited(1024 * 1024));

    // Parse OpenAPI JSON
    var parsed = zjema_openapi.parse(arena, spec_data) catch |err| {
        std.debug.print("Error parsing OpenAPI spec: {s}\n", .{@errorName(err)});
        usage();
        return err;
    };
    defer parsed.deinit();

    // Generate client code
    const gen = zjema_openapi.ClientGenerator.init(arena);
    const code = gen.generate(parsed.spec, .{
        .enable_sse = enable_sse,
        .use_union_for_oneof = use_union_for_oneof,
    }) catch |err| {
        std.debug.print("Error generating code: {s}\n", .{@errorName(err)});
        usage();
        return err;
    };

    // Write output file
    try cwd.writeFile(io, .{
        .sub_path = output_path,
        .data = code,
    });

    std.debug.print("Generated {s} ({d} bytes)\n", .{output_path, code.len});
}

fn usage() void {
    std.debug.print("Usage: zjema-codegen <openapi.json> <output.zig> [--sse] [--no-union]\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  --sse          Enable Server-Sent Events support\n", .{});
    std.debug.print("  --no-union     Do not generate union(enum) for oneOf\n", .{});
}
