# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Sourced, never run: the one place the nested session's state directory is
# resolved. run-nested.sh and every script beside it source this, so a
# follow-up script always joins the session run-nested.sh started.
#
# Sets RUNTIME_DIR (the host's runtime dir) and NEST (the session's state dir).
# Exits the sourcing script when neither XDG_RUNTIME_DIR nor
# LAMBENT_NESTED_DIR says where that is, or LAMBENT_NESTED_SESSION is
# malformed.
#
# env.sh points XDG_RUNTIME_DIR at the session's private runtime dir
# ($NEST/runtime) and exports LAMBENT_NESTED_DIR, so a shell that sourced it
# still resolves the same session here.

# LAMBENT_NESTED_SESSION names a second, independent session: it suffixes the
# default state dir. It is a NAME, not a path, so it may not carry a slash or
# start with a dot ('..' would walk the default state dir up into the runtime
# dir itself).
case "${LAMBENT_NESTED_SESSION:-}" in
    '') ;;
    .* | *[!A-Za-z0-9._-]*)
        echo "LAMBENT_NESTED_SESSION must match [A-Za-z0-9._-]+ and not start with '.', got '$LAMBENT_NESTED_SESSION'" >&2
        exit 1
        ;;
esac

if [ -n "${LAMBENT_NESTED_DIR:-}" ]; then
    NEST="$LAMBENT_NESTED_DIR"
    # Inside a sourced env.sh, XDG_RUNTIME_DIR is the session's own; the host's
    # is recorded beside it.
    RUNTIME_DIR="${LAMBENT_NESTED_HOST_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-}}"
else
    # No fallback for a missing XDG_RUNTIME_DIR: a /tmp default would be a
    # predictable path another local user could create first.
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        echo "XDG_RUNTIME_DIR is unset; the nested session keeps its state under it" >&2
        exit 1
    fi
    RUNTIME_DIR="$XDG_RUNTIME_DIR"
    NEST="$RUNTIME_DIR/lambent-nested${LAMBENT_NESTED_SESSION:+-$LAMBENT_NESTED_SESSION}"
fi
