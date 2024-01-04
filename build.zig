// Copyright 2023-present, Mark Delk
// SPDX-License-Identifier: Apache-2.0

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vosk_dep = b.dependency("vosk_src", .{});
    const fst_dep = b.dependency("openfst", .{});
    const kaldi_dep = b.dependency("kaldi", .{});
    const model_dep = b.dependency("vosk_model_small_en_us_0_15", .{});

    //--

    const fst = b.addStaticLibrary(.{
        .name = "fst",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = fst;

        const srcs: []const []const u8 = &.{
            "src/lib/compat.cc",
            "src/lib/encode.cc",
            "src/lib/flags.cc",
            "src/lib/fst-types.cc",
            "src/lib/fst.cc",
            "src/lib/mapped-file.cc",
            "src/lib/properties.cc",
            "src/lib/symbol-table-ops.cc",
            "src/lib/symbol-table.cc",
            "src/lib/util.cc",
            "src/lib/weight.cc",
        };
        for (srcs) |src| {
            lib.addCSourceFile(.{ .file = fst_dep.path(src), .flags = &.{} });
        }

        lib.defineCMacro("NDEBUG", "1");
        lib.defineCMacro("FST_NO_DYNAMIC_LINKING", "1");
        lib.addIncludePath(fst_dep.path("src/include"));
        lib.linkLibCpp();

        lib.pie = true;
        lib.strip = true;
    }

    //

    const fstngram = b.addStaticLibrary(.{
        .name = "fstngram",
        .target = target,
        .optimize = optimize,
    });
    {
        const lib = fstngram;

        const srcs: []const []const u8 = &.{
            "src/extensions/ngram/bitmap-index.cc",
            "src/extensions/ngram/ngram-fst.cc",
            "src/extensions/ngram/nthbit.cc",
        };
        for (srcs) |src| {
            lib.addCSourceFile(.{ .file = fst_dep.path(src), .flags = &.{} });
        }

        lib.addIncludePath(fst_dep.path("src/include"));
        lib.linkLibCpp();
        lib.linkLibrary(fst);

        lib.pie = true;
        lib.strip = true;
    }

    //--

    // NOTE: vosk only needs the following Kaldi libraries: kaldi-base kaldi-online2 kaldi-rnnlm
    const kaldi = b.addStaticLibrary(.{
        .name = "kaldi",
        .target = target,
        // NOTE: Needed with zig's `-Doptimize=Debug`, since UBSan throws
        // an EXC_BAD_INSTRUCTION error at `nnet-common.cc:371:13`.
        //
        // See https://devlog.hexops.com/2022/debugging-undefined-behavior/
        //
        // TODO: set a compiler flag to avoid having to use `ReleaseFast` for
        // the entire library, OR compile nnet3 separately.
        .optimize = .ReleaseFast,
    });
    {
        const lib = kaldi;

        lib.defineCMacro("NDEBUG", "1");
        // kaldi-matrix
        lib.defineCMacro("HAVE_CLAPACK", "1");
        // kaldi-cudamatrix
        lib.defineCMacro("HAVE_CUDA", "0");
        // kaldi-online
        lib.defineCMacro("KALDI_NO_PORTAUDIO", "1");
        // kaldi/src/.version
        lib.defineCMacro("KALDI_VERSION", "\"5.5\"");

        lib.addIncludePath(kaldi_dep.path("src"));
        lib.addIncludePath(kaldi_dep.path("src/base"));
        lib.addIncludePath(fst_dep.path("src/include"));

        // NOTE: we could build each library separately if we want, but this
        // seems simpler.
        const srcs: []const []const u8 = &.{
            "src/base/io-funcs.cc",
            "src/base/kaldi-error.cc",
            "src/base/kaldi-math.cc",
            "src/base/kaldi-utils.cc",
            "src/base/timer.cc",

            "src/matrix/compressed-matrix.cc",
            "src/matrix/kaldi-matrix.cc",
            "src/matrix/kaldi-vector.cc",
            "src/matrix/matrix-functions.cc",
            "src/matrix/optimization.cc",
            "src/matrix/packed-matrix.cc",
            "src/matrix/qr.cc",
            "src/matrix/sp-matrix.cc",
            "src/matrix/sparse-matrix.cc",
            "src/matrix/srfft.cc",
            "src/matrix/tp-matrix.cc",

            "src/util/kaldi-holder.cc",
            "src/util/kaldi-io.cc",
            "src/util/kaldi-semaphore.cc",
            "src/util/kaldi-table.cc",
            "src/util/kaldi-thread.cc",
            "src/util/parse-options.cc",
            "src/util/simple-io-funcs.cc",
            "src/util/simple-options.cc",
            "src/util/text-utils.cc",

            "src/tree/build-tree-questions.cc",
            "src/tree/build-tree-utils.cc",
            "src/tree/build-tree.cc",
            "src/tree/cluster-utils.cc",
            "src/tree/clusterable-classes.cc",
            "src/tree/context-dep.cc",
            "src/tree/event-map.cc",
            "src/tree/tree-renderer.cc",

            "src/gmm/am-diag-gmm.cc",
            "src/gmm/decodable-am-diag-gmm.cc",
            "src/gmm/diag-gmm-normal.cc",
            "src/gmm/diag-gmm.cc",
            "src/gmm/ebw-diag-gmm.cc",
            "src/gmm/full-gmm-normal.cc",
            "src/gmm/full-gmm.cc",
            "src/gmm/indirect-diff-diag-gmm.cc",
            "src/gmm/mle-am-diag-gmm.cc",
            "src/gmm/mle-diag-gmm.cc",
            "src/gmm/mle-full-gmm.cc",
            "src/gmm/model-common.cc",

            "src/transform/basis-fmllr-diag-gmm.cc",
            "src/transform/cmvn.cc",
            "src/transform/compressed-transform-stats.cc",
            "src/transform/decodable-am-diag-gmm-regtree.cc",
            "src/transform/fmllr-diag-gmm.cc",
            "src/transform/fmllr-raw.cc",
            "src/transform/fmpe.cc",
            "src/transform/lda-estimate.cc",
            "src/transform/lvtln.cc",
            "src/transform/mllt.cc",
            "src/transform/regression-tree.cc",
            "src/transform/regtree-fmllr-diag-gmm.cc",
            "src/transform/regtree-mllr-diag-gmm.cc",
            "src/transform/transform-common.cc",

            "src/ivector/agglomerative-clustering.cc",
            "src/ivector/ivector-extractor.cc",
            "src/ivector/logistic-regression.cc",
            "src/ivector/plda.cc",
            "src/ivector/voice-activity-detection.cc",

            "src/cudamatrix/cu-allocator.cc",
            "src/cudamatrix/cu-array.cc",
            "src/cudamatrix/cu-block-matrix.cc",
            "src/cudamatrix/cu-common.cc",
            "src/cudamatrix/cu-compressed-matrix.cc",
            "src/cudamatrix/cu-device.cc",
            "src/cudamatrix/cu-math.cc",
            "src/cudamatrix/cu-matrix.cc",
            "src/cudamatrix/cu-packed-matrix.cc",
            "src/cudamatrix/cu-rand.cc",
            "src/cudamatrix/cu-sp-matrix.cc",
            "src/cudamatrix/cu-sparse-matrix.cc",
            "src/cudamatrix/cu-tp-matrix.cc",
            "src/cudamatrix/cu-vector.cc",

            "src/hmm/hmm-topology.cc",
            "src/hmm/hmm-utils.cc",
            "src/hmm/posterior.cc",
            "src/hmm/transition-model.cc",
            "src/hmm/tree-accu.cc",

            "src/lat/compose-lattice-pruned.cc",
            "src/lat/confidence.cc",
            "src/lat/determinize-lattice-pruned.cc",
            "src/lat/kaldi-lattice.cc",
            "src/lat/lattice-functions-transition-model.cc",
            "src/lat/lattice-functions.cc",
            "src/lat/minimize-lattice.cc",
            "src/lat/phone-align-lattice.cc",
            "src/lat/push-lattice.cc",
            "src/lat/sausages.cc",
            "src/lat/word-align-lattice-lexicon.cc",
            "src/lat/word-align-lattice.cc",

            "src/fstext/context-fst.cc",
            "src/fstext/grammar-context-fst.cc",
            "src/fstext/kaldi-fst-io.cc",
            "src/fstext/push-special.cc",

            "src/chain/chain-supervision.cc",
            "src/chain/chain-numerator.cc",
            "src/chain/chain-den-graph.cc",
            "src/chain/language-model.cc",
            "src/chain/chain-denominator.cc",
            "src/chain/chain-training.cc",
            "src/chain/chain-generic-numerator.cc",

            "src/decoder/decodable-matrix.cc",
            "src/decoder/decoder-wrappers.cc",
            "src/decoder/faster-decoder.cc",
            "src/decoder/grammar-fst.cc",
            "src/decoder/lattice-faster-decoder.cc",
            "src/decoder/lattice-faster-online-decoder.cc",
            "src/decoder/lattice-incremental-decoder.cc",
            "src/decoder/lattice-incremental-online-decoder.cc",
            "src/decoder/lattice-simple-decoder.cc",
            "src/decoder/simple-decoder.cc",
            "src/decoder/training-graph-compiler.cc",

            "src/nnet3/am-nnet-simple.cc",
            "src/nnet3/attention.cc",
            "src/nnet3/convolution.cc",
            "src/nnet3/decodable-batch-looped.cc",
            "src/nnet3/decodable-online-looped.cc",
            "src/nnet3/decodable-simple-looped.cc",
            "src/nnet3/discriminative-supervision.cc",
            "src/nnet3/discriminative-training.cc",
            "src/nnet3/natural-gradient-online.cc",
            "src/nnet3/nnet-am-decodable-simple.cc",
            "src/nnet3/nnet-analyze.cc",
            "src/nnet3/nnet-attention-component.cc",
            "src/nnet3/nnet-batch-compute.cc",
            "src/nnet3/nnet-chain-diagnostics.cc",
            "src/nnet3/nnet-chain-diagnostics2.cc",
            "src/nnet3/nnet-chain-example.cc",
            "src/nnet3/nnet-chain-training.cc",
            "src/nnet3/nnet-chain-training2.cc",
            "src/nnet3/nnet-combined-component.cc",
            "src/nnet3/nnet-common.cc",
            "src/nnet3/nnet-compile-looped.cc",
            "src/nnet3/nnet-compile-utils.cc",
            "src/nnet3/nnet-compile.cc",
            "src/nnet3/nnet-component-itf.cc",
            "src/nnet3/nnet-computation-graph.cc",
            "src/nnet3/nnet-computation.cc",
            "src/nnet3/nnet-compute.cc",
            "src/nnet3/nnet-convolutional-component.cc",
            "src/nnet3/nnet-descriptor.cc",
            "src/nnet3/nnet-diagnostics.cc",
            "src/nnet3/nnet-discriminative-diagnostics.cc",
            "src/nnet3/nnet-discriminative-example.cc",
            "src/nnet3/nnet-discriminative-training.cc",
            "src/nnet3/nnet-example-utils.cc",
            "src/nnet3/nnet-example.cc",
            "src/nnet3/nnet-general-component.cc",
            "src/nnet3/nnet-graph.cc",
            "src/nnet3/nnet-nnet.cc",
            "src/nnet3/nnet-normalize-component.cc",
            "src/nnet3/nnet-optimize-utils.cc",
            "src/nnet3/nnet-optimize.cc",
            "src/nnet3/nnet-parse.cc",
            "src/nnet3/nnet-simple-component.cc",
            "src/nnet3/nnet-tdnn-component.cc",
            "src/nnet3/nnet-training.cc",
            "src/nnet3/nnet-utils.cc",

            "src/feat/feature-fbank.cc",
            "src/feat/feature-functions.cc",
            "src/feat/feature-mfcc.cc",
            "src/feat/feature-plp.cc",
            "src/feat/feature-spectrogram.cc",
            "src/feat/feature-window.cc",
            "src/feat/mel-computations.cc",
            "src/feat/online-feature.cc",
            "src/feat/pitch-functions.cc",
            "src/feat/resample.cc",
            "src/feat/signal.cc",
            "src/feat/wave-reader.cc",

            "src/lm/arpa-file-parser.cc",
            "src/lm/arpa-lm-compiler.cc",
            "src/lm/const-arpa-lm.cc",
            "src/lm/kaldi-rnnlm.cc",
            "src/lm/kenlm.cc",
            "src/lm/mikolov-rnnlm-lib.cc",

            "src/rnnlm/rnnlm-compute-state.cc",
            "src/rnnlm/rnnlm-core-compute.cc",
            "src/rnnlm/rnnlm-core-training.cc",
            "src/rnnlm/rnnlm-embedding-training.cc",
            "src/rnnlm/rnnlm-example-utils.cc",
            "src/rnnlm/rnnlm-example.cc",
            "src/rnnlm/rnnlm-lattice-rescoring.cc",
            "src/rnnlm/rnnlm-training.cc",
            "src/rnnlm/rnnlm-utils.cc",
            "src/rnnlm/sampler.cc",
            "src/rnnlm/sampling-lm-estimate.cc",
            "src/rnnlm/sampling-lm.cc",

            "src/nnet2/am-nnet.cc",
            "src/nnet2/combine-nnet-fast.cc",
            "src/nnet2/combine-nnet.cc",
            "src/nnet2/get-feature-transform.cc",
            "src/nnet2/mixup-nnet.cc",
            "src/nnet2/nnet-component.cc",
            "src/nnet2/nnet-compute-discriminative-parallel.cc",
            "src/nnet2/nnet-compute-discriminative.cc",
            "src/nnet2/nnet-compute-online.cc",
            "src/nnet2/nnet-compute.cc",
            "src/nnet2/nnet-example-functions.cc",
            "src/nnet2/nnet-example.cc",
            "src/nnet2/nnet-fix.cc",
            "src/nnet2/nnet-functions.cc",
            "src/nnet2/nnet-limit-rank.cc",
            "src/nnet2/nnet-nnet.cc",
            "src/nnet2/nnet-precondition-online.cc",
            "src/nnet2/nnet-precondition.cc",
            "src/nnet2/nnet-stats.cc",
            "src/nnet2/nnet-update-parallel.cc",
            "src/nnet2/nnet-update.cc",
            "src/nnet2/online-nnet2-decodable.cc",
            "src/nnet2/rescale-nnet.cc",
            "src/nnet2/train-nnet-ensemble.cc",
            "src/nnet2/train-nnet.cc",
            "src/nnet2/widen-nnet.cc",

            "src/online2/online-endpoint.cc",
            "src/online2/online-feature-pipeline.cc",
            "src/online2/online-gmm-decodable.cc",
            "src/online2/online-gmm-decoding.cc",
            "src/online2/online-ivector-feature.cc",
            "src/online2/online-nnet2-decoding-threaded.cc",
            "src/online2/online-nnet2-decoding.cc",
            "src/online2/online-nnet2-feature-pipeline.cc",
            "src/online2/online-nnet3-decoding.cc",
            "src/online2/online-nnet3-incremental-decoding.cc",
            "src/online2/online-nnet3-wake-word-faster-decoder.cc",
            "src/online2/online-speex-wrapper.cc",
            "src/online2/online-timing.cc",
            "src/online2/onlinebin-util.cc",
        };
        for (srcs) |src| {
            // https://github.com/alphacep/kaldi/pull/3#issuecomment-1147084916
            lib.addCSourceFile(.{ .file = kaldi_dep.path(src), .flags = &.{"-std=c++17"} });
        }

        lib.linkLibCpp();

        // NOTE: needed for `kaldi-matrix`
        if (target.isDarwin()) {
            const target_info = std.zig.system.NativeTargetInfo.detect(target) catch unreachable;
            const sdk = std.zig.system.darwin.getSdk(b.allocator, target_info.target) orelse
                @panic("macOS SDK is missing");
            lib.addSystemIncludePath(.{ .path = b.pathJoin(&.{ sdk, "/usr/include" }) });
            lib.addSystemFrameworkPath(.{ .path = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
            lib.addLibraryPath(.{ .path = b.pathJoin(&.{ sdk, "/usr/lib" }) });

            // NOTE: Using Xcode's `Accelerate` framework means that we have to
            //   comply with Apple's Xcode license:
            //
            //   https://www.apple.com/legal/sla/docs/xcode.pdf
            //
            // See https://github.com/hexops/xcode-frameworks/blob/main/LICENSE
            //
            // TODO: use OpenBLAS instead to avoid this (requires Kaldi changes).
            lib.linkFramework("Accelerate");
        }

        lib.pie = true;
        lib.strip = true;
    }

    //----

    const static_lib = b.addStaticLibrary(.{
        .name = "vosk-static",
        .target = target,
        .optimize = optimize,
    });
    const shared_lib = b.addSharedLibrary(.{
        .name = "vosk-shared",
        .target = target,
        .optimize = optimize,
    });

    {
        const libs: *const [2]*std.Build.Step.Compile = &.{
            static_lib,
            shared_lib,
        };
        const srcs: []const []const u8 = &.{
            "src/language_model.cc",
            "src/model.cc",
            "src/recognizer.cc",
            "src/spk_model.cc",
            "src/vosk_api.cc",
        };

        for (libs) |lib| {
            for (srcs) |src| {
                lib.addCSourceFile(.{ .file = vosk_dep.path(src), .flags = &.{"-std=c++17"} });
            }

            lib.addIncludePath(kaldi_dep.path("src"));
            lib.addIncludePath(fst_dep.path("src/include"));

            lib.linkLibCpp();
            lib.linkLibrary(kaldi);
            lib.linkLibrary(fstngram);

            lib.installHeader(
                vosk_dep.path("src/vosk_api.h").getPath(b),
                "vosk_api.h",
            );

            // TODO: why isn't `linkLibrary(kaldi)` enough?
            if (target.isDarwin()) {
                const target_info = std.zig.system.NativeTargetInfo.detect(target) catch unreachable;
                const sdk = std.zig.system.darwin.getSdk(b.allocator, target_info.target) orelse
                    @panic("macOS SDK is missing");
                lib.addSystemIncludePath(.{ .path = b.pathJoin(&.{ sdk, "/usr/include" }) });
                lib.addSystemFrameworkPath(.{ .path = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
                lib.addLibraryPath(.{ .path = b.pathJoin(&.{ sdk, "/usr/lib" }) });

                lib.linkFramework("Accelerate");
            }

            lib.strip = true;
            if (lib.linkage == .static) {
                lib.pie = true;
            }

            b.installArtifact(lib);
        }
    }

    //--

    const final_static_lib = ArchiveStep.create(b, .{
        .out_name = b.fmt("libvosk{s}", .{target.staticLibSuffix()}),
        .inputs = &.{
            fst.getEmittedBin(),
            fstngram.getEmittedBin(),
            kaldi.getEmittedBin(),
            static_lib.getEmittedBin(),
        },
    });
    {
        const installFinalStep = b.addInstallLibFile(
            final_static_lib.output,
            final_static_lib.opts.out_name,
        );

        // Install explicitly, not by default
        // b.getInstallStep().dependOn(&installFinalStep.step);

        const step = b.step("static", "Build static lib");
        step.dependOn(&installFinalStep.step);
    }

    //--

    var additional_args = std.ArrayList([]const u8).init(b.allocator);
    {
        additional_args.append("-lc++") catch @panic("appendSlice");

        if (target.isDarwin()) {
            const target_info = std.zig.system.NativeTargetInfo.detect(target) catch unreachable;
            const sdk = std.zig.system.darwin.getSdk(b.allocator, target_info.target) orelse
                @panic("macOS SDK is missing");

            additional_args.appendSlice(&.{
                "-F",
                b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }),
                "-framework",
                "Accelerate",
                "-lc++",
            }) catch @panic("appendSlice");
        }
    }

    const final_shared_lib = DynamicArchiveStep.create(b, .{
        .out_name = b.fmt("libvosk{s}", .{target.dynamicLibSuffix()}),
        .target = target,
        .input = final_static_lib.output,
        .additional_args = additional_args.items,
    });
    const build_final_shared_lib_step = b.step("shared", "Build shared lib");
    {
        const installLib = b.addInstallLibFile(
            final_shared_lib.output,
            final_shared_lib.opts.out_name,
        );
        const installHeader = b.addInstallHeaderFile(
            vosk_dep.path("src/vosk_api.h").getPath(b),
            "vosk_api.h",
        );

        const step = build_final_shared_lib_step;
        step.dependOn(&installLib.step);
        step.dependOn(&installHeader.step);
    }

    //--------------------------------

    const c_example = b.addExecutable(.{
        .name = "c-example",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/example.c" },
    });
    {
        const exe = c_example;

        // exe.linkLibrary(static_lib);
        exe.addObjectFile(final_static_lib.output);
        exe.addIncludePath(vosk_dep.path("src"));
        exe.linkLibCpp();

        const run = b.addRunArtifact(exe);
        run.addFileSourceArg(model_dep.path(""));
        run.addFileSourceArg(vosk_dep.path("python/example/test.wav"));

        const step = b.step("c-example", "Run the C example");
        step.dependOn(&run.step);

        if (target.isDarwin()) {
            const target_info = std.zig.system.NativeTargetInfo.detect(target) catch unreachable;
            const sdk = std.zig.system.darwin.getSdk(b.allocator, target_info.target) orelse
                @panic("macOS SDK is missing");
            exe.addSystemIncludePath(.{ .path = b.pathJoin(&.{ sdk, "/usr/include" }) });
            exe.addSystemFrameworkPath(.{ .path = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
            exe.addLibraryPath(.{ .path = b.pathJoin(&.{ sdk, "/usr/lib" }) });
            exe.linkFramework("Accelerate");
        }
    }

    //--

    const zig_example = b.addExecutable(.{
        .name = "zig-example",
        .target = target,
        // TODO: this segfaults without this...
        .optimize = .ReleaseFast,
        .root_source_file = .{ .path = "src/example.zig" },
    });
    {
        const exe = zig_example;

        // exe.linkLibrary(static_lib);
        exe.addObjectFile(final_static_lib.output);
        exe.addIncludePath(vosk_dep.path("src"));
        exe.linkLibCpp();

        const run = b.addRunArtifact(exe);
        run.addFileSourceArg(model_dep.path(""));
        run.addFileSourceArg(vosk_dep.path("python/example/test.wav"));

        const step = b.step("zig-example", "Run the zig example");
        step.dependOn(&run.step);

        if (target.isDarwin()) {
            const target_info = std.zig.system.NativeTargetInfo.detect(target) catch unreachable;
            const sdk = std.zig.system.darwin.getSdk(b.allocator, target_info.target) orelse
                @panic("macOS SDK is missing");
            exe.addSystemIncludePath(.{ .path = b.pathJoin(&.{ sdk, "/usr/include" }) });
            exe.addSystemFrameworkPath(.{ .path = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
            exe.addLibraryPath(.{ .path = b.pathJoin(&.{ sdk, "/usr/lib" }) });
            exe.linkFramework("Accelerate");
        }
    }

    //--

    const zig_example_shared = b.addExecutable(.{
        .name = "zig-example-shared",
        .target = target,
        // TODO: this segfaults without this...
        .optimize = .ReleaseFast,
        .root_source_file = .{ .path = "src/example.zig" },
    });
    {
        const exe = zig_example_shared;

        // exe.linkLibrary(shared_lib);

        exe.linkSystemLibrary("vosk");
        exe.step.dependOn(build_final_shared_lib_step);
        exe.addLibraryPath(.{ .path = b.getInstallPath(.lib, "") });
        exe.addRPath(.{ .path = b.getInstallPath(.lib, "") });

        exe.addIncludePath(vosk_dep.path("src"));
        exe.linkLibCpp();

        const run = b.addRunArtifact(exe);
        run.addFileSourceArg(model_dep.path(""));
        run.addFileSourceArg(vosk_dep.path("python/example/test.wav"));

        const step = b.step("zig-example-shared", "Run the zig shared-library example");
        step.dependOn(&run.step);

        if (target.isDarwin()) {
            const target_info = std.zig.system.NativeTargetInfo.detect(target) catch unreachable;
            const sdk = std.zig.system.darwin.getSdk(b.allocator, target_info.target) orelse
                @panic("macOS SDK is missing");
            exe.addSystemIncludePath(.{ .path = b.pathJoin(&.{ sdk, "/usr/include" }) });
            exe.addSystemFrameworkPath(.{ .path = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
            exe.addLibraryPath(.{ .path = b.pathJoin(&.{ sdk, "/usr/lib" }) });
            exe.linkFramework("Accelerate");
        }
    }
}

// Combine static archives into a single static archive, e.g:
//
//   zig ar q libfull.a -c -L liba.a -L libb.a ...
//
const ArchiveStep = struct {
    step: *std.Build.Step,
    output: std.Build.FileSource,
    opts: Options,

    const Options = struct {
        out_name: []const u8,
        inputs: []const std.Build.FileSource,
    };

    fn create(b: *std.Build, opts: Options) *ArchiveStep {
        const self = b.allocator.create(ArchiveStep) catch @panic("OOM");

        const run_step = std.Build.RunStep.create(b, b.fmt(
            "create-static-archive-{s}",
            .{opts.out_name},
        ));
        run_step.addArgs(&.{ b.zig_exe, "ar", "q" });
        const output = run_step.addOutputFileArg(opts.out_name);
        run_step.addArgs(&.{"-c"});
        for (opts.inputs) |input_lib| {
            run_step.addArgs(&.{"-L"});
            run_step.addFileSourceArg(input_lib);
        }

        self.* = .{
            .step = &run_step.step,
            .output = output,
            .opts = opts,
        };

        return self;
    }
};

// Convert static archive into a dynamic archive, e.g:
//
//   zig cc -shared \
//     -Wl,--whole-archive libstatic.a -Wl,--no-whole-archive \
//     -o libshared.dylib \
//     -install_name @rpath/libshared.dylib \
//     ...
//
const DynamicArchiveStep = struct {
    step: *std.Build.Step,
    output: std.Build.FileSource,
    opts: Options,

    const Options = struct {
        out_name: []const u8,
        input: std.Build.FileSource,
        additional_args: []const []const u8,
        target: std.zig.CrossTarget,
    };

    fn create(b: *std.Build, opts: Options) *DynamicArchiveStep {
        const self = b.allocator.create(DynamicArchiveStep) catch @panic("OOM");
        const triple = opts.target.zigTriple(b.allocator) catch @panic("OOM, zigTriple");

        const run_step = std.Build.RunStep.create(b, b.fmt(
            "create-dynamic-archive-{s}",
            .{opts.out_name},
        ));

        // NOTE: this reduces binary size from 23M to 14M by linking against
        // c++, instead of including it.
        //
        //   clang -shared -all_load zig-out/lib/libvosk.a -framework Accelerate -lc++ -o libvosk.dylib
        //
        // TODO: get zig to do this as well.
        run_step.addArgs(&.{
            b.zig_exe,
            "cc",
            "-target",
            triple,
            "-shared",
            "-Wl,--whole-archive",
        });
        run_step.addFileSourceArg(opts.input);
        run_step.addArgs(&.{
            "-Wl,--no-whole-archive",
            "-o",
        });
        const output = run_step.addOutputFileArg(opts.out_name);
        run_step.addArgs(&.{
            "-install_name",
            b.fmt("@rpath/{s}", .{opts.out_name}),
        });
        run_step.addArgs(opts.additional_args);

        self.* = .{
            .step = &run_step.step,
            .output = output,
            .opts = opts,
        };

        return self;
    }
};
