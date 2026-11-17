# Lambent

A desktop shell for Wayland, written in QML. Its bar draws the windows of each screen as they are placed, and its
popouts open where the window placement engine puts them, the way windows do.

- A bar with a live map of the window layout, workspaces, a clock and a system tray
- A control center with quick settings for audio, network, Bluetooth and brightness
- An application launcher, notifications with a history, and on-screen displays
- A lock screen and a PolicyKit authentication prompt
- A shell tree in QML that you copy into `~/.config/lambent/` and edit, with hot reload

Lambent is built on [phosphor-libs](https://github.com/phosphor-works/phosphor-libs) and
[phosphor-shell-libs](https://github.com/phosphor-works/phosphor-shell-libs). It runs under any Wayland compositor with
wlr-layer-shell. The live window map and engine-placed popouts come from a placement host on the
`org.phosphor_works.Placement` D-Bus API, such as [PlasmaZones](https://github.com/phosphor-works/PlasmaZones)' daemon.
Without one the bar shows no window map and popouts open at their anchors.

## Build

Needs CMake 3.25, Qt 6.10 with its private headers, extra-cmake-modules, Wayland and the Vulkan headers, KF6 Kirigami,
GuiAddons, Config and WindowSystem, libpipewire, polkit-qt6 and PAM. The first configure downloads the
pinned phosphor-libs, phosphor-shell-libs, phosphor-surface-packs and branding archives
(`cmake/LambentDependencies.cmake`) into `.cache/cpm`.

```sh
cmake --workflow --preset dev
```

That configures into `build/`, builds Lambent and the libraries, and runs the tests. To build against local checkouts
of the libraries, add `-DCPM_phosphor-libs_SOURCE=/path/to/phosphor-libs` and
`-DCPM_phosphor-shell-libs_SOURCE=/path/to/phosphor-shell-libs` to the configure.

The surface decoration packs the bar and popouts draw come from
[phosphor-surface-packs](https://github.com/phosphor-works/phosphor-surface-packs) and install to
`share/phosphor-works/surface`, where every app of the suite finds them. A distribution that packages them once for all
apps configures with `-DLAMBENT_INSTALL_SURFACE_PACKS=OFF`.

## Run

Lambent installs a systemd user unit. Enable it in a session whose compositor it should draw the shell for:

```sh
systemctl --user enable --now lambent.service
```

`phosphorctl` drives a running shell over its IPC socket (`phosphorctl list`, `phosphorctl call <target>.<fn>`).

Keyboard shortcuts and touchpad gestures belong to the compositor, which runs `phosphorctl` for them. In sway, for
example:

```
bindsym $mod+d exec phosphorctl call launcher.toggle
bindgesture swipe:3:up exec phosphorctl call launcher.toggle
bindgesture swipe:3:down exec phosphorctl call launcher.hide
bindgesture swipe:4:up exec phosphorctl call dashboard.toggle
bindgesture pinch:4:outward exec phosphorctl call dashboard.hide
```

`scripts/nested-shell/run-shell.sh` runs the build-tree shell in a nested headless labwc or sway session, with its
own session bus, runtime dir and XDG homes, and `ctl.sh` and `capture.sh` beside it drive it and take screenshots
with grim.

## Contributing

The application is in `lambent/`: the C++ in `src/`, the bundled shell tree in `shell/`, `phosphorctl` in `cli/`, the
tests in `tests/`. See `CONTRIBUTING.md` for the code style, the pre-commit hooks and how to send a change, and
`CHANGELOG.md` for what changed.

## License

GPL-3.0-or-later. See `LICENSE`.
