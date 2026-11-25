<!-- SPDX-FileCopyrightText: 2026 Phosphor Works Team -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

# Visual identity

This page tells how the shell looks, which appearance settings a user can change, and how each surface behaves.
Read it before you change a surface, a token or an appearance default. The approved visual reference is
[`design/mockups-v3/`](design/mockups-v3/). The design balances visual identity, usable controls and user
customization.

## Shared identity

The placement map is the feature that identifies the shell. It shows the real snapping zones, the tiling layout or
the scrolling viewport from the placement host. One color field of cyan, blue, violet and rose connects the map, the
material edges, the selection and the media visualization. Rounded floating surfaces, inset controls, clear
typography and quiet color washes give that field depth.

`AppearanceStore` saves the choices. `Appearance.qml`, `Tokens.qml` and `Spectrum.qml` resolve them. Surfaces use
`ShellSurface` and `ShellButton`. Semantic errors keep the theme colors of their service. Do not copy a private dark
palette into a popup. Paper must stay readable in all of the shell.

## Presentations

| Presentation | Overview | Quick settings |
| --- | --- | --- |
| Navigator | A bounded popup anchored to the workspace map. A preview and a readable window list let the user activate a window directly. | A compact vertical panel with connection rows, levels and media |
| Stage | Workspace maps on the left and a live desktop preview in the center. An inspector for the selected window is on the right, and a bounded window strip is below. | The same compact panel, anchored to the status area |

The workspace overview does not set the popup geometry. In both presentations, quick settings opens next to the
status area of the bar, and the launcher opens near the top center. Custom composers can still use wide content
layouts.

Stage shows a preview of the desktop from the placement map. The QML surface stays full-screen, so its hit areas
match its preview. Selection and activation are different actions. The arrow keys select a window, and Enter opens
it.

The bar stays compact with four, ten or twenty scrolling windows. Its miniature shows a viewport and capped markers
with counts for the windows off the screen. Navigator and Stage use cards of a fixed width and scroll the list. They
do not make the cards smaller or the bar wider. Minimized windows, inactive tabs and columns off the screen stay in
the full navigation model.

## Materials and customization

| Preset | Palette | Material | Density | Bar edge | Corner radius | Gap | Glow |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Phosphor | Spectrum | Glass (dark) | Comfortable | Top | 18 px | 16 px | On |
| Paper | Wallpaper | Light | Comfortable | Top | 24 px | 22 px | Off |
| Ember | Ember (warm) | Solid | Compact | Bottom | 8 px | 10 px | Off |

The Ember preset also turns the media widget off.

| Setting | Range |
| --- | --- |
| Corner radius | 4 px to 30 px |
| Gap | 6 px to 30 px |
| Bar inset | 6 px to 30 px (16 px by default) |

Each setting in the presets can change by itself, as can the bar inset, the animations and the custom surface
packs. A preset keeps the presentation, the bar layout,
the fonts, the motion, the visualizer, the wallpapers, and the tray and status-icon choices of the user. Surface packs
are off until the user turns them on. The usual shared surfaces give the default look.

The Appearance workspace has the Wallpaper, Style, Bar and Presets pages. The user chooses a wallpaper for each
display. The previews, the colors and the bar layout share one transaction, with Apply, Revert and a prompt for
unsaved changes on close. The user can move a widget between the left, center and right regions, reorder it, hide it
and show it again. Each of the three bar regions has a maximum width and overflow controls. If the bar is narrower
than 1100 px, the bar hides the focused-app and media labels. Their panel functions stay available through commands.
Preset JSON keeps the groups and the IDs of extension widgets. Validation refuses duplicates and malformed values.

The user can set the interface font family and the number font family separately. An empty value uses `FontFaces`:
Manrope and JetBrains Mono when they are installed, and named fallbacks when they are not. Lambent does not bundle
font files.

The settings are in `~/.config/phosphor-works/lambent/appearance.json`, as a versioned JSON object that contains
`settings`. Apply, import and export validate the full document before they replace the current appearance. Apply
writes the file atomically. Colors, fonts and widget moves update live. A change of bar geometry rebuilds the shell
surfaces. The source watcher ignores writes to other settings files, and it still sees an atomic replacement of
`shell.qml`.

## Surface behavior

- Wi-Fi and Bluetooth rows have one continuous background, with an inset divider before their details button.
  Labels and trailing actions have the same geometry in each material.
- Media cards use the real MPRIS metadata, artwork and player capabilities. Ribbon, Bars and Halo use one shared
  CAVA spectrum. Off turns the visualization off. No decorative sample takes the place of stopped or unavailable
  audio.
- The spectrum runs only for a visible consumer that plays. Pause, a closed surface, media or visualization turned
  off, or reduced motion releases it.
- The calendar opens from the clock. It shows the local time and date, and it supports month browsing, Today, the
  arrow keys, Home, Page Up and Page Down. It shows no appointments or weather unless a service supplies them.
- The launcher rows, notifications, OSDs, the power menu, the picker, the lock screen and the authentication prompt
  share the selected text and material palette. They keep their service and permission boundaries.
- Popouts stay inside the bar inset and the available output size. Long settings panels scroll, and they bring a
  control that has the keyboard focus into view.

## See also

- [architecture.md](architecture.md): the modules, the controllers and the data flow
- [`design/mockups-v3/`](design/mockups-v3/): the approved visual reference
- [workspace#35](https://github.com/phosphor-works/workspace/issues/35): how the suite ships Manrope and JetBrains
  Mono
