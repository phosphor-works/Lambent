#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 fuddlesworth
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Screenshot one nested output as a PNG, the harness's eyes for headless and
# AI-driven runs.
#
#   scripts/nested-shell/capture.sh [OutputName] <out.png>
#
# OutputName defaults to HEADLESS-1, the first output of the headless backend
# (HEADLESS-2 and on for the others; WL-1 and on under LAMBENT_NESTED_VISIBLE).
# `wlr-randr` lists them after sourcing env.sh. Takes the shot with grim over
# wlr-screencopy, which the nested compositor offers.
#
# The shell is an ordinary layer-shell client on the normal composite path:
# bars, popouts and toasts appear in these captures, so they are genuine
# rendering evidence here.
set -eu

# nest-dir.sh resolves the session's state dir the way run-nested.sh does
# (LAMBENT_NESTED_SESSION included).
SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPTS/nest-dir.sh"

case $# in
    1) OUTPUT="HEADLESS-1"; OUT="$1" ;;
    2) OUTPUT="$1"; OUT="$2" ;;
    *) echo "usage: capture.sh [OutputName] <out.png>" >&2; exit 1 ;;
esac

if [ ! -f "$NEST/env.sh" ]; then
    echo "no nested session in $NEST (run scripts/nested-shell/run-shell.sh first)" >&2
    exit 1
fi
# shellcheck disable=SC1091
. "$NEST/env.sh"

if ! command -v grim >/dev/null 2>&1; then
    echo "grim is not on PATH; install it to take screenshots of the nested session" >&2
    exit 1
fi
# env.sh pins the nested runtime dir, so grim cannot reach the host compositor.
case "${XDG_RUNTIME_DIR:-}" in
    "${LAMBENT_NESTED_DIR:-}/runtime") ;;
    *) echo "env.sh did not set the nested runtime dir; refusing to capture the host" >&2; exit 1 ;;
esac
exec grim -o "$OUTPUT" "$OUT"
