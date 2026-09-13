#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Phase 4, via build-and-publish-site.bash.
#
# Publishes the assembled payload to gh-pages, which is what keelson.pro serves.
#
# Everything up to the commit and tag runs every build, so a PR exercises all
# of it. Only the two pushes are gated. The clone is thrown away, so the
# throwaway tag costs nothing.
#
# The branch is replaced wholesale rather than merged: the history is the tags,
# each 42.X an immutable snapshot of one published site.
#
# With no gh-pages branch this bootstraps one as an orphan. Enable GitHub Pages
# once afterwards.

set -euo pipefail

: "${VERSION:?VERSION is required (set by the versions-and-naming build step)}"
: "${REPOSITORY_OWNER:?REPOSITORY_OWNER is required (set by the build)}"
: "${REPOSITORY_NAME:?REPOSITORY_NAME is required (set by the build)}"

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-kaptain-out}"

BUILD_MODE="${BUILD_MODE:-local}"
IS_RELEASE="${IS_RELEASE:-false}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=.github/bin/pages-tag.bash
source "$(dirname "${BASH_SOURCE[0]}")/pages-tag.bash"
PAGES_TAG="$(pages_tag_for "${VERSION}")"

# Publishing needs both: a real release, and a build server to do it from.
PUBLISH=false
if [[ "${IS_RELEASE}" == "true" && "${BUILD_MODE}" == "build_server" ]]; then
    PUBLISH=true
fi

GITHUB_REPOSITORY="${REPOSITORY_OWNER}/${REPOSITORY_NAME}"

# shellcheck source=.github/bin/site-url.bash
source "$(dirname "${BASH_SOURCE[0]}")/site-url.bash"
SITE_URL="$(site_url)"

GH_AUTH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ "${PUBLISH}" == "true" && -z "${GH_AUTH_TOKEN}" ]]; then
    printf 'GH_TOKEN or GITHUB_TOKEN is required to push gh-pages on a release build.\n' >&2
    exit 1
fi

if [[ "${PUBLISH}" == "true" ]] && ! command -v gh >/dev/null 2>&1; then
    printf 'gh not found on PATH - required to create the %s release.\n' "${PAGES_TAG}" >&2
    exit 1
fi

