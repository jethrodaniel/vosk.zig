const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vosk_dep = b.dependency("vosk", .{
        .target = target,
        .optimize = .ReleaseFast,
    });
    const model_dep = b.dependency("vosk_model_small_en_us_0_15", .{});
    const vosk_src_dep = b.dependency("vosk_src", .{});

    //--

    const exe = b.addExecutable(.{
        .name = "example-exe",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    {
        exe.root_module.addImport("vosk", vosk_dep.module("vosk"));

        b.installArtifact(exe);

        const run = b.addRunArtifact(exe);
        run.addFileArg(model_dep.path(""));
        run.addFileArg(vosk_src_dep.path("python/example/test.wav"));

        const step = b.step("run", "Run the example");
        step.dependOn(&run.step);
    }

    {
        const tests = b.addTest(.{
            .root_source_file = .{ .path = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        });
        tests.root_module.addImport("vosk", vosk_dep.module("vosk"));

        const run = b.addRunArtifact(tests);
        const step = b.step("test", "Run unit tests");
        step.dependOn(&run.step);
    }
}
