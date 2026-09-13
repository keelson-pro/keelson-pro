#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Renders the Logging section screenshots from the log text in src/logs/. Run
# after editing those, then commit both the text and the PNG.
#
# Text plus a renderer rather than hand-made images: the log lines are copy, and
# copy has to stay reviewable in a diff. The PNGs are committed because a
# browser cannot be a build dependency of a static site.
#
# Usage: src/bin/render-log-shots.bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

LOG_DIR="src/logs"
OUT_DIR="src/static/img"
WORK="kaptain-out/log-shots"

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [[ ! -x "${CHROME}" ]]; then
    if command -v google-chrome >/dev/null 2>&1; then
        CHROME="$(command -v google-chrome)"
    elif command -v chromium >/dev/null 2>&1; then
        CHROME="$(command -v chromium)"
    else
        printf 'Chrome not found. Set CHROME=/path/to/chrome and re-run.\n' >&2
        exit 1
    fi
fi

rm -rf "${WORK}"
mkdir -p "${WORK}" "${OUT_DIR}"

SCALE=2

# Chrome screenshots the window, not the document, so the window is sized from
# the content or the image is silently cropped.
FONT_PX=15
LINE_PX=25          # 15px at 1.65 line-height, rounded up
CHAR_PX=9.0225      # SF Mono advance width at 15px, 0.6015em
PAD_X=13
PAD_Y=11

shopt -s nullglob
LOGS=("${LOG_DIR}"/*.log)
if [[ ${#LOGS[@]} -eq 0 ]]; then
    printf 'No .log files in %s\n' "${LOG_DIR}" >&2
    exit 1
fi

for log in "${LOGS[@]}"; do
    name="$(basename "${log}" .log)"
    page="${WORK}/${name}.html"
    out="${OUT_DIR}/log-${name}.png"

    # An ELIDED line renders without timestamp and level, so measures short.
    read -r cols rows < <(awk '
        { n = length($0)
          if ($0 ~ /^ELIDED /) n = n - 7 + 4
          else if ($0 ~ /^RAW/)  n = n - 4
          if (n > max) max = n }
        END { print max, NR }' "${log}")

    # An optional <name>.cols caps the width. The text still renders in full
    # and runs past the edge, like a terminal too narrow for its output.
    cap="${LOG_DIR}/${name}.cols"
    if [[ -f "${cap}" ]]; then
        cols="$(tr -d '[:space:]' < "${cap}")"
    fi

    win_w=$(awk -v c="${cols}" -v w="${CHAR_PX}" -v p="${PAD_X}" \
        'BEGIN { printf "%d", (c * w) + (p * 2) + 2 }')
    win_h=$(( (rows * LINE_PX) + (PAD_Y * 2) ))
    clip_w=$(awk -v c="${cols}" -v w="${CHAR_PX}" 'BEGIN { printf "%d", c * w }')

    # ELIDED lines are an editorial aside, not output.
    {
        cat <<'HEAD'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>log</title>
<style>
  html, body { margin: 0; background: #0b0b0b; }
  pre {
    margin: 0;
    padding: PADYpx PADXpx;
    background: #0b0b0b;
    color: #2ff255;
    font: 400 FONTPXpx/1.65 "SF Mono", "Menlo", "DejaVu Sans Mono", monospace;
    white-space: pre;
    overflow: hidden;
  }
  /* Width is the capped column count. A line longer than it is clipped here,
   * inside the padding, so the black border survives the cut. */
  code { display: block; width: CLIPWpx; overflow: hidden; }
  .el { display: block; text-align: center; font-style: italic; opacity: 0.75; }
</style></head><body><pre>
HEAD
        # No newline after <code>: HTML strips one directly after <pre> but
        # keeps it after any other tag, and with white-space:pre that shows up
        # as a blank first line, pushing the last line out of the window.
        printf '<code>'
        while IFS= read -r line; do
            case "${line}" in
                RAW\ *|RAW)
                    # Verbatim: a prompt, a command, shell output.
                    raw="${line#RAW}"
                    raw="${raw# }"
                    raw="${raw//&/&amp;}"
                    raw="${raw//</&lt;}"
                    raw="${raw//>/&gt;}"
                    printf '%s\n' "${raw}"
                    ;;
                ELIDED\ *)
                    printf '<span class="el">&#8230; %s &#8230;</span>\n' \
                        "${line#ELIDED }"
                    ;;
                *)
                    ts="${line%% *}"
                    rest="${line#* }"
                    lvl="${rest%% *}"
                    msg="${rest#* }"
                    # A quoted image ref must render literally.
                    msg="${msg//&/&amp;}"
                    msg="${msg//</&lt;}"
                    msg="${msg//>/&gt;}"
                    printf '%s %s %s\n' "${ts}" "${lvl}" "${msg}"
                    ;;
            esac
        done < "${log}"
        printf '</code></pre></body></html>\n'
    } | sed -e "s/FONTPX/${FONT_PX}/" -e "s/PADY/${PAD_Y}/" -e "s/PADX/${PAD_X}/" -e "s/CLIPW/${clip_w}/" \
      > "${page}"

    # A profile per render: Chrome takes a singleton lock on one, and a second
    # invocation blocks forever rather than failing.
    "${CHROME}" --headless=new --disable-gpu --hide-scrollbars \
        --user-data-dir="${WORK}/profile-${name}" \
        --no-first-run --no-default-browser-check \
        --disable-component-update --disable-background-networking \
        --disable-sync --disable-extensions --metrics-recording-only --no-pings \
        --force-device-scale-factor="${SCALE}" \
        --window-size="${win_w},${win_h}" \
        --screenshot="${out}" \
        --virtual-time-budget=4000 \
        "file://${REPO_ROOT}/${page}" >/dev/null 2>&1 &
    chrome_pid=$!

    # Chrome writes the file then sometimes lingers, so wait for the image.
    waited=0
    while [[ ! -s "${out}" && ${waited} -lt 60 ]]; do
        sleep 1
        waited=$((waited + 1))
    done
    kill "${chrome_pid}" 2>/dev/null || true
    wait "${chrome_pid}" 2>/dev/null || true

    if [[ ! -s "${out}" ]]; then
        printf 'Failed to render %s\n' "${out}" >&2
        exit 1
    fi
    printf 'Rendered %-34s %sx%s  %s bytes\n' "${out}" \
        "$((win_w * SCALE))" "$((win_h * SCALE))" \
        "$(wc -c < "${out}" | tr -d ' ')"
done
