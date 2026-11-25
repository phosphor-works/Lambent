// SPDX-FileCopyrightText: 2026 Phosphor Works Team
// SPDX-License-Identifier: GPL-3.0-or-later

#include "ShellEffects.h"

#include <PhosphorWayland/BackgroundEffect.h>

#include <QLoggingCategory>
#include <QPainterPath>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegion>

namespace {
Q_LOGGING_CATEGORY(lcEffects, "phosphorshell.effects")
QRegion roundedRegion(const QRect& rect, qreal radius)
{
    if (rect.isEmpty())
        return {};
    QPainterPath path;
    path.addRoundedRect(rect, radius, radius);
    return QRegion(path.toFillPolygon().toPolygon());
}
}

namespace PhosphorShellApp {

ShellEffects::ShellEffects(QObject* parent)
    : QObject(parent)
{
}

bool ShellEffects::blurAvailable()
{
    return PhosphorWayland::BackgroundEffect::instance()->isBlurSupported();
}

bool ShellEffects::setBlurBehind(QQuickItem* item, const QRect& region, const QRect& secondary, qreal radius,
                                 qreal secondaryRadius)
{
    QQuickWindow* window = item ? item->window() : nullptr;
    if (!window) {
        return false;
    }
    const bool enable = region.width() > 0 && region.height() > 0;
    PhosphorWayland::BackgroundEffect::instance()->setBlurRegion(
        window,
        enable ? roundedRegion(region, radius)
                     .united(roundedRegion(secondary, secondaryRadius < 0 ? radius : secondaryRadius))
               : QRegion());
    qCDebug(lcEffects) << (enable ? "blur behind" : "blur off for") << window->title() << region;
    return true;
}

bool ShellEffects::setOverviewRegions(QQuickItem* item, const QRect& bar, const QRect& preview,
                                      const QVariantList& windows, qreal radius)
{
    QQuickWindow* window = item ? item->window() : nullptr;
    if (!window || window->width() <= 0 || window->height() <= 0) {
        return false;
    }
    const QRegion bounds(QRect(0, 0, window->width(), window->height()));
    const auto barRegion = roundedRegion(bar, radius);
    window->setMask(bounds.subtracted(barRegion));
    QRegion apertures;
    for (const auto& rect : windows)
        apertures += roundedRegion(rect.toRectF().toAlignedRect(), radius);
    apertures &= QRegion(preview);
    PhosphorWayland::BackgroundEffect::instance()->setBlurRegion(window,
                                                                 bounds.subtracted(barRegion).subtracted(apertures));
    window->update();
    return true;
}

} // namespace PhosphorShellApp
