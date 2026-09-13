#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Phase 2, via build-and-publish-site.bash.
#
# Tars the payload as the release asset. KaptainPM points verbatimFiles here.
#
# Reproducible where tar allows it, so two builds of one commit produce the
# same bytes and the asset is worth checksumming against gh-pages.

set -euo pipefail

: "${VERSION:?VERSION is required (set by the versions-and-naming build step)}"

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-kaptain-out}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

BUILD_DIR="${OUTPUT_SUB_PATH%/}/site-build"
PAYLOAD="${BUILD_DIR}/site"
TARBALL="${BUILD_DIR}/keelson-pro-site.tgz"

if [[ ! -d "${PAYLOAD}" ]]; then
    printf 'Assembled payload not found at %s\n' "${PAYLOAD}" >&2
    printf 'assemble-site.bash should run before this script.\n' >&2
    exit 1
fi

rm -f "${TARBALL}"

# GNU only. BSD tar spells these differently, so a plain tar is the honest
# fallback rather than a half-reproducible one.
TAR_FLAGS=()
if tar --version 2>/dev/null | grep -q 'GNU tar'; then
    TAR_FLAGS=(--sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner)
else
    printf 'GNU tar not found - packaging without reproducibility flags.\n' >&2
fi

# The ${arr[@]+...} guard is load bearing: bash 3.2 counts an empty array as
# unbound under set -u, so a plain expansion aborts on any host without GNU tar.
tar ${TAR_FLAGS[@]+"${TAR_FLAGS[@]}"} -czf "${TARBALL}" -C "${PAYLOAD}" .

printf 'Packaged %s (%s bytes) for release %s\n' \
    "${TARBALL}" "$(wc -c < "${TARBALL}" | tr -d ' ')" "${VERSION}"
