// SPDX-FileCopyrightText: 2026 fuddlesworth
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

#include <QDBusConnection>
#include <QObject>
#include <QStringList>
#include <QVariantMap>

#include <memory>
#include <optional>

namespace PhosphorServiceNightLight {
class NightLight;
}

namespace PhosphorShellApp {

// Process-owned live controls: the night light and the power profile.
//
// The night light is phosphor-service-nightlight's NightLight, which warms the
// outputs through wlr-gamma-control on any compositor that offers it. The
// library keeps no settings, so this controller loads the user's from
// ~/.config/phosphor-works/lambent/nightlight.json, hands them over and saves what the user
// changes. The power profile is power-profiles-daemon's, read and written over
// the system bus; reads never change it.
class QuickSettingsController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool nightLightAvailable READ nightLightAvailable NOTIFY changed)
    Q_PROPERTY(bool nightLightEnabled READ nightLightEnabled NOTIFY changed)
    Q_PROPERTY(bool nightLightRunning READ nightLightRunning NOTIFY changed)
    Q_PROPERTY(bool nightLightInhibited READ nightLightInhibited NOTIFY changed)
    Q_PROPERTY(bool nightLightPaused READ nightLightPaused NOTIFY changed)
    Q_PROPERTY(bool nightLightScheduleAvailable READ nightLightScheduleAvailable CONSTANT)
    Q_PROPERTY(int nightLightTemperature READ nightLightTemperature NOTIFY changed)
    Q_PROPERTY(QString nightLightSchedule READ nightLightSchedule NOTIFY changed)
    Q_PROPERTY(QString nightLightMorning READ nightLightMorning NOTIFY changed)
    Q_PROPERTY(QString nightLightEvening READ nightLightEvening NOTIFY changed)
    Q_PROPERTY(bool nightLightPending READ nightLightPending CONSTANT)
    Q_PROPERTY(bool nightLightNeedsLocation READ nightLightNeedsLocation NOTIFY changed)
    Q_PROPERTY(QString nightLightError READ nightLightError NOTIFY changed)
    Q_PROPERTY(bool powerAvailable READ powerAvailable NOTIFY changed)
    Q_PROPERTY(QString powerProfile READ powerProfile NOTIFY changed)
    Q_PROPERTY(QStringList powerProfiles READ powerProfiles NOTIFY changed)
    Q_PROPERTY(QString performanceDegraded READ performanceDegraded NOTIFY changed)
    Q_PROPERTY(bool powerPending READ powerPending NOTIFY changed)
    Q_PROPERTY(QString powerError READ powerError NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit QuickSettingsController(QObject* parent = nullptr);
    /// @p nightLight is the night light to drive (tests give one a fake gamma
    /// backend and clock); @p nightLightConfig the JSON file its settings are
    /// loaded from and saved to.
    QuickSettingsController(QDBusConnection system, std::unique_ptr<PhosphorServiceNightLight::NightLight> nightLight,
                            QString nightLightConfig, QObject* parent = nullptr);
    ~QuickSettingsController() override;

    [[nodiscard]] bool nightLightAvailable() const;
    [[nodiscard]] bool nightLightEnabled() const;
    [[nodiscard]] bool nightLightRunning() const;
    [[nodiscard]] bool nightLightInhibited() const;
    [[nodiscard]] bool nightLightPaused() const
    {
        return m_cookie.has_value();
    }
    /// Every schedule runs in the library, so all three can always be chosen.
    /// Read by Phosphor.Bar's NightLightPanel.
    [[nodiscard]] bool nightLightScheduleAvailable() const
    {
        return true;
    }
    [[nodiscard]] int nightLightTemperature() const;
    /// "manual", "custom" or "automatic": the Constant, Hours and Location
    /// schedules.
    [[nodiscard]] QString nightLightSchedule() const;
    [[nodiscard]] QString nightLightMorning() const;
    [[nodiscard]] QString nightLightEvening() const;
    /// The library applies a change at once, so no request is ever in flight.
    /// Read by Phosphor.Bar's NightLightPanel.
    [[nodiscard]] bool nightLightPending() const
    {
        return false;
    }
    /// The automatic schedule follows sunset and sunrise, which needs a
    /// location. Without one the night light stays at day colour.
    [[nodiscard]] bool nightLightNeedsLocation() const;
    [[nodiscard]] QString nightLightError() const
    {
        return m_nightError;
    }
    [[nodiscard]] bool powerAvailable() const
    {
        return m_power.available;
    }
    [[nodiscard]] QString powerProfile() const
    {
        return m_power.profile;
    }
    [[nodiscard]] QStringList powerProfiles() const
    {
        return m_power.profiles;
    }
    [[nodiscard]] QString performanceDegraded() const
    {
        return m_power.degraded;
    }
    [[nodiscard]] bool powerPending() const
    {
        return m_powerPending;
    }
    [[nodiscard]] QString powerError() const
    {
        return m_powerError;
    }
    [[nodiscard]] QString error() const
    {
        return m_nightError;
    }
    Q_INVOKABLE void toggleNightLight();
    Q_INVOKABLE void setNightLightEnabled(bool enabled);
    Q_INVOKABLE void setNightLightTemperature(int temperature);
    Q_INVOKABLE void setNightLightSchedule(const QString& schedule);
    Q_INVOKABLE void setNightLightTimes(const QString& morning, const QString& evening);
    /// The location the automatic schedule computes sunset and sunrise for,
    /// degrees north and east.
    Q_INVOKABLE void setNightLightLocation(double latitude, double longitude);
    Q_INVOKABLE void toggleNightLightPause();
    Q_INVOKABLE void refreshNightLight();
    Q_INVOKABLE void refreshPower();
    Q_INVOKABLE void setPowerProfile(const QString& profile);
Q_SIGNALS:
    void changed();
private Q_SLOTS:
    void propertiesChanged(const QString& interface, const QVariantMap& values, const QStringList& invalidated);

private:
    struct PowerState
    {
        bool available = false;
        QString profile;
        QStringList profiles;
        QString degraded;
        bool operator==(const PowerState&) const = default;
    };
    void loadNightConfig();
    void saveNightConfig();
    void setNightError(const QString& error);
    QDBusConnection m_system;
    std::unique_ptr<PhosphorServiceNightLight::NightLight> m_nightLight;
    QString m_nightConfig;
    PowerState m_power;
    QString m_nightError;
    QString m_powerError;
    bool m_powerPending = false;
    quint64 m_powerEpoch = 0;
    quint64 m_powerRead = 0;
    std::optional<uint> m_cookie;
};
}
