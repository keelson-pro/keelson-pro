#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Local review loop. Serves the assembled payload rather than src/, so what you
# review is what would be published. Prints the URL; does not open a browser.
#
# Stock macOS bash 3.2 and python3 only. No node, no container.
#
# Usage: src/bin/serve-site.bash [port]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

REQUESTED_PORT="${1:-8000}"

if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 not found on PATH (xcode-select --install)\n' >&2
    exit 1
fi

# Deliberately not a real version: releases start at 1.1, so a screenshot of a
# dev build is never mistaken for one.
OUTPUT_SUB_PATH="kaptain-out" \
    "${REPO_ROOT}/.github/bin/fetch-upstream-images.bash"

VERSION="0.0" \
OUTPUT_SUB_PATH="kaptain-out" \
    "${REPO_ROOT}/.github/bin/assemble-site.bash"

PAYLOAD="${REPO_ROOT}/kaptain-out/site-build/site"

# Walk up rather than fail, so a stale server does not stop the review.
PORT="${REQUESTED_PORT}"
LIMIT=$((REQUESTED_PORT + 20))
while [ "${PORT}" -lt "${LIMIT}" ]; do
    if ! nc -z 127.0.0.1 "${PORT}" >/dev/null 2>&1; then
        break
    fi
    printf 'Port %s is busy, trying %s\n' "${PORT}" "$((PORT + 1))"
    PORT=$((PORT + 1))
done

if [ "${PORT}" -ge "${LIMIT}" ]; then
    printf 'No free port between %s and %s\n' "${REQUESTED_PORT}" "${LIMIT}" >&2
    exit 1
fi

printf '\n'
printf '  Serving %s\n' "${PAYLOAD}"
printf '\n'
printf '      http://localhost:%s/\n' "${PORT}"
printf '\n'
printf '  Ctrl-C to stop. Re-run after edits to reassemble.\n'
printf '\n'

exec python3 -m http.server "${PORT}" --directory "${PAYLOAD}" --bind 127.0.0.1
