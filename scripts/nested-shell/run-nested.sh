#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Launch a nested, headless wlroots compositor with layer-shell for the shell
# to run in: its own outputs, its own session bus, its own XDG homes and its
# own runtime dir, so nothing reaches the user's session.
#
# Usage:
#   scripts/nested-shell/run-nested.sh [output-count] [width height] [scale]
#
# The compositor is LAMBENT_NESTED_COMPOSITOR when set (a command line, run
# through sh), otherwise labwc, otherwise sway. Any wlroots compositor with
# wlr-layer-shell works. The headless backend gives it output-count outputs
# (HEADLESS-1, HEADLESS-2, ...; default 2). width/height and scale apply to
# every output: sway takes them from the config this script writes, any other
# compositor through wlr-randr once it is up, which then has to be installed.
#
# Set LAMBENT_NESTED_VISIBLE to any value to run the compositor as a window on
# the host desktop instead (the wlroots wayland backend, one window per
# output), with the same isolation. LAMBENT_NESTED_RENDERER sets
# WLR_RENDERER (gles2, vulkan or pixman) for a machine where the default
# renderer cannot start headless.
#
# State lives in $LAMBENT_NESTED_DIR (default $XDG_RUNTIME_DIR/lambent-nested,
# or lambent-nested-<name> with LAMBENT_NESTED_SESSION=<name>; nest-dir.sh is
# the one place that is resolved):
#   env.sh          what every follow-up shell sources; written once the
#                   compositor's socket is bound, so a fresh one means "up"
#   home/           XDG config, data, cache and state homes, wiped every run
#   runtime/        the session's XDG_RUNTIME_DIR, where the compositor binds
#                   its wayland socket
#   compositor.log  the compositor's output (also on this terminal when run
#                   directly)
#   compositor.pid  the compositor's pid: kill it to end the session
#
# PipeWire stays the host's (env.sh points PIPEWIRE_RUNTIME_DIR at it), and so
# does the system bus: UPower, NetworkManager, BlueZ and logind answer for the
# real machine. No placement host runs on the nested bus, so Placement clients
# (the bar's window map, the pane rule) see none.
#
# Gotchas:
#   - fish cannot source env.sh (POSIX `export VAR=...`); use bash -c.
#   - Qt sends log output to the journal when stderr is not a tty unless
#     QT_FORCE_STDERR_LOGGING is set, which env.sh does. Read the nested logs,
#     not `journalctl --user`, which shows the host's.
set -eu

OUTPUTS="${1:-2}"
WIDTH="${2:-}"
HEIGHT="${3:-}"
SCALE="${4:-}"
case "$OUTPUTS" in
    '' | *[!0-9]* | 0*)
        echo "output-count must be a positive integer, got '$OUTPUTS'" >&2
        exit 1
        ;;
esac
for n in "$WIDTH" "$HEIGHT"; do
    case "$n" in
        '') ;;
        *[!0-9]* | 0*)
            echo "width/height must be positive integers, got '$n'" >&2
            exit 1
            ;;
    esac
done
if { [ -n "$WIDTH" ] && [ -z "$HEIGHT" ]; } || { [ -z "$WIDTH" ] && [ -n "$HEIGHT" ]; }; then
    echo "width and height must be given together" >&2
    exit 1
fi
case "$SCALE" in
    '') ;;
    *[!0-9.]* | *.*.* | . | *.)
        echo "scale must be numeric, got '$SCALE'" >&2
        exit 1
        ;;
    *)
        if ! awk -v s="$SCALE" 'BEGIN { exit !(s + 0 > 0) }'; then
            echo "scale must be greater than zero, got '$SCALE'" >&2
            exit 1
        fi
        ;;
esac

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPTS/../.." && pwd)"
. "$SCRIPTS/nest-dir.sh"

# NEST is wiped below and written into generated scripts, so it must be an
# absolute, plain path that is not the home, the runtime dir or this checkout,
# nor an ancestor of one of them. Checked on the canonical path, so /tmp/..
# and a symlinked ancestor cannot get past.
case "$NEST" in
    /*) ;;
    *)
        echo "refusing: LAMBENT_NESTED_DIR must be an absolute path, got '$NEST'" >&2
        exit 1
        ;;
esac
NEST=$(realpath -m -- "$NEST")
case "$NEST" in
    *[!A-Za-z0-9._/-]*)
        echo "refusing: LAMBENT_NESTED_DIR must match [A-Za-z0-9._/-]+, got '$NEST'" >&2
        exit 1
        ;;
    /*/*) ;;
    *)
        echo "refusing: LAMBENT_NESTED_DIR must be at least two components below '/', got '$NEST'" >&2
        exit 1
        ;;
