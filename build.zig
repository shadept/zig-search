const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const search_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = search_mod,
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const examples_step = b.step("examples", "Build example applications");

    const examples = [_][]const u8{
        "connect4",
        "tictactoe",
    };

    inline for (examples) |example| {
        const example_mod = b.createModule(.{
            .root_source_file = b.path("examples/" ++ example ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });
        example_mod.addImport("search", search_mod);

        const example_exe = b.addExecutable(.{
            .name = example,
            .root_module = example_mod,
        });

        const example_run_cmd = b.addInstallArtifact(example_exe, .{});
        example_run_cmd.step.dependOn(b.getInstallStep());

        examples_step.dependOn(&example_run_cmd.step);

        const example_test = b.addTest(.{
            .root_module = example_mod,
            .target = target,
            .optimize = optimize,
        });

        const example_test_run = b.addRunArtifact(example_test);
        test_step.dependOn(&example_test_run.step);
    }
}
