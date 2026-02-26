const std = @import("std");

/// Root build script: orchestrates tests across all subpackages.
pub fn build(b: *std.Build) void {
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
