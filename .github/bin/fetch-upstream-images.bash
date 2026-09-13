#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Phase 1, via build-and-publish-site.bash.
#
# Pulls the diagrams that belong to other repositories. Fetched rather than
# copied in so each has one master, in the repo that owns it. Always latest on
# main: filenames are stable, so a redrawn diagram arrives on the next build.
#
# A release build insists on a fresh copy. A local build falls back to the last
# one fetched, so being offline does not stop you working on the CSS.

set -euo pipefail

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-kaptain-out}"
BUILD_MODE="${BUILD_MODE:-local}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

CACHE="${OUTPUT_SUB_PATH%/}/site-build/upstream"
mkdir -p "${CACHE}"

# shellcheck source=.github/bin/upstream-assets.bash
source "$(dirname "${BASH_SOURCE[0]}")/upstream-assets.bash"

for entry in "${UPSTREAM_ASSETS[@]}"; do
    name="${entry%%:*}"
    url="${entry#*:}"
    target="${CACHE}/${name}"

    # --fail, or a 404 lands as an HTML error page saved with a .png name.
    if curl --silent --show-error --fail --location --max-time 60 \
            --output "${target}.part" "${url}"; then

        # A 200 is not proof of an image, and a broken one would ship.
        kind="$(file --brief --mime-type "${target}.part")"
        if [[ "${kind}" != image/* ]]; then
            printf 'Fetched %s is not an image (%s)\n' "${name}" "${kind}" >&2
            rm -f "${target}.part"
            exit 1
        fi

        mv "${target}.part" "${target}"
        printf 'Fetched %-32s %s bytes\n' "${name}" \
            "$(wc -c < "${target}" | tr -d ' ')"
        continue
    fi

    rm -f "${target}.part"

    if [[ "${BUILD_MODE}" == "build_server" || ! -s "${target}" ]]; then
        printf '\nCould not fetch %s\n  from %s\n' "${name}" "${url}" >&2
        exit 1
    fi

    printf 'Could not fetch %s, using the previously fetched copy.\n' "${name}" >&2
done
