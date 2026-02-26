const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zjema_openapi_dep = b.dependency("zjema_openapi", .{});
    const zjema_openapi_mod = zjema_openapi_dep.module("zjema_openapi");

    // 1. Generate the API client code at build time
    const codegen_exe = zjema_openapi_dep.artifact("zjema-codegen");
    const gen_cmd = b.addRunArtifact(codegen_exe);
    gen_cmd.addArg("spec.json");
    gen_cmd.addArg("src/generated_api.zig");
    // gen_cmd.addArg("--sse"); // optional

    // Ensure generation runs before compiling the exe
    const generate_step = b.step("generate", "Generate API client from OpenAPI spec");
    generate_step.dependOn(&gen_cmd.step);

    // 2. Build the example executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "petstore-example",
        .root_module = exe_mod,
    });

    // Import the generated code (created by codegen step)
    exe.root_module.addImport("generated_api", b.createModule(.{
        .root_source_file = b.path("src/generated_api.zig"),
        .target = target,
        .optimize = optimize,
    }));

    // Import required dependencies for generated_api
    exe.root_module.addImport("zjema_openapi", zjema_openapi_mod);
    exe.root_module.addImport("izomorph", b.createModule(.{
        .root_source_file = b.path("../../../izomorph/src/root.zig"),
        .target = target,
        .optimize = optimize,
    }));

    // Optionally use StdHttpBackend from zjema-openapi-http
    // exe.root_module.addImport("http", b.dependency("zjema_openapi_http", .{}).module("zjema_openapi_http"));

    b.installArtifact(exe);

    // Make the exe depend on code generation
    exe.step.dependOn(&gen_cmd.step);
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the petstore example");
    run_step.dependOn(&run_cmd.step);
}
