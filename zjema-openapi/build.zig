const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependency on zjema core
    const zjema_dep = b.dependency("zjema", .{});
    const zjema_mod = zjema_dep.module("zjema");

    // Create and register the openapi module
    const openapi_mod = b.addModule("zjema_openapi", .{
        .root_source_file = b.path("src/zjema-openapi.zig"),
        .imports = &.{
            .{ .name = "zjema", .module = zjema_mod },
        },
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "zjema-openapi",
        .root_module = openapi_mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Codegen CLI tool
    const codegen_mod = b.addModule("codegen", .{
        .root_source_file = b.path("src/codegen_main.zig"),
        .imports = &.{
            .{ .name = "zjema_openapi", .module = openapi_mod },
        },
        .target = target,
        .optimize = optimize,
    });
    const codegen_exe = b.addExecutable(.{
        .name = "zjema-codegen",
        .root_module = codegen_mod,
    });
    // Install the codegen tool
    b.installArtifact(codegen_exe);

    // Custom step for running codegen (users can: zig build codegen)
    const codegen_step = b.step("codegen", "Generate OpenAPI client code");
    codegen_step.dependOn(&codegen_exe.step);

    // Tests
    const test_step = b.step("test", "Run zjema-openapi tests");
    test_step.dependOn(&codegen_exe.step);

    const test_files = &[_][]const u8{
        "tests/parser_test.zig",
        "tests/type_generator_test.zig",
        "tests/client_generator_test.zig",
    };

    for (test_files) |test_file| {
        const test_mod_name = b.fmt("test-{s}", .{std.fs.path.stem(test_file)});
        const test_mod = b.addModule(test_mod_name, .{
            .root_source_file = b.path(test_file),
            .imports = &.{
                .{ .name = "zjema", .module = zjema_mod },
                .{ .name = "zjema_openapi", .module = openapi_mod },
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
