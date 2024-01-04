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

# gh release create v0.3.45 -n 'macos builds of https://github.com/alphacep/vosk-api'
gh release upload --clobber v0.3.45 vosk-0.3.45-x86_64-macos.tar.gz
gh release upload --clobber v0.3.45 vosk-0.3.45-aarch64-macos.tar.gz
