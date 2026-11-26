<!-- SPDX-FileCopyrightText: 2026 Phosphor Works Team -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Lambent

Lambent is a desktop shell for Wayland, written in QML. Its bar shows the windows of each screen in their positions.
Its popouts open where the window placement engine puts them, as windows do.

## Features

- A bar with a live map of the window layout, workspaces, a clock and a system tray
- A control center with quick settings for audio, network, Bluetooth and brightness
- An application launcher, notifications with a history, and on-screen displays
- A lock screen and a PolicyKit authentication prompt
- A shell tree in QML that you copy into `~/.config/phosphor-works/lambent/` and edit, with hot reload

Lambent uses [phosphor-libs](https://github.com/phosphor-works/phosphor-libs) and
[phosphor-shell-libs](https://github.com/phosphor-works/phosphor-shell-libs). It runs under each Wayland compositor
that has wlr-layer-shell.

A placement host on the `org.phosphor_works.Placement` D-Bus API supplies the live window map and the popout
positions. The daemon of [PlasmaZones](https://github.com/phosphor-works/PlasmaZones) is an example. If no placement
host runs, the bar shows no window map and each popout opens at its anchor.

## Install

Build Lambent from source (see "Build"). The flake in `flake.nix` also gives a Nix package
(`packaging/nix/package.nix`).

To start the shell, enable its systemd user unit in the session of your compositor:

```sh
systemctl --user enable --now lambent.service
```

[docs/RUN.md](docs/RUN.md) tells how to control the shell with `phosphorctl` and how to bind shortcuts and gestures
in the compositor.

## Build

The build needs these packages:

- CMake 3.25
- Qt 6.10 with its private headers
- extra-cmake-modules
- The Wayland and Vulkan headers
- KF6 Kirigami and KF6 WindowSystem
- libxkbcommon, libpipewire, polkit-qt6 and PAM

The first configure downloads the pinned phosphor-libs, phosphor-shell-libs, phosphor-surface-packs and branding
archives (`cmake/LambentDependencies.cmake`) into `.cache/cpm`.

```sh
cmake --workflow --preset dev
```

This command configures into `build/`, builds Lambent and the libraries, and runs the tests. To build against local
checkouts of the libraries, add these options to the configure:

- `-DCPM_phosphor-libs_SOURCE=/path/to/phosphor-libs`
- `-DCPM_phosphor-shell-libs_SOURCE=/path/to/phosphor-shell-libs`

The bar and the popouts use the surface decoration packs of
[phosphor-surface-packs](https://github.com/phosphor-works/phosphor-surface-packs). Lambent installs them to
`share/phosphor-works/shaders/surface`, where each app of the suite finds them. A distribution that packages them one
time for all apps configures with `-DLAMBENT_INSTALL_SURFACE_PACKS=OFF`.

## Documentation

[docs/README.md](docs/README.md) lists the pages: how to run the shell, its architecture and its visual identity.

## Contributing

The application is in `lambent/`. The C++ is in `src/`, the bundled shell tree is in `shell/`, `phosphorctl` is in
`cli/` and the tests are in `tests/`. `CONTRIBUTING.md` gives the code style, the pre-commit hooks and how to send a
change. `CHANGELOG.md` records the changes.

## License

Lambent is licensed under GPL-3.0-or-later. The license text is in `LICENSE`.
