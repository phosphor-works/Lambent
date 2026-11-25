// SPDX-FileCopyrightText: 2026 Phosphor Works Team
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QObject>
#include <QRect>
#include <QVariantList>

QT_BEGIN_NAMESPACE
class QQuickItem;
QT_END_NAMESPACE

namespace PhosphorShellApp {

// Compositor-side effects the shell's surfaces ask for. Exposed to QML as
// the `ShellEffects` context property (the BarRegistry precedent).
//
// A Wayland client cannot read what is behind its own surface, so the
// phosphor-glass material (real backdrop blur under a navy tint, 05 §5)
// cannot be rendered client-side over live windows. What a client CAN do
// is ask the compositor to blur behind a region of its surface, through the
// standard ext-background-effect-v1 protocol that phosphor-wayland's
// BackgroundEffect speaks. It remembers each window's region and sends it
// again whenever the wl_surface is recreated, so one call per shape change
// suffices.
//
// The band then paints the pack's navy tint at its opacity over the
// compositor's blur, which is the glass; the pack's glow and sweep are
// off on the bar by design (A2 §3.2), so nothing of the shader is lost.
class ShellEffects : public QObject
{
    Q_OBJECT

public:
    explicit ShellEffects(QObject* parent = nullptr);

    /// Whether the compositor applies the blur now (it advertises
    /// ext-background-effect-v1 with the blur capability).
    [[nodiscard]] Q_INVOKABLE static bool blurAvailable();

    /// Request compositor blur behind `region` of the window `item` lives
    /// in (window-local logical pixels). An empty region disables it.
    /// Returns false when the item has no window yet, so a caller can retry
    /// once the window exists. The region is kept for a compositor that
    /// cannot blur and applied if it starts to.
    /// A negative secondaryRadius uses the primary radius for both regions.
    Q_INVOKABLE static bool setBlurBehind(QQuickItem* item, const QRect& region, const QRect& secondary = {},
                                          qreal radius = 0, qreal secondaryRadius = -1);

    /// Leave a visible region, such as the bar, available to the surface below.
    Q_INVOKABLE static bool setOverviewRegions(QQuickItem* item, const QRect& bar, const QRect& preview,
                                               const QVariantList& windows = {}, qreal radius = 0);
};

} // namespace PhosphorShellApp
