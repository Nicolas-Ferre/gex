const std = @import("std");
const zlinter = @import("zlinter");

const Build = std.Build;
const Step = Build.Step;
const Import = Build.Module.Import;
const Target = Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;

const app_name = "gex";
const disabled_lint_rules = [_]zlinter.BuiltinLintRule{
    .import_ordering,
    .require_doc_comment,
};

pub fn build(b: *Build) anyerror!void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const compile_step = addCompileStep(b, target, optimize);
    const install_step = try addInstallStep(b, compile_step, target, optimize);
    const run_step = addRunStep(b, compile_step);
    const test_step = addTestStep(b, target, optimize, .normal);
    const valgrind_step = addTestStep(b, target, optimize, .valgrind);
    const lint_step = addLintStep(b);
    b.getInstallStep().dependOn(&install_step.step);
    b.step("run", "Run the application").dependOn(&run_step.step);
    b.step("test", "Run tests").dependOn(&test_step.step);
    b.step("valgrind", "Run valgrind on tests").dependOn(&valgrind_step.step);
    b.step("lint", "Lint source code").dependOn(lint_step);
}

fn addCompileStep(b: *Build, target: Target, optimize: Optimize) *Step.Compile {
    return b.addExecutable(.{
        .name = app_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{sdl3Import(b, target, optimize)},
        }),
    });
}

fn addInstallStep(
    b: *Build,
    compile_step: *Step.Compile,
    target: Target,
    optimize: Optimize,
) anyerror!*Step.InstallArtifact {
    const target_name = try target.result.linuxTriple(b.allocator);
    const path = try std.fs.path.join(b.allocator, &.{ @tagName(optimize), target_name });
    return b.addInstallArtifact(compile_step, .{
        .dest_dir = .{ .override = .{ .custom = path } },
    });
}

fn addRunStep(b: *Build, compile_step: *Step.Compile) *Step.Run {
    return b.addRunArtifact(compile_step);
}

fn addTestStep(b: *Build, target: Target, optimize: Optimize, mode: TestMode) *Step.Run {
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{sdl3Import(b, target, optimize)},
        }),
    });
    if (mode == .valgrind) {
        tests.setExecCmd(&[_]?[]const u8{
            "valgrind",
            "--track-origins=yes",
            "--leak-check=full",
            "--show-leak-kinds=all",
            "--errors-for-leak-kinds=all",
            "--error-exitcode=1",
            null,
        });
    }
    return b.addRunArtifact(tests);
}

fn addLintStep(b: *Build) *Step {
    var builder = zlinter.builder(b, .{});
    inline for (@typeInfo(zlinter.BuiltinLintRule).@"enum".fields) |field| {
        const rule: zlinter.BuiltinLintRule = @enumFromInt(field.value);
        if (std.mem.indexOfScalar(zlinter.BuiltinLintRule, &disabled_lint_rules, rule) == null) {
            builder.addRule(.{ .builtin = rule }, .{});
        }
    }
    return builder.build();
}

fn sdl3Import(b: *Build, target: Target, optimize: Optimize) Import {
    const sdl3_dep = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
        .ext_image = false,
        .ext_net = false,
        .ext_ttf = false,
    });
    return .{ .name = "sdl3", .module = sdl3_dep.module("sdl3") };
}

const TestMode = enum {
    normal,
    valgrind,
};
