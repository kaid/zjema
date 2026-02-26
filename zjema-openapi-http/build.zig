const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const zjema_dep = b.dependency("zjema", .{});
    const zjema_mod = zjema_dep.module("zjema");

    const openapi_dep = b.dependency("zjema_openapi", .{});
    const openapi_mod = openapi_dep.module("zjema_openapi");

    // Create and register the http module
    const http_mod = b.addModule("zjema_openapi_http", .{
        .root_source_file = b.path("src/zjema-openapi-http.zig"),
        .imports = &.{
            .{ .name = "zjema", .module = zjema_mod },
            .{ .name = "zjema_openapi", .module = openapi_mod },
        },
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "zjema-openapi-http",
        .root_module = http_mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Tests
    const test_step = b.step("test", "Run zjema-openapi-http tests");

    const test_files = &[_][]const u8{
        "tests/backend_test.zig",
        "tests/sse_integration_test.zig",
    };

    for (test_files) |test_file| {
        const test_mod_name = b.fmt("test-{s}", .{std.fs.path.stem(test_file)});
        const test_mod = b.addModule(test_mod_name, .{
            .root_source_file = b.path(test_file),
            .imports = &.{
                .{ .name = "zjema", .module = zjema_mod },
                .{ .name = "zjema_openapi", .module = openapi_mod },
                .{ .name = "zjema_openapi_http", .module = http_mod },
            },
            .target = target,
            .optimize = optimize,
        });
        const t = b.addTest(.{
            .root_module = test_mod,
        });
        const run = b.addRunArtifact(t);
        const step = b.step(test_mod_name, test_mod_name);
        step.dependOn(&run.step);
        test_step.dependOn(step);
    }
}
