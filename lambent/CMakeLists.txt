# SPDX-FileCopyrightText: 2026 Phosphor Works Team
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The application: the lambent binary, the phosphorctl IPC CLI, the bundled
# shell QML tree, the desktop integration and the tests. Entered from the root
# CMakeLists.txt once ECM, Qt and the Phosphor libraries are set up.

# The tests compile the sources under src/ directly, and name them from here.
set(LAMBENT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

# Lambent's version and application ID, for main.cpp.
configure_file(src/version.h.in "${PROJECT_BINARY_DIR}/generated/version.h" @ONLY)
include_directories("${PROJECT_BINARY_DIR}/generated")

# ═══════════════════════════════════════════════════════════════════════════════
# The shell
# ═══════════════════════════════════════════════════════════════════════════════

add_subdirectory(cli/phosphorctl)       # phosphorctl call / list / schema / subscribe

# Build the bundled shell as the Lambent.Shell QML module so qmlcachegen
# and qmlsc run at build time. The resulting static module gets linked
# into the lambent binary below so the executable has a working default
# that doesn't depend on a filesystem install (ShellLoader's qrc fallback,
# which main.cpp names).
add_subdirectory(shell)

# Install the example shell QML/shaders so users can copy
# them into their config dir and edit. Same source as the qrc above.
# The qrc is the build-time frozen copy used as final fallback. This
# install is the user-editable copy. ShellLoader::resolve() probes
# Lambent's folder of the suite in GenericConfigLocation (~/.config), then in
# GenericDataLocation (this install), then the linked-in qrc:/ copy main.cpp
# hands it.
install(DIRECTORY shell/
    DESTINATION ${KDE_INSTALL_DATADIR}/${PHOSPHOR_SUITE_DIRECTORY_NAME}/${LAMBENT_APP_DIRECTORY_NAME}
    FILES_MATCHING
        PATTERN "*.qml"
        PATTERN "*.frag"
        PATTERN "*.glsl"
)

add_executable(lambent
    src/main.cpp
    # The bar's IBarWidgetFactory registry owner + the generic
    # QML-component factory. First production owner of a UI-seam
    # registry. The Phosphor.Bar QML module stays registry-agnostic.
    src/BarController.h
    src/barcontroller.cpp
    src/LayerPopoutTransport.h
    src/layerpopouttransport.cpp
    src/QmlComponentBarWidgetFactory.h
    src/qmlcomponentbarwidgetfactory.cpp
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
    # The engine-placed pane: a real toplevel the placement host
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
        # Lambent's folder of the suite: every config and data path.
        PhosphorPaths::PhosphorPaths
        Qt6::QuickControls2
        PhosphorControl::PhosphorControl
        PhosphorShell::PhosphorShell
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
        # registerQmlTypes() block in src/main.cpp already publishes.
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
        # The quick settings' night light (wlr-gamma-control).
        PhosphorServiceNightLight::PhosphorServiceNightLight
        PhosphorServiceClipboard::PhosphorServiceClipboard
        PhosphorServiceLock::PhosphorServiceLock
        PhosphorServiceSession::PhosphorServiceSession
        PhosphorLayer::PhosphorLayer
        # The wlr-layer-shell transport main.cpp builds (PhosphorWaylandTransport),
        # in its own target since phosphor-libs#3.
        PhosphorLayer::Wayland
        PhosphorWayland::PhosphorWayland
        # Linked from shell/ (the bundled shell QML module): bakes the default shell.qml
        # tree into the binary as a qt-qml-module resource. Two effects:
        # (1) qmlcachegen / qmlsc run at build time (faster cold start,
        # typed bindings compile to C++); (2) when no user config exists
        # under XDG paths, ShellLoader falls back to qrc:/qt/qml/Lambent/Shell
        # so the binary works without the optional DATADIR install.
        lambent_shellplugin
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

# The notification centre asks for an xdg-activation token through
# KWaylandExtras when an action opens an app, so the app may take focus.
# Optional: without it the action runs with no token.
find_package(KF6WindowSystem QUIET)
if(KF6WindowSystem_FOUND)
    target_link_libraries(lambent PRIVATE KF6::WindowSystem)
    target_compile_definitions(lambent PRIVATE PHOSPHOR_SHELL_HAVE_KWINDOWSYSTEM)
else()
    message(STATUS "KF6WindowSystem not found: notification actions open apps without an activation token")
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

# The surface decoration packs the chrome draws, from the pinned
# phosphor-surface-packs commit (cmake/LambentDependencies.cmake), fetched in
# the top-level CMakeLists ahead of the libraries. They install to
# share/phosphor-works/shaders/surface, where every app of the suite looks for them,
# so a distribution that packages phosphor-surface-packs on its own turns the
# install off here. main.cpp hands that subdir to phosphor-surface at startup.
# The tests read the packs from the source tree, PHOSPHOR_SURFACE_PACKS_DIR.
option(LAMBENT_INSTALL_SURFACE_PACKS
       "Install the surface decoration packs (off when the distribution packages phosphor-surface-packs on its own)" ON)
if(LAMBENT_INSTALL_SURFACE_PACKS)
    phosphor_install_surface_packs()
endif()
target_compile_definitions(lambent PRIVATE LAMBENT_SURFACE_PACKS_DATA_SUBDIR="${PHOSPHOR_SURFACE_PACKS_DATA_SUBDIR}")

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
