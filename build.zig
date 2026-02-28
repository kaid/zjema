const std = @import("std");

/// Root build script: orchestrates tests across all subpackages.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get izomorph dependency
    const izo_dep = b.dependency("izomorph", .{});

    // Expose modules for dependent packages
    // Note: These modules are used when this package is a dependency.
    // The subpackages use their own build.zig when built standalone.
    const zjema_mod = b.addModule("zjema", .{
        .root_source_file = b.path("zjema/src/zjema.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "izomorph", .module = izo_dep.module("izomorph") },
        },
    });

    const zjema_openapi_mod = b.addModule("zjema_openapi", .{
        .root_source_file = b.path("zjema-openapi/src/zjema-openapi.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zjema", .module = zjema_mod },
        },
    });

    _ = b.addModule("zjema_openapi_http", .{
        .root_source_file = b.path("zjema-openapi-http/src/zjema-openapi-http.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zjema", .module = zjema_mod },
            .{ .name = "zjema_openapi", .module = zjema_openapi_mod },
        },
    });

    const test_step = b.step("test", "Run all tests for all packages");

    const packages = &[_][]const u8{
        "zjema",
        "zjema-openapi",
        "zjema-openapi-http",
    };

    for (packages) |pkg| {
        const cmd = b.addSystemCommand(&.{ "zig", "build", "test" });
        cmd.cwd = b.path(pkg);

        const step_name = b.fmt("test-{s}", .{pkg});
        const step = b.step(step_name, b.fmt("Run tests in {s}", .{pkg}));
        step.dependOn(&cmd.step);
        test_step.dependOn(&cmd.step);
    }
}
