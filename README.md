# keelson.pro - published site

This branch is what GitHub Pages serves at https://keelson.pro.

This tree is tagged `42.1.2`, published from release `1.2` on `main`.
The tag is released to make it immutable, so it will always serve what it
served on the day it shipped.

`CNAME` is what points the custom domain here. It is a source file in
`src/static/`, not something set through the Pages settings UI, because each
release replaces this branch wholesale and would otherwise delete it.

Every commit here is generated. The site is built from `src/` on `main` and
pushed by `.github/bin/publish-site-pages.bash` on a release build.

Do not edit this branch by hand. The next release replaces it wholesale.
