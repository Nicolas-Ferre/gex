const std = @import("std");
const Build = std.Build;
const Target = Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;
const CompileStep = Build.Step.Compile;
const Import = Build.Module.Import;

const APP_NAME = "gex";

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const compute_step = try add_compile_step(b, target, optimize);
    try add_install_step(b, compute_step, target, optimize);
    add_run_step(b, compute_step);
    add_test_step(b, target, optimize);
}

fn add_compile_step(b: *Build, target: Target, optimize: Optimize) !*CompileStep {
    const step = b.addExecutable(.{
        .name = APP_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{sdl3_import(b, target, optimize)},
        }),
    });
    return step;
}

fn add_install_step(b: *Build, compute_step: *CompileStep, target: Target, optimize: Optimize) !void {
    const targetName = try target.result.linuxTriple(b.allocator);
    const path = try std.fs.path.join(b.allocator, &.{ @tagName(optimize), targetName });
    const step = b.addInstallArtifact(compute_step, .{ .dest_dir = .{ .override = .{ .custom = path } } });
    b.getInstallStep().dependOn(&step.step);
}

fn add_run_step(b: *Build, compute_step: *CompileStep) void {
    b.step("run", "Run the application").dependOn(&b.addRunArtifact(compute_step).step);
}

fn add_test_step(b: *Build, target: Target, optimize: Optimize) void {
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{sdl3_import(b, target, optimize)},
        }),
    });
    b.step("test", "Run tests").dependOn(&b.addRunArtifact(tests).step);
}

fn sdl3_import(b: *Build, target: Target, optimize: Optimize) Import {
    const sdl3_dep = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .ext_image = false,
        .ext_net = false,
        .ext_ttf = false,
    });
    return .{ .name = "sdl3", .module = sdl3_dep.module("sdl3") };
}
