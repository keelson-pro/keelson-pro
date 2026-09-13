#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Sourced, not run. One list, so the fetcher and the source checks cannot
# disagree about what the build supplies.

# shellcheck disable=SC2148 # sourced, the sourcing script sets the shell

UPSTREAM_RAW="https://raw.githubusercontent.com/keelson-pro"

# "filename:url". The filename is what index.html references under img/.
UPSTREAM_ASSETS=(
    "keelson-ecosystem.png:${UPSTREAM_RAW}/keelson-all/main/images/keelson-ecosystem.png"
    "keelson-version-coverage.png:${UPSTREAM_RAW}/keelson/main/images/keelson-version-coverage.png"
)

# For callers that only need to know what to expect.
upstream_asset_names() {
    local entry
    for entry in "${UPSTREAM_ASSETS[@]}"; do
        printf '%s\n' "${entry%%:*}"
    done
}
