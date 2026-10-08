const std = @import("std");
pub const Event = struct { down: bool, frames: u32 };
pub const Pattern = struct {
    events: [2048]Event = undefined,
    len: usize = 0,
    fn add(p: *Pattern, down: bool, frames: u32) !void {
        if (p.len == p.events.len) return error.PatternTooLong;
        p.events[p.len] = .{ .down = down, .frames = frames };
        p.len += 1;
    }
    pub fn encode(text: []const u8, wpm: u32) !Pattern {
        if (wpm < 5 or wpm > 60) return error.InvalidSpeed;
        var p: Pattern = .{};
        const unit = 52920 / wpm;
        var gap: u32 = 0;
        for (text) |raw| {
            const c = std.ascii.toUpper(raw);
            if (c == ' ') {
                if (p.len > 0) gap = 7;
                continue;
            }
            const code = lookup(c) orelse return error.UnsupportedCharacter;
            if (gap > 0) try p.add(false, unit * gap);
            for (code, 0..) |symbol, i| {
                if (i > 0) try p.add(false, unit);
                try p.add(true, unit * (if (symbol == '-') @as(u32, 3) else 1));
            }
            gap = 3;
        }
        if (p.len == 0) return error.EmptyPattern;
        try p.add(false, unit * 7);
        return p;
    }
    pub fn single(ms: u32) Pattern {
        var p: Pattern = .{};
        p.add(true, ms * 44100 / 1000) catch unreachable;
        p.add(false, 4410) catch unreachable;
        return p;
    }
};
fn lookup(c: u8) ?[]const u8 {
    const codes = [_][]const u8{ ".-", "-...", "-.-.", "-..", ".", "..-.", "--.", "....", "..", ".---", "-.-", ".-..", "--", "-.", "---", ".--.", "--.-", ".-.", "...", "-", "..-", "...-", ".--", "-..-", "-.--", "--.." };
    const digits = [_][]const u8{ "-----", ".----", "..---", "...--", "....-", ".....", "-....", "--...", "---..", "----." };
    if (c >= 'A' and c <= 'Z') return codes[c - 'A'];
    if (c >= '0' and c <= '9') return digits[c - '0'];
    return switch (c) {
        '.' => ".-.-.-",
        ',' => "--..--",
        '?' => "..--..",
        '/' => "-..-.",
        '=' => "-...-",
        '+' => ".-.-.",
        else => null,
    };
}
test "PARIS standard 50 units and gaps" {
    const p = try Pattern.encode("PARIS", 20);
    var total: u32 = 0;
    for (p.events[0..p.len]) |e| total += e.frames;
    try std.testing.expectEqual(@as(u32, 132300), total);
    try std.testing.expectError(error.UnsupportedCharacter, Pattern.encode("!", 20));
}
