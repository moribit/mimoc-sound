const std = @import("std");
const ui = @import("mimoc_ui");
const dsp = @import("engine.zig");
const audio = @import("audio.zig");
const W = 640;
const H = 400;
var pixels: [W * H / 8]u8 = @splat(0);
var parameters: dsp.Parameters = .{};
var previous: dsp.Parameters = .{};
var a: dsp.Parameters = .{};
var b: dsp.Parameters = .{ .harmonic_2 = 0.08, .attack_ms = 12, .release_ms = 18 };
var side_b = false;
var playing = false;
var morse_active = false;
var ab_match = false;
var loop = true;
var dirty = true;
var audio_ok = false;
var focused: usize = 0;
var dragging = false;
var edit: ui.controls.NumericInput = .{};
var editing = false;
var status: []const u8 = "READY";
var morse_choice: usize = 3;
var wpm: u32 = 20;
var custom: [128]u8 = @splat(0);
var custom_len: usize = 0;
const morse_names = [_][]const u8{ "SINGLE", "DOT", "DASH", "SOS", "CQ CQ", "CUSTOM" };
extern fn tone_prompt([*:0]const u8, [*]u8, usize) c_int;
var samples: [1024]f32 = @splat(0);
var sample_pos: usize = 0;
var sample_count: usize = 0;
const names = [_][]const u8{ "FREQUENCY Hz", "HARMONIC 2", "HARMONIC 3", "ATTACK ms", "RELEASE ms", "GAIN" };
const fields = .{ "frequency_hz", "harmonic_2", "harmonic_3", "attack_ms", "release_ms", "gain" };
const mins = [_]f32{ 200, 0, 0, 0, 0, 0 };
const maxs = [_]f32{ 1200, 0.2, 0.15, 50, 100, 1 };
const steps = [_]f32{ 1, 0.001, 0.001, 1, 1, 0.01 };
extern fn mimoc_canvas_run([*]const u8, c_int, c_int, [*:0]const u8) void;
fn value(index: usize) f32 {
    inline for (fields, 0..) |f, i| if (index == i) return @field(parameters, f);
    return 0;
}
fn set(index: usize, v: f32) void {
    inline for (fields, 0..) |f, i| if (index == i) {
        @field(parameters, f) = v;
    };
    dirty = true;
}
fn rect(index: usize) ui.geometry.Rect {
    return .{ .x = 145, .y = @intCast(73 + index * 29), .w = 155, .h = 18 };
}
fn slider(index: usize) ui.controls.Slider {
    return .{ .min = mins[index], .max = maxs[index], .step = steps[index], .value = value(index) };
}
fn publishParameters() dsp.Parameters {
    var p = parameters;
    if (ab_match and p.gain > 0) {
        var e: dsp.Engine = .{ .current = p, .target = p, .envelope = 1, .goal = 1, .length = 0, .down = true, .triangle_mix = if (p.waveform == .triangle) 1 else 0 };
        e.current.gain = 1;
        e.target.gain = 1;
        var sum: f32 = 0;
        for (0..4096) |_| {
            const sample = e.next();
            sum += sample * sample;
        }
        p.gain = @min(1, 0.12 / @sqrt(sum / 4096));
    }
    return p;
}
fn submit() void {
    if (dirty and audio.commands.push(.{ .parameters = publishParameters(), .playing = playing, .duration = if (playing and !loop) 22050 else 0, .restart = !morse_active })) dirty = false;
}
fn text(r: *ui.mono1.Renderer, x: i16, y: i16, s: []const u8) void {
    ui.font.draw(r, .tiny5x7, x, y, s, true);
}
fn button(r: *ui.mono1.Renderer, x: i16, y: i16, w: i16, s: []const u8) void {
    r.rect(.{ .x = x, .y = y, .w = w, .h = 20 }, true);
    text(r, x + 4, y + 6, s);
}
fn paint() void {
    var surface = ui.surface.Mono1.init(&pixels, W, H) catch unreachable;
    surface.clear(false);
    var r = ui.mono1.Renderer.init(&surface);
    text(&r, 12, 12, "MO-BUS TONE STUDIO");
    text(&r, 390, 12, if (audio_ok) "COREAUDIO 44100 Hz" else "AUDIO UNAVAILABLE");
    button(&r, 12, 32, 85, "BASELINE");
    button(&r, 105, 32, 70, if (side_b) "B -> A" else "A -> B");
    button(&r, 183, 32, 65, "UNDO");
    button(&r, 256, 32, 60, "SAVE");
    button(&r, 324, 32, 60, "LOAD");
    button(&r, 392, 32, 80, "EXPORT C");
    button(&r, 480, 32, 70, "WAV");
    for (names, 0..) |name, i| {
        const y: @TypeOf(@as(i16, 0)) = @intCast(78 + i * 29);
        text(&r, 12, y, name);
        slider(i).draw(&r, rect(i), focused == i);
        var buf: [40]u8 = undefined;
        const label = std.fmt.bufPrint(&buf, "{d:.3}", .{value(i)}) catch "?";
        text(&r, 312, y, if (editing and focused == i) edit.bytes[0..edit.len] else label);
    }
    button(&r, 12, 252, 175, if (parameters.waveform == .sine) "WAVEFORM: SINE" else "WAVEFORM: TRIANGLE");
    button(&r, 12, 282, 85, if (playing) "STOP" else "PLAY");
    button(&r, 105, 282, 85, if (loop) "LOOP ON" else "LOOP OFF");
    button(&r, 198, 282, 95, "MORSE TEST");
    button(&r, 12, 309, 90, morse_names[morse_choice]);
    var speed_buf: [32]u8 = undefined;
    button(&r, 110, 309, 45, "WPM-");
    button(&r, 163, 309, 45, "WPM+");
    text(&r, 218, 315, std.fmt.bufPrint(&speed_buf, "{d} WPM", .{wpm}) catch "?");
    text(&r, 12, 335, "SPACE PLAY | TAB | ARROWS | ENTER VALUE");
    text(&r, 12, 354, status);
    var buf: [64]u8 = undefined;
    text(&r, 12, 376, std.fmt.bufPrint(&buf, "LATE {d}  MONITOR DROP {d}", .{ audio.underruns.load(.monotonic), audio.dropped_monitor.load(.monotonic) }) catch "?");
    text(&r, 400, 72, "PCM WAVEFORM");
    r.rect(.{ .x = 400, .y = 87, .w = 228, .h = 78 }, true);
    for (0..226) |i| {
        const j = (sample_pos + 1024 - 226 + i) % 1024;
        const s = samples[j];
        r.pixel(@intCast(401 + i), 126 - @as(i16, @intFromFloat(s * 35)), true);
    }
    text(&r, 400, 180, "ENVELOPE (MODEL)");
    var model: dsp.Engine = .{ .current = parameters, .target = parameters };
    model.key(true);
    for (0..226) |i| {
        if (i == 113) model.key(false);
        for (0..20) |_| _ = model.next();
        r.pixel(@intCast(401 + i), 250 - @as(i16, @intFromFloat(model.envelope * 50)), true);
    }
    var sum: f32 = 0;
    var peak: f32 = 0;
    var clipped: usize = 0;
    for (samples) |s| {
        sum += s * s;
        peak = @max(peak, @abs(s));
        if (@abs(s) >= 1) clipped += 1;
    }
    text(&r, 400, 268, std.fmt.bufPrint(&buf, "PEAK {d:.3} RMS {d:.3}", .{ peak, @sqrt(sum / 1024) }) catch "?");
    text(&r, 400, 284, std.fmt.bufPrint(&buf, "CLIPS {d}", .{clipped}) catch "?");
    text(&r, 400, 304, "FFT HANN 0..11 kHz");
    var ordered: [1024]f32 = undefined;
    for (&ordered, 0..) |*v, i| v.* = samples[(sample_pos + i) % 1024];
    var mags: [512]f32 = undefined;
    @import("analysis.zig").spectrum(&ordered, &mags);
    r.rect(.{ .x = 400, .y = 318, .w = 228, .h = 63 }, true);
    for (0..226) |i| {
        const magnitude = mags[i * 256 / 226];
        const db = 20 * @log10(@max(0.0001, magnitude));
        const h: @TypeOf(@as(i16, 0)) = @intFromFloat(std.math.clamp((db + 80) / 80, 0, 1) * 60);
        r.vline(@intCast(401 + i), 380 - h, h, true);
    }
}
export fn mimoc_canvas_tick() void {
    submit();
    while (audio.monitor.pop()) |s| {
        samples[sample_pos] = s;
        sample_pos = (sample_pos + 1) % samples.len;
        sample_count += 1;
    }
    paint();
}
export fn mimoc_canvas_event(kind: c_int, x: c_int, y: c_int, key: c_int) void {
    if (kind == 2) {
        dragging = false;
        return;
    }
    if (kind == 0 or kind == 1) {
        if (kind == 0) {
            dragging = false;
            for (0..6) |i| {
                if (y >= 73 + @as(c_int, @intCast(i)) * 29 and y < 95 + @as(c_int, @intCast(i)) * 29) {
                    focused = i;
                    previous = parameters;
                    if (x >= 145 and x <= 300) dragging = true;
                    if (x >= 305 and x < 385) {
                        editing = true;
                        edit = .{};
                    }
                    break;
                }
            }
        }
        if (dragging) {
            var s = slider(focused);
            s.drag(rect(focused), @intCast(std.math.clamp(x, 0, W - 1)));
            set(focused, s.value);
        }
        if (kind != 0) return;
        if (y >= 32 and y < 52) {
            if (x < 97) {
                previous = parameters;
                parameters = .{};
                ab_match = false;
                status = "BASELINE";
            } else if (x < 175) {
                if (side_b) {
                    b = parameters;
                    parameters = a;
                } else {
                    a = parameters;
                    parameters = b;
                }
                side_b = !side_b;
                ab_match = true;
                status = "A/B: RMS MATCH 0.12, SAME TRANSPORT";
            } else if (x < 248) {
                const tmp = parameters;
                parameters = previous;
                previous = tmp;
            } else if (x < 316) {
                savePreset();
            } else if (x < 384) {
                loadPreset();
            } else if (x < 472) {
                exportPreset();
            } else if (x < 550) {
                exportWav();
            }
            dirty = true;
        }
        if (y >= 309 and y < 329) {
            if (x < 102) {
                morse_choice = (morse_choice + 1) % morse_names.len;
                if (morse_choice == 5) {
                    const n = tone_prompt("CUSTOM MORSE (A-Z 0-9)", &custom, custom.len);
                    if (n > 0) custom_len = @intCast(n);
                }
            } else if (x < 155) {
                wpm = @max(5, wpm - 1);
            } else if (x < 208) {
                wpm = @min(60, wpm + 1);
            }
        }
        if (y >= 252 and y < 272 and x < 187) {
            previous = parameters;
            parameters.waveform = if (parameters.waveform == .sine) .triangle else .sine;
            dirty = true;
        }
        if (y >= 282 and y < 302) {
            if (x < 97) {
                playing = !playing;
                morse_active = false;
                dirty = true;
            } else if (x < 190) {
                loop = !loop;
                dirty = true;
            } else if (x < 293) {
                morseTest();
            }
        }
    } else if (kind == 3) {
        if (editing) {
            if (key == 27) {
                editing = false;
            } else if (key == 8) {
                edit.backspace();
            } else if (key == 13) {
                const v = edit.parse(mins[focused], maxs[focused]) catch {
                    status = "INVALID VALUE";
                    return;
                };
                previous = parameters;
                set(focused, v);
                editing = false;
            } else if (key >= 0 and key < 128) edit.append(@intCast(key));
            return;
        }
        switch (key) {
            32 => {
                playing = !playing;
                morse_active = false;
                dirty = true;
            },
            260, 259 => focused = (focused + 1) % 6,
            258 => focused = (focused + 5) % 6,
            256, 257 => {
                previous = parameters;
                var s = slider(focused);
                s.adjust(if (key == 256) -1 else 1);
                set(focused, s.value);
            },
            13 => {
                edit = .{};
                editing = true;
            },
            'z', 'Z' => {
                const tmp = parameters;
                parameters = previous;
                previous = tmp;
                dirty = true;
            },
            else => {},
        }
    }
}
extern fn tone_file_path(c_int, [*:0]const u8, [*]u8, usize) c_int;
fn savePreset() void {
    var path: [4096]u8 = undefined;
    if (tone_file_path(1, "json", &path, path.len) == 0) return;
    const bytes = @import("preset.zig").serialize(std.heap.page_allocator, .{ .name = "Studio", .parameters = parameters }) catch {
        status = "INVALID PRESET";
        return;
    };
    defer std.heap.page_allocator.free(bytes);
    @import("files.zig").write(@ptrCast(&path), bytes) catch {
        status = "SAVE FAILED";
        return;
    };
    status = "PRESET SAVED";
}
fn loadPreset() void {
    var path: [4096]u8 = undefined;
    if (tone_file_path(0, "json", &path, path.len) == 0) return;
    var buffer: [8192]u8 = undefined;
    const bytes = @import("files.zig").read(@ptrCast(&path), &buffer) catch {
        status = "LOAD FAILED";
        return;
    };
    var p = @import("preset.zig").parse(std.heap.page_allocator, bytes) catch {
        status = "INVALID PRESET / SCHEMA";
        return;
    };
    defer p.deinit();
    previous = parameters;
    parameters = p.value.parameters;
    ab_match = false;
    dirty = true;
    status = "PRESET LOADED";
}
fn exportPreset() void {
    var path: [4096]u8 = undefined;
    if (tone_file_path(1, "h", &path, path.len) == 0) return;
    var buffer: [2048]u8 = undefined;
    const bytes = @import("preset.zig").header(&buffer, .{ .parameters = parameters }) catch {
        status = "EXPORT FAILED";
        return;
    };
    @import("files.zig").write(@ptrCast(&path), bytes) catch {
        status = "EXPORT WRITE FAILED";
        return;
    };
    status = "FIRMWARE HEADER EXPORTED";
}
fn exportWav() void {
    var e: dsp.Engine = .{ .current = parameters, .target = parameters };
    var pcm: [44100]i16 = undefined;
    e.key(true);
    for (&pcm, 0..) |*s, i| {
        if (i == 22050) e.key(false);
        s.* = e.pcm();
    }
    var path: [4096]u8 = undefined;
    if (tone_file_path(1, "wav", &path, path.len) == 0) return;
    @import("files.zig").wav(@ptrCast(&path), &pcm) catch {
        status = "WAV WRITE FAILED";
        return;
    };
    status = "WAV EXPORTED";
}
fn morseTest() void {
    const m = @import("morse.zig");
    const pattern = switch (morse_choice) {
        0 => m.Pattern.single(500),
        1 => m.Pattern.encode("E", wpm) catch unreachable,
        2 => m.Pattern.encode("T", wpm) catch unreachable,
        3 => m.Pattern.encode("SOS", wpm) catch unreachable,
        4 => m.Pattern.encode("CQ CQ", wpm) catch unreachable,
        else => m.Pattern.encode(custom[0..custom_len], wpm) catch {
            status = "INVALID CUSTOM MORSE";
            return;
        },
    };
    if (!audio.commands.push(.{ .parameters = publishParameters(), .playing = false, .pattern = pattern, .loop_pattern = loop })) {
        status = "AUDIO COMMAND QUEUE FULL";
        return;
    }
    playing = true;
    morse_active = true;
    dirty = false;
    status = "MORSE TEST PLAYING";
}
pub fn main() void {
    audio_ok = true;
    audio.open() catch {
        status = "COREAUDIO INIT FAILED";
        audio_ok = false;
    };
    defer audio.close();
    paint();
    mimoc_canvas_run(&pixels, W, H, "Mo-Bus Tone Studio");
}
