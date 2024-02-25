const std = @import("std");
const vosk = @import("vosk").c;

const allocator = std.heap.page_allocator;

pub fn main() !void {
    std.log.debug("¡hola, mundo!", .{});

    const args = std.process.argsAlloc(allocator) catch @panic("OOM");
    defer std.process.argsFree(allocator, args);

    const model_path = args[1];
    const wav_path = args[2];

    const wav_file = try std.fs.cwd().openFile(wav_path, .{});
    errdefer wav_file.close();

    try wav_file.seekTo(44); // skip wav header

    const wav_data_slice = try wav_file.readToEndAlloc(allocator, std.math.maxInt(u32));
    errdefer allocator.free(wav_data_slice);

    const model_path_c_str = @as([*c]const u8, @constCast(@ptrCast(model_path)));
    const wav_data_c = @as([*c]u8, @ptrCast(@alignCast(wav_data_slice)));

    const model: ?*vosk.VoskModel = vosk.vosk_model_new(model_path_c_str);
    defer vosk.vosk_model_free(model);

    const recognizer: ?*vosk.VoskRecognizer = vosk.vosk_recognizer_new(model, 16_000.0);
    defer vosk.vosk_recognizer_free(recognizer);

    const VoskResult = struct {
        text: [:0]const u8,
    };

    const final = vosk.vosk_recognizer_accept_waveform(
        recognizer,
        wav_data_c,
        @as(c_int, @intCast(wav_data_slice.len)),
    );

    if (final == -1) {
        std.log.err("vosk_recognizer_accept_waveform failed", .{});
        std.os.exit(1);
    }
    const json = vosk.vosk_recognizer_final_result(recognizer);

    const result = std.json.parseFromSlice(
        VoskResult,
        allocator,
        std.mem.sliceTo(json, 0),
        .{},
    ) catch |err| {
        std.log.err("Failed to parse result JSON ({any})", .{err});
        std.os.exit(1);
    };
    defer result.deinit();

    const transcription_result = result.value.text[0..];
    std.log.debug("-> {s}", .{transcription_result});
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
