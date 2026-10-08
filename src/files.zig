const std = @import("std");
extern "c" fn fopen([*:0]const u8, [*:0]const u8) ?*anyopaque;
extern "c" fn fclose(*anyopaque) c_int;
extern "c" fn fwrite([*]const u8, usize, usize, *anyopaque) usize;
extern "c" fn fread([*]u8, usize, usize, *anyopaque) usize;
pub fn write(path: [*:0]const u8, bytes: []const u8) !void {
    const f = fopen(path, "wb") orelse return error.OpenFailed;
    defer _ = fclose(f);
    if (fwrite(bytes.ptr, 1, bytes.len, f) != bytes.len) return error.WriteFailed;
}
pub fn read(path: [*:0]const u8, bytes: []u8) ![]u8 {
    const f = fopen(path, "rb") orelse return error.OpenFailed;
    defer _ = fclose(f);
    const n = fread(bytes.ptr, 1, bytes.len, f);
    if (n == bytes.len) return error.FileTooLarge;
    return bytes[0..n];
}
pub fn wav(path: [*:0]const u8, pcm: []const i16) !void {
    const f = fopen(path, "wb") orelse return error.OpenFailed;
    defer _ = fclose(f);
    var header: [44]u8 = @splat(0);
    @memcpy(header[0..4], "RIFF");
    @memcpy(header[8..16], "WAVEfmt ");
    @memcpy(header[36..40], "data");
    const size: u32 = @intCast(pcm.len * 2);
    std.mem.writeInt(u32, header[4..8], size + 36, .little);
    std.mem.writeInt(u32, header[16..20], 16, .little);
    std.mem.writeInt(u16, header[20..22], 1, .little);
    std.mem.writeInt(u16, header[22..24], 1, .little);
    std.mem.writeInt(u32, header[24..28], 44100, .little);
    std.mem.writeInt(u32, header[28..32], 88200, .little);
    std.mem.writeInt(u16, header[32..34], 2, .little);
    std.mem.writeInt(u16, header[34..36], 16, .little);
    std.mem.writeInt(u32, header[40..44], size, .little);
    if (fwrite(&header, 1, 44, f) != 44) return error.WriteFailed;
    var bytes: [2]u8 = undefined;
    for (pcm) |s| {
        std.mem.writeInt(i16, &bytes, s, .little);
        if (fwrite(&bytes, 1, 2, f) != 2) return error.WriteFailed;
    }
}
