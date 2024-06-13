#!/usr/bin/env sh

# Copyright 2023-present, Mark Delk
# SPDX-License-Identifier: Apache-2.0

# Usage:
#  ./release.sh 0.3.50 v0.4.0

set -ex

if [ "$1" = "" ]; then
  echo "Missing VOSK-VERSION"
  echo "Usage: $0 <VOSK-VERSION> <TAG>"
  exit 1
fi

if [ "$2" = "" ]; then
  echo "Missing TAG"
  echo "Usage: $0 <VOSK-VERSION> <TAG>"
  exit 1
fi

rm -rf ./tmp
gh run download -D tmp -n vosk

tree tmp
cd tmp

VERSION="$1"
TAG="$2"

if [ "$(uname)" == "Darwin" ]; then
  tar czvf "vosk-$VERSION-x86_64-macos.tar.gz" --uid=0 --gid=0 x86_64-macos
  tar czvf "vosk-$VERSION-aarch64-macos.tar.gz" --uid=0 --gid=0 aarch64-macos
else
  tar czvf "vosk-$VERSION-x86_64-macos.tar.gz" --owner=0 --group=0 x86_64-macos
  tar czvf "vosk-$VERSION-aarch64-macos.tar.gz" --owner=0 --group=0 aarch64-macos
fi

gh release create "$TAG" -n "
Vosk ([v$VERSION](https://github.com/alphacep/vosk-api/releases/tag/v$VERSION)), Zig $(zig version)
"

gh release upload --clobber "$TAG" "vosk-$VERSION-x86_64-macos.tar.gz"
gh release upload --clobber "$TAG" "vosk-$VERSION-aarch64-macos.tar.gz"
