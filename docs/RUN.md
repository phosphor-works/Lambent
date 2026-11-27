<!-- SPDX-FileCopyrightText: 2026 Phosphor Works Team -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Run Lambent

This page tells how to start the shell and control it with `phosphorctl`. It also tells how to bind shortcuts and
gestures in the compositor. Read it after you install Lambent.

## Start the shell

Lambent installs a systemd user unit. To start the shell, enable the unit in the session of the compositor that
Lambent draws the shell for:

```sh
systemctl --user enable --now lambent.service
```

## Control the shell

`phosphorctl` controls a running shell through its IPC socket. Give it `--app lambent`
(`phosphorctl --app lambent list`, `phosphorctl --app lambent call <target>.<fn>`). Without `--app`, `phosphorctl`
talks to the Phosphor compositor.

| Subcommand | What it does |
| --- | --- |
| `call <target>.<fn>` | Calls a function on a target and prints the return value |
| `list` | Prints the id of each registered target |
| `schema <target>` | Prints the JSON Schema of a target |
| `subscribe <target>.<signal>` | Prints the JSON events of a signal until you push Ctrl+C |

Lambent binds `$LAMBENT_SOCKET`, or `$XDG_RUNTIME_DIR/lambent.sock` when that variable is not set.
`phosphorctl --app lambent` finds the socket in the same order. The `--socket` option overrides both.

## Bind shortcuts and gestures

The compositor owns the keyboard shortcuts and the touchpad gestures. It runs `phosphorctl` for them. For example,
in sway:

```
bindsym $mod+d exec phosphorctl --app lambent call launcher.toggle
bindgesture swipe:3:up exec phosphorctl --app lambent call launcher.toggle
bindgesture swipe:3:down exec phosphorctl --app lambent call launcher.hide
bindgesture swipe:4:up exec phosphorctl --app lambent call dashboard.toggle
bindgesture pinch:4:outward exec phosphorctl --app lambent call dashboard.hide
```

## See also

- [architecture.md](architecture.md): the modules of the shell and how the data moves between them
