# SPDX-FileCopyrightText: 2026 fuddlesworth
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Lambent: a QML desktop shell for Wayland. The lambent binary, the phosphorctl
# IPC CLI, the bundled shell QML tree and the shell's tests.
#
# Built on phosphor-libs and phosphor-shell-libs, from the commits
# cmake/LambentDependencies.cmake pins, added with CPM as subprojects.
# -DCPM_phosphor-libs_SOURCE=<dir> and -DCPM_phosphor-shell-libs_SOURCE=<dir>
# build local checkouts of them instead.

cmake_minimum_required(VERSION 3.16)

project(Lambent VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC_PARALLEL_ENABLED ON)

option(CMAKE_UNITY_BUILD "Enable unity builds for faster compilation" ON)
set(CMAKE_UNITY_BUILD_BATCH_SIZE 16 CACHE STRING "Number of sources per unity batch")
option(ENABLE_PCH "Share one precompiled header across the test targets" ON)

find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
endif()

set(QT_MIN_VERSION "6.10.0")
set(KF_MIN_VERSION "6.26.0")

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

# Must come before KDECMakeSettings, which includes CTest and locks
# BUILD_TESTING into the cache as ON.
option(BUILD_TESTING "Build the test suite" OFF)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)

# Makes the Qt6 string-literal rule a compile error rather than a convention:
# no implicit const char* to QString.
add_compile_definitions(QT_NO_CAST_FROM_ASCII)

