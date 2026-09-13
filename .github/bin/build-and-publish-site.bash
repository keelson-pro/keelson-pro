#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# The postVersionsAndNaming hook, and the only site-side entry point. Each
# phase is separately runnable and documents itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for phase in \
    fetch-upstream-images \
    assemble-site \
    package-site \
    write-release-notes \
    publish-site-pages
do
    printf '\n== site hook: %s ==\n' "${phase}"
    "${SCRIPT_DIR}/${phase}.bash"
done
