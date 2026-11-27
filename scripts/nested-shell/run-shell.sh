#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
#
# One-command Lambent harness: a nested headless wlroots compositor with the
# BUILD-TREE shell running inside it, drivable over the shell's own IPC socket
# and screenshot-able for eyes-free (AI) test loops. No install or logout.
# Configuration, the session bus, the runtime dir and shell IPC are isolated.
# Hardware services (the system bus, PipeWire) and logind power actions still
# reach the host: use service fixtures when testing actions such as suspend,
# reboot or shutdown.
#
# Usage:
#   scripts/nested-shell/run-shell.sh [output-count] [width height] [scale]
#
# The arguments go to run-nested.sh, which picks the compositor (labwc, sway,
# or LAMBENT_NESTED_COMPOSITOR) and documents the rest.
#
# What it does, in order:
#   1. starts run-nested.sh in the background (compositor log:
#      $LAMBENT_NESTED_DIR/compositor.log) and waits for a fresh env.sh,
#      which is written once the compositor's socket is bound;
#   2. seeds the bundled shell tree into the nested config home
#      ($NEST/home/config/phosphor-works/lambent/), so shell.qml edits there hot-reload
#      without rebuilds. Seeding happens after the launcher wiped the homes;
#   3. starts the build-tree lambent inside the session through shell.sh
#      (shell log: $NEST/shell.log, IPC socket: $NEST/lambent.sock).
#
# Follow-ups (each sources env.sh itself):
#   scripts/nested-shell/ctl.sh call power.toggle       # drive the shell
#   scripts/nested-shell/capture.sh HEADLESS-1 out.png  # look at it
#   scripts/nested-shell/shell.sh                       # restart after a rebuild
#   kill "$(cat "$LAMBENT_NESTED_DIR/compositor.pid")"  # end the session
#
# The shell is an ordinary layer-shell client, so its bars, popouts and toasts
# appear in captures, and screenshots are real rendering evidence.
#
# Environment knobs (the sibling scripts read the same ones):
#   LAMBENT_NESTED_SESSION     one name for a whole extra session, so two can
#                              run at once:
#                                LAMBENT_NESTED_SESSION=ai run-shell.sh 1
#                                LAMBENT_NESTED_SESSION=ai ctl.sh list
#   LAMBENT_NESTED_DIR         the state dir itself, over the session default.
#   LAMBENT_NESTED_COMPOSITOR  the compositor's command line, over labwc/sway.
#   LAMBENT_NESTED_VISIBLE     a windowed compositor on the host desktop.
#   LAMBENT_NESTED_RENDERER    WLR_RENDERER for the compositor.
#   LAMBENT_BUILD              Lambent's build dir other than build/.
#   LAMBENT_SHELL_NO_SEED      keep the shell linked into the binary instead of
#                              seeding an editable copy.
set -eu

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPTS/../.." && pwd)"
. "$SCRIPTS/nest-dir.sh"

# A stale env.sh from a crashed previous session must not satisfy the wait
# below. run-nested.sh deletes it and moves a fresh one into place, so a new
# inode and mtime mark the new session's.
PRE_ENV_ID=$(stat -c '%i %Y' "$NEST/env.sh" 2>/dev/null || echo none)
env_fresh() {
    [ -f "$NEST/env.sh" ] && [ "$(stat -c '%i %Y' "$NEST/env.sh" 2>/dev/null || echo none)" != "$PRE_ENV_ID" ]
}

# Until run-nested.sh has checked the state dir and moved its output into
# compositor.log there, what it prints (its refusals) goes to a private temp
# file, shown if it exits before the session is up.
LAUNCH_LOG=$(mktemp "$RUNTIME_DIR/lambent-nested-launch.XXXXXX")
trap 'rm -f "$LAUNCH_LOG"' EXIT
LAMBENT_NESTED_DETACH=1 "$SCRIPTS/run-nested.sh" "$@" > "$LAUNCH_LOG" 2>&1 &
LAUNCHER_PID=$!

for _ in $(seq 1 150); do
    env_fresh && break
    if ! kill -0 "$LAUNCHER_PID" 2>/dev/null; then
        echo "the nested session did not come up; its output:" >&2
        cat "$LAUNCH_LOG" >&2
        [ ! -f "$NEST/compositor.log" ] || cat "$NEST/compositor.log" >&2
        exit 1
    fi
    sleep 0.1
done
if ! env_fresh; then
    echo "timed out waiting for $NEST/env.sh; see $NEST/compositor.log" >&2
    exit 1
fi

# Seed an EDITABLE copy of the bundled shell. Without it the binary runs the
# copy linked into it, which works but cannot be edited, so the hot-reload loop
# the harness exists for has nothing to watch.
if [ -z "${LAMBENT_SHELL_NO_SEED:-}" ]; then
    SHELL_CFG="$NEST/home/config/phosphor-works/lambent"
    mkdir -p "$SHELL_CFG"
    cp -r "$REPO/lambent/shell/." "$SHELL_CFG/"
    echo "seeded editable shell: $SHELL_CFG/shell.qml"
fi

rm -f "$LAUNCH_LOG"
trap - EXIT
exec "$SCRIPTS/shell.sh"
