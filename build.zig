const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the zjema library module
    const lib_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Test runner
    const test_step = b.step("test", "Run all tests");

    const test_files = &[_][]const u8{
        "tests/basic.zig",
        "tests/petstore_test.zig",
    };

    for (test_files) |test_file| {
        // Create test module with target/optimize and import zjema
        const test_module = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zjema", .module = lib_module },
            },
        });

        const t = b.addTest(.{
            .root_module = test_module,
        });

        const run = b.addRunArtifact(t);
        run.step.dependOn(b.getInstallStep());

        const test_name = std.fs.path.stem(test_file);
        const desc = b.fmt("Run test: {s}", .{test_name});
        const step_name = b.fmt("test-{s}", .{test_name});
        const step = b.step(step_name, desc);
        step.dependOn(&run.step);
        test_step.dependOn(step);
    }
}
