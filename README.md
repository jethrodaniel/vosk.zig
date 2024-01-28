<!-- Copyright 2023-present, Mark Delk -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# vosk.zig

Building [vosk-api](https://github.com/alphacep/vosk-api) using [zig](https://ziglang.org).

## Status

- currently only supports MacOS (x86/arm64)
  - NOTE: requires `-framework Accelerate`

## Setup

Install zig, if you haven't already, e.g:

```
ZIG=zig-macos-x86_64-0.12.0-dev.1861+412999621
wget -nv https://ziglang.org/builds/${ZIG}.tar.xz
tar xf ${ZIG}.tar.xz
cp -v ${ZIG}/zig /usr/local/bin/zig
zig version
```

Then clone this project:
```sh
git clone https://github.com/jethrodaniel/vosk.zig
cd vosk.zig
```

## Building

To build dynamic libraries for x86/arm64:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos.10.13...13.6.3-none -p vosk/x86_64-macos shared
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos.11.0...13.6.3-none -p vosk/aarch64-macos shared
```

Result:
```sh
% tree vosk
vosk
├── aarch64-macos
│   ├── include
│   │   └── vosk_api.h
│   └── lib
│       └── libvosk.dylib
└── x86_64-macos
    ├── include
    │   └── vosk_api.h
    └── lib
        └── libvosk.dylib
```

To build static libraries for x86/arm64:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos.10.13...13.6.3-none -p vosk/x86_64-macos static
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos.11.0...13.6.3-none -p vosk/aarch64-macos static
```

Result:
```sh
% tree vosk
vosk
├── aarch64-macos
│   ├── include
│   │   └── vosk_api.h
│   └── lib
│       └── libvosk.a
└── x86_64-macos
    ├── include
    │   └── vosk_api.h
    └── lib
│       └── libvosk.a
```

## Examples

```sh
zig build c-example
zig build zig-example
zig build zig-example-shared
```

## Usage

### C/C++

To use the static library:

```sh
zig cc -I vosk/x86_64-macos/include src/example.c vosk/x86_64-macos/lib/libvosk.a -framework Accelerate -lc++
./a.out path/to/model path/to/wav
```

To use the dynamic library:

```sh
zig cc -Ivosk/x86_64-macos/include -Lvosk/x86_64-macos/lib src/example.c -lvosk -Wl,-rpath,vosk/x86_64-macos/lib
./a.out path/to/model path/to/wav
```

### FFI

To use the dynamic library, move it somewhere your system can find it, e.g:

```sh
cp -v vosk/x86_64-macos/lib/libvosk.a /usr/local/lib/

git clone -b ruby https://github.com/jethrodaniel/vosk-api
cd vosk-api/ruby
bundle
bundle exec ruby examples/transcribe.rb
```

### Zig

Add to your `build.zig.zon`:
```zig
.{
    .name = "example",
    .version = "0.0.0",
    .dependencies = .{
        .vosk_source = .{
            .url = "git+https://github.com/jethrodaniel/vosk.zig#dev",
            .hash = "12206658cfeb9fab1531ea506761d158c02b3a4fba83ba593c2bdc32af3f917c1134",
        },
        .vosk_x86_64_macos = .{
            .url = "https://github.com/jethrodaniel/vosk.zig/releases/download/v0.1.0/vosk-0.3.45-x86_64-macos.tar.gz",
            .hash = "1220d9484589f6201795ec1e08c877068254753527245e57d888ce339caa6a01a38a",
        },
        .vosk_aarch64_macos = .{
            .url = "https://github.com/jethrodaniel/vosk.zig/releases/download/v0.1.0/vosk-0.3.45-aarch64-macos.tar.gz",
            .hash = "1220f91ec8be66fbe01d0773db8c309c62ec160db94ff0f77325e8dd710e276b8b40",
        },
        .vosk_model_small_en_us_0_15 = .{
            // TODO: fetch from https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
            //  once https://github.com/ziglang/zig/issues/17408 is resolved.
            .url = "https://github.com/jethrodaniel/vosk-models/releases/download/vosk-model-small-en-us-0.15/vosk-model-small-en-us-0.15.tar.gz",
            .hash = "1220e90dfb99e498e47515674d2934fcb6ce982598e0a76937573e69f2c009890342",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

Update your `build.zig`:
```zig
   // 1. use vosk.zig

    const use_precompiled_vosk = b.option(bool, "use_precompiled_vosk",
        \\Use precompiled Vosk (default: true)
    ) orelse (target.result.os.tag == .macos);

    if (use_precompiled_vosk and
        !(target.result.cpu.arch == .aarch64 or target.result.cpu.arch == .x86_64))
    {
        const triple = target.result.zigTriple(b.allocator) catch @panic("OOM, zigTriple");
        @panic(b.fmt("arch {s} is invalid for vosk", .{triple}));
    }
    const vosk_dep_name = if (use_precompiled_vosk and target.result.cpu.arch == .aarch64)
        "vosk_aarch64_macos"
    else if (use_precompiled_vosk and target.result.cpu.arch == .x86_64)
        "vosk_x86_64_macos"
    else
        "vosk_source";

    const vosk_dep = b.dependency(vosk_dep_name, .{
        .target = target,
        .optimize = .ReleaseFast,
    });

    const vosk_precompiled_module = b.createModule(.{
        .root_source_file = b.addWriteFiles().add("lib.zig",
            \\pub const c = @cImport({
            \\    @cInclude("vosk_api.h");
            \\});
        ),
        .link_libcpp = true,
        .target = target,
    });
    {
        const module = vosk_precompiled_module;
        module.linkSystemLibrary("vosk", .{ .needed = true });
        module.addLibraryPath(vosk_dep.path("lib"));
        module.addIncludePath(vosk_dep.path("include"));
    }

    const vosk_module = if (use_precompiled_vosk)
        vosk_precompiled_module
    else
        vosk_dep.module("vosk");

    exe.root_module.addImport("vosk", vosk_module);


    // 2. use a vosk model

    const model_dep = b.dependency("vosk_model_small_en_us_0_15", .{});

    const install_model = b.addInstallDirectory(.{
        .source_dir = model_dep.path(""),
        .install_dir = .bin,
        .install_subdir = "model",
    });
    exe.step.dependOn(&install_model.step);
```

## License

[Apache-2.0](https://spdx.org/licenses/Apache-2.0.html), same as [Vosk](https://github.com/alphacep/vosk-api).

See the [SPDX identifiers](https://spdx.dev/)  on each source code file.
