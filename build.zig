const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // Pure Zig
    const exe = b.addExecutable("handmade", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.linkLibC();
    exe.linkSystemLibrary("gdi32");

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Pure C
    const c_exe = b.addExecutable("c_handmade", null);
    c_exe.setTarget(target);
    c_exe.setBuildMode(mode);
    c_exe.install();
    c_exe.linkLibC();
    c_exe.linkSystemLibrary("gdi32");
    c_exe.linkSystemLibrary("user32");
    c_exe.addCSourceFiles(&.{"src/main.c"}, &.{});

    const run_c_cmd = c_exe.run();
    run_c_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_c_cmd.addArgs(args);
    }
    const run_c_step = b.step("runc", "Run the C app");
    run_c_step.dependOn(&run_c_cmd.step);

    // Translated C to Zig
    // const t_exe = b.addExecutable("t_handmade", "src/translated.zig");
    // t_exe.setTarget(target);
    // t_exe.setBuildMode(mode);
    // t_exe.install();
    // t_exe.linkLibC();
    // t_exe.linkSystemLibrary("gdi32");
    // t_exe.linkSystemLibrary("user32");

    // const run_t_cmd = t_exe.run();
    // run_t_cmd.step.dependOn(b.getInstallStep());
    // if (b.args) |args| {
    //     run_t_cmd.addArgs(args);
    // }
    // const run_t_step = b.step("runt", "Run the translated app");
    // run_t_step.dependOn(&run_t_cmd.step);
}
