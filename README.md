<!-- Copyright 2023-present, Mark Delk -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# vosk.zig

Building [vosk-api](https://github.com/alphacep/vosk-api) using [zig](https://ziglang.org).

## Status

- currently MacOS only (using `-framework Accelerate`)
- linux is _almost_ there, but depends on your system's openblas

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
zig build -Doptimize=ReleaseFast example-static
zig build -Doptimize=ReleaseFast example-shared
zig build -Doptimize=ReleaseFast example-zig
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

See the `example-zig` step in `build.zig`.

## License

[Apache-2.0](https://spdx.org/licenses/Apache-2.0.html), same as [Vosk](https://github.com/alphacep/vosk-api).

See the [SPDX identifiers](https://spdx.dev/) on each source code file.
