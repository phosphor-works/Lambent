<!-- SPDX-FileCopyrightText: 2026 Phosphor Works Team -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Contributing to Lambent

This page tells contributors how to build Lambent, where its files are, which code style it uses and how to send a
change.

## Getting started

Build Lambent on your computer first. The README gives the packages that the build needs. The short procedure is:

```sh
cmake --workflow --preset dev
```

This command configures a Debug build with tests into `build/`, builds it and runs the tests. The first configure
downloads the pinned phosphor-libs and phosphor-shell-libs, so it takes some time.

A change that also needs a change in one of the libraries is two pull requests. One pull request goes to the
repository of the library. The other goes to this repository and builds against the library change. To build against
a local checkout of a library, use one of these options:

- `-DCPM_phosphor-libs_SOURCE=/path/to/phosphor-libs`
- `-DCPM_phosphor-shell-libs_SOURCE=/path/to/phosphor-shell-libs`

## Where things are

The application is in `lambent/`.

| Folder | Contents |
| --- | --- |
| `lambent/src/` | The C++ |
| `lambent/shell/` | The bundled shell QML tree |
| `lambent/cli/` | `phosphorctl` |
| `lambent/tests/` | The tests |
| `lambent/data/` | The desktop integration |

`cmake/`, `packaging/`, `scripts/` and `docs/` are at the root.

## Code style

The repository root has a `.clang-format`. Run clang-format on the C++ that you change, and qmlformat on the QML:

```sh
clang-format -i lambent/src/path/to/your/file.cpp
qmlformat -i lambent/shell/YourFile.qml
```

[Lefthook](https://github.com/evilmartians/lefthook) runs both tools on the staged files before each commit. It also
checks the commit message. To set it up, run `lefthook install` one time.

The main rules are:

- Indent with 4 spaces, not tabs.
- Put the braces of functions and classes on their own line. Put the braces of control flow on the same line.
- Put the pointer asterisk with the type: `int* foo` not `int *foo`.
- Keep lines to 120 characters or fewer.
- `QT_NO_CAST_FROM_ASCII` is on, so a string constant is a `QStringLiteral`.

If you are not sure about a rule, look at the existing code and do the same. `CLAUDE.md` has the full set of rules
for the project.

## License headers

Each source file starts with an SPDX header in this format:

```cpp
// SPDX-FileCopyrightText: 2026 Your Name
// SPDX-License-Identifier: GPL-3.0-or-later
```

If you change an existing file, add your name to the copyright line, or add a new line below the existing lines.

## Submitting changes

1. Fork the repository.
2. Create a branch for your work.
3. Make your changes.
4. Test your changes. As a minimum, make sure that the build and the tests pass.
5. Open a pull request.

Keep each commit to one logical change. A commit with one change is easier to review than a commit with many
unrelated changes.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/). A message starts with a type
(`feat:`, `fix:`, `refactor:`, `docs:`, `build:`, `ci:` or another type) and a short summary. If you need more
detail, add a blank line and then the detail. A change that users see gets a line under `## Unreleased` in
`CHANGELOG.md`.

## Testing

The tests are in `lambent/tests/`. The dev preset runs them together with the tests of the libraries:

```sh
ctest --preset dev
ctest --test-dir build -R test_bar_controller   # one test
```

If you add a feature, add tests for it. If you fix a bug, add a test that finds the bug, if you can.

To see a change on the screen without an effect on your own session, use `scripts/nested-shell/run-shell.sh`. It runs
the shell of the build tree in a nested headless labwc or sway session. That session has its own session bus, runtime
dir and XDG homes. `ctl.sh` and `capture.sh` in the same folder control the shell and take screenshots with grim.

## Questions

If you have a problem or want to discuss a change, open an issue. The project has no mailing list or chat channel.
