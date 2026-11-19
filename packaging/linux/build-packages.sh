#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds Debian (.deb) and Red Hat (.rpm) packages for HORCOM using CPack
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
build_dir=${BUILD_DIR:-$root/build}

log() {
    printf "\033[1;32m[HORCOM-PACKAGING]\033[0m %s\n" "$1"
}

log "Configuring build directory at $build_dir..."
mkdir -p "$build_dir"
cd "$build_dir"

if [ ! -f "Makefile" ] && [ ! -f "build.ninja" ]; then
    cmake -S "$root" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
fi

log "Building targets..."
cmake --build "$build_dir" -j"$(nproc 2>/dev/null || echo 2)"

log "Generating .deb package..."
cpack -G DEB

if command -v rpmbuild >/dev/null 2>&1; then
    log "Generating .rpm package..."
    cpack -G RPM
else
    log "rpmbuild not found, skipping .rpm package generation."
fi

log "Packages successfully created in $build_dir:"
ls -la "$build_dir"/horcom-*.deb "$build_dir"/horcom-*.rpm 2>/dev/null || true
