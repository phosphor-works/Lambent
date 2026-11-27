#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build-tree phosphorctl aimed at the NESTED shell's socket. The pinned
# --socket is the point: a bare phosphorctl resolves the host session's
# $XDG_RUNTIME_DIR/lambent.sock, silently driving the wrong shell.
#
#   scripts/nested-shell/ctl.sh call power.toggle
#   scripts/nested-shell/ctl.sh list
set -eu

# These scripts live two levels below the repository root, where the build
# tree and lambent/ are. nest-dir.sh resolves the session's state dir the way
# run-nested.sh does (LAMBENT_NESTED_SESSION included).
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPTS/../.." && pwd)"
. "$SCRIPTS/nest-dir.sh"

if [ ! -f "$NEST/env.sh" ]; then
    echo "no nested session in $NEST (run scripts/nested-shell/run-shell.sh first)" >&2
    exit 1
fi
# shellcheck disable=SC1091
. "$NEST/env.sh"
BUILD="${LAMBENT_BUILD:-build}"
case "$BUILD" in
    /*) ;;
    *) BUILD="$REPO/$BUILD" ;;
esac

if [ ! -S "$NEST/lambent.sock" ]; then
    echo "the nested shell's socket $NEST/lambent.sock is not bound (start it with scripts/nested-shell/shell.sh)" >&2
    exit 1
fi
exec "$BUILD/bin/phosphorctl" --socket "$NEST/lambent.sock" "$@"
