const std = @import("std");
pub const N = 1024;
pub fn spectrum(samples: *const [N]f32, magnitudes: *[N / 2]f32) void {
    var re: [N]f32 = undefined;
    var im: [N]f32 = @splat(0);
    for (samples, 0..) |v, i| {
        var rev: usize = 0;
        var index = i;
        for (0..10) |_| {
            rev = (rev << 1) | (index & 1);
            index >>= 1;
        }
        re[rev] = v * (0.5 - 0.5 * @cos(2 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, N - 1)));
    }
    var len: usize = 2;
    while (len <= N) : (len *= 2) {
        const angle = -2 * std.math.pi / @as(f32, @floatFromInt(len));
        const wr_step = @cos(angle);
        const wi_step = @sin(angle);
        var start: usize = 0;
        while (start < N) : (start += len) {
            var wr: f32 = 1;
            var wi: f32 = 0;
            for (0..len / 2) |j| {
                const a = start + j;
                const b = a + len / 2;
                const tr = wr * re[b] - wi * im[b];
                const ti = wr * im[b] + wi * re[b];
                re[b] = re[a] - tr;
                im[b] = im[a] - ti;
                re[a] += tr;
                im[a] += ti;
                const next = wr * wr_step - wi * wi_step;
                wi = wr * wi_step + wi * wr_step;
                wr = next;
            }
        }
    }
    for (magnitudes, 0..) |*v, i| v.* = 4 * @sqrt(re[i] * re[i] + im[i] * im[i]) / N;
}
test "FFT bin amplitude" {
    var s: [N]f32 = undefined;
    for (&s, 0..) |*v, i| v.* = @sin(2 * std.math.pi * 32 * @as(f32, @floatFromInt(i)) / N);
    var m: [N / 2]f32 = undefined;
    spectrum(&s, &m);
    try std.testing.expectApproxEqAbs(@as(f32, 1), m[32], 0.005);
    try std.testing.expect(m[40] < 0.001);
}
