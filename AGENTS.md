# Lambent: Codex configuration

Lambent is a desktop shell for Wayland: Qt 6, C++20 and QML. The `lambent` binary hosts the shell QML tree, its
controllers in `lambent/src/` own the registries, services and popout transports the QML reads, and `phosphorctl`
drives a running shell over phosphor-ipc. Application ID `org.phosphor_works.Lambent` (the `.desktop` file, AppStream
id and icon); user files in `~/.config/lambent/`, installed data in `share/lambent/`.

The application is in `lambent/` (`src/`, `shell/`, `cli/`, `tests/`, `data/`, entered from the root CMakeLists.txt
through `lambent/CMakeLists.txt`). The root holds the build setup (`cmake/`, `CMakePresets.json`, `flake.nix`),
`packaging/`, `docs/` and `scripts/`. `AGENTS.md` is this file for Codex: change both together.

## Rules

- Do what has been asked, nothing more. Solve the root cause; no workarounds, TODOs or "for now" hacks.
- Never run `cmake --install` into the system or `sudo`. The user installs.
- Read a file before editing it. Never save working files in the repository root.
- Run the tests after a change, and confirm the build has no warnings before committing.
- Unreleased: no migration code for renamed settings, paths or IPC names. Change them directly.
- Lambent assumes no particular compositor: wlr-layer-shell and standard Wayland protocols, and window placement
  through the host-neutral `org.phosphor_works.Placement` D-Bus API (`PlacementMap`, `ShortcutCatalog`, the pane rule,
  the chrome's decoration tree). Nothing new talks to `org.kde.KWin`, reads `kwinrc` or needs a KWin-only protocol.
  Night light is phosphor-service-nightlight on wlr-gamma-control, with Lambent's settings in
  `~/.config/lambent/nightlight.json`. Blur behind a surface is ext-background-effect-v1, through `ShellEffects`
  and phosphor-wayland's `BackgroundEffect`. Shortcuts and gestures are compositor binds that run `phosphorctl`.
- Conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `build:`, `ci:`). Stage files by name.
- A user-visible change gets a line under `## Unreleased` in `CHANGELOG.md`.
- `lefthook install` sets up the pre-commit hooks: clang-format and qmlformat on the staged files, and the
  conventional-commit check. CI's lint job runs the same formatters over the files a change touches.

## The libraries

The Phosphor libraries are not in this repository. phosphor-libs (placement, rendering, layer-shell, animation,
config, ipc) and phosphor-shell-libs (theme, popout, the `Phosphor.*` surfaces, the `phosphor-service-*` libraries)
are built from the commits `cmake/LambentDependencies.cmake` pins, added with CPM as subprojects. The surface
decoration packs come from the phosphor-surface-packs commit pinned there too.

- A change to a library is a pull request in that library's repository. Build Lambent against a local checkout with
  `-DCPM_phosphor-libs_SOURCE=<dir>` or `-DCPM_phosphor-shell-libs_SOURCE=<dir>`.
- After the library change merges, move the pin: VERSION, URL, FILE and SHA-256 together, in
  `cmake/LambentDependencies.cmake` and `packaging/nix/package.nix`. The phosphor-libs pin here is the one
  phosphor-shell-libs builds against, so move both when the shell libraries need a newer phosphor-libs.
- `${PHOSPHOR_LIBS_CMAKE_DIR}` holds the shared test helpers (`PhosphorTestIsolation`, `PhosphorTestPch`).
- The libraries keep no app paths. `main.cpp` hands them Lambent's at startup, before QML loads: the shell name
  (`Lambent::APP_DIR`, `lambent`, from the generated `version.h`) to ShellLoader and ShellEngine, the appearance file
  and library folder, the surface pack subdir, and ShellChrome's preset root. A new library path setting goes there.

## License

