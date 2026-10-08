const std = @import("std");
const engine = @import("engine.zig");
const presets = @import("preset.zig");
const files = @import("files.zig");
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var p: engine.Parameters = .{};
    if (args.len > 1) {
        var buffer: [8192]u8 = undefined;
        const bytes = try files.read(args[1], &buffer);
        var parsed = try presets.parse(init.gpa, bytes);
        defer parsed.deinit();
        p = parsed.value.parameters;
    }
    var e: engine.Engine = .{ .current = p, .target = p, .triangle_mix = if (p.waveform == .triangle) 1 else 0 };
    var pcm: [44100]i16 = undefined;
    e.key(true);
    for (&pcm, 0..) |*s, i| {
        if (i == 22050) e.key(false);
        s.* = e.pcm();
    }
    try files.wav(if (args.len > 2) args[2] else "tone.wav", &pcm);
    var header: [2048]u8 = undefined;
    try files.write(if (args.len > 3) args[3] else ".zig-cache/baseline.h", try presets.header(&header, .{ .parameters = p }));
}
