const std = @import("std");
const dsp = @import("engine.zig");
extern fn reference_init() void;
extern fn reference_key(c_int) void;
extern fn reference_update(f32, f32) void;
extern fn reference_next() i16;
fn magnitude(p: dsp.Parameters, harmonic: f32) f32 {
    var e: dsp.Engine = .{ .current = p, .target = p, .envelope = 1, .goal = 1, .down = true, .length = 0 };
    var real: f64 = 0;
    var imag: f64 = 0;
    for (0..44100) |i| {
        const sample = e.next();
        const phase = 2 * std.math.pi * harmonic * p.frequency_hz * @as(f64, @floatFromInt(i)) / 44100;
        real += sample * @cos(phase);
        imag += sample * @sin(phase);
    }
    return @floatCast(2 * @sqrt(real * real + imag * imag) / 44100);
}
test "frequency precision and harmonic ratios" {
    const p: dsp.Parameters = .{ .frequency_hz = 441, .harmonic_2 = 0.1, .harmonic_3 = 0.05, .gain = 1 };
    const fundamental = magnitude(p, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 1.15), fundamental, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), magnitude(p, 2) / fundamental, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), magnitude(p, 3) / fundamental, 0.001);
    var e: dsp.Engine = .{ .current = p, .target = p };
    e.key(true);
    var crossings: usize = 0;
    var last: f32 = 0;
    for (0..44100) |_| {
        const s = e.next();
        if (last <= 0 and s > 0) crossings += 1;
        last = s;
    }
    try std.testing.expect(crossings >= 440 and crossings <= 442);
}
test "Zig versus portable C PCM including dynamic update" {
    var e: dsp.Engine = .{};
    reference_init();
    e.key(true);
    reference_key(1);
    var max_error: i32 = 0;
    for (0..44100) |i| {
        if (i == 10000) {
            e.target.frequency_hz = 800;
            e.target.harmonic_2 = 0.15;
            reference_update(800, 0.15);
        }
        if (i == 20000) {
            e.key(false);
            reference_key(0);
        }
        const diff = @abs(@as(i32, e.pcm()) - @as(i32, reference_next()));
        max_error = @max(max_error, @as(i32, @intCast(diff)));
    }
    try std.testing.expect(max_error <= 3);
}
test "block size independent generation and parameter boundaries" {
    var a: dsp.Engine = .{};
    var b: dsp.Engine = .{};
    a.key(true);
    b.key(true);
    for (0..20000) |_| try std.testing.expectEqual(a.pcm(), b.pcm());
    try (dsp.Parameters{ .frequency_hz = 200, .gain = 0, .attack_ms = 0, .release_ms = 0 }).validate();
    try (dsp.Parameters{ .frequency_hz = 1200, .harmonic_2 = 0.2, .harmonic_3 = 0.15, .attack_ms = 50, .release_ms = 100, .gain = 1, .waveform = .triangle }).validate();
    try std.testing.expectError(error.InvalidParameter, (dsp.Parameters{ .gain = std.math.nan(f32) }).validate());
}
