#!/usr/bin/env sh

# Copyright 2023-present, Mark Delk
# SPDX-License-Identifier: Apache-2.0

set -ex

rm -rf ./tmp
gh run download -D tmp -n vosk

tree tmp
cd tmp

# NOTE: on linux, use --owner=0 --group=0
tar czvf vosk-0.3.45-x86_64-macos.tar.gz --uid=0 --gid=0 x86_64-macos
tar czvf vosk-0.3.45-aarch64-macos.tar.gz --uid=0 --gid=0 aarch64-macos

TAG='v0.1.0'

gh release create "$TAG" -n '
Builds of https://github.com/alphacep/vosk-api.

### NOTE

This initial release is only for MacOS, and uses `-framework Accelerate`.
'

gh release upload --clobber "$TAG" vosk-0.3.45-x86_64-macos.tar.gz
gh release upload --clobber "$TAG" vosk-0.3.45-aarch64-macos.tar.gz
