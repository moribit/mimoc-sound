const std = @import("std");
const dsp = @import("engine.zig");
const Queue = @import("queue.zig").Queue;
pub const Command = struct { parameters: dsp.Parameters, playing: bool, duration: u32 = 0, pattern: ?@import("morse.zig").Pattern = null, loop_pattern: bool = false, restart: bool = true };
pub var commands: Queue(Command, 64) = .{};
pub var monitor: Queue(f32, 8192) = .{};
pub var playback_state: std.atomic.Value(u32) = .init(0);
var sequence: u31 = 0;
pub var underruns: std.atomic.Value(u32) = .init(0);
pub var dropped_monitor: std.atomic.Value(u32) = .init(0);
var engine: dsp.Engine = .{};
var remaining: u32 = 0;
var one_shot = false;
var pattern: ?@import("morse.zig").Pattern = null;
var event_index: usize = 0;
var event_left: u32 = 0;
var repeat: bool = false;
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
        sequence +%= 1;
        engine.configure(c.parameters) catch {};
        repeat = c.loop_pattern;
        if (!c.restart) continue;
        engine.key(c.playing);
        remaining = c.duration;
        one_shot = c.duration > 0;
        pattern = c.pattern;
        event_index = 0;
        event_left = 0;
        repeat = c.loop_pattern;
    }
    for (output[0..count]) |*s| {
        if (pattern) |*p| {
            if (event_left == 0) {
                if (event_index == p.len) {
                    if (repeat) event_index = 0 else {
                        pattern = null;
                        engine.key(false);
                    }
                }
                if (pattern != null) {
                    const event = p.events[event_index];
                    engine.key(event.down);
                    event_left = event.frames;
                    event_index += 1;
                }
            }
            if (event_left > 0) event_left -= 1;
        }
        if (remaining > 0) {
            remaining -= 1;
        }
        s.* = engine.next();
        if (remaining == 0 and pattern == null and engine.down and one_shot) {
            engine.key(false);
            one_shot = false;
        }
        if (!monitor.push(s.*)) _ = dropped_monitor.fetchAdd(1, .monotonic);
    }
    playback_state.store((@as(u32, sequence) << 1) | @intFromBool(pattern != null or engine.down or engine.envelope > 0), .release);
}

test "render silence, live updates, stop and late detection" {
    commands = .{};
    monitor = .{};
    engine = .{};
    pattern = null;
    remaining = 0;
    var output: [512]f32 = undefined;
    tone_audio_render(&output, 512, 0);
    for (output) |s| try std.testing.expectEqual(@as(f32, 0), s);
    try std.testing.expect(commands.push(.{ .parameters = .{}, .playing = true }));
    tone_audio_render(&output, 512, 0);
    var peak: f32 = 0;
    for (output) |s| peak = @max(peak, @abs(s));
    try std.testing.expect(peak > 0.2);
    try std.testing.expect(commands.push(.{ .parameters = .{ .frequency_hz = 800 }, .playing = true, .restart = false }));
    tone_audio_render(&output, 512, 1);
    try std.testing.expect(engine.current.frequency_hz > 700);
    try std.testing.expect(underruns.load(.monotonic) > 0);
    try std.testing.expect(commands.push(.{ .parameters = .{}, .playing = false }));
    tone_audio_render(&output, 512, 0);
    try std.testing.expectEqual(@as(f32, 0), output[511]);
}

test "one-shot ends and parameter updates preserve deadline" {
    commands = .{};
    monitor = .{};
    engine = .{};
    pattern = null;
    remaining = 0;
    one_shot = false;
    sequence = 0;
    var output: [512]f32 = undefined;
    try std.testing.expect(commands.push(.{ .parameters = .{}, .playing = true, .duration = 600 }));
    tone_audio_render(&output, 512, 0);
    try std.testing.expect(commands.push(.{ .parameters = .{ .frequency_hz = 900 }, .playing = true, .restart = false }));
    tone_audio_render(&output, 512, 0);
    try std.testing.expectEqual(@as(u32, 4), playback_state.load(.acquire));
    try std.testing.expectEqual(@as(f32, 0), output[511]);
}
