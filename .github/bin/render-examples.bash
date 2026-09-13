#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Called by assemble-site.bash, before token substitution.
#
# Each file in src/examples/ is a plain, editable example. This highlights one
# and drops it into the payload at its token, so the page carries no
# hand-written markup and the example stays a file you can paste into a cluster.
#
# registries.yaml becomes @EXAMPLE_REGISTRIES_YAML@.
#
# Three rules, not a parser: comment lines, the value of auth-mode, and the
# value of any *-override. A real highlighter would be a dependency, and these
# examples are small enough that three rules cover them.

set -euo pipefail

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:-kaptain-out}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

EXAMPLE_DIR="src/examples"
PAYLOAD="${OUTPUT_SUB_PATH%/}/site-build/site"
WORK="${OUTPUT_SUB_PATH%/}/site-build/examples"

if [[ ! -d "${EXAMPLE_DIR}" ]]; then
    printf 'No %s directory; nothing to render.\n' "${EXAMPLE_DIR}"
    exit 0
fi

rm -rf "${WORK}"
mkdir -p "${WORK}"

shopt -s nullglob
EXAMPLES=("${EXAMPLE_DIR}"/*)
if [[ ${#EXAMPLES[@]} -eq 0 ]]; then
    printf 'No examples in %s; nothing to render.\n' "${EXAMPLE_DIR}"
    exit 0
fi

for example in "${EXAMPLES[@]}"; do
    name="$(basename "${example}")"
    token="@EXAMPLE_$(printf '%s' "${name}" | tr '[:lower:]' '[:upper:]' \
        | sed -e 's/[^A-Z0-9]\{1,\}/_/g')@"
    rendered="${WORK}/${name}.html"

    awk '
        function esc(s) {
            gsub(/&/, "\\&amp;", s)
            gsub(/</, "\\&lt;",  s)
            gsub(/>/, "\\&gt;",  s)
            return s
        }
        {
            line = esc($0)

            # Indent stays outside the span.
            if (match(line, /^[ \t]*#/)) {
                indent = substr(line, 1, RSTART + RLENGTH - 2)
                rest   = substr(line, RSTART + RLENGTH - 1)
                print indent "<span class=\"c\">" rest "</span>"
                next
            }

            # Split first, so the value rules see the value alone.
            trail = ""
            if (match(line, /[ \t]+#.*$/)) {
                trail = "<span class=\"c\">" substr(line, RSTART + 1) "</span>"
                trail = substr(line, RSTART, 1) trail
                line  = substr(line, 1, RSTART - 1)
            }

            # The key decides how the value is marked.
            if (match(line, /^[ \t]*[A-Za-z0-9._-]+:[ \t]+/)) {
                head = substr(line, 1, RSTART + RLENGTH - 1)
                val  = substr(line, RSTART + RLENGTH)
                key  = head
                sub(/^[ \t]*/, "", key)
                sub(/:[ \t]*$/, "", key)

                if (key == "auth-mode") {
                    print head "<span class=\"s\">" val "</span>" trail
                    next
                }
                if (key ~ /-override$/) {
                    print head "<span class=\"v\">" val "</span>" trail
                    next
                }
            }

            line = line trail

            print line
        }
    ' "${example}" > "${rendered}"

    # Whatever sits either side of the token on that line is kept: a newline
    # between <code> and the first line renders as a blank first line.
    hits=0
    while IFS= read -r page; do
        grep -qF "${token}" "${page}" || continue
        awk -v tok="${token}" -v file="${rendered}" '
            BEGIN {
                while ((getline chunk < file) > 0) {
                    block = (block == "" ? chunk : block "\n" chunk)
                }
                close(file)
            }
            {
                at = index($0, tok)
                if (at == 0) { print; next }
                print substr($0, 1, at - 1) block substr($0, at + length(tok))
            }
        ' "${page}" > "${page}.new"
        mv "${page}.new" "${page}"
        hits=$((hits + 1))
    done < <(find "${PAYLOAD}" -type f -name '*.html' | sort)

    printf 'Rendered %-24s -> %-30s %s page(s)\n' "${name}" "${token}" "${hits}"
done
