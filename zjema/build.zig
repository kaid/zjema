const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const izomorph_dep = b.dependency("izomorph", .{
        .target = target,
        .optimize = optimize,
    });

    // Core module
    const zjema_mod = b.addModule("zjema", .{
        .root_source_file = b.path("src/zjema.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "izomorph", .module = izomorph_dep.module("izomorph") },
        },
    });

    const lib = b.addLibrary(.{
        .name = "zjema",
        .root_module = zjema_mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Tests
    const test_step = b.step("test", "Run zjema tests");

    // 1. Library internal tests (test blocks inside src/*.zig)
    const core_tests = b.addTest(.{
        .root_module = zjema_mod,
    });
    const run_core = b.addRunArtifact(core_tests);
    test_step.dependOn(&run_core.step);

    // 2. External test files in tests/ directory
    const test_files = &[_][]const u8{
        "tests/codegen_test.zig",
    };

    for (test_files) |test_file| {
        const mod_name = b.fmt("test-{s}", .{std.fs.path.stem(test_file)});
        const test_mod = b.addModule(mod_name, .{
            .root_source_file = b.path(test_file),
            .imports = &.{
                .{ .name = "zjema", .module = zjema_mod },
            },
            .target = target,
            .optimize = optimize,
        });
        const t = b.addTest(.{ .root_module = test_mod });
        const run = b.addRunArtifact(t);
        const step = b.step(mod_name, mod_name);
        step.dependOn(&run.step);
        test_step.dependOn(step);
    }
}