# Absolute, because we cd into the clone below.
if [[ "${OUTPUT_SUB_PATH}" == /* ]]; then
    OUTPUT_ABS="${OUTPUT_SUB_PATH%/}"
else
    OUTPUT_ABS="${REPO_ROOT}/${OUTPUT_SUB_PATH%/}"
fi
BUILD_DIR="${OUTPUT_ABS}/site-build"
PAYLOAD="${BUILD_DIR}/site"
PAGES_NOTES_FILE="${BUILD_DIR}/pages-release-notes.md"

if [[ ! -f "${PAYLOAD}/index.html" ]]; then
    printf 'Assembled payload has no index.html at %s\n' "${PAYLOAD}" >&2
    printf 'assemble-site.bash should run before this script.\n' >&2
    exit 1
fi

if [[ ! -f "${PAGES_NOTES_FILE}" ]]; then
    printf 'Pages release notes not found at %s\n' "${PAGES_NOTES_FILE}" >&2
    printf 'write-release-notes.bash should run before this script.\n' >&2
    exit 1
fi

# Kept, not cleaned: it is what you read when a publish misbehaves.
WORK="${BUILD_DIR}/gh-pages-publish"
rm -rf "${WORK}"
mkdir -p "${WORK}"
PAGES_REPO="${WORK}/clone"

if [[ -n "${GH_AUTH_TOKEN}" ]]; then
    REMOTE_URL="https://x-access-token:${GH_AUTH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
else
    # Anonymous, fine for the dry run against a public repo.
    REMOTE_URL="https://github.com/${GITHUB_REPOSITORY}.git"
fi

printf '== publish-site-pages: workspace at %s ==\n' "${PAGES_REPO}"
printf '   version=%s pages-tag=%s\n' "${VERSION}" "${PAGES_TAG}"
printf '   IS_RELEASE=%s BUILD_MODE=%s -> %s\n' \
    "${IS_RELEASE}" "${BUILD_MODE}" \
    "$([[ "${PUBLISH}" == "true" ]] && printf 'PUBLISH' || printf 'dry run (no push)')"

# Asked, not inferred from a failed clone: a network blip must not look like
# "no branch yet" and orphan away the published site.
if ! REMOTE_HEADS="$(git ls-remote --heads "${REMOTE_URL}" gh-pages)"; then
    printf 'Could not reach %s to check for the gh-pages branch.\n' "${GITHUB_REPOSITORY}" >&2
    printf 'Refusing to continue: bootstrapping now could discard the published site.\n' >&2
    exit 1
fi

# Before the work, so a re-release fails with the reason rather than with a
# rejected push at the end.
if [[ "${PUBLISH}" == "true" ]]; then
    if [[ -n "$(git ls-remote --tags "${REMOTE_URL}" "refs/tags/${PAGES_TAG}")" ]]; then
        printf 'Tag %s already exists on %s.\n' "${PAGES_TAG}" "${GITHUB_REPOSITORY}" >&2
        printf 'Published sites are immutable; it will not be moved.\n' >&2
        exit 1
    fi
fi

if [[ -n "${REMOTE_HEADS}" ]]; then
    git clone --quiet --depth 1 --branch gh-pages "${REMOTE_URL}" "${PAGES_REPO}"
    cd "${PAGES_REPO}"
    printf 'Cloned existing gh-pages branch.\n'
else
    git clone --quiet --depth 1 "${REMOTE_URL}" "${PAGES_REPO}"
    cd "${PAGES_REPO}"
    printf 'gh-pages branch does not exist on the remote - bootstrapping as orphan.\n'
    git checkout --quiet --orphan gh-pages
fi

# Without this a file deleted from src/static/ would live on forever.
git rm -rf --quiet --ignore-unmatch . >/dev/null

# Verbatim, so the branch matches the release tarball byte for byte.
cp -R "${PAYLOAD}/." .

git config user.email 'keelson-bot@users.noreply.github.com'
git config user.name 'keelson-bot'

git add --all

if git diff --cached --quiet; then
    printf 'No changes to gh-pages - the published site already matches this build.\n'
    exit 0
fi

git commit --quiet -m "Publish keelson.pro site ${VERSION} as ${PAGES_TAG}"
git tag --annotate "${PAGES_TAG}" -m "keelson.pro site ${VERSION}"

if [[ "${PUBLISH}" != "true" ]]; then
    printf '\n== dry run - gh-pages commit and tag %s prepared but NOT pushed ==\n' "${PAGES_TAG}"
    git --no-pager show --stat --oneline HEAD
    printf '\nWould publish %s file(s) to %s\n' \
        "$(git ls-files | wc -l | tr -d ' ')" "${SITE_URL}"
    printf 'Would create release %s with these notes:\n\n' "${PAGES_TAG}"
    sed 's/^/    /' "${PAGES_NOTES_FILE}"
    exit 0
fi

git push --quiet origin gh-pages
git push --quiet origin "refs/tags/${PAGES_TAG}"
printf 'Published site %s to gh-pages, tagged %s.\n' "${VERSION}" "${PAGES_TAG}"

# The release freezes the tag: with immutable releases set on the org it can no
# longer be moved or deleted. No assets, because the tree here is the site.
gh release create "${PAGES_TAG}" \
    --repo "${GITHUB_REPOSITORY}" \
    --title "keelson.pro site ${PAGES_TAG}" \
    --notes-file "${PAGES_NOTES_FILE}"
printf 'Released %s, tag is now immutable.\n' "${PAGES_TAG}"
