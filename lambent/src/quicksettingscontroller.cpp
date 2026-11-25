// SPDX-FileCopyrightText: 2026 Phosphor Works Team
// SPDX-License-Identifier: GPL-3.0-or-later
#include "QuickSettingsController.h"
#include "PhosphorShellI18n.h"

#include <PhosphorPaths/SuiteDirectories.h>
#include <PhosphorServiceNightLight/NightLight.h>

#include <QDBusArgument>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QTime>

#include <utility>

namespace PhosphorShellApp {
using PhosphorServiceNightLight::NightLight;
namespace {
const QString power = QStringLiteral("org.freedesktop.UPower.PowerProfiles");
const QString powerPath = QStringLiteral("/org/freedesktop/UPower/PowerProfiles");
const QString propertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");
const QString timeFormat = QStringLiteral("HH:mm");
QDBusMessage getAll(const QString& service, const QString& path, const QString& interface)
{
    auto message = QDBusMessage::createMethodCall(service, path, propertiesInterface, QStringLiteral("GetAll"));
    message << interface;
    return message;
}
QStringList profileIds(const QVariant& value)
{
    QList<QVariantMap> rows;
    if (value.metaType() == QMetaType::fromType<QDBusArgument>())
        rows = qdbus_cast<QList<QVariantMap>>(value.value<QDBusArgument>());
    else
        for (const auto& item : value.toList())
            rows.append(item.toMap());
    QStringList result;
    for (const auto& row : rows) {
        const auto id = row.value(QLatin1String("Profile")).toString();
        if ((id == QLatin1String("power-saver") || id == QLatin1String("balanced")
             || id == QLatin1String("performance"))
            && !result.contains(id))
            result.append(id);
    }
    return result;
}
QString scheduleName(NightLight::Mode mode)
{
    switch (mode) {
    case NightLight::Mode::Constant:
        return QStringLiteral("manual");
    case NightLight::Mode::Hours:
        return QStringLiteral("custom");
    case NightLight::Mode::Location:
        return QStringLiteral("automatic");
    }
    return {};
}
std::optional<NightLight::Mode> scheduleMode(const QString& name)
{
    if (name == QLatin1String("manual"))
        return NightLight::Mode::Constant;
    if (name == QLatin1String("custom"))
        return NightLight::Mode::Hours;
    if (name == QLatin1String("automatic"))
        return NightLight::Mode::Location;
    return std::nullopt;
}
}
QuickSettingsController::QuickSettingsController(QObject* parent)
    : QuickSettingsController(QDBusConnection::systemBus(), std::make_unique<NightLight>(),
                              PhosphorPaths::appConfigDir() + QStringLiteral("/nightlight.json"), parent)
{
}
QuickSettingsController::QuickSettingsController(QDBusConnection system, std::unique_ptr<NightLight> nightLight,
                                                 QString nightLightConfig, QObject* parent)
    : QObject(parent)
    , m_system(std::move(system))
    , m_nightLight(std::move(nightLight))
    , m_nightConfig(std::move(nightLightConfig))
{
    loadNightConfig();
    // The library emits each signal only when its value changed.
    for (const auto signal : {&NightLight::availableChanged, &NightLight::enabledChanged, &NightLight::modeChanged,
                              &NightLight::nightTemperatureChanged, &NightLight::hoursChanged,
                              &NightLight::locationChanged, &NightLight::activeChanged})
        connect(m_nightLight.get(), signal, this, &QuickSettingsController::changed);
    // An inhibition taken "until the next transition" ends by itself there.
    connect(m_nightLight.get(), &NightLight::inhibitedChanged, this, [this] {
        if (!m_nightLight->isInhibited())
            m_cookie.reset();
        Q_EMIT changed();
    });
    auto* profiles = new QDBusServiceWatcher(power, m_system, QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(profiles, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] {
        const bool hadState = m_powerPending || m_power != PowerState{};
        ++m_powerEpoch;
        m_powerPending = false;
        m_power = {};
        if (hadState)
            Q_EMIT changed();
        refreshPower();
    });
    m_system.connect(power, powerPath, propertiesInterface, QStringLiteral("PropertiesChanged"), this,
                     SLOT(propertiesChanged(QString, QVariantMap, QStringList)));
    refreshPower();
}
QuickSettingsController::~QuickSettingsController() = default;
bool QuickSettingsController::nightLightAvailable() const
{
    return m_nightLight->isAvailable();
}
bool QuickSettingsController::nightLightEnabled() const
{
    return m_nightLight->isEnabled();
}
bool QuickSettingsController::nightLightRunning() const
{
    return m_nightLight->isActive();
}
bool QuickSettingsController::nightLightInhibited() const
{
    return m_nightLight->isInhibited();
}
int QuickSettingsController::nightLightTemperature() const
{
    return m_nightLight->nightTemperature();
}
QString QuickSettingsController::nightLightSchedule() const
{
    return scheduleName(m_nightLight->mode());
}
QString QuickSettingsController::nightLightMorning() const
{
    return m_nightLight->morningStart().toString(timeFormat);
}
QString QuickSettingsController::nightLightEvening() const
{
    return m_nightLight->eveningStart().toString(timeFormat);
}
bool QuickSettingsController::nightLightNeedsLocation() const
{
    return m_nightLight->mode() == NightLight::Mode::Location && !m_nightLight->hasLocation();
}
void QuickSettingsController::loadNightConfig()
{
    QFile file(m_nightConfig);
    if (!file.open(QIODevice::ReadOnly))
        return;
    const auto settings = QJsonDocument::fromJson(file.readAll()).object();
    if (const auto mode = scheduleMode(settings.value(QLatin1String("schedule")).toString()))
        m_nightLight->setMode(*mode);
    if (settings.contains(QLatin1String("temperature")))
        m_nightLight->setNightTemperature(settings.value(QLatin1String("temperature")).toInt());
    const QTime evening = QTime::fromString(settings.value(QLatin1String("evening")).toString(), timeFormat);
    const QTime morning = QTime::fromString(settings.value(QLatin1String("morning")).toString(), timeFormat);
    if (evening.isValid() && morning.isValid())
        m_nightLight->setHours(evening, morning);
    if (settings.contains(QLatin1String("latitude")) && settings.contains(QLatin1String("longitude")))
        m_nightLight->setLocation(settings.value(QLatin1String("latitude")).toDouble(),
                                  settings.value(QLatin1String("longitude")).toDouble());
    m_nightLight->setEnabled(settings.value(QLatin1String("enabled")).toBool());
}
void QuickSettingsController::saveNightConfig()
{
    QJsonObject settings{{QLatin1String("enabled"), m_nightLight->isEnabled()},
                         {QLatin1String("schedule"), nightLightSchedule()},
                         {QLatin1String("temperature"), m_nightLight->nightTemperature()},
                         {QLatin1String("evening"), nightLightEvening()},
                         {QLatin1String("morning"), nightLightMorning()}};
    if (m_nightLight->hasLocation()) {
        settings.insert(QLatin1String("latitude"), m_nightLight->latitude());
        settings.insert(QLatin1String("longitude"), m_nightLight->longitude());
    }
    QSaveFile file(m_nightConfig);
    const bool saved = QDir().mkpath(QFileInfo(m_nightConfig).absolutePath()) && file.open(QIODevice::WriteOnly)
        && file.write(QJsonDocument(settings).toJson()) >= 0 && file.commit();
    setNightError(saved ? QString() : PhosphorI18n::tr("Could not save Night light settings"));
}
void QuickSettingsController::refreshPower()
{
    const auto serial = ++m_powerRead;
    const auto epoch = m_powerEpoch;
    auto* watcher = new QDBusPendingCallWatcher(m_system.asyncCall(getAll(power, powerPath, power)), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, serial, epoch] {
        const QDBusPendingReply<QVariantMap> reply = *watcher;
        watcher->deleteLater();
        if (serial != m_powerRead || epoch != m_powerEpoch)
            return;
        const auto values = reply.isError() ? QVariantMap{} : reply.value();
        const PowerState state{!reply.isError(), values.value(QLatin1String("ActiveProfile")).toString(),
                               profileIds(values.value(QLatin1String("Profiles"))),
                               values.value(QLatin1String("PerformanceDegraded")).toString()};
        if (state != m_power) {
            m_power = state;
            Q_EMIT changed();
        }
    });
}
void QuickSettingsController::propertiesChanged(const QString& interface, const QVariantMap&, const QStringList&)
{
    if (interface == power)
        refreshPower();
}
void QuickSettingsController::setNightError(const QString& error)
{
    if (error == m_nightError)
        return;
    m_nightError = error;
    Q_EMIT changed();
}
void QuickSettingsController::toggleNightLight()
{
    setNightLightEnabled(!m_nightLight->isEnabled());
}
void QuickSettingsController::setNightLightEnabled(bool enabled)
{
    if (enabled == m_nightLight->isEnabled())
        return;
    // Turning it off ends a pause: there is nothing left to hold off.
    if (!enabled && m_cookie) {
        m_nightLight->uninhibit(*std::exchange(m_cookie, std::nullopt));
        Q_EMIT changed();
    }
    m_nightLight->setEnabled(enabled);
    saveNightConfig();
}
void QuickSettingsController::setNightLightTemperature(int temperature)
{
    if (temperature < 1000 || temperature > 6500) {
        setNightError(PhosphorI18n::tr("Choose a temperature from 1000 K to 6500 K"));
        return;
    }
    if (temperature == m_nightLight->nightTemperature())
        return;
    m_nightLight->setNightTemperature(temperature);
    saveNightConfig();
}
void QuickSettingsController::setNightLightSchedule(const QString& schedule)
{
    const auto mode = scheduleMode(schedule);
    if (!mode) {
        setNightError(PhosphorI18n::tr("Choose a valid Night light schedule"));
        return;
    }
    if (*mode == m_nightLight->mode())
        return;
    m_nightLight->setMode(*mode);
    saveNightConfig();
}
void QuickSettingsController::setNightLightTimes(const QString& morning, const QString& evening)
{
    const QTime start = QTime::fromString(morning, timeFormat);
    const QTime end = QTime::fromString(evening, timeFormat);
    if (!start.isValid() || !end.isValid() || !m_nightLight->setHours(end, start)) {
        setNightError(PhosphorI18n::tr("Choose different valid start and end times"));
        return;
    }
    m_nightLight->setMode(NightLight::Mode::Hours);
    saveNightConfig();
}
void QuickSettingsController::setNightLightLocation(double latitude, double longitude)
{
    if (!m_nightLight->setLocation(latitude, longitude)) {
        setNightError(PhosphorI18n::tr("Choose a latitude from -90 to 90 and a longitude from -180 to 180"));
        return;
    }
    saveNightConfig();
}
void QuickSettingsController::toggleNightLightPause()
{
    if (m_cookie) {
        m_nightLight->uninhibit(*std::exchange(m_cookie, std::nullopt));
        Q_EMIT changed();
        return;
    }
    if (!m_nightLight->isAvailable() || !m_nightLight->isEnabled())
        return;
    // On a schedule the pause ends by itself at the next transition, the way
    // "pause until tomorrow" reads. In manual mode it lasts until resumed.
    m_cookie = m_nightLight->inhibit(m_nightLight->mode() != NightLight::Mode::Constant);
    Q_EMIT changed();
}
void QuickSettingsController::refreshNightLight()
{
    m_nightLight->refresh();
}
void QuickSettingsController::setPowerProfile(const QString& profile)
{
    if (!m_power.available || m_powerPending || profile == m_power.profile)
        return;
    if (!m_power.profiles.contains(profile)) {
        const auto error = PhosphorI18n::tr("This power profile is not available on your device");
        if (m_powerError != error) {
            m_powerError = error;
            Q_EMIT changed();
        }
        return;
    }
    m_powerPending = true;
    m_powerError.clear();
    Q_EMIT changed();
    const auto epoch = m_powerEpoch;
    auto message = QDBusMessage::createMethodCall(power, powerPath, propertiesInterface, QStringLiteral("Set"));
    message << power << QStringLiteral("ActiveProfile") << QVariant::fromValue(QDBusVariant(profile));
    auto* watcher = new QDBusPendingCallWatcher(m_system.asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, epoch] {
        const QDBusPendingReply<> reply = *watcher;
        watcher->deleteLater();
        if (epoch != m_powerEpoch)
            return;
        m_powerPending = false;
        m_powerError = reply.isError() ? PhosphorI18n::tr("Could not change the power profile") : QString();
        Q_EMIT changed();
        refreshPower();
    });
}
}
