const std = @import("std");
const dsp = @import("engine.zig");
const Queue = @import("queue.zig").Queue;
pub const Command = struct { parameters: dsp.Parameters, playing: bool, duration: u32 = 0 };
pub var commands: Queue(Command, 64) = .{};
pub var monitor: Queue(f32, 8192) = .{};
pub var underruns: std.atomic.Value(u32) = .init(0);
pub var dropped_monitor: std.atomic.Value(u32) = .init(0);
var engine: dsp.Engine = .{};
var remaining: u32 = 0;
extern fn tone_audio_open() c_int;
extern fn tone_audio_close() void;
pub fn open() !void {
    if (tone_audio_open() != 0) return error.AudioInitializationFailed;
}
pub fn close() void {
    tone_audio_close();
}
export fn tone_audio_render(output: [*]f32, count: u32, late: c_int) void {
    if (late != 0) _ = underruns.fetchAdd(1, .monotonic);
    // Bounded drain: producer cannot prolong callback indefinitely.
    for (0..64) |_| {
        const c = commands.pop() orelse break;
        engine.configure(c.parameters) catch {};
        engine.key(c.playing);
        remaining = c.duration;
    }
    for (output[0..count]) |*s| {
        if (remaining > 0) {
            remaining -= 1;
            if (remaining == 0) engine.key(false);
        }
        s.* = engine.next();
        if (!monitor.push(s.*)) _ = dropped_monitor.fetchAdd(1, .monotonic);
    }
}
