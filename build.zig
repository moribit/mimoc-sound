const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const engine = b.createModule(.{ .root_source_file = b.path("src/engine.zig"), .target = target, .optimize = optimize });
    const render = b.addExecutable(.{ .name = "tone-render", .root_module = b.createModule(.{ .root_source_file = b.path("src/render.zig"), .target = target, .optimize = optimize, .link_libc = true }) });
    b.installArtifact(render);
    const test_step = b.step("test", "DSP and application tests");
    inline for (.{ "queue", "morse", "analysis", "preset", "audio", "quality" }) |name| {
        const module = b.createModule(.{ .root_source_file = b.path("src/" ++ name ++ ".zig"), .target = target, .optimize = optimize });
        if (comptime std.mem.eql(u8, name, "quality")) module.addCSourceFile(.{ .file = b.path("tests/reference_bridge.c"), .flags = &.{"-ffp-contract=off"} });
        module.link_libc = true;
        module.addIncludePath(b.path("integration"));
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = module })).step);
    }
    test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = engine })).step);
    if (target.result.os.tag == .macos) {
        const app = b.addExecutable(.{ .name = "tone-studio", .root_module = b.createModule(.{ .root_source_file = b.path("src/studio.zig"), .target = target, .optimize = optimize, .link_libc = true }) });
        app.root_module.addImport("mimoc_ui", b.createModule(.{ .root_source_file = b.path("vendor/mimoc-ui/src/root.zig"), .target = target, .optimize = optimize }));
        app.root_module.addCSourceFile(.{ .file = b.path("platform/dialogs.m"), .flags = &.{"-fobjc-arc"} });
        app.root_module.addCSourceFile(.{ .file = b.path("platform/audio.c"), .flags = &.{} });
        app.root_module.addCSourceFile(.{ .file = b.path("vendor/mimoc-ui/src/platform/macos/canvas.m"), .flags = &.{"-fobjc-arc"} });
        app.root_module.linkFramework("AppKit", .{});
        app.root_module.linkFramework("AudioUnit", .{});
        app.root_module.linkFramework("CoreAudio", .{});
        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = app.root_module })).step);
        b.installArtifact(app);
        const run = b.addRunArtifact(app);
        b.step("run", "Run Tone Studio").dependOn(&run.step);
    }
}
