const std = @import("std");
const zlinter = @import("zlinter");

const Build = std.Build;
const Target = Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;
const CompileStep = Build.Step.Compile;
const Import = Build.Module.Import;

const app_name = "gex";
const disabled_lint_rules = [_]zlinter.BuiltinLintRule{.require_doc_comment};

pub fn build(b: *Build) anyerror!void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const compile_step = addCompileStep(b, target, optimize);
    try addInstallStep(b, compile_step, target, optimize);
    addRunStep(b, compile_step);
    addTestStep(b, target, optimize);
    addLintStep(b);
}

fn addCompileStep(b: *Build, target: Target, optimize: Optimize) *CompileStep {
    const step = b.addExecutable(.{
        .name = app_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{sd3Import(b, target, optimize)},
        }),
    });
    return step;
}

fn addInstallStep(
    b: *Build,
    compile_step: *CompileStep,
    target: Target,
    optimize: Optimize,
) anyerror!void {
    const target_name = try target.result.linuxTriple(b.allocator);
    const path = try std.fs.path.join(b.allocator, &.{ @tagName(optimize), target_name });
    const step = b.addInstallArtifact(compile_step, .{
        .dest_dir = .{ .override = .{ .custom = path } },
    });
    b.getInstallStep().dependOn(&step.step);
}

fn addRunStep(b: *Build, compile_step: *CompileStep) void {
    b.step("run", "Run the application").dependOn(&b.addRunArtifact(compile_step).step);
}

fn addTestStep(b: *Build, target: Target, optimize: Optimize) void {
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{sd3Import(b, target, optimize)},
        }),
    });
    b.step("test", "Run tests").dependOn(&b.addRunArtifact(tests).step);
}

fn addLintStep(b: *Build) void {
    var builder = zlinter.builder(b, .{});
    inline for (@typeInfo(zlinter.BuiltinLintRule).@"enum".fields) |field| {
        const rule: zlinter.BuiltinLintRule = @enumFromInt(field.value);
        if (std.mem.indexOfScalar(zlinter.BuiltinLintRule, &disabled_lint_rules, rule) == null) {
            builder.addRule(.{ .builtin = rule }, .{});
        }
    }
    b.step("lint", "Lint source code.").dependOn(builder.build());
}

fn sd3Import(b: *Build, target: Target, optimize: Optimize) Import {
    const sdl3_dep = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .ext_image = false,
        .ext_net = false,
        .ext_ttf = false,
    });
    return .{ .name = "sdl3", .module = sdl3_dep.module("sdl3") };
}
