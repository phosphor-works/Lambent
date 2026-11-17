#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 fuddlesworth
# SPDX-License-Identifier: GPL-3.0-or-later
# Run the production lock-screen QML with fake auth, media and power services.
# Requires an existing nested session. The fixture has its own config and IPC
# socket, so the normal shell and its appearance settings remain usable.
#
#   LAMBENT_NESTED_SESSION=review scripts/nested-shell/lock-preview.sh run
#   LAMBENT_NESTED_SESSION=review scripts/nested-shell/lock-preview.sh call preview.state
#   LAMBENT_NESTED_SESSION=review scripts/nested-shell/lock-preview.sh call preview.media --arg enabled=true
#
# `run` stays in the foreground. Stop that process to dismiss the preview.
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
    *) echo "Lock preview requires the nested compositor." >&2; exit 1 ;;
esac
BUILD="${LAMBENT_BUILD:-build}"
case "$BUILD" in
    /*) ;;
    *) BUILD="$REPO/$BUILD" ;;
esac
export PHOSPHOR_SOCKET="$NEST/lock-preview.sock"
if [ "${1:-run}" != run ]; then
    exec "$BUILD/bin/phosphorctl" --socket "$PHOSPHOR_SOCKET" "$@"
fi
export XDG_CONFIG_HOME="$NEST/lock-preview/config"
mkdir -p "$XDG_CONFIG_HOME/lambent"
cp "$REPO/scripts/nested-shell/lock-preview.qml" "$XDG_CONFIG_HOME/lambent/shell.qml"
exec "$BUILD/bin/lambent"
