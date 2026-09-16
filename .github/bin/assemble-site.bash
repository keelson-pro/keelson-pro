#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Phase 1, via build-and-publish-site.bash.
#
# Builds the tree that gets published. What this writes is byte for byte what
# lands on gh-pages and what goes into the release tarball.

set -euo pipefail

: "${VERSION:?VERSION is required (set by the versions-and-naming build step)}"

# Defaulted so a direct call lands somewhere sane; real builds always set it.
OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-kaptain-out}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=.github/bin/pages-tag.bash
source "$(dirname "${BASH_SOURCE[0]}")/pages-tag.bash"
PAGES_TAG="$(pages_tag_for "${VERSION}")"

# shellcheck source=.github/bin/site-url.bash
source "$(dirname "${BASH_SOURCE[0]}")/site-url.bash"
SITE_URL="$(site_url)"

# One line of prose used three times, as the page description and in both
# preview cards. Kept as a file so it is findable and editable without going
# near the markup. Newlines are folded to spaces so it can be wrapped in the
# file, and the HTML-significant characters are escaped so a quote or an
# ampersand in it cannot break the attribute it lands in.
DESCRIPTION_FILE="src/meta-description.txt"
if [[ ! -f "${DESCRIPTION_FILE}" ]]; then
    printf 'Description source not found: %s\n' "${DESCRIPTION_FILE}" >&2
    exit 1
fi
DESCRIPTION="$(tr '\n' ' ' < "${DESCRIPTION_FILE}" \
    | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//' \
    -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g')"

# sed reads & in a replacement as the whole match, so it has to be escaped
# again after the HTML escaping put ampersands in.
DESCRIPTION_SED="${DESCRIPTION//&/\\&}"

STATIC_DIR="src/static"
PAYLOAD="${OUTPUT_SUB_PATH%/}/site-build/site"

if [[ ! -d "${STATIC_DIR}" ]]; then
    printf 'Static source directory not found: %s\n' "${STATIC_DIR}" >&2
    exit 1
fi

rm -rf "${PAYLOAD}"
mkdir -p "${PAYLOAD}"

# The trailing dot takes dotfiles, which is the point for .nojekyll.
cp -R "${STATIC_DIR}/." "${PAYLOAD}/"

printf 'Copied %s into %s\n' "${STATIC_DIR}" "${PAYLOAD}"

# Copied in rather than linked so the release tarball is self-contained.
UPSTREAM="${OUTPUT_SUB_PATH%/}/site-build/upstream"
if [[ ! -d "${UPSTREAM}" ]]; then
    printf 'Upstream images not found at %s\n' "${UPSTREAM}" >&2
    printf 'fetch-upstream-images.bash should run before this script.\n' >&2
    exit 1
fi
mkdir -p "${PAYLOAD}/img"
cp "${UPSTREAM}"/*.png "${PAYLOAD}/img/"
printf 'Copied %s upstream image(s) into the payload\n' \
    "$(find "${UPSTREAM}" -name '*.png' | wc -l | tr -d ' ')"

# Branch signage. Assembled here rather than written during publish so the
# tarball and gh-pages are the same bytes.
cp src/pages-README.md "${PAYLOAD}/README.md"

# Before the token pass, so an example can itself carry a token.
"$(dirname "${BASH_SOURCE[0]}")/render-examples.bash"

# Every text file, so a token can be used wherever it reads best.
while IFS= read -r file; do
    sed -i.bak \
        -e "s|@VERSION@|${VERSION}|g" \
        -e "s|@PAGES_TAG@|${PAGES_TAG}|g" \
        -e "s|@SITE_URL@|${SITE_URL}|g" \
        -e "s|@DESCRIPTION@|${DESCRIPTION_SED}|g" \
        "${file}"
    rm -f "${file}.bak"
done < <(find "${PAYLOAD}" -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' \
    -o -name '*.xml' -o -name '*.txt' -o -name '*.md' \) | sort)

# A surviving token is a typo, and would ship as literal text. -I because a
# PNG will contain bytes that look like one.
if grep -rnI '@[A-Z_]\{2,\}@' "${PAYLOAD}" >&2; then
    printf 'Unsubstituted token left in the assembled site (above).\n' >&2
    exit 1
fi

printf 'Assembled site %s at %s (%s files)\n' \
    "${VERSION}" "${PAYLOAD}" "$(find "${PAYLOAD}" -type f | wc -l | tr -d ' ')"