esac
for protected in "${HOME:-}" "$RUNTIME_DIR" "$REPO"; do
    [ -n "$protected" ] || continue
    protected=$(realpath -m -- "$protected")
    case "$protected/" in
        "$NEST"/*)
            echo "refusing: LAMBENT_NESTED_DIR '$NEST' is or contains '$protected'" >&2
            exit 1
            ;;
    esac
done

BUILD="${LAMBENT_BUILD:-build}"
case "$BUILD" in
    /*) BUILD_DIR="$BUILD" ;;
    *) BUILD_DIR="$REPO/$BUILD" ;;
esac
if [ ! -x "$BUILD_DIR/bin/lambent" ]; then
    echo "no $BUILD_DIR/bin/lambent; build Lambent first (cmake --workflow --preset dev)" >&2
    exit 1
fi

# The compositor, as an argv array. Detected before anything is reset, so a
# machine without one keeps the previous session's state and logs.
if [ -n "${LAMBENT_NESTED_COMPOSITOR:-}" ]; then
    COMPOSITOR_KIND=custom
elif command -v labwc >/dev/null 2>&1; then
    COMPOSITOR_KIND=labwc
elif command -v sway >/dev/null 2>&1; then
    COMPOSITOR_KIND=sway
else
    echo "no nested compositor: install labwc or sway, or set LAMBENT_NESTED_COMPOSITOR to a wlroots compositor's command" >&2
    exit 1
fi
if [ -n "$WIDTH$SCALE" ] && [ "$COMPOSITOR_KIND" != sway ] && ! command -v wlr-randr >/dev/null 2>&1; then
    echo "an output size or scale under $COMPOSITOR_KIND needs wlr-randr, which is not on PATH" >&2
    exit 1
fi
for tool in dbus-run-session flock realpath; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "$tool is not on PATH; the nested session needs it" >&2
        exit 1
    fi
done
HOST_WAYLAND=""
if [ -n "${LAMBENT_NESTED_VISIBLE:-}" ]; then
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        echo "LAMBENT_NESTED_VISIBLE needs a live host Wayland session (WAYLAND_DISPLAY is unset)" >&2
        exit 1
    fi
    # The compositor runs with the session's own XDG_RUNTIME_DIR, so the host
    # display is handed to it as an absolute path.
    case "$WAYLAND_DISPLAY" in
        /*) HOST_WAYLAND="$WAYLAND_DISPLAY" ;;
        *) HOST_WAYLAND="$RUNTIME_DIR/$WAYLAND_DISPLAY" ;;
    esac
fi

mkdir -p "$NEST"
if [ -L "$NEST" ] || [ ! -O "$NEST" ]; then
    echo "refusing: $NEST is not a directory owned by you" >&2
    exit 1
fi
chmod 700 "$NEST"
RUNTIME_N="$NEST/runtime"
HOME_N="$NEST/home"

# A live session in this state dir holds the lock run-nested takes for its
# whole life. Refuse rather than wipe its homes and runtime dir from under it.
exec 9>"$NEST/session.lock"
if ! flock -n 9; then
    echo "a nested session is live in $NEST; stop it first, or set LAMBENT_NESTED_SESSION to start another" >&2
    exit 1
fi

# Services the previous session's bus activated can outlive it and go on
# writing into its homes. Each carries that bus's address in
# DBUS_STARTER_ADDRESS, which nothing else has, so the sweep stops exactly
# those. Run again when this session's compositor exits.
cat > "$NEST/sweep-activated.sh" <<'SWEEP'
#!/usr/bin/env bash
# Generated by run-nested.sh. Stops the services one nested bus activated.
# Usage: bash sweep-activated.sh <DBUS_SESSION_BUS_ADDRESS of that bus>
addr="${1:-}"
[ -n "$addr" ] || exit 0
activated() { [ -O "/proc/$1" ] && grep -qszFx -- "DBUS_STARTER_ADDRESS=$addr" "/proc/$1/environ"; }
targets=()
for d in /proc/[0-9]*; do
    activated "${d#/proc/}" && targets+=("${d#/proc/}")
done
[ "${#targets[@]}" -gt 0 ] || exit 0
kill -TERM "${targets[@]}" 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    alive=0
    for p in "${targets[@]}"; do [ -d "/proc/$p" ] && alive=1; done
    [ "$alive" = 1 ] || exit 0
    sleep 0.2
done
for p in "${targets[@]}"; do activated "$p" && kill -KILL "$p" 2>/dev/null || true; done
SWEEP
if [ -f "$NEST/env.sh" ]; then
    OLDADDR=$(sed -n "s/^export DBUS_SESSION_BUS_ADDRESS='\(.*\)'\$/\1/p" "$NEST/env.sh" | head -n1)
    [ -z "$OLDADDR" ] || bash "$NEST/sweep-activated.sh" "$OLDADDR"
fi

# A clean slate every run: homes, runtime dir, control files and logs.
rm -rf "$HOME_N" "$RUNTIME_N"
rm -f "$NEST/env.sh" "$NEST/env.sh.static" "$NEST/compositor.log" "$NEST/compositor.pid" "$NEST/shell.pid" "$NEST/shell.log"
mkdir -p "$HOME_N/config" "$HOME_N/data" "$HOME_N/cache" "$HOME_N/state" "$RUNTIME_N"
chmod 700 "$RUNTIME_N"
# run-shell.sh starts the session in the background: from here on, with the
# state dir known to be ours, everything goes to the session's log rather than
# to the caller.
if [ -n "${LAMBENT_NESTED_DETACH:-}" ]; then
    exec >"$NEST/compositor.log" 2>&1
fi

export XDG_CONFIG_HOME="$HOME_N/config"
export XDG_DATA_HOME="$HOME_N/data"
export XDG_CACHE_HOME="$HOME_N/cache"
export XDG_STATE_HOME="$HOME_N/state"
export QT_QPA_PLATFORM=wayland
# A nested client has to die with the nested compositor, not wait for it.
unset QT_WAYLAND_RECONNECT
# The build tree's layer-shell integration plugin, ahead of an installed one,
# so layer-shell changes in a local library checkout are what runs.
export QT_PLUGIN_PATH="$BUILD_DIR/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QT_LOGGING_RULES="${LAMBENT_NESTED_LOGGING_RULES:-phosphor*=true;org.phosphor.*=true}"
export QT_FORCE_STDERR_LOGGING=1

# The compositor's command line and its configuration.
case "$COMPOSITOR_KIND" in
    custom) COMPOSITOR=(sh -c "exec $LAMBENT_NESTED_COMPOSITOR") ;;
    labwc) COMPOSITOR=(labwc) ;;
    sway)
        # sway reads /etc/sway/config without one of its own, and that starts
        # swaybar and binds keys. This config has outputs and nothing else.
        {
            echo "# Generated by run-nested.sh."
            echo "xwayland disable"
            for i in $(seq 1 "$OUTPUTS"); do
                line="output HEADLESS-$i"
                [ -n "$WIDTH" ] && line="$line mode --custom ${WIDTH}x${HEIGHT}"
                [ -n "$SCALE" ] && line="$line scale $SCALE"
                [ "$line" = "output HEADLESS-$i" ] || echo "$line"
            done
        } > "$NEST/sway.config"
        COMPOSITOR=(sway --config "$NEST/sway.config")
        ;;
esac

shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}
# env.sh, in two parts: everything known now, written here with every value
# quoted; then the bus address and the compositor's socket name, which only
# exist once the session is up.
{
    echo "export XDG_RUNTIME_DIR=$(shell_quote "$RUNTIME_N")"
    echo "export LAMBENT_NESTED_HOST_RUNTIME_DIR=$(shell_quote "$RUNTIME_DIR")"
    echo "export PIPEWIRE_RUNTIME_DIR=$(shell_quote "${PIPEWIRE_RUNTIME_DIR:-$RUNTIME_DIR}")"
    echo "export XDG_CONFIG_HOME=$(shell_quote "$XDG_CONFIG_HOME")"
    echo "export XDG_DATA_HOME=$(shell_quote "$XDG_DATA_HOME")"
    echo "export XDG_CACHE_HOME=$(shell_quote "$XDG_CACHE_HOME")"
    echo "export XDG_STATE_HOME=$(shell_quote "$XDG_STATE_HOME")"
    echo "export QT_QPA_PLATFORM=wayland"
    echo "unset QT_WAYLAND_RECONNECT DISPLAY"
    echo "export PATH=$(shell_quote "$BUILD_DIR/bin"):\"\$PATH\""
    echo "export QT_PLUGIN_PATH=$(shell_quote "$QT_PLUGIN_PATH")"
    echo "export QT_LOGGING_RULES=$(shell_quote "$QT_LOGGING_RULES")"
    echo "export QT_FORCE_STDERR_LOGGING=1"
    echo "export LAMBENT_NESTED_DIR=$(shell_quote "$NEST")"
    echo "export LAMBENT_NESTED_OUTPUTS=$(shell_quote "$OUTPUTS")"
} > "$NEST/env.sh.static"

# The compositor's environment: the session's runtime dir and the wlroots
# backend. Exported here so the session shell below inherits it; env.sh
# carries only what clients need.
export XDG_RUNTIME_DIR="$RUNTIME_N"
if [ -n "$HOST_WAYLAND" ]; then
    export WLR_BACKENDS=wayland WLR_WL_OUTPUTS="$OUTPUTS" WAYLAND_DISPLAY="$HOST_WAYLAND"
else
    export WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS="$OUTPUTS" WLR_LIBINPUT_NO_DEVICES=1
    unset WAYLAND_DISPLAY
fi
unset DISPLAY SWAYSOCK
[ -z "${LAMBENT_NESTED_RENDERER:-}" ] || export WLR_RENDERER="$LAMBENT_NESTED_RENDERER"

# The compositor's output goes to compositor.log as well, unless stderr already
# is a regular file (compositor.log itself under LAMBENT_NESTED_DETACH).
LOG_TEE=1
[ -f /dev/stderr ] && LOG_TEE=0
export LAMBENT_NESTED_SIZE="${WIDTH:+${WIDTH}x${HEIGHT}}" LAMBENT_NESTED_SCALE="$SCALE"
export NEST OUTPUTS COMPOSITOR_KIND LOG_TEE

exec dbus-run-session -- bash -c '
    set -e
    # The compositor runs in the background so this shell can wait for its
    # socket, and a background job ignores SIGINT: Ctrl+C, a hangup or a TERM
    # reaches this shell, which hands it on as TERM and stays to sweep after.
    # The log copy ignores them and ends when the compositor closes the pipe.
    if [ "$LOG_TEE" = 1 ]; then
        "$@" > >(trap "" INT TERM HUP; exec tee -a "$NEST/compositor.log" >&2) 2>&1 &
    else
        "$@" &
    fi
    compositor=$!
    echo "$compositor" > "$NEST/compositor.pid"
    trap "kill -TERM $compositor 2>/dev/null || true" INT TERM HUP
    socket=""
    for _ in $(seq 1 100); do
        for s in "$XDG_RUNTIME_DIR"/wayland-*; do
            case "$s" in *.lock) continue ;; esac
            [ -S "$s" ] && socket="${s##*/}" && break
        done
        [ -n "$socket" ] && break
        kill -0 "$compositor" 2>/dev/null || break
        sleep 0.1
    done
    if [ -z "$socket" ]; then
        echo "the nested compositor bound no wayland socket in $XDG_RUNTIME_DIR" >&2
        kill "$compositor" 2>/dev/null || true
        wait "$compositor" || true
        exit 1
    fi
    # Services the bus activates inherit its environment: give them the
    # nested runtime dir and display rather than the host ones.
    dbus-update-activation-environment XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$socket" DISPLAY= \
        || echo "warning: dbus-update-activation-environment failed; services the nested bus activates keep the host display" >&2
    # Output size and scale for a compositor that takes no config from here.
    if [ "$COMPOSITOR_KIND" != sway ] && [ -n "$LAMBENT_NESTED_SIZE$LAMBENT_NESTED_SCALE" ]; then
        for i in $(seq 1 "$OUTPUTS"); do
            set -- --output "HEADLESS-$i"
            [ -n "$LAMBENT_NESTED_SIZE" ] && set -- "$@" --custom-mode "$LAMBENT_NESTED_SIZE"
            [ -n "$LAMBENT_NESTED_SCALE" ] && set -- "$@" --scale "$LAMBENT_NESTED_SCALE"
            WAYLAND_DISPLAY="$socket" wlr-randr "$@" || echo "warning: wlr-randr could not configure HEADLESS-$i" >&2
        done
    fi
    {
        echo "export DBUS_SESSION_BUS_ADDRESS='"'"'$DBUS_SESSION_BUS_ADDRESS'"'"'"
        echo "export WAYLAND_DISPLAY='"'"'$socket'"'"'"
        cat "$NEST/env.sh.static"
    } > "$NEST/env.sh.tmp"
    mv "$NEST/env.sh.tmp" "$NEST/env.sh"
    echo "nested $COMPOSITOR_KIND up on $XDG_RUNTIME_DIR/$socket; source $NEST/env.sh" >&2
    # A trapped signal ends a wait early, so wait until the compositor is gone.
    status=0
    while kill -0 "$compositor" 2>/dev/null; do
        wait "$compositor" && status=0 || status=$?
    done
    bash "$NEST/sweep-activated.sh" "$DBUS_SESSION_BUS_ADDRESS" || true
    exit $status
' lambent-nested "${COMPOSITOR[@]}"
