const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zjview",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize
    });

    // This is crucial for WASM
    exe.entry = .disabled;
    exe.rdynamic = true;

    b.installArtifact(exe);
}
