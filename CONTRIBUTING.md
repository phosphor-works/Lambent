<!-- SPDX-FileCopyrightText: 2026 Phosphor Works Team -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Contributing to Lambent

Thanks for considering contributing. This document covers the basics of how to get involved.

## Getting started

Build it locally first. The README lists what the build needs. The short version:

```sh
cmake --workflow --preset dev
```

That configures a Debug build with tests into `build/`, builds it and runs the tests. The first configure downloads the
pinned phosphor-libs and phosphor-shell-libs, so it takes a while.

A change that also needs a change in one of the libraries is two pull requests: one in the library's repository, and
one here that builds against it. Build against a local checkout of the library with
`-DCPM_phosphor-libs_SOURCE=/path/to/phosphor-libs` or `-DCPM_phosphor-shell-libs_SOURCE=/path/to/phosphor-shell-libs`.

## Where things are

The application is in `lambent/`: the C++ in `src/`, the bundled shell QML tree in `shell/`, `phosphorctl` in `cli/`,
the tests in `tests/` and the desktop integration in `data/`. `cmake/`, `packaging/`, `scripts/` and `docs/` are at the
root.

## Code style

There's a `.clang-format` in the repo root. Run clang-format on the C++ you change and qmlformat on the QML:

```sh
clang-format -i lambent/src/path/to/your/file.cpp
qmlformat -i lambent/shell/YourFile.qml
```

[Lefthook](https://github.com/evilmartians/lefthook) runs both on the staged files before every commit, and checks the
commit message. Set it up once with `lefthook install`.

The highlights:
- 4 spaces, no tabs
- Braces on their own line for functions and classes, same line for control flow
- Pointer asterisk goes with the type: `int* foo` not `int *foo`
- 120 character line limit
- `QT_NO_CAST_FROM_ASCII` is on, so a string constant is a `QStringLiteral`

If you're not sure about something, look at the existing code and match what's already there. `CLAUDE.md` has the
project's full set of rules.

## License headers

Every source file needs an SPDX header at the top. Use this format:

```cpp
// SPDX-FileCopyrightText: 2026 Your Name
// SPDX-License-Identifier: GPL-3.0-or-later
```

If you're modifying an existing file, add your name to the copyright line or add a new line below the existing ones.

## Submitting changes

1. Fork the repo
2. Create a branch for your work
3. Make your changes
4. Test them (at minimum, make sure it builds and the tests pass)
5. Open a pull request

Keep commits focused. One logical change per commit is easier to review than a massive dump of unrelated changes.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `refactor:`,
`docs:`, `build:`, `ci:` and so on, then a short summary, a blank line, and more detail if needed. A change people will
notice gets a line under `## Unreleased` in `CHANGELOG.md`.

## Testing

The tests live in `lambent/tests/`. The dev preset runs them along with the libraries' own tests:

```sh
ctest --preset dev
ctest --test-dir build -R test_bar_controller   # one test
```

If you're adding new functionality, add tests for it. If you're fixing a bug, a test that would have caught it is
appreciated.

To see a change on screen without touching your own session, `scripts/nested-shell/run-shell.sh` runs the build-tree
shell in a nested session, and `ctl.sh` and `capture.sh` beside it drive it and take screenshots.

## Questions

Open an issue if you're stuck or want to discuss something. There's no mailing list or chat channel at the moment.
