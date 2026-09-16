#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Renders the link-preview card and the iOS touch icon from the lockup. Run
# after changing the lockup or the card wording, then commit the PNGs.
#
# Committed rather than built: og:image has to be a raster at a stable URL, and
# a browser cannot be a build dependency of a static site.
#
# Usage: src/bin/render-social.bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

STATIC="src/static"
OUT="${STATIC}/img"
WORK="kaptain-out/social"

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
mkdir -p "${WORK}" "${OUT}"

# 1200x630 is what every scraper crops to. Rendered at 1x: the card is mostly
# vector and flat colour, so 2x would only double the bytes on every unfurl.
cat > "${WORK}/card.html" <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><title>card</title>
<style>
  @font-face {
    font-family: 'Plex Cond';
    src: url('${REPO_ROOT}/${STATIC}/fonts/plex-condensed-700.woff2') format('woff2');
    font-weight: 700;
  }
  html, body { margin: 0; width: 1200px; height: 630px; }
  body {
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    background: #eef1f4;
    background-image:
      radial-gradient(60rem 40rem at 78% -10%, rgba(1,168,253,0.16), transparent 65%),
      linear-gradient(rgba(204,215,225,0.55) 1px, transparent 1px),
      linear-gradient(90deg, rgba(204,215,225,0.55) 1px, transparent 1px);
    background-size: 100% 100%, 40px 40px, 40px 40px;
  }
  /*
   * keelson-lockup.svg carries wide margins inside its own 680x320 viewBox:
   * measured with getBBox the artwork is x 41.4..649.1, y 40.0..281.2. Left
   * alone, a quarter of the card's height is empty. The crop box sizes to the
   * artwork and the image is pulled out by exactly that margin.
   *
   *   680   / 607.7 = 111.897%   scale so the artwork spans the box
   *   41.4  / 607.7 =   6.813%   left margin inside the file
   *   30.9  / 607.7 =   5.085%   right
   *   40.0  / 607.7 =   6.582%   top
   *   38.8  / 607.7 =   6.385%   bottom
   */
  .crop { width: 1030px; aspect-ratio: 607.7 / 241.2; overflow: hidden; }
  .crop img {
    width: 111.897%;
    height: auto;
    display: block;
    margin: -6.582% -5.085% -6.385% -6.813%;
  }
  p {
    margin: 34px 0 0;
    font: 700 54px/1.1 'Plex Cond', sans-serif;
    letter-spacing: -0.005em;
    color: #33485e;
  }
  p::before {
    content: ''; display: block;
    width: 118px; height: 4px; margin: 0 auto 24px;
    background: #01a8fd;
  }
</style></head><body>
<div class="crop"><img src="${REPO_ROOT}/${STATIC}/img/keelson-lockup.svg" alt=""></div>
<p>Keep your workloads up-to-date.</p>
</body></html>
HTML

# The lockup is 680x320; square with room to breathe for the home screen.
cat > "${WORK}/icon.html" <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><title>icon</title>
<style>
  html, body { margin: 0; width: 180px; height: 180px; }
  body {
    display: flex; align-items: center; justify-content: center;
    background: #eef1f4;
  }
  /* Same crop as the card; see the note there for the numbers. */
  .crop { width: 172px; aspect-ratio: 607.7 / 241.2; overflow: hidden; }
  .crop img {
    width: 111.897%;
    height: auto;
    display: block;
    margin: -6.582% -5.085% -6.385% -6.813%;
  }
</style></head><body>
<div class="crop"><img src="${REPO_ROOT}/${STATIC}/img/keelson-lockup.svg" alt=""></div>
</body></html>
HTML

render() {
    local name="$1" w="$2" h="$3" out="${OUT}/$4"
    rm -f "${out}"
    "${CHROME}" --headless=new --disable-gpu --hide-scrollbars \
        --user-data-dir="${WORK}/profile-${name}" \
        --no-first-run --no-default-browser-check \
        --disable-component-update --disable-background-networking \
        --disable-sync --disable-extensions --metrics-recording-only --no-pings \
        --allow-file-access-from-files \
        --window-size="${w},${h}" \
        --screenshot="${out}" \
        --virtual-time-budget=4000 \
        "file://${REPO_ROOT}/${WORK}/${name}.html" >/dev/null 2>&1 &
    local pid=$! waited=0
    while [[ ! -s "${out}" && ${waited} -lt 60 ]]; do
        sleep 1
        waited=$((waited + 1))
    done
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true

    if [[ ! -s "${out}" ]]; then
        printf 'Failed to render %s\n' "${out}" >&2
        exit 1
    fi
    printf 'Rendered %-34s %sx%s  %s bytes\n' "${out}" "${w}" "${h}" \
        "$(wc -c < "${out}" | tr -d ' ')"
}

render card 1200 630 social-card.png
render icon 180 180 apple-touch-icon.png
