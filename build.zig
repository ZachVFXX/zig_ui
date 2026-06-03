const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zclay_dep = b.dependency("zclay", .{ .target = target, .optimize = optimize });
    const raylib_dep = b.dependency("raylib", .{ .target = target, .optimize = optimize });
    const raylib = raylib_dep.artifact("raylib");
    raylib.root_module.addCMacro("SUPPORT_FILEFORMAT_JPG", "1");

    const my_module = b.addModule("zig_ui", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    my_module.addImport("zclay", zclay_dep.module("zclay"));
    my_module.linkLibrary(raylib);

    const freetype_dep = b.dependency("freetype", .{ .target = target, .optimize = optimize });
    const freetype = freetype_dep.artifact("freetype");
    my_module.linkLibrary(freetype);

    // module séparé pour le test
    const test_module = b.createModule(.{
        .root_source_file = b.path("test/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("zig_ui", my_module);

    const test_exe = b.addExecutable(.{
        .name = "test_app",
        .root_module = test_module,
    });
    b.installArtifact(test_exe);

    const run = b.addRunArtifact(test_exe);
    const run_step = b.step("test", "Run test app");
    run_step.dependOn(&run.step);
}
