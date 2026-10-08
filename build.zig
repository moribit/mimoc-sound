const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const engine = b.createModule(.{ .root_source_file = b.path("src/engine.zig"), .target = target, .optimize = optimize });
    const render = b.addExecutable(.{ .name = "tone-render", .root_module = b.createModule(.{ .root_source_file = b.path("src/render.zig"), .target = target, .optimize = optimize, .link_libc = true }) });
    b.installArtifact(render);
    const test_step = b.step("test", "DSP and application tests");
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = engine })).step);
}
