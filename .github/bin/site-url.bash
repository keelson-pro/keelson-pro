#!/usr/bin/env bash
# All rights reserved. See LICENSE.md.
# Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
#
# Sourced, not run. One definition of where the site lives.
#
# src/static/CNAME has to be a source file rather than set through the Pages
# UI: publish replaces the branch wholesale, so a CNAME committed by GitHub
# would be deleted on the next release and unset the domain every time.

# shellcheck disable=SC2148 # sourced, the sourcing script sets the shell

CNAME_FILE="src/static/CNAME"

# Takes no arguments: every caller cds to the repo root first.
site_url() {
    local domain

    if [[ ! -f "${CNAME_FILE}" ]]; then
        printf 'No CNAME at %s: the custom domain is undeclared.\n' "${CNAME_FILE}" >&2
        return 1
    fi

    # Command substitution strips the trailing newline for us.
    domain="$(cat "${CNAME_FILE}")"

    if [[ ! "${domain}" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
        printf 'CNAME does not look like a domain: %s\n' "${domain}" >&2
        return 1
    fi

    printf 'https://%s' "${domain}"
}
