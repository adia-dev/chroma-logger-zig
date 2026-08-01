const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const chroma = b.dependency("chroma", .{
        .target = target,
        .optimize = optimize,
    }).module("chroma");

    const logger = b.addModule("chroma-logger", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "chroma", .module = chroma },
        },
    });

    const example_module = b.createModule(.{
        .root_source_file = b.path("examples/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "chroma-logger", .module = logger },
        },
    });

    const example = b.addExecutable(.{
        .name = "chroma-logger-demo",
        .root_module = example_module,
    });
    b.installArtifact(example);

    const run_command = b.addRunArtifact(example);
    run_command.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_command.addArgs(args);

    const run_step = b.step("run", "Run the live logger demo");
    run_step.dependOn(&run_command.step);

    const library_tests = b.addTest(.{ .root_module = logger });
    const run_library_tests = b.addRunArtifact(library_tests);

    const example_tests = b.addTest(.{ .root_module = example_module });
    const run_example_tests = b.addRunArtifact(example_tests);

    const test_step = b.step("test", "Run unit and example tests");
    test_step.dependOn(&run_library_tests.step);
    test_step.dependOn(&run_example_tests.step);

    addCompileErrorTest(
        b,
        test_step,
        logger,
        target,
        optimize,
        "tests/compile_errors/invalid_offset.zig",
        "error: chroma-logger config: utc_offset_minutes must be between -1439 and 1439",
    );
    addCompileErrorTest(
        b,
        test_step,
        logger,
        target,
        optimize,
        "tests/compile_errors/newline_label.zig",
        "error: chroma-logger config: info label cannot contain a newline",
    );
    addCompileErrorTest(
        b,
        test_step,
        logger,
        target,
        optimize,
        "tests/compile_errors/unknown_message_style.zig",
        "error: chroma: unknown directive 'missing' at byte 2",
    );

    const benchmark_module = b.createModule(.{
        .root_source_file = b.path("benchmarks/compile.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "chroma-logger", .module = logger },
        },
    });
    const benchmark_compile = b.addTest(.{ .root_module = benchmark_module });

    const benchmark_step = b.step("benchmark", "Compile the logger stress fixture");
    benchmark_step.dependOn(&benchmark_compile.step);
}

fn addCompileErrorTest(
    b: *std.Build,
    test_step: *std.Build.Step,
    logger: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    path: []const u8,
    expected: []const u8,
) void {
    const fixture_module = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "chroma-logger", .module = logger },
        },
    });
    const fixture = b.addTest(.{ .root_module = fixture_module });
    fixture.expect_errors = .{ .contains = expected };
    test_step.dependOn(&fixture.step);
}