- Every file that can hold a comment starts with `SPDX-FileCopyrightText: 2026 fuddlesworth` and
  `SPDX-License-Identifier: GPL-3.0-or-later`. AppStream metadata is `CC0-1.0`. JSON carries no header.

## C++ and QML

- C++20, `#pragma once`, `explicit` single-argument constructors, `override` on virtuals. Members `m_camelCase`.
- `Q_EMIT`, `Q_SIGNALS:`, `Q_SLOTS:`. Emit a signal only when the value changed. Parent ownership for QObjects,
  `std::unique_ptr` or `QPointer` otherwise.
- `QT_NO_CAST_FROM_ASCII` is on: `QStringLiteral` for constants and paths, `QLatin1String` for comparisons and JSON
  keys. A raw literal is a compile error.
- The shell has no translation catalog; its strings are plain literals.
- QML: Qt Quick 6, typed properties over `var`, `required property` for mandatory ones, bindings over JS assignments.
  Every QML file of a module is listed in its `qt_add_qml_module`.
- User-facing text (the `.desktop` file, AppStream metadata, UI strings) is plain prose: no em dash between clauses,
  no semicolon joining sentences, no spaced hyphen as a dash.

## Build and test

```sh
cmake --workflow --preset dev            # configure into build/, build, test
ctest --test-dir build -R <name>         # one test
```

- The suite includes phosphor-libs' and phosphor-shell-libs' tests, which build as subprojects with tests on.
- `test_shell_chrome` resolves against the pinned phosphor-surface-packs tree (`PHOSPHOR_SURFACE_PACKS_DIR`).
- `PHOSPHOR_PW_TESTS_ALLOW_WRITE=0` keeps the PipeWire smoke test from toggling the host's real sink.
- `scripts/nested-shell/run-shell.sh [outputs] [width height] [scale]` runs the build-tree shell in a nested headless
  wlroots compositor (labwc or sway, or `LAMBENT_NESTED_COMPOSITOR`) with its own session bus, runtime dir and XDG
  homes, under `$XDG_RUNTIME_DIR/lambent-nested` (`LAMBENT_NESTED_SESSION=<name>` for another). `ctl.sh`,
  `capture.sh` (grim) and `shell.sh` drive it, after sourcing its `env.sh`. Never run the shell, `phosphorctl` or
  D-Bus calls against the user's own session.
- The decoration packs the shell draws are phosphor-surface-packs', installed to `share/phosphor-works/shaders/surface`
  (`PHOSPHOR_SURFACE_PACKS_DATA_SUBDIR`, set as phosphor-surface's pack subdir at startup).
  `-DLAMBENT_INSTALL_SURFACE_PACKS=OFF` leaves the install to a distribution's own package of them.

## Where things are

| Area | Files |
| --- | --- |
| Process and engine setup | `lambent/src/main.cpp` |
| Bar, popouts, panes | `lambent/src/barcontroller.cpp`, `layerpopouttransport.cpp`, `routingpopouttransport.cpp`, `socketpopouttransport.cpp`, `panepopouttransport.cpp`, `panerules.cpp` |
| Chrome and motion | `lambent/src/shellchrome.cpp` (decoration packs), `shellmotion.cpp`, `shelleffects.cpp` |
| Controllers | `lambent/src/*controller.cpp`: control center, quick settings, status icons, launcher, OSD, toasts, notifications, polkit, picker, color mode, airplane |
| Shell QML | `lambent/shell/` (the bundled tree, linked in as the `Lambent.Shell` module at `qrc:/qt/qml/Lambent/Shell/` and installed to `share/lambent/`) |
| CLI | `lambent/cli/phosphorctl/` |
| Tests | `lambent/tests/` |
| Desktop integration | `lambent/data/`: the `.desktop` file, AppStream metadata, the `lambent.service` user unit |
| Dependency pins | `cmake/LambentDependencies.cmake`, repeated in `packaging/nix/package.nix` |
| Nested test session | `scripts/nested-shell/` |
| Design | `docs/design/` |
