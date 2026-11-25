<!-- SPDX-FileCopyrightText: 2026 Phosphor Works Team -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Architecture

This page tells which modules make the shell, which surface each module draws, and how the data moves between them.
Read it before you change a controller in `lambent/src/`, the composition root `lambent/shell/shell.qml`, or the
libraries that Lambent builds on.

## Layers

The libraries are LGPL and own no policy. The shell process and its composition root are GPL and own all of it.

| Layer | Where | What it holds |
| --- | --- | --- |
| Libraries | [phosphor-libs](https://github.com/phosphor-works/phosphor-libs) and [phosphor-shell-libs](https://github.com/phosphor-works/phosphor-shell-libs) | The QML modules of the surfaces, the theme, the popout arbitration and the `phosphor-service-*` services |
| Shell process | `lambent/src/` | `main.cpp` (the composition: registries, transports, context properties) and the controllers |
| Composition root | `lambent/shell/shell.qml` | Every surface, mounted for each screen |

## Libraries

| Library | Module or contents |
| --- | --- |
| `phosphor-theme` | `Phosphor.Theme`: `Theme`, `Tokens`, `Motion`, `StateLayer`, `Spectrum`, `Appearance`, and the C++ `PaletteStore`, `AppearanceStore`, `FontFaces`, `MatugenRunner`, `TemplateEngine` |
| `phosphor-shell-widgets` | `Phosphor.Widgets`: `SpectrumRail`, `SpectrumStroke`, `SpectrumUnderline`, `TabularText`, `PlacementMiniature` (with `MiniatureEdges.js`), `SettleAnimation`, `DecorationSlot`, `ShellSurface`, `ShellButton`, `WorkspaceNavigator`, `MediaCard`, `SpectrumVisualizer` |
| `phosphor-shell` | `Phosphor.Shell`: `ShellEngine`, `PanelWindow`, `FloatingWindow`, `PerScreenPanels`, `PlacementMap` (the D-Bus model of the placement engines), `Toplevels`, `Workspaces`, `WallpaperService`, `SystemStats` |
| `phosphor-shell-bar` | `Phosphor.Bar`: `BarHost`, `BarRegion`, `Slot`, `MapPane`, `PaneTether`, `CalendarPanel`, the connection and audio panels, `BatteryPanel`, `Stats/*`, `Status/*`, `Tray/*`, `Widgets/*` |
| `phosphor-shell-control-center` | `Phosphor.ControlCenter`: `ControlCenter`, `Tile`, `SliderTile` and the tiles |
| `phosphor-shell-launcher` | `Phosphor.Launcher` and `PhosphorShellLauncher` (the providers and `FuzzyMatcher`, a port of the fzf matcher) |
| `phosphor-shell-osd` | `Phosphor.OSD`: `OSDHost`, `OSDCard`, `VolumeOSD`, `BrightnessOSD`, `MicOSD`, `CapsLockOSD` |
| `phosphor-shell-notifications` | `Phosphor.Notifications`: `ToastHost`, `Toast`, `NotificationCenter` |
| `phosphor-shell-power` | `Phosphor.Power`: `PowerMenu`, the word column |
| `phosphor-shell-lock` | `Phosphor.Lock`: `LockScreen`, `LockController`, `LockCard`, `LockBackdrop`, `LockClock`, `LockAuthField`, `LockMedia`, `LockPowerMenu` |
| `phosphor-shell-dashboard` | `Phosphor.Dashboard`: `StageOverview`, `Dashboard`, `Cheatsheet`, `FullMap` |
| `phosphor-shell-picker` | `Phosphor.Picker`: `AppearanceWorkspace`, `AppearanceLibrary`, `WallpaperSurface`, `WallpaperCandidates`, `RetintController`, `ThemePresets`, and the older `Picker` strip |
| `phosphor-shell-polkit` | `Phosphor.Polkit`: `PolkitSurface`, `PolkitPrompt`, `PolkitPasswordField`, `PolkitDim` |
| `phosphor-popout` | `PopoutController` and the `IPopoutTransport` interface, and `Phosphor.Popout`: `PopoutHost`, `PaneHost` |
| `phosphor-shell-patterns` | The layer roles: `Wallpaper`, `Hud`, `Modal`, `Floating`, `Panel(edge)` and `Toast(corner)` |
| `phosphor-layer`, `phosphor-surfaces`, `phosphor-wayland` | The layer-shell and session-lock surfaces, and the QPA plugin |
| `phosphor-ipc`, `phosphor-registry` | `IpcTarget` and `phosphorctl`, and the typed factory registries |
| `phosphor-service-*` | `sni`, `upower`, `mpris`, `pipewire`, `network`, `bluetooth`, `brightness`, `notifications`, `polkit`, `idle`, `clipboard`, `lock`, `session`, `icontheme`, `nightlight` |

## Shell process

| Class | Job |
| --- | --- |
| `BarController` | Owns the `IBarWidgetFactory` registry. Tells the bar which widget has its panel open. |
| `ControlCenterController` | Owns the tile registry and the open state of the control center for each screen |
| `QuickSettingsController` | The night light (phosphor-service-nightlight) and the power profile (power-profiles-daemon) |
| `AirplaneController` | Turns the Wi-Fi and WWAN radios (NetworkManager) and Bluetooth (BlueZ) off and on. It never turns off global networking, so wired connections stay available. |
| `ColorModeController` | Dark mode: the color preference of the settings portal and the remembered dark material in `AppearanceStore` |
| `NotificationController` | The notification history: retained, bounded snapshots with read state, groups, replies, actions and Do not disturb |
| `StatusIconsController` | The configurable status-icon group of the bar. It reads the services through a `StatusIconsSource`, which tests replace with a fake. |
| `LauncherController` | Owns the provider registry and the result model |
| `OsdController`, `ToastController` | Send a show request to the OSD host or the toast host on the correct screen |
| `PolkitController`, `PickerController` | The authentication prompt, and the Appearance workspace with its navigation state |
| `LayerPopoutTransport` | Gives each popout a layer-shell surface of its own |
| `SocketPopoutTransport` | Paints the control center into the bar, with no surface of its own |
| `PanePopoutTransport` | Opens a popout as an engine-placed pane: an xdg toplevel that the placement engine positions |
| `RoutingPopoutTransport` | One transport in front of the others, so that one `PopoutController` arbitrates every popout. It routes by popout id. |
| `PaneRules` | Seeds the window rule of the pane into the placement host over `org.phosphor_works.Placement.Rules` |
| `ShellEffects` | Asks the compositor for blur behind a region (ext-background-effect-v1) |
| `ShellMotion` | Owns the profile registry (`shell.settle`) and reads reduced motion from the settings portal |
| `ShellChrome` | Turns the decoration tree and the pack registry into the stage lists for `DecorationSlot` |

## Surfaces

| Surface | Module | Behavior |
| --- | --- | --- |
| Floating bar and placement miniature | `Phosphor.Bar` | The placement map of each output, a workspace caption, saved widget groups and bounded overflow |
| Navigator | `Phosphor.Bar.MapPane`, `Phosphor.Widgets.WorkspaceNavigator` | An anchored preview and the full window list, with keyboard activation |
| Stage | `Phosphor.Dashboard.StageOverview` | Workspace maps, a desktop preview from the placement map, a window inspector and a bounded filmstrip |
| Quick settings | `Phosphor.ControlCenter`, the detail panels of `Phosphor.Bar` | A compact panel anchored to the status area in both presentations. It has pages for Wi-Fi, Bluetooth, Output, Input, Apps, Night light, Dark mode, Airplane mode, Power profiles, Wallpaper and Battery. |
| Status icons | `Phosphor.Bar.Status`, `StatusIconsController` | A group of nine icons. Each icon has an order, a policy (Always, When active or Hidden) and its own context menu. The group has a visible limit, overflow and a battery percentage. |
| Calendar | `Phosphor.Bar.CalendarPanel` | Local time and date, month navigation, Today, and day selection with the keyboard |
| Appearance | `Phosphor.Picker.AppearanceWorkspace` | Wallpaper, Style, Bar and Presets pages, a preview for each display, atomic Apply, Revert, import and export |
| Media card | `Phosphor.Widgets.MediaCard` | The MPRIS state and artwork, and a CAVA visualization (Ribbon, Bars or Halo) |
| Launcher | `Phosphor.Launcher` | Search, provider filters, readable results and keyboard actions |
| OSD edge bands and readouts | `Phosphor.OSD` | Value feedback, placed from the placement map of the focused window |
| Toasts and notification history | `Phosphor.Notifications`, `Phosphor.Bar.NotificationPanel` | Rich arrivals, a grouped history, an unread filter, replies, actions, Do not disturb, and clear with undo |
| System stats | The `Stats` components of `Phosphor.Bar`, `Phosphor.Shell.SystemStats` | Live system metrics, history charts and configurable bar readouts |
| System tray | The `Tray` components of `Phosphor.Bar`, `Phosphor.Service.Sni` | Configurable SNI application icons, an overflow drawer and the native application menus. It is not the status-icon group. |
| Battery | `Phosphor.Bar.BatteryPanel`, `Phosphor.Service.UPower` | Charge, the charging, full and low states, time estimates, health, energy, draw and device readouts. It tells a service failure from a system with no battery, links to the power profiles and offers Power saver where the system has it. |
| Power menu | `Phosphor.Power` | The session actions, with their availability and confirmation |
| Session lock | `Phosphor.Lock` | The lock surface of the shell and PAM authentication |
| Shortcut reference | `Phosphor.Dashboard.Cheatsheet` | The effective bindings with search, mode guides, alternative chords, and the states of services and capabilities |
| Authentication prompt | `Phosphor.Polkit` | A modal with account selection, request details, bounded retries and the keyboard state |
| Wallpaper and theme picker library | `Phosphor.Picker.Picker` | The older strip, kept for library consumers. The bundled shell opens Appearance. |
| Wallpaper surface | `Phosphor.Picker.WallpaperSurface` | The wallpaper on the background layer |

## Services

The `phosphor-service-*` libraries supply the data that the surfaces bind.

| Service | Source |
| --- | --- |
| SNI tray | StatusNotifierItem |
| UPower | UPower |
| MPRIS | MPRIS players |
| PipeWire | PipeWire |
| Network | NetworkManager |
| Bluetooth | BlueZ |
| Brightness | Backlight and DDC/CI |
| Notifications | The notification server |
| Polkit | The polkit agent |
| Idle | The idle stages and the idle inhibitor (the Wayland idle protocols) |
| Clipboard | The clipboard history (wlr-data-control) |
| Icon theme | The icon theme |
| Lock | PAM |
| Session | logind |
| Night light | wlr-gamma-control |

The night light is phosphor-service-nightlight. It warms the outputs through wlr-gamma-control on each compositor
that has that protocol. `QuickSettingsController` keeps its settings in
`~/.config/phosphor-works/lambent/nightlight.json`. Dark mode follows the color preference of the settings portal. The
power profiles come from power-profiles-daemon.

Airplane mode turns off Wi-Fi and WWAN through NetworkManager and Bluetooth through BlueZ, and it can restore the
radios to their earlier state. Dark mode keeps the palette, the wallpaper and the remembered dark material in
`AppearanceStore`. A change of dark mode joins an open Appearance preview. The Wallpaper page of quick settings opens
the Wallpaper or Style page of Appearance. `StatusIconsController` uses the same service hosts as the detail panels,
and the one PipeWire host of the process.

## Placement state

The placement host is the process that provides the `org.phosphor_works.Placement` D-Bus API. The daemon of
[PlasmaZones](https://github.com/phosphor-works/PlasmaZones) is one placement host. The shell reads these interfaces:

| Interface | What the shell uses it for |
| --- | --- |
| `WindowTracking` | Windows, focus, metadata, urgency and the window states of each desktop |
| `Tiling` | The current tiles |
| `Scrolling` | The strip model and the view |
| `LayoutRegistry` | The layout assignments |
| `Control` | The shortcuts, for the shortcut reference (`ShortcutCatalog`) |
| `Settings` | The decoration tree of the chrome |
| `WindowDrag` | The drop proxies |
| `Rules` | The window rule of the pane (`PaneRules`) |

`PlacementMap` in `phosphor-shell` puts these into one model for each screen (`PlacementMap.forScreen(name)`). The
bar miniature, Navigator, Stage, the shortcut reference, the OSD host and the toast host read it. Actions go back
through the same API (`activateWindow`, `moveColumnTo`, `switchDesktop`, the drop proxies). If no placement host
runs, the bar shows no window map and each popout opens at its anchor.

## Popouts

`PopoutController` arbitrates the transient surfaces and their exclusivity. `RoutingPopoutTransport` sends each
popout to the layer transport, except the popout ids that it routes to the pane transport. Quick settings uses the
layer transport and is anchored to its bar control in Navigator and in Stage. `PopoutHost` keeps it inside the
output and outside the reserved bar margins. Stage takes the full output.

`main.cpp` wires `PanePopoutTransport` and `PaneRules`, and seeds the rule of the control-center pane at startup.
The route set of `RoutingPopoutTransport` is empty, so no popout opens as a pane. The decision about which surfaces
become panes is [workspace#32](https://github.com/phosphor-works/workspace/issues/32).

## Stage preview

Stage draws its desktop preview from the placement map. The compositor does not transform its own windows.

## Feedback

`OsdController` (`OsdRegistry`) and `ToastController` (`ToastRegistry`) send a show request to the host on the
correct screen. The host puts the band on the edge of the focused window from the placement map. If no window has
the focus, the host puts the band on the screen edge.

## Chrome packs

When Appearance turns the surface packs on, `ShellChrome` gets the decoration tree from
`Settings.getSetting(decorationProfileTree)`, which starts with the defaults of the shell. It resolves a surface path
against the pack registry and gives the stage list to the shared `SurfaceDecoration` host. The `DecorationSlot` of a
surface makes that host. The composition root supplies the host component through
`ShellChrome.decorationComponent`, because a delegate for one screen cannot see the ids in `shell.qml`.

## Gestures and shortcuts

The compositor owns the touchpad gestures and the keyboard shortcuts. Its binds run `phosphorctl call
launcher.toggle`, `dashboard.toggle` or another IPC command. Lambent has no gesture relay of its own.

## Motion

`ShellMotion` owns the profile registry of the process and publishes it as the QML default. `SettleAnimation` (a
`PhosphorMotionAnimation` on `shell.settle`) resolves against it. `ShellMotion` reads reduced motion from the
settings portal and binds it to `Motion.reducedMotion`.

## Theme

`PickerController` opens `AppearanceWorkspace`. The `AppearanceStore` of the process holds one transaction for the
wallpaper, the palette, the fonts, the materials and the bar layout. The transaction stays through a QML reload. Apply
saves the full look. Revert and Discard restore the applied state. `Appearance` resolves the choices against the
palette, and `Spectrum` gives its stops as a coordinate. A change of geometry rebuilds the surfaces. Other appearance
changes apply live. The source watcher ignores saves of other settings files.

`PaletteStore`, `RetintController`, `MatugenRunner` and `TemplateEngine` stay as library services. The older `Picker`
strip uses them directly. The bundled shell does not use that strip.

## Rules for the code

- A surface uses the module dependencies it declares and the service models it receives. The composition root
  supplies the registries of the application and the actions that cross services. Tests bind fakes at those points.
- A delegate for one screen reads only context properties. `PerScreenPanels` and the popout transports make their
  objects in new contexts, so an id in `shell.qml` does not resolve in them.
- Each QML module lists Kirigami as a `DEPENDENCIES` entry, never as an `IMPORTS` entry. Its `Theme` attached type
  would hide ours.
- Surfaces share the appearance tokens and support Paper and Ember. A surface keeps no private copy of a palette.
  [visual-identity.md](visual-identity.md) gives the material rules.

## See also

- [visual-identity.md](visual-identity.md): the look of the shell and its appearance settings
- [`design/mockups-v3/`](design/mockups-v3/): the approved visual reference
- [workspace#31](https://github.com/phosphor-works/workspace/issues/31): verification on real hardware
