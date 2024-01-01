<!-- Copyright 2023-present, Mark Delk -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# vosk.zig

Building [vosk-api](https://github.com/alphacep/vosk-api) using [zig](https://ziglang.org).

**NOTE**: currently only supports MacOS (x86/arm64)

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
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos.13.0...13.0-none -p vosk/x86_64-macos
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos.13.0...13.0-none -p vosk/aarch64-macos
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

To build dynamic and static libraries for x86/arm64:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos.13.0...13.0-none -p vosk/x86_64-macos install static
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos.13.0...13.0-none -p vosk/aarch64-macos install static
```

Result:
```sh
% tree vosk
vosk
├── aarch64-macos
│   ├── include
│   │   └── vosk_api.h
│   └── lib
│       ├── libvosk.a
│       └── libvosk.dylib
└── x86_64-macos
    ├── include
    │   └── vosk_api.h
    └── lib
        ├── libvosk.a
        └── libvosk.dylib
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

#### Compiling from source

Add to your `build.zig.zon`:
```sh
TODO
```

Update your `build.zig`:
```sh
TODO
```

Use in your code like so:
```sh
TODO
```

#### Using the pre-compiled binaries

Add to your `build.zig.zon`:
```sh
TODO
```

Update your `build.zig`:
```sh
TODO
```

Use in your code like so:
```sh
TODO
```

## License

[Apache-2.0](https://spdx.org/licenses/Apache-2.0.html), same as [Vosk](https://github.com/alphacep/vosk-api).

See the [SPDX identifiers](https://spdx.dev/)  on each source code file.
