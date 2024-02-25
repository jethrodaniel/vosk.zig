// Copyright 2023-present, Mark Delk
// SPDX-License-Identifier: Apache-2.0

const std = @import("std");
const c = @cImport({
    @cInclude("vosk_api.h");
});

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    //-- argument validation

    const args = std.process.argsAlloc(allocator) catch @panic("OOM");
    {
        defer std.process.argsFree(allocator, args);

        if (args.len != 3) {
            std.log.err(
                \\Wrong number of arguments.
                \\  Usage: {s} <model> <wavefile>
                \\
            , .{args[0]});
            std.os.exit(1);
        }
    }

    const model_path = args[1];
    {
        if (model_path.len == 0) {
            std.log.err(
                \\Missing `model`.
                \\  Usage: {s} <model> <wavefile>
                \\
            , .{args[0]});
            std.os.exit(1);
        }
        const dir = std.fs.cwd().openDir(model_path, .{}) catch |err| {
            std.log.err("Failed to open model ({any})", .{err});
            std.os.exit(1);
        };
        errdefer dir.close();
    }

    const wav_path = args[2];
    {
        if (wav_path.len == 0) {
            std.log.err(
                \\Missing `wavfile`.
                \\  Usage: {s} <model> <wavefile>
                \\
            , .{args[0]});
            std.os.exit(1);
        }
    }

    const wav_file = std.fs.cwd().openFile(wav_path, .{}) catch |err| {
        std.log.err("Failed to open wavefile ({any})", .{err});
        std.os.exit(1);
    };
    errdefer wav_file.close();

    // skip wav header
    // TODO: validate this is a wav file?
    try wav_file.seekTo(44);

    const wav_data_slice = wav_file.readToEndAlloc(allocator, std.math.maxInt(u32)) catch |err| {
        std.log.err("Failed to read wavfile data (error: {any})", .{err});
        std.os.exit(1);
    };
    errdefer allocator.free(wav_data_slice);

    std.log.debug(
        \\
        \\model_path: {s}
        \\wav_path: {s}
        \\
    , .{ model_path, wav_path });

    //--

    const model_path_c_str = @as([*c]const u8, @constCast(@ptrCast(model_path)));
    const wav_data_c = @as([*c]u8, @ptrCast(@alignCast(wav_data_slice)));

    const model: ?*c.VoskModel = c.vosk_model_new(model_path_c_str);
    defer c.vosk_model_free(model);

    const recognizer: ?*c.VoskRecognizer = c.vosk_recognizer_new(model, 16_000.0);
    defer c.vosk_recognizer_free(recognizer);

    const VoskResult = struct {
        text: [:0]const u8,
    };

    const final = c.vosk_recognizer_accept_waveform(
        recognizer,
        wav_data_c,
        @as(c_int, @intCast(wav_data_slice.len)),
    );

    if (final == -1) {
        std.log.err("vosk_recognizer_accept_waveform failed", .{});
        std.os.exit(1);
    }
    const json = c.vosk_recognizer_final_result(recognizer);

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
