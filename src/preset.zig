const std = @import("std");
const dsp = @import("engine.zig");
pub const Preset = struct { schema_version: u32 = 1, name: []const u8 = "Baseline", parameters: dsp.Parameters = .{} };
pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Preset) {
    var metadata = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer metadata.deinit();
    if (metadata.value != .object) return error.InvalidPreset;
    inline for (.{ "schema_version", "name", "parameters" }) |key| if (metadata.value.object.get(key) == null) return error.MissingField;
    var result = try std.json.parseFromSlice(Preset, allocator, bytes, .{ .ignore_unknown_fields = false, .allocate = .alloc_always });
    errdefer result.deinit();
    if (result.value.schema_version != 1) return error.UnsupportedSchema;
    if (result.value.name.len == 0 or result.value.name.len > 128) return error.InvalidName;
    try result.value.parameters.validate();
    return result;
}
pub fn serialize(allocator: std.mem.Allocator, p: Preset) ![]u8 {
    try p.parameters.validate();
    if (p.schema_version != 1) return error.UnsupportedSchema;
    return std.json.Stringify.valueAlloc(allocator, p, .{ .whitespace = .indent_2 });
}
pub fn header(buffer: []u8, p: Preset) ![]const u8 {
    try p.parameters.validate();
    const v = p.parameters;
    return std.fmt.bufPrint(buffer, "#pragma once\n#include <stdint.h>\n#include \"tone_studio_renderer.h\"\n/* Tone Studio v1: final linear gain; do not apply firmware volume twice. */\n#define MOBUS_TONE_SCHEMA_VERSION 1\n#define MOBUS_TONE_RATE 44100u\n#define MOBUS_TONE_FREQUENCY {d:.6}f\n#define MOBUS_TONE_HARMONIC_2 {d:.6}f\n#define MOBUS_TONE_HARMONIC_3 {d:.6}f\n#define MOBUS_TONE_ATTACK_MS {d:.6}f\n#define MOBUS_TONE_RELEASE_MS {d:.6}f\n#define MOBUS_TONE_GAIN {d:.6}f\n#define MOBUS_TONE_TRIANGLE {d}\nstatic inline tone_parameters tone_studio_exported_parameters(void) {{\n  tone_parameters p = {{MOBUS_TONE_FREQUENCY,MOBUS_TONE_HARMONIC_2,MOBUS_TONE_HARMONIC_3,MOBUS_TONE_ATTACK_MS,MOBUS_TONE_RELEASE_MS,MOBUS_TONE_GAIN,MOBUS_TONE_TRIANGLE}};\n  return p;\n}}\n", .{ v.frequency_hz, v.harmonic_2, v.harmonic_3, v.attack_ms, v.release_ms, v.gain, @intFromBool(v.waveform == .triangle) });
}
test "schema strict values roundtrip" {
    const a = std.testing.allocator;
    const bytes = try serialize(a, .{});
    defer a.free(bytes);
    var p = try parse(a, bytes);
    defer p.deinit();
    try std.testing.expectEqual(@as(f32, 450), p.value.parameters.frequency_hz);
    try std.testing.expectError(error.UnsupportedSchema, parse(a, "{\"schema_version\":2,\"name\":\"x\",\"parameters\":{}}"));
    try std.testing.expectError(error.UnknownField, parse(a, "{\"schema_version\":1,\"name\":\"x\",\"parameters\":{},\"unexpected\":1}"));
    try std.testing.expectError(error.InvalidParameter, parse(a, "{\"schema_version\":1,\"name\":\"x\",\"parameters\":{\"frequency_hz\":1500}}"));
}
