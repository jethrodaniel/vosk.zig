// Copyright 2023-present, Mark Delk
// SPDX-License-Identifier: Apache-2.0

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vosk_dep = b.dependency("vosk", .{});
    const fst_dep = b.dependency("openfst", .{});
    const kaldi_dep = b.dependency("kaldi", .{});
    const model_dep = b.dependency("vosk_model_small_en_us_0_15", .{});

    //--

    const fst = b.addStaticLibrary(.{
        .name = "fst",
        .target = target,
        .optimize = .ReleaseFast,
        .strip = true,
    });
    {
        const lib = fst;
        lib.addCSourceFiles(.{
            .root = fst_dep.path(""),
            .files = &.{
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
            },
        });

        lib.defineCMacro("NDEBUG", "1");
        lib.defineCMacro("FST_NO_DYNAMIC_LINKING", "1");
        lib.addIncludePath(fst_dep.path("src/include"));
        lib.linkLibCpp();

        lib.pie = true;
    }

    //

    const fstngram = b.addStaticLibrary(.{
        .name = "fstngram",
        .target = target,
        .optimize = .ReleaseFast,
        .strip = true,
    });
    {
        const lib = fstngram;
        lib.addCSourceFiles(.{
            .root = fst_dep.path(""),
            .files = &.{
                "src/extensions/ngram/bitmap-index.cc",
                "src/extensions/ngram/ngram-fst.cc",
                "src/extensions/ngram/nthbit.cc",
            },
        });

        lib.addIncludePath(fst_dep.path("src/include"));
        lib.linkLibCpp();
        lib.linkLibrary(fst);

        lib.pie = true;
    }

    //--

    const kaldi_optimize = .ReleaseFast;

    //

    const kaldi_base = b.addStaticLibrary(.{
        .name = "kaldi-base",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_base;
        const srcs: []const []const u8 = &.{
            "src/base/io-funcs.cc",
            "src/base/kaldi-error.cc",
            "src/base/kaldi-math.cc",
            "src/base/kaldi-utils.cc",
            "src/base/timer.cc",
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.defineCMacro("KALDI_VERSION", "\"5.5\""); // kaldi/src/.version
        lib.defineCMacro("NDEBUG", "1");
    }

    //

    const kaldi_matrix = b.addStaticLibrary(.{
        .name = "kaldi-matrix",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_matrix;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);
        lib.linkLibrary(kaldi_base);

        lib.defineCMacro("HAVE_CLAPACK", "1");
        // lib.defineCMacro("HAVE_OPENBLAS", "1");

        if (target.result.os.tag == .macos) {
            // NOTE: Using Xcode's `Accelerate` framework means that we have to
            //   comply with Apple's Xcode license:
            //
            //   https://www.apple.com/legal/sla/docs/xcode.pdf
            //
            // See https://github.com/hexops/xcode-frameworks/blob/main/LICENSE
            //
            // TODO: use OpenBLAS instead to avoid this (requires Kaldi changes).
            lib.linkFramework("Accelerate");
        } else if (target.result.os.tag == .linux) {
            lib.addIncludePath(kaldi_dep.path("tools/CLAPACK"));

            // sudo apt-get install -y libopenblas-dev
            lib.linkSystemLibrary("openblas");
        }
    }

    //

    const kaldi_util = b.addStaticLibrary(.{
        .name = "kaldi-util",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_util;
        const srcs: []const []const u8 = &.{
            "src/util/kaldi-holder.cc",
            "src/util/kaldi-io.cc",
            "src/util/kaldi-semaphore.cc",
            "src/util/kaldi-table.cc",
            "src/util/kaldi-thread.cc",
            "src/util/parse-options.cc",
            "src/util/simple-io-funcs.cc",
            "src/util/simple-options.cc",
            "src/util/text-utils.cc",
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        kaldi_util.linkLibrary(kaldi_matrix);
        kaldi_util.linkLibrary(kaldi_base);
    }

    //

    const kaldi_tree = b.addStaticLibrary(.{
        .name = "kaldi-tree",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_tree;

        const srcs: []const []const u8 = &.{
            "src/tree/build-tree-questions.cc",
            "src/tree/build-tree-utils.cc",
            "src/tree/build-tree.cc",
            "src/tree/cluster-utils.cc",
            "src/tree/clusterable-classes.cc",
            "src/tree/context-dep.cc",
            "src/tree/event-map.cc",
            "src/tree/tree-renderer.cc",
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_gmm = b.addStaticLibrary(.{
        .name = "kaldi-gmm",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_gmm;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_transform = b.addStaticLibrary(.{
        .name = "kaldi-transform",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });

    {
        const lib = kaldi_transform;

        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_gmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_ivector = b.addStaticLibrary(.{
        .name = "kaldi-ivector",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_ivector;

        const srcs: []const []const u8 = &.{
            "src/ivector/agglomerative-clustering.cc",
            "src/ivector/ivector-extractor.cc",
            "src/ivector/logistic-regression.cc",
            "src/ivector/plda.cc",
            "src/ivector/voice-activity-detection.cc",
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_transform);
        lib.linkLibrary(kaldi_gmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_cudamatrix = b.addStaticLibrary(.{
        .name = "kaldi-cudamatrix",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_cudamatrix;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);

        lib.defineCMacro("HAVE_CUDA", "0");
        lib.defineCMacro("NDEBUG", "1");
    }

    //

    const kaldi_hmm = b.addStaticLibrary(.{
        .name = "kaldi-hmm",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_hmm;
        const srcs: []const []const u8 = &.{
            "src/hmm/hmm-topology.cc",
            "src/hmm/hmm-utils.cc",
            "src/hmm/posterior.cc",
            "src/hmm/transition-model.cc",
            "src/hmm/tree-accu.cc",
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_lat = b.addStaticLibrary(.{
        .name = "kaldi-lat",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_lat;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_hmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_fstext = b.addStaticLibrary(.{
        .name = "kaldi-fstext",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_fstext;
        const srcs: []const []const u8 = &.{
            "src/fstext/context-fst.cc",
            "src/fstext/grammar-context-fst.cc",
            "src/fstext/kaldi-fst-io.cc",
            "src/fstext/push-special.cc",
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);
    }

    //

    const kaldi_chain = b.addStaticLibrary(.{
        .name = "kaldi-chain",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_chain;
        const srcs: []const []const u8 = &.{
            "src/chain/chain-supervision.cc",
            "src/chain/chain-numerator.cc",
            "src/chain/chain-den-graph.cc",
            "src/chain/language-model.cc",
            "src/chain/chain-denominator.cc",
            "src/chain/chain-training.cc",
            "src/chain/chain-generic-numerator.cc",
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);
        lib.defineCMacro("HAVE_CUDA", "0");

        lib.linkLibrary(kaldi_cudamatrix);
        lib.linkLibrary(kaldi_lat);
        lib.linkLibrary(kaldi_fstext);
        lib.linkLibrary(kaldi_hmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_decoder = b.addStaticLibrary(.{
        .name = "kaldi-decoder",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_decoder;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_lat);
        lib.linkLibrary(kaldi_fstext);
        lib.linkLibrary(kaldi_hmm);
        lib.linkLibrary(kaldi_transform);
        lib.linkLibrary(kaldi_gmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_nnet3 = b.addStaticLibrary(.{
        .name = "kaldi-nnet3",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_nnet3;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);
        lib.defineCMacro("HAVE_CUDA", "0");

        lib.linkLibrary(kaldi_chain);
        lib.linkLibrary(kaldi_cudamatrix);
        lib.linkLibrary(kaldi_decoder);
        lib.linkLibrary(kaldi_lat);
        lib.linkLibrary(kaldi_fstext);
        lib.linkLibrary(kaldi_hmm);
        lib.linkLibrary(kaldi_transform);
        lib.linkLibrary(kaldi_gmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_feat = b.addStaticLibrary(.{
        .name = "kaldi-feat",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_feat;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_transform);
        lib.linkLibrary(kaldi_gmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_lm = b.addStaticLibrary(.{
        .name = "kaldi-lm",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_lm;
        const srcs: []const []const u8 = &.{
            "src/lm/arpa-file-parser.cc",
            "src/lm/arpa-lm-compiler.cc",
            "src/lm/const-arpa-lm.cc",
            "src/lm/kaldi-rnnlm.cc",
            "src/lm/kenlm.cc",
            "src/lm/mikolov-rnnlm-lib.cc",
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_fstext);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_rnnlm = b.addStaticLibrary(.{
        .name = "kaldi-rnnlm",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_rnnlm;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);
        lib.linkLibCpp();

        lib.linkLibrary(kaldi_nnet3);
        lib.linkLibrary(kaldi_cudamatrix);
        lib.linkLibrary(kaldi_lm);
        lib.linkLibrary(kaldi_hmm);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_nnet2 = b.addStaticLibrary(.{
        .name = "kaldi-nnet2",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_nnet2;
        const srcs: []const []const u8 = &.{
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
        };
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);
        lib.defineCMacro("HAVE_CUDA", "0");

        lib.linkLibrary(kaldi_cudamatrix);
        lib.linkLibrary(kaldi_lat);
        lib.linkLibrary(kaldi_hmm);
        lib.linkLibrary(kaldi_transform);
        lib.linkLibrary(kaldi_gmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //

    const kaldi_online2 = b.addStaticLibrary(.{
        .name = "kaldi-online2",
        .target = target,
        .optimize = kaldi_optimize,
        .strip = true,
    });
    {
        const lib = kaldi_online2;
        const srcs: []const []const u8 = &.{
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
        kaldiLibrary(b, target, lib, kaldi_dep, fst_dep, srcs);

        lib.linkLibrary(kaldi_ivector);
        lib.linkLibrary(kaldi_nnet3);
        lib.linkLibrary(kaldi_chain);
        lib.linkLibrary(kaldi_nnet2);
        lib.linkLibrary(kaldi_cudamatrix);
        lib.linkLibrary(kaldi_decoder);
        lib.linkLibrary(kaldi_lat);
        lib.linkLibrary(kaldi_hmm);
        lib.linkLibrary(kaldi_feat);
        lib.linkLibrary(kaldi_transform);
        lib.linkLibrary(kaldi_gmm);
        lib.linkLibrary(kaldi_tree);
        lib.linkLibrary(kaldi_util);
        lib.linkLibrary(kaldi_matrix);
        lib.linkLibrary(kaldi_base);
    }

    //----

    const static_lib = b.addStaticLibrary(.{
        .name = "vosk",
        .target = target,
        .optimize = optimize,
        .strip = true,
    });
    const shared_lib = b.addSharedLibrary(.{
        .name = "vosk",
        .target = target,
        .optimize = optimize,
        .strip = true,
    });

    {
        const libs: *const [2]*std.Build.Step.Compile = &.{
            static_lib,
            shared_lib,
        };
        for (libs) |lib| {
            lib.addCSourceFiles(.{
                .root = vosk_dep.path(""),
                .files = &.{
                    "src/language_model.cc",
                    "src/model.cc",
                    "src/postprocessor.cc",
                    "src/recognizer.cc",
                    "src/spk_model.cc",
                    "src/vosk_api.cc",
                },
                .flags = &.{"-std=c++17"},
            });

            lib.addIncludePath(kaldi_dep.path("src"));
            lib.addIncludePath(fst_dep.path("src/include"));

            lib.linkLibCpp();
            lib.linkLibrary(kaldi_rnnlm);
            lib.linkLibrary(kaldi_online2);
            lib.linkLibrary(fstngram);

            if (target.result.os.tag == .macos) {
                const sdk = std.zig.system.darwin.getSdk(b.allocator, b.host.result) orelse
                    @panic("macOS SDK is missing");
                lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
                lib.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
                lib.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
            }

            lib.installHeader(vosk_dep.path("src/vosk_api.h"), "vosk_api.h");

            if (lib.linkage == .static)
                lib.pie = true
            else
                b.installArtifact(lib);
        }
    }

    const module = b.addModule("vosk", .{
        .root_source_file = b.path("src/lib.zig"),
        .link_libcpp = true,
    });
    {
        module.linkLibrary(static_lib);
    }

    //--

    const example_static = b.addExecutable(.{
        .name = "example-static",
        .target = target,
        .optimize = optimize,
    });
    {
        const exe = example_static;

        exe.addCSourceFile(.{ .file = b.path("src/example.c"), .flags = &.{} });

        exe.linkLibrary(static_lib);

        const run = b.addRunArtifact(exe);
        run.addFileArg(model_dep.path(""));
        run.addFileArg(vosk_dep.path("python/example/test.wav"));

        const step = b.step("example-static", "Run the static library example");
        step.dependOn(&run.step);
    }

    const example_shared = b.addExecutable(.{
        .name = "example-shared",
        .target = target,
        .optimize = optimize,
    });
    {
        const exe = example_shared;

        exe.addCSourceFile(.{ .file = b.path("src/example.c"), .flags = &.{} });

        exe.linkLibrary(shared_lib);

        const run = b.addRunArtifact(exe);
        run.addFileArg(model_dep.path(""));
        run.addFileArg(vosk_dep.path("python/example/test.wav"));

        const step = b.step("example-shared", "Run the shared-library example");
        step.dependOn(&run.step);
    }

    const example_zig = b.addExecutable(.{
        .name = "example-zig",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/example.zig"),
    });
    {
        const exe = example_zig;

        exe.root_module.addImport("vosk", module);

        const run = b.addRunArtifact(exe);
        run.addFileArg(model_dep.path(""));
        run.addFileArg(vosk_dep.path("python/example/test.wav"));

        const step = b.step("example-zig", "Run the zig example");
        step.dependOn(&run.step);
    }
}

fn kaldiLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    lib: *std.Build.Step.Compile,
    kaldi_dep: *std.Build.Dependency,
    fst_dep: *std.Build.Dependency,
    srcs: []const []const u8,
) void {
    lib.addCSourceFiles(.{
        .root = kaldi_dep.path(""),
        .files = srcs,
        .flags = &.{"-std=c++17"},
    });

    lib.addIncludePath(kaldi_dep.path("src"));
    lib.addIncludePath(kaldi_dep.path("src/base"));
    lib.addIncludePath(fst_dep.path("src/include"));
    lib.linkLibCpp();

    if (target.result.os.tag == .macos) {
        const sdk = std.zig.system.darwin.getSdk(b.allocator, b.host.result) orelse
            @panic("macOS SDK is missing");
        lib.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
        lib.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
        lib.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
    }

    lib.pie = true;
}
