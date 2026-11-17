#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 fuddlesworth
# SPDX-License-Identifier: GPL-3.0-or-later
# Native production PolkitSurface with a preview-only agent. No Polkit/PAM
# registration, host account changes, or real authorization is possible.
#
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/authentication-preview.sh run
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/authentication-preview.sh run --example accounts --state error
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/authentication-preview.sh call preview.show --arg example=code --arg state=ready
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/authentication-preview.sh call preview.phase --arg name=unavailable
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/authentication-preview.sh call preview.state
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/authentication-preview.sh call preview.quit
#
# Submit "demo" (or "123456" for the code example). Other input exercises the
# retry state. Captures and input use the existing nested compositor tooling.
set -eu
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPTS/../.." && pwd)"
# The same state-dir resolution run-nested.sh uses (LAMBENT_NESTED_SESSION included).
. "$SCRIPTS/nest-dir.sh"
if [ ! -f "$NEST/env.sh" ]; then
    echo "Start a nested session with run-shell.sh first." >&2
    exit 1
fi
# shellcheck disable=SC1091
. "$NEST/env.sh"
case "${XDG_RUNTIME_DIR:-}" in
    "${LAMBENT_NESTED_DIR:-}/runtime") ;;
    *) echo "Authentication preview requires the nested compositor." >&2; exit 1 ;;
esac
BUILD="${LAMBENT_BUILD:-build}"
case "$BUILD" in
    /*) ;;
    *) BUILD="$REPO/$BUILD" ;;
esac
export PHOSPHOR_SOCKET="$NEST/authentication-preview.sock"
if [ "${1:-run}" != run ]; then
    exec "$BUILD/bin/phosphorctl" --socket "$PHOSPHOR_SOCKET" "$@"
fi
if [ "$#" -gt 0 ]; then
    shift
fi
export XDG_CONFIG_HOME="$NEST/authentication-preview/config"
export XDG_DATA_HOME="$NEST/authentication-preview/data"
export XDG_CACHE_HOME="$NEST/authentication-preview/cache"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
exec "$BUILD/bin/phosphor-authentication-preview" --socket "$PHOSPHOR_SOCKET" "$@"
