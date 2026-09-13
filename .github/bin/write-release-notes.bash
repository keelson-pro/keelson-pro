#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Phase 3, via build-and-publish-site.bash.
#
# Writes both sets of release notes. Prose lives in src/; this fills in the
# versions and URLs so they cannot drift. KaptainPM points notesFile here.

set -euo pipefail

: "${VERSION:?VERSION is required (set by the versions-and-naming build step)}"
: "${REPOSITORY_OWNER:?REPOSITORY_OWNER is required (set by the build)}"
: "${REPOSITORY_NAME:?REPOSITORY_NAME is required (set by the build)}"

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-kaptain-out}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=.github/bin/pages-tag.bash
source "$(dirname "${BASH_SOURCE[0]}")/pages-tag.bash"
PAGES_TAG="$(pages_tag_for "${VERSION}")"

BUILD_DIR="${OUTPUT_SUB_PATH%/}/site-build"
NOTES_FILE="${BUILD_DIR}/release-notes.md"
NOTES_SOURCE="src/release-notes.md"

if [[ ! -f "${NOTES_SOURCE}" ]]; then
    printf 'Release notes source not found: %s\n' "${NOTES_SOURCE}" >&2
    exit 1
fi

# shellcheck source=.github/bin/site-url.bash
source "$(dirname "${BASH_SOURCE[0]}")/site-url.bash"
SITE_URL="$(site_url)"

REPO_URL="https://github.com/${REPOSITORY_OWNER}/${REPOSITORY_NAME}"

# Together, so the substitution has one implementation:
#
#   NOTES_FILE       the X.Y release on main, attached by kaptain
#   PAGES_NOTES_FILE the 42.X.Y release on the gh-pages tag
PAGES_NOTES_SOURCE="src/pages-release-notes.md"
PAGES_NOTES_FILE="${BUILD_DIR}/pages-release-notes.md"

if [[ ! -f "${PAGES_NOTES_SOURCE}" ]]; then
    printf 'Pages release notes source not found: %s\n' "${PAGES_NOTES_SOURCE}" >&2
    exit 1
fi

mkdir -p "${BUILD_DIR}"
for pair in "${NOTES_SOURCE}:${NOTES_FILE}" "${PAGES_NOTES_SOURCE}:${PAGES_NOTES_FILE}"; do
    source_file="${pair%%:*}"
    target_file="${pair#*:}"

    sed -e "s|@VERSION@|${VERSION}|g" \
        -e "s|@PAGES_TAG@|${PAGES_TAG}|g" \
        -e "s|@SITE_URL@|${SITE_URL}|g" \
        -e "s|@REPO_URL@|${REPO_URL}|g" \
        "${source_file}" > "${target_file}"

    if grep -n '@[A-Z_]\{2,\}@' "${target_file}" >&2; then
        printf 'Unsubstituted token left in %s (above).\n' "${target_file}" >&2
        exit 1
    fi

    printf 'Wrote %s\n' "${target_file}"
done
