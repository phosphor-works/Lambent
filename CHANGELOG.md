<!-- SPDX-FileCopyrightText: 2026 fuddlesworth -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Changelog

All notable changes to Lambent are documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Lambent follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Lambent is its own repository. It was split out of PlasmaZones with its history, where it was the `phosphor-shell`
  tier, and builds against pinned commits of phosphor-libs and phosphor-shell-libs rather than in-tree copies.
- A Nix flake that builds Lambent and runs its tests, and CI on Arch and Nix.

### Changed

- The bundled shell QML module is `Lambent.Shell`, at `qrc:/qt/qml/Lambent/Shell/`.
- The application's sources are in `lambent/`, and the Nix package in `packaging/nix/`.
- Lambent no longer assumes KWin. It needs a Wayland compositor with wlr-layer-shell, and reads window placement from
  any host of the `org.phosphor_works.Placement` D-Bus API.
- The nested test session is a headless labwc or sway compositor with its own session bus and runtime dir, and takes
  screenshots with grim. It no longer needs a PlasmaZones checkout.

- The surface decoration packs come from phosphor-surface-packs and install to `share/phosphor-works/shaders/surface`,
  shared with the suite's other apps. They were PlasmaZones' before.
- Lambent passes the libraries its own paths: `~/.config/lambent/` for the shell tree, appearance and wallpapers,
  `~/.local/share/lambent/` for the appearance library and saved shader presets.

- Blur behind the bar, popouts and other glass surfaces uses the standard ext-background-effect-v1 protocol, so
  any compositor that offers it blurs them, not only KWin.
- Night light warms the screen through the standard wlr-gamma-control protocol rather than KWin's Night Light, and
  keeps its settings in `~/.config/lambent/nightlight.json`. The sunset schedule needs a latitude and longitude saved
  there, and until one is set the quick settings say a location is needed.

### Removed

- The "Match desktop windows" style, which wrote KWin's window decoration and PlasmaZones' gaps.
- Stage's native desktop preview through the KWin effect. Stage shows the placement-map preview.
- The touchpad gesture relay from the KWin effect. Bind the compositor's gestures to `phosphorctl call launcher.toggle`
  or `phosphorctl call dashboard.toggle` instead.
