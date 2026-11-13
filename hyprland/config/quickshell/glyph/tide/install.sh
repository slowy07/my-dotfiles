#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
build="${XDG_CACHE_HOME:-$HOME/.cache}/glyph/tide-build"

cmake -S "$here" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$build"
sudo cmake --install "$build"
