# SPDX-FileCopyrightText: 2026 fuddlesworth
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The Lambent package: the lambent binary, phosphorctl, the bundled shell tree,
# the desktop integration, and the phosphor-libs and phosphor-shell-libs
# libraries it is built with, from the commits cmake/LambentDependencies.cmake
# pins. `withTests` builds and runs the test suite (the libraries' included) in
# the sandbox, which is what the flake's `checks.<system>.tests` does.
{
  lib,
  stdenv,
  fetchurl,
  linkFarm,
  cmake,
  ninja,
  pkg-config,
  qt6,
  kdePackages,
  wayland,
  wayland-scanner,
  libxkbcommon,
  vulkan-headers,
  dbus,
  pipewire,
  pam,
  ddcutil,
  python3,
  glib,
  gobject-introspection,
  makeFontsConf,
  dejavu_fonts,
  src,
  version,
  withTests ? false,
}:

let
  # The phosphor-libs, phosphor-shell-libs and phosphor-surface-packs commits
  # and the branding release cmake/LambentDependencies.cmake pins, and the Luau
  # and valijson archives the phosphor-libs commit pins in its
  # cmake/PhosphorDependencies.cmake. The sandbox has no network, so they are
  # fetched here as fixed-output derivations and handed to CMake as one
  # directory (PHOSPHOR_DEPS_ARCHIVES), each under the FILE name its pin gives
  # it. CMake checks each against the pin's hash again before unpacking it.
  # fetchurl, not fetchFromGitHub: the pin hashes the archive file itself.
  depsArchives = linkFarm "lambent-deps-archives" [
    {
      name = "phosphor-libs-d41667f4005dbc1bbf3d2ce21da1655838cb6474.tar.gz";
      path = fetchurl {
        url = "https://github.com/phosphor-works/phosphor-libs/archive/d41667f4005dbc1bbf3d2ce21da1655838cb6474.tar.gz";
        # sha256 5b74faa9bf154619af64936d554b56d7a09e82d27898b34fdabe8feb2f7d8c20
        hash = "sha256-W3T6qb8VRhmvZJNtVUtW16CegtJ4mLNP2r6P6y99jCA=";
      };
    }
    {
      name = "phosphor-shell-libs-ac2adf6d443af042690bc29882ac060d92120c83.tar.gz";
      path = fetchurl {
        url = "https://github.com/phosphor-works/phosphor-shell-libs/archive/ac2adf6d443af042690bc29882ac060d92120c83.tar.gz";
        # sha256 6addb9a2c36d2a8b30583177c179a0aa7d9815337a6d174f89f4da3655dcd2f6
        hash = "sha256-at25osNtKoswWDF3wXmgqn2YFTN6bRdPifTaNlXc0vY=";
      };
    }
    {
      name = "phosphor-surface-packs-e89d9f7bb6320eab8b6a0b3325858d2ca5356ce3.tar.gz";
      path = fetchurl {
        url = "https://github.com/phosphor-works/phosphor-surface-packs/archive/e89d9f7bb6320eab8b6a0b3325858d2ca5356ce3.tar.gz";
        # sha256 fbbf0b9849d83396029bc4e310c3dcac49c08758e73d560538888e685f0a5e30
        hash = "sha256-+78LmEnYM5YCm8TjEMPcrEnAh1jnPVYFOIiOaF8KXjA=";
      };
    }
    {
      name = "phosphor-branding-0.3.1.tar.gz";
      path = fetchurl {
        url = "https://github.com/phosphor-works/branding/releases/download/v0.3.1/phosphor-branding-0.3.1.tar.gz";
        # sha256 d6ec9261d4391148f5c21dfb02be410214d42ea675f1558a826042d63f495094
        hash = "sha256-1uySYdQ5EUj1wh37Ar5BAhTULqZ18VWKgmBC1j9JUJQ=";
      };
    }
    {
      name = "luau-0.745.tar.gz";
      path = fetchurl {
        url = "https://github.com/luau-lang/luau/archive/refs/tags/0.745.tar.gz";
        # sha256 53c22773bace6cabbabaead576fbc08d11a0317fce11a3dbf9d027dda6849248
        hash = "sha256-U8Inc7rObKu6uurVdvvAjRGgMX/OEaPb+dAn3aaEkkg=";
      };
    }
    {
      name = "valijson-1.1.3.tar.gz";
      path = fetchurl {
        url = "https://github.com/tristanpenman/valijson/archive/refs/tags/v1.1.3.tar.gz";
        # sha256 887b53b1a924f6fe0b35fa3bbc9bbbe5ae8c72097b7f0f7c17b45f4cfa646029
        hash = "sha256-iHtTsakk9v4LNfo7vJu75a6Mcgl7fw98F7RfTPpkYCk=";
      };
    }
  ];
  trayFixturePython = python3.withPackages (ps: [
    ps.dbus-python
    ps.pygobject3
  ]);
