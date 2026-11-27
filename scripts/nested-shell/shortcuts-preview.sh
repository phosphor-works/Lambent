#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
# Production shortcut reference with fixture bindings. It never registers or
# invokes the displayed shortcuts. Run only inside an existing nested session.
#
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/shortcuts-preview.sh run
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/shortcuts-preview.sh call preview.mode --arg name=scrolling
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/shortcuts-preview.sh call preview.profile --arg name=custom
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/shortcuts-preview.sh call preview.query --arg text=column
# LAMBENT_NESTED_SESSION=review scripts/nested-shell/shortcuts-preview.sh call preview.state
# Stop the foreground preview with Ctrl+C before restarting it.
#
# Capture with nested-shell/capture.sh on the original nested session bus.
# LAMBENT_SHORTCUTS_SCREEN optionally selects an output by name instead of primary.
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
    *) echo "Shortcut preview requires the nested compositor." >&2; exit 1 ;;
esac
if [ ! -S "${XDG_RUNTIME_DIR:?}/$WAYLAND_DISPLAY" ]; then
    echo "The nested compositor socket is not available." >&2
    exit 1
fi
BUILD="${LAMBENT_BUILD:-build}"
case "$BUILD" in
    /*) ;;
    *) BUILD="$REPO/$BUILD" ;;
esac
export LAMBENT_SOCKET="$NEST/shortcuts-preview.sock"
if [ "${1:-run}" != run ]; then
    exec "$BUILD/bin/lambentctl" --socket "$LAMBENT_SOCKET" "$@"
fi
if [ "$#" -gt 1 ]; then
    echo "usage: shortcuts-preview.sh [run | lambentctl arguments]" >&2
    exit 1
fi
if [ ! -x "$BUILD/bin/lambent" ]; then
    echo "Build Lambent first (cmake --workflow --preset dev)." >&2
    exit 1
fi
if [ -S "$LAMBENT_SOCKET" ] && "$BUILD/bin/lambentctl" --socket "$LAMBENT_SOCKET" call preview.state >/dev/null 2>&1; then
    echo "The shortcut preview is already running. Stop its process before restarting it." >&2
    exit 1
fi

# Each launch has its own activation-free session bus. The system-bus override
# also contains the generic shell host's Polkit/logind/controller startup calls.
# No installed D-Bus service files are loaded into this preview bus.
PREVIEW="$NEST/shortcuts-preview"
umask 077
export XDG_CONFIG_HOME="$PREVIEW/config"
export XDG_DATA_HOME="$PREVIEW/data"
export XDG_CACHE_HOME="$PREVIEW/cache"
export XDG_STATE_HOME="$PREVIEW/state"
export PIPEWIRE_RUNTIME_DIR="$PREVIEW/runtime"
unset PIPEWIRE_REMOTE
export PULSE_SERVER="unix:$PREVIEW/runtime/pulse-native"
mkdir -p "$XDG_CONFIG_HOME/phosphor-works/lambent" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$PIPEWIRE_RUNTIME_DIR"
cp "$REPO/scripts/nested-shell/shortcuts-preview.qml" "$XDG_CONFIG_HOME/phosphor-works/lambent/shell.qml"
cat > "$PREVIEW/bus.conf" <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow user="$(id -u)"/>
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>
EOF
exec dbus-run-session --config-file="$PREVIEW/bus.conf" -- bash -c '
    unset DBUS_STARTER_ADDRESS DBUS_STARTER_BUS_TYPE
    export DBUS_SYSTEM_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS"
    exec "$@"
' shortcuts-preview "$BUILD/bin/lambent"
