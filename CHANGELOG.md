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
