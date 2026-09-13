#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Sourced, not run. One definition, so the notes and the publish cannot
# disagree about what got tagged.
#
# main X.Y publishes as 42.X.Y. Carrying both parts lets the main series be
# bumped, 1.9 to 2.0, without colliding with a patch sharing the last number.
# gh-pages is an orphan, so these tags never reach the version calculation.

# shellcheck disable=SC2148 # sourced, the sourcing script sets the shell

PAGES_TAG_SERIES=42

pages_tag_for() {
    local version="${1:?version is required}"
    if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+$ ]]; then
        printf 'Expected a two part version like 1.7, got: %s\n' "${version}" >&2
        return 1
    fi
    printf '%s.%s' "${PAGES_TAG_SERIES}" "${version}"
}
