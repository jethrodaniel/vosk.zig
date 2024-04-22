#!/usr/bin/env sh

# Copyright 2023-present, Mark Delk
# SPDX-License-Identifier: Apache-2.0

set -ex

rm -rf ./tmp
gh run download -D tmp -n vosk

tree tmp
cd tmp

VERSION='0.3.50'
TAG='v0.3.0'

# NOTE: on linux, use --owner=0 --group=0
tar czvf "vosk-$VERSION-x86_64-macos.tar.gz" --uid=0 --gid=0 x86_64-macos
tar czvf "vosk-$VERSION-aarch64-macos.tar.gz" --uid=0 --gid=0 aarch64-macos


gh release create "$TAG" -n "
Builds of https://github.com/alphacep/vosk-api.

### NOTE

Vosk release: https://github.com/alphacep/vosk-api/releases/tag/v$VERSION
"

gh release upload --clobber "$TAG" "vosk-$VERSION-x86_64-macos.tar.gz"
gh release upload --clobber "$TAG" "vosk-$VERSION-aarch64-macos.tar.gz"
