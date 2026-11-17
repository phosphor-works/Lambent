# Lambent

A desktop shell for Wayland, written in QML. Its bar draws the windows of each screen as they are placed, and its
popouts open where the window placement engine puts them, the way windows do.

- A bar with a live map of the window layout, workspaces, a clock and a system tray
- A control center with quick settings for audio, network, Bluetooth and brightness
- An application launcher, notifications with a history, and on-screen displays
- A lock screen and a PolicyKit authentication prompt
- A shell tree in QML that you copy into `~/.config/lambent/` and edit, with hot reload

Lambent is built on [phosphor-libs](https://github.com/phosphor-works/phosphor-libs) and
[phosphor-shell-libs](https://github.com/phosphor-works/phosphor-shell-libs). Under KDE Plasma it works with
[PlasmaZones](https://github.com/phosphor-works/PlasmaZones), whose placement daemon places its popouts and whose KWin
effect draws its decorations.

## Build

Needs CMake 3.25, Qt 6.10 with its private headers, extra-cmake-modules, Wayland and the Vulkan headers, KF6 Kirigami,
GuiAddons, Config, CoreAddons and WindowSystem, libpipewire, polkit-qt6 and PAM. The first configure downloads the
pinned phosphor-libs, phosphor-shell-libs and branding archives (`cmake/LambentDependencies.cmake`) into
`.cache/cpm`.

```sh
cmake --workflow --preset dev
```

That configures into `build/`, builds Lambent and the libraries, and runs the tests. To build against local checkouts
of the libraries, add `-DCPM_phosphor-libs_SOURCE=/path/to/phosphor-libs` and
`-DCPM_phosphor-shell-libs_SOURCE=/path/to/phosphor-shell-libs` to the configure. `test_shell_chrome` resolves against
PlasmaZones' decoration packs: add `-DLAMBENT_SURFACE_PACKS_DIR=/path/to/PlasmaZones/plasmazones/data/surface` to run
it.

## Run

Lambent installs a systemd user unit. Enable it in a session whose compositor it should draw the shell for:

```sh
systemctl --user enable --now lambent.service
```

`phosphorctl` drives a running shell over its IPC socket (`phosphorctl list`, `phosphorctl call <target>.<fn>`).
`scripts/nested-shell/run-shell.sh` runs the build-tree shell inside a nested KWin session, using a built PlasmaZones
checkout beside this one.

## Contributing

The application is in `lambent/`: the C++ in `src/`, the bundled shell tree in `shell/`, `phosphorctl` in `cli/`, the
tests in `tests/`. See `CONTRIBUTING.md` for the code style, the pre-commit hooks and how to send a change, and
`CHANGELOG.md` for what changed.

## License

GPL-3.0-or-later. See `LICENSE`.
