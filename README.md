# Keelson's keelson.pro Website

Source for the [keelson.pro](https://keelson.pro) website.

Static HTML, CSS and native ES modules. No framework, no bundler, no node. The
build assembles `src/static/` into a payload, publishes it to the `gh-pages`
branch. tags the commit, then publishes the commit as GitHub Release to ensure
tag immutability relying on the org repo setting of immutable releases.

All rights reserved: see [LICENSE.md](LICENSE.md). Public for transparency, not
for reuse.


## Local review

```bash
src/bin/serve-site.bash [8888] # Optional port number arg
```

Assembles the site the same way a build does and serves the result at a
`localhost` URL it prints. Needs only `python3`. Re-run after edits.


## Layout

| Path                         |                                                              |
|------------------------------|--------------------------------------------------------------|
| `src/static/`                | The site. Copied to the published root verbatim.             |
| `src/static/.nojekyll`       | Stops Pages running Jekyll over the branch. Must stay empty.  |
| `src/static/CNAME`           | The custom domain. Sole declaration of where the site lives.  |
| `src/static/img/`            | Site imagery. `keelson-mark.svg` is the hero banner.          |
| `src/release-notes.md`       | Notes for the `X.Y` release on `main`, attached by kaptain.   |
| `src/pages-release-notes.md` | Notes for the `42.X.Y` release on the `gh-pages` tag.         |
| `src/pages-README.md`        | Signage. Assembled into the payload as `README.md`.           |
| `src/bin/`                   | Local helpers. Not part of the build or the site.             |
| `.github/bin/`               | The build scripts chained by `build-and-publish-site.bash`.   |

Edit the site under `src/static/`. `@VERSION@` is substituted during assembly,
and any `@TOKEN@` left unsubstituted fails the build rather than shipping as
literal text.


## Versioning

Two tag series, deliberately far apart so they can never be confused:

| Series   | Where      |                                                            |
|----------|------------|------------------------------------------------------------|
| `X.Y`    | `main`     | The release that built the site. Currently the `1` series. |
| `42.X.Y` | `gh-pages` | The published site. Carries the whole `main` version.      |

`main` uses Kaptain's `git-auto-closest-highest` strategy with `maxParts: 2`.

The site tag carries both parts of the main version rather than just the last
one, so `1.7` publishes as `42.1.7`. That is what lets the main series be bumped,
`1.9` to `2.0` say, without the site tag colliding with a patch that happens to
share a last number. `gh-pages` is an orphan branch, so its tags are unreachable
from `main` and never affect the version calculation there.


## Build

`.github/bin/build-and-publish-site.bash` runs four phases, each separately
runnable:

1. `assemble-site` builds the payload and substitutes version tokens.
2. `package-site` tars it as the release asset.
3. `write-release-notes` fills in the notes.
4. `publish-site-pages` replaces `gh-pages` wholesale, commits and tags it.

Phase 4 does its whole path on every build and gates only the two pushes, on
`IS_RELEASE` and `BUILD_MODE`. A PR build clones, wipes, copies, commits and
tags in a throwaway clone under `kaptain-out/`, then reports what it would have
published. Nothing leaves the runner until a release build on `main`.

Published site tags are immutable. A release whose `42.X.Y` tag already exists on
the remote fails before doing any work rather than moving the tag.


## First-time setup

After the first release build creates `gh-pages`, enable GitHub Pages once in
Settings -> Pages: Source `gh-pages`, folder `/`.
