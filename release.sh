#!/usr/bin/env sh

# Copyright 2023-present, Mark Delk
# SPDX-License-Identifier: Apache-2.0

set -ex

rm -rf ./tmp
gh run download -D tmp -n vosk

tree tmp
cd tmp

# NOTE: on linux, use --owner=0 --group=0
tar czvf vosk-0.3.48-x86_64-macos.tar.gz --uid=0 --gid=0 x86_64-macos
tar czvf vosk-0.3.48-aarch64-macos.tar.gz --uid=0 --gid=0 aarch64-macos

TAG='v0.2.0'

gh release create "$TAG" -n "
Builds of https://github.com/alphacep/vosk-api.

### NOTE

v0.3.48 isn't officially released yet.

Vosk version: https://github.com/alphacep/vosk-api/tree/40937b6bcbe318eeb01879093c59cf5a1219a29d
"

gh release upload --clobber "$TAG" vosk-0.3.48-x86_64-macos.tar.gz
gh release upload --clobber "$TAG" vosk-0.3.48-aarch64-macos.tar.gz
