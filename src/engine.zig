const std = @import("std");
pub const Waveform = enum { sine, triangle };
pub const Parameters = struct {
    frequency_hz: f32 = 450,
    harmonic_2: f32 = 0.025,
    harmonic_3: f32 = 0,
    attack_ms: f32 = 3,
    release_ms: f32 = 4,
    gain: f32 = 0.24,
    waveform: Waveform = .sine,
    pub fn validate(p: Parameters) !void {
        const values = .{ p.frequency_hz, p.harmonic_2, p.harmonic_3, p.attack_ms, p.release_ms, p.gain };
        const lows = .{ 200, 0, 0, 0, 0, 0 };
        const highs = .{ 1200, 0.2, 0.15, 50, 100, 1 };
        inline for (values, lows, highs) |v, lo, hi| if (!std.math.isFinite(v) or v < lo or v > hi) return error.InvalidParameter;
    }
};
pub const Engine = struct {
    rate: f32 = 44100,
    phase: f32 = 0,
    current: Parameters = .{},
    target: Parameters = .{},
    triangle_mix: f32 = 0,
    envelope: f32 = 0,
    from: f32 = 0,
    goal: f32 = 0,
    position: u32 = 0,
    length: u32 = 2,
    down: bool = false,
    pub fn configure(e: *Engine, p: Parameters) !void {
        try p.validate();
        e.target = p;
    }
    pub fn key(e: *Engine, down: bool) void {
        if (e.down == down) return;
        e.down = down;
        e.from = e.envelope;
        e.goal = if (down) 1 else 0;
        e.position = 0;
        // Minimum 1ms de-click even when the requested envelope is zero.
        e.length = @max(2, @as(u32, @intFromFloat(e.rate * @max(1, if (down) e.target.attack_ms else e.target.release_ms) / 1000)));
    }
    pub fn next(e: *Engine) f32 {
        const alpha = 1 - @exp(-1 / (0.005 * e.rate));
        inline for (.{ "frequency_hz", "harmonic_2", "harmonic_3", "gain" }) |field| @field(e.current, field) += alpha * (@field(e.target, field) - @field(e.current, field));
        e.triangle_mix += alpha * (@as(f32, if (e.target.waveform == .triangle) 1 else 0) - e.triangle_mix);
        if (e.position < e.length) {
            const t = @as(f32, @floatFromInt(e.position)) / @as(f32, @floatFromInt(e.length - 1));
            e.envelope = e.from + (e.goal - e.from) * t * t * (3 - 2 * t);
            e.position += 1;
        } else e.envelope = e.goal;
        const tau: f32 = 2 * std.math.pi;
        const sine = @sin(e.phase);
        const tri = 1 - 4 * @abs(e.phase / tau - 0.5);
        const p = e.current;
        const wave = (sine + e.triangle_mix * (tri - sine) + p.harmonic_2 * @sin(2 * e.phase) + p.harmonic_3 * @sin(3 * e.phase)) / (1 + p.harmonic_2 + p.harmonic_3);
        const sample = wave * p.gain * e.envelope;
        e.phase += tau * p.frequency_hz / e.rate;
        if (e.phase >= tau) e.phase -= tau;
        return std.math.clamp(sample, -1, 1);
    }
    pub fn pcm(e: *Engine) i16 {
        return @intFromFloat(e.next() * 32767);
    }
};
test "baseline, release and bounded long generation" {
    var e: Engine = .{};
    e.key(true);
    var peak: f32 = 0;
    for (0..2646000) |_| {
        const s = e.next();
        try std.testing.expect(std.math.isFinite(s));
        peak = @max(peak, @abs(s));
    }
    try std.testing.expect(peak < 0.241 and peak > 0.23);
    e.key(false);
    for (0..4410) |_| _ = e.next();
    try std.testing.expectEqual(@as(f32, 0), e.next());
}
test "validation and continuous phase" {
    var e: Engine = .{};
    try std.testing.expectError(error.InvalidParameter, e.configure(.{ .gain = 2 }));
    _ = e.next();
    const phase = e.phase;
    try e.configure(.{ .frequency_hz = 1200, .harmonic_2 = 0.2, .harmonic_3 = 0.15, .gain = 1 });
    try std.testing.expectEqual(phase, e.phase);
    e.key(true);
    for (0..44100) |_| try std.testing.expect(@abs(e.next()) <= 1);
}
