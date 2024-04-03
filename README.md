<!-- Copyright 2023-present, Mark Delk -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# vosk.zig

Building [vosk-api](https://github.com/alphacep/vosk-api) using [zig](https://ziglang.org).

## Status

- MacOS (using `linkFramework("Accelerate")`)
- Linux (using `linkSystemLibrary("openblas")`)

## Building

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-native -p vosk/x86_64-macos
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-native -p vosk/aarch64-macos
```

Result (on MacOS):
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

## Examples

```sh
zig build -Doptimize=ReleaseFast example-static
zig build -Doptimize=ReleaseFast example-shared
zig build -Doptimize=ReleaseFast example-zig
```

## Usage

### C/C++

```sh
zig cc -Ivosk/aarch64-macos/include -Lvosk/aarch64-macos/lib src/example.c -lvosk -Wl,-rpath,vosk/aarch64-macos/lib
./a.out path/to/model path/to/wav
```

### FFI

```sh
git clone -b ruby https://github.com/jethrodaniel/vosk-api
cd vosk-api/ruby

cp -v path/to/libvosk.dylib .

bundle
bundle exec ruby examples/transcribe.rb
```

### Zig

See the `example-zig` step in `build.zig`.

## License

[Apache-2.0](https://spdx.org/licenses/Apache-2.0.html), same as [Vosk](https://github.com/alphacep/vosk-api).

See the [SPDX identifiers](https://spdx.dev/) on each source code file.