in
stdenv.mkDerivation {
  pname = if withTests then "lambent-tests" else "lambent";
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    kdePackages.extra-cmake-modules
    wayland-scanner
    # Wraps lambent and phosphorctl so they find every Qt input's plugins and
    # QML modules (QtQuick, Controls, Kirigami, each in its own store path), and
    # collects those directories into qtWrapperArgs, which preCheck turns into
    # the test environment.
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtshadertools
    qt6.qtsvg
    qt6.qtwayland
    wayland
    # Qt declares QVulkanInstance only with the Vulkan headers present, and
    # phosphor-surfaces uses it when Qt has Vulkan, as nixpkgs' Qt does.
    vulkan-headers
    # The shell libraries draw their icons through Kirigami.
    kdePackages.kirigami
    # phosphor-shell-lock reads the keyboard layout and Caps Lock from the
    # seat's keymap.
    libxkbcommon
    # Lambent's own: KWindowSystem for the notification centre's activation
    # tokens.
    kdePackages.kwindowsystem
    # The service libraries' system interfaces: PipeWire, polkit-qt6, PAM, and
    # ddcutil for phosphor-service-brightness's optional external-monitor
    # backend.
    pipewire
    kdePackages.polkit-qt-1
    pam
    ddcutil
  ];

  # dbus-run-session gives each test a private session bus
  # (cmake/PhosphorTestIsolation.cmake). The tray tests run a fixture of real
  # StatusNotifierItem apps (libs/phosphor-shell-bar/tests/tray-fixture.py)
  # through a Python with dbus-python and PyGObject, which reaches GLib
  # through gobject-introspection.
  nativeCheckInputs = [
    dbus
    trayFixturePython
    gobject-introspection
  ];
  checkInputs = [ glib ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBUILD_TESTING=${if withTests then "ON" else "OFF"}"
    "-DPHOSPHOR_DEPS_ARCHIVES=${depsArchives}"
    "-DKDE_INSTALL_QTPLUGINDIR=${placeholder "out"}/${qt6.qtbase.qtPluginPrefix}"
    "-DKDE_INSTALL_QMLDIR=${placeholder "out"}/${qt6.qtbase.qtQmlPrefix}"
  ]
  # The interpreter the tray tests launch their fixture with, named so CMake
  # cannot pick another Python on PATH that lacks the modules.
  ++ lib.optional withTests "-DPython3_EXECUTABLE=${trayFixturePython.interpreter}";

  doCheck = withTests;
  # The tests run uninstalled, from the build tree, so nothing wraps them.
  # nixpkgs' Qt finds QML modules through NIXPKGS_QT6_QML_IMPORT_PATH and
  # plugins through QT_PLUGIN_PATH, and wrapQtAppsHook puts both only into the
  # wrapper arguments of installed programs. Export the same entries here, so
  # the tests that load QtQuick, Controls or Kirigami find them. Then the
  # offscreen platform for the GUI tests, and a writable HOME for the ones the
  # XDG sandbox does not cover.
  preCheck = ''
    for ((i = 0; i + 3 < ''${#qtWrapperArgs[@]}; i++)); do
      if [[ "''${qtWrapperArgs[i]}" == --prefix ]]; then
        case "''${qtWrapperArgs[i + 1]}" in
          NIXPKGS_QT6_QML_IMPORT_PATH | QT_PLUGIN_PATH)
            addToSearchPath "''${qtWrapperArgs[i + 1]}" "''${qtWrapperArgs[i + 3]}"
            ;;
        esac
      fi
    done
    export NIXPKGS_QT6_QML_IMPORT_PATH QT_PLUGIN_PATH
    # GLib's typelibs, for the tray fixture's `from gi.repository import GLib`.
    addToSearchPath GI_TYPELIB_PATH "${glib.out}/lib/girepository-1.0"
    export GI_TYPELIB_PATH
    # One real font family, so the theme's font tests resolve an installed face.
    export FONTCONFIG_FILE=${makeFontsConf { fontDirectories = [ dejavu_fonts ]; }}
    export QT_QPA_PLATFORM=offscreen
    export HOME="$(mktemp -d)"
    export CTEST_OUTPUT_ON_FAILURE=1
  '';

  meta = {
    description = "A desktop shell with a bar that shows the live window layout";
    homepage = "https://github.com/phosphor-works/Lambent";
    mainProgram = "lambent";
    license = with lib.licenses; [
      gpl3Plus
      lgpl21Plus
      mit
      bsd2
      # The vendored wlr-gamma-control protocol of phosphor-service-nightlight.
      hpndSellVariant
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
