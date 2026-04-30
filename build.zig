const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zclay_dep = b.dependency("zclay", .{ .target = target, .optimize = optimize });
    const raylib_dep = b.dependency("raylib", .{ .target = target, .optimize = optimize });
    const raylib = raylib_dep.artifact("raylib");
    raylib.root_module.addCMacro("SUPPORT_FILEFORMAT_JPG", "1");
    const my_module = b.addModule("zig_ui", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    my_module.addImport("zclay", zclay_dep.module("zclay"));
    my_module.linkLibrary(raylib);

    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = my_module,
    });

    const run_tests = b.addRunArtifact(exe);
    const test_step = b.step("run", "Run test app");
    test_step.dependOn(&run_tests.step);
}
