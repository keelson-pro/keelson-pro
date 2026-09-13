#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# The preTaggingTests hook. Runs before $VERSION exists, so nothing
# version-aware belongs here.
#
# The link check earns its place: a static site has no runtime to complain, so
# a typo'd path ships silently and the page just looks wrong.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STATIC_DIR="src/static"

printf '== required sources ==\n'
REQUIRED=(
    "${STATIC_DIR}/index.html"
    "${STATIC_DIR}/.nojekyll"
    "${STATIC_DIR}/CNAME"
    src/release-notes.md
    src/pages-release-notes.md
    src/pages-README.md
)
MISSING=0
for file in "${REQUIRED[@]}"; do
    if [[ ! -f "${file}" ]]; then
        printf 'Missing required source file: %s\n' "${file}" >&2
        MISSING=1
    fi
done
[[ ${MISSING} -eq 0 ]] || exit 1
printf 'All %s required source files present.\n' "${#REQUIRED[@]}"

# Validates the CNAME as a side effect: site_url fails on a non-domain and the
# assignment propagates it. A bad CNAME takes the domain down at publish.
# shellcheck source=.github/bin/site-url.bash
source "$(dirname "${BASH_SOURCE[0]}")/site-url.bash"
SITE_URL="$(site_url)"
printf 'Custom domain declares %s\n' "${SITE_URL}"

printf '\n== shellcheck ==\n'
if ! command -v shellcheck >/dev/null 2>&1; then
    printf 'shellcheck not found on PATH (brew install shellcheck / apt install shellcheck)\n' >&2
    exit 1
fi
# Named rather than searched for: nothing else in the repo is shell.
shopt -s nullglob
SCRIPTS=(.github/bin/*.bash src/bin/*.bash)
if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    printf 'no .bash scripts found in .github/bin or src/bin\n' >&2
    exit 1
fi
shellcheck --shell=bash "${SCRIPTS[@]}"
printf 'All %s scripts pass.\n' "${#SCRIPTS[@]}"

printf '\n== local asset links ==\n'
# Fetched at build time, so not in src/static/ and not broken.
# shellcheck source=.github/bin/upstream-assets.bash
source "$(dirname "${BASH_SOURCE[0]}")/upstream-assets.bash"
BUILD_SUPPLIED="$(upstream_asset_names)"
# Only same-site references are ours to resolve.
BROKEN=0
CHECKED=0
SUPPLIED=0
while IFS= read -r page; do
    while IFS= read -r link; do
        case "${link}" in
            ''|'#'*|http://*|https://*|//*|mailto:*|tel:*|data:*) continue ;;
        esac
        # Drop any fragment or query before resolving to a path on disk.
        target="${link%%#*}"
        target="${target%%\?*}"
        [[ -n "${target}" ]] || continue
        if [[ "${target}" == /* ]]; then
            # Site-absolute: resolves against the published root, not the repo root.
            resolved="${STATIC_DIR}${target}"
        else
            resolved="$(dirname "${page}")/${target}"
        fi
        CHECKED=$((CHECKED + 1))
        if printf '%s\n' "${BUILD_SUPPLIED}" | grep -qxF "${target##*/}"; then
            SUPPLIED=$((SUPPLIED + 1))
            continue
        fi
        if [[ ! -e "${resolved}" ]]; then
            printf 'Broken link in %s: %s (looked for %s)\n' "${page}" "${link}" "${resolved}" >&2
            BROKEN=$((BROKEN + 1))
        fi
    done < <(grep -oE '(href|src)="[^"]*"' "${page}" | sed -E 's/^(href|src)="//; s/"$//' | sort -u)
done < <(find "${STATIC_DIR}" -type f -name '*.html' | sort)

if [[ ${BROKEN} -gt 0 ]]; then
    printf '%s broken local link(s) found.\n' "${BROKEN}" >&2
    exit 1
fi
printf '%s local link(s) resolve (%s supplied by the build).\n' \
    "${CHECKED}" "${SUPPLIED}"

printf '\n== trailing newlines ==\n'
# Empty files excluded: src/static/.nojekyll is deliberately zero bytes.
#
# find, not git ls-files: reading the index would invite staging things just to
# get a clean run. What is on disk is what the build consumes.
NO_NEWLINE=0
CHECKED_FILES=0
while IFS= read -r file; do
    [[ -s "${file}" ]] || continue
    CHECKED_FILES=$((CHECKED_FILES + 1))
    if [[ -n "$(tail -c 1 "${file}")" ]]; then
        printf 'No trailing newline: %s\n' "${file}" >&2
        NO_NEWLINE=$((NO_NEWLINE + 1))
    fi
done < <(find . \
    -name .git -prune -o \
    -name kaptain-out -prune -o \
    -name kaptainpm -prune -o \
    -type f \( -name '*.md' -o -name '*.html' -o -name '*.css' \
        -o -name '*.js' -o -name '*.yaml' -o -name '*.bash' \) -print | sort)

if [[ ${NO_NEWLINE} -gt 0 ]]; then
    printf '%s file(s) missing a trailing newline.\n' "${NO_NEWLINE}" >&2
    exit 1
fi
printf 'All %s text files end with a newline.\n' "${CHECKED_FILES}"
