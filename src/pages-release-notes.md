The [keelson.pro](@SITE_URL@) website, exactly as served from this tag.

This tag points at the `gh-pages` commit itself, so the tree here is the site:
no build step, no assets to unpack. Releasing it is what makes the tag
immutable.

| | |
| --- | --- |
| Live site | @SITE_URL@ |
| Built from | [`@VERSION@`](@REPO_URL@/releases/tag/@VERSION@) on `main` |

A `.tgz` of this exact tree is attached to the `@VERSION@` release linked above,
for anyone who wants to serve it themselves.