include(KDEClangFormat)
file(GLOB_RECURSE LAMBENT_CLANG_FORMAT_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/cli/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/cli/*.h
    ${CMAKE_CURRENT_SOURCE_DIR}/tests/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/tests/*.h
)
kde_clang_format(${LAMBENT_CLANG_FORMAT_FILES})

# The shell draws its icons through Kirigami and has no Qt-only fallback.
# KConfig and KCoreAddons for the desktop-style controller (kwinrc, and the
# installed window decoration plugin's metadata).
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS Kirigami Config CoreAddons)

# The Qt lookups every library and the shell share, at this scope before the
# libraries are added: an IMPORTED target belongs to the directory that found
# it, so targets found inside a library subproject (Qt's private modules, XKB
# through GuiPrivate) would be invisible here, and Qt's QML plugin dependency
# walk warns for each one.
find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Concurrent
    Core
    DBus
    Gui
    Qml
    Quick
    QuickControls2
    ShaderTools
    Svg
    WaylandClient
    Widgets
)
if(QT_KNOWN_POLICY_QTP0001)
    qt_policy(SET QTP0001 NEW)
endif()
if(QT_KNOWN_POLICY_QTP0004)
    qt_policy(SET QTP0004 NEW)
endif()
foreach(_lambent_private GuiPrivate ShaderToolsPrivate QuickPrivate WaylandClientPrivate)
    if(NOT TARGET Qt6::${_lambent_private})
        find_package(Qt6${_lambent_private} CONFIG REQUIRED)
    endif()
endforeach()

# ═══════════════════════════════════════════════════════════════════════════════
# The Phosphor libraries
# ═══════════════════════════════════════════════════════════════════════════════

include(cmake/LambentDependencies.cmake)
lambent_add_phosphor_libraries()

# Lambent's version and application ID, for main.cpp.
configure_file(src/version.h.in "${PROJECT_BINARY_DIR}/generated/version.h" @ONLY)
include_directories("${PROJECT_BINARY_DIR}/generated")

# ═══════════════════════════════════════════════════════════════════════════════
# The shell
# ═══════════════════════════════════════════════════════════════════════════════

add_subdirectory(cli/phosphorctl)       # phosphorctl call / list / schema / subscribe

# Build the bundled example shell as a Qt QML module so qmlcachegen
# and qmlsc run at build time. The resulting static module gets linked
# into the lambent binary below so the
# executable has a working default that doesn't depend on filesystem
# install (qrc fallback in ShellLoader::resolve()).
add_subdirectory(shell)

# Install the example shell QML/shaders so users can copy
# them into their config dir and edit. Same source as the qrc above.
# The qrc is the build-time frozen copy used as final fallback. This
# install is the user-editable copy. ShellLoader::resolve() probes
# GenericConfigLocation (~/.config), then GenericDataLocation (this
# install), then qrc:/ (linked-in fallback) in that order.
install(DIRECTORY shell/
    DESTINATION ${KDE_INSTALL_DATADIR}/lambent
    FILES_MATCHING
        PATTERN "*.qml"
        PATTERN "*.frag"
        PATTERN "*.glsl"
)

add_executable(lambent
    src/main.cpp
    # The bar's IBarWidgetFactory registry owner + the generic
    # QML-component factory. First production owner of a UI-seam
    # registry; the Phosphor.Bar QML module stays registry-agnostic
    # (Phase 4.1).
    src/BarController.h
    src/barcontroller.cpp
    src/LayerPopoutTransport.h
    src/layerpopouttransport.cpp
    src/QmlComponentBarWidgetFactory.h
    src/qmlcomponentbarwidgetfactory.cpp
    src/DesktopStyleController.h
    src/desktopstylecontroller.cpp
    src/AirplaneController.h
    src/airplanecontroller.cpp
    src/ColorModeController.h
    src/colormodecontroller.cpp
    src/QuickSettingsController.h
    src/quicksettingscontroller.cpp
    src/StatusIconsController.h
    src/StatusIconsSource.h
    src/statusiconscontroller.cpp
    src/statusiconsservices.cpp
    src/ControlCenterController.h
    src/controlcentercontroller.cpp
    src/QmlComponentTileFactory.h
    src/qmlcomponenttilefactory.cpp
    # The popout transport stack: one router in front of the layer
    # transport and the bar-socket transport, so PopoutController
    # arbitrates both presentation paths.
    src/RoutingPopoutTransport.h
    src/routingpopouttransport.cpp
    src/SocketPopoutTransport.h
    src/socketpopouttransport.cpp
    # The engine-placed pane (A2 §4): a real toplevel the daemon
    # places, with the bar-socket transport as its floating fallback;
    # the bundled window rule that names its placement; and the
    # compositor blur request behind the bar's band.
    src/PanePopoutTransport.h
    src/panepopouttransport.cpp
    src/PaneRules.h
    src/panerules.cpp
    src/ShellEffects.h
    src/shelleffects.cpp
    src/ShellMotion.h
    src/shellmotion.cpp
    src/ShellGestures.h
    src/shellgestures.cpp
    src/ShellChrome.h
    src/shellchrome.cpp
    # The launcher's registry owner: built-in providers, the model the
    # launcher popout binds, and the clipboard + Toplevels services the
    # providers read that nothing else in the shell owns yet.
    src/LauncherController.h
    src/launchercontroller.cpp
    # The OSD registry owner + its generic QML-component factory, and
    # the toast broker: the per-screen OSDHost / ToastHost surfaces in
    # shell.qml read them as the OsdRegistry / ToastRegistry context
    # properties, and the `osd` / `notify` IpcTargets fan out through
    # them.
    src/OsdController.h
    src/osdcontroller.cpp
    src/QmlComponentOSDFactory.h
    src/qmlcomponentosdfactory.cpp
    src/ToastController.h
    src/toastcontroller.cpp
    # The notification centre: the org.freedesktop.Notifications server
    # this process owns, plus the retained list the bar's notification
    # panel reads as the NotificationRegistry context property. The
    # server's own model tracks only LIVE notifications, so the centre
    # keeps its own snapshots (see the header).
    src/NotificationController.h
    src/notificationcontroller.cpp
    # The PolicyKit agent owner (registers the shell as the session's
    # agent, starts each PAM conversation, carries the requester's pid
    # and the prompt's placement) and the picker strip's open state:
    # the PolkitRegistry / PickerRegistry context properties.
    src/PolkitController.h
    src/polkitcontroller.cpp
    src/PickerController.h
    src/pickercontroller.cpp
)

target_link_libraries(lambent
    PRIVATE
        Qt6::QuickControls2
        KF6::ConfigCore
        PhosphorControl::PhosphorControl
        PhosphorShell::PhosphorShell
        # KPluginMetaData, for DesktopStyleController's probe of the
        # installed window decoration plugin.
        KF6::CoreAddons
        # Registry core (Registry<IBarWidgetFactory> + RegistryNotifier)
        # for BarController, and the Phosphor.Bar QML module + its plugin
        # registrar so the bar delegates resolve at runtime.
        PhosphorRegistry::PhosphorRegistry
        PhosphorShellBar::PhosphorShellBarQml
        PhosphorShellBarQmlplugin
        PhosphorShellPower::PhosphorShellPowerQml
        PhosphorShellPowerQmlplugin
        # Phosphor.ControlCenter + its registrar, so shell.qml's
        # control-center popout resolves the surface and its tiles.
        # The tiles import Phosphor.Service.* modules, which the
        # registerQmlTypes() block in shell/main.cpp already publishes.
        PhosphorShellControlCenter::PhosphorShellControlCenterQml
        PhosphorShellControlCenterQmlplugin
        # The launcher: its core (LauncherModel + the built-in providers
        # LauncherController materialises), the Phosphor.Launcher module
        # + registrar for shell.qml's launcher popout. The clipboard
        # service the controller owns for the clipboard provider is
        # already listed with the other services below.
        PhosphorShellLauncher::PhosphorShellLauncher
        PhosphorShellLauncher::PhosphorShellLauncherQml
        PhosphorShellLauncherQmlplugin
        # Phosphor.OSD and Phosphor.Notifications + their registrars,
        # for the per-screen OSD and toast overlays shell.qml mounts.
        PhosphorShellOsd::PhosphorShellOsdQml
        PhosphorShellOsdQmlplugin
        PhosphorShellNotifications::PhosphorShellNotificationsQml
        PhosphorShellNotificationsQmlplugin
        # Phosphor.Dashboard + its registrar: the dashboard and the
        # cheatsheet popouts shell.qml opens, and the ShortcutCatalog
        # the sheet reads its chords through.
        PhosphorShellDashboard::PhosphorShellDashboardQml
        PhosphorShellDashboardQmlplugin
        # Phosphor.Lock + its registrar, for the per-screen lock
        # surfaces shell.qml mounts (LockSurface windows + LockScreen).
        PhosphorShellLock::PhosphorShellLockQml
        PhosphorShellLockQmlplugin
        # Phosphor.Picker (the wallpaper and theme strip, whose C++
        # types ride in the module) and Phosphor.Polkit (the prompt)
        # + their registrars, for the per-screen strips and the polkit
        # popout shell.qml mounts. The picker's committed palette is
        # loaded at startup through PaletteStore (see main.cpp).
        PhosphorShellPicker::PhosphorShellPickerQml
        PhosphorShellPickerQmlplugin
        # ShellGestures subscribes to the daemon's gestureReported relay
        # by the protocol's interface constants.
        PhosphorProtocol::PhosphorProtocol
        # ShellChrome: the decoration tree + pack registry (PhosphorSurface), the
        # preset store it flattens through (PhosphorShaders — declared rather than
        # taken transitively, because ShellChrome.h includes ShaderPresetStore.h and
        # holds one by unique_ptr), and the org.phosphor.surface module: the
        # SurfaceDecoration.qml host that draws a pack chain on the chrome and
        # the SurfaceShaderItem stages it runs.
        PhosphorShaders::PhosphorShaders
        PhosphorSurface::PhosphorSurface
        PhosphorSurfaceQuick::PhosphorSurfaceQuickQml
        PhosphorSurfaceQuickQmlplugin
        # ShellMotion owns the profile registry behind SettleAnimation
        # and publishes the QML-side motion defaults.
        PhosphorAnimation::PhosphorAnimation
        PhosphorAnimation::PhosphorAnimationQml
        PhosphorAnimationQmlplugin
        PhosphorShellPolkit::PhosphorShellPolkitQml
        PhosphorShellPolkitQmlplugin
        PhosphorTheme::PhosphorTheme
        # IpcRouter + the Phosphor.Ipc module that publishes IpcTarget.
        # The router has to be installed on each engine (see main.cpp)
        # or every IpcTarget logs a warning and stays inert.
        PhosphorIpc::PhosphorIpc
        PhosphorIpc::PhosphorIpcQml
        PhosphorIpcQmlplugin
        # Popout policy + the QML host it drives. Static QML modules ship
        # both a library and a plugin registrar; the registrar is what
        # publishes the module to a QQmlEngine, so without it the
        # transport's PopoutHost.qml load would fail at runtime.
        PhosphorPopout::PhosphorPopout
        PhosphorPopout::PhosphorPopoutQml
        PhosphorPopoutQmlplugin
        PhosphorServiceIconTheme::PhosphorServiceIconTheme
        PhosphorServiceSni::PhosphorServiceSni
        PhosphorServiceUPower::PhosphorServiceUPower
        PhosphorServiceMpris::PhosphorServiceMpris
        PhosphorServicePipeWire::PhosphorServicePipeWire
        PhosphorServiceNetwork::PhosphorServiceNetwork
        PhosphorServiceBluetooth::PhosphorServiceBluetooth
        PhosphorServiceBrightness::PhosphorServiceBrightness
        PhosphorServiceNotifications::PhosphorServiceNotifications
        PhosphorServicePolkit::PhosphorServicePolkit
        PhosphorServiceIdle::PhosphorServiceIdle
        PhosphorServiceClipboard::PhosphorServiceClipboard
        PhosphorServiceLock::PhosphorServiceLock
        PhosphorServiceSession::PhosphorServiceSession
        PhosphorLayer::PhosphorLayer
        PhosphorWayland::PhosphorWayland
        # Linked from shell/ (the bundled shell QML module): bakes the default shell.qml
        # tree into the binary as a qt-qml-module resource. Two effects:
        # (1) qmlcachegen / qmlsc run at build time (faster cold start,
        # typed bindings compile to C++); (2) when no user config exists
        # under XDG paths, ShellLoader falls back to qrc:/qt/qml/...
        # so the binary works without the optional DATADIR install.
        phosphor_shell_exampleplugin
        # The pane rule is built with the rules library's own types
        # and seeded over org.phosphor_works.Placement.Rules.
        PhosphorRules::PhosphorRules
        PhosphorProtocol::PhosphorProtocol
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::Qml
        Qt6::DBus
)

# Compositor blur behind the bar's band goes through the kde-blur
# Wayland protocol, which KWindowEffects speaks. Optional: without it
# the band is a plain navy tint and ShellEffects.blurAvailable() says
# so, rather than the whole shell tier failing to configure.
find_package(KF6WindowSystem QUIET)
if(KF6WindowSystem_FOUND)
    target_link_libraries(lambent PRIVATE KF6::WindowSystem)
    target_compile_definitions(lambent PRIVATE PHOSPHOR_SHELL_HAVE_KWINDOWSYSTEM)
else()
    message(STATUS "KF6WindowSystem not found: the Phosphor bar band gets no compositor blur")
endif()

install(TARGETS lambent DESTINATION ${KDE_INSTALL_BINDIR})

# Desktop integration, under the application ID org.phosphor_works.Lambent:
# the .desktop file and AppStream metadata, and the systemd user unit a session
# starts the shell through.
configure_file(data/org.phosphor_works.Lambent.desktop.in
               "${PROJECT_BINARY_DIR}/org.phosphor_works.Lambent.desktop" @ONLY)
install(FILES "${PROJECT_BINARY_DIR}/org.phosphor_works.Lambent.desktop" DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES data/org.phosphor_works.Lambent.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
if(NOT DEFINED KDE_INSTALL_SYSTEMDUSERUNITDIR)
    set(KDE_INSTALL_SYSTEMDUSERUNITDIR "${KDE_INSTALL_LIBDIR}/systemd/user")
endif()
configure_file(data/lambent.service.in "${PROJECT_BINARY_DIR}/lambent.service" @ONLY)
install(FILES "${PROJECT_BINARY_DIR}/lambent.service" DESTINATION ${KDE_INSTALL_SYSTEMDUSERUNITDIR})

# The icon, from the pinned branding release (cmake/LambentDependencies.cmake),
# installed under the application ID.
lambent_fetch_dependency(branding)
include(${branding_SOURCE_DIR}/cmake/PhosphorBranding.cmake)
phosphor_install_brand_icons(org.phosphor_works.Lambent lambent)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

# ═══════════════════════════════════════════════════════════════════════════════
# Finish
# ═══════════════════════════════════════════════════════════════════════════════

if(BUILD_TESTING AND ENABLE_PCH)
    include(PhosphorTestPch)
    phosphor_share_test_pch()
endif()

feature_summary(WHAT REQUIRED_PACKAGES_FOUND REQUIRED_PACKAGES_NOT_FOUND
                     OPTIONAL_PACKAGES_FOUND OPTIONAL_PACKAGES_NOT_FOUND
                FATAL_ON_MISSING_REQUIRED_PACKAGES)
