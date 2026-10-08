const engine = @import("engine.zig");
pub fn main() !void {
    var e: engine.Engine = .{};
    var pcm: [44100]i16 = undefined;
    e.key(true);
    for (&pcm, 0..) |*s, i| {
        if (i == 22050) e.key(false);
        s.* = e.pcm();
    }
    try @import("files.zig").wav("tone.wav", &pcm);
}
