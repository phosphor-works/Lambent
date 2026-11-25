// SPDX-FileCopyrightText: 2026 Phosphor Works Team
// SPDX-License-Identifier: GPL-3.0-or-later
#include "QuickSettingsController.h"

#include <PhosphorServiceNightLight/ColorTemperature.h>
#include <PhosphorServiceNightLight/GammaBackend.h>
#include <PhosphorServiceNightLight/NightLight.h>

#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusVariant>
#include <QDBusVirtualObject>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QTimeZone>

#include <memory>
#include <utility>

// Named, not anonymous: the test class below holds a QuickSettingsFixture, and a member of
// internal-linkage type warns (-Wsubobject-linkage) once the unity build includes this file.
namespace QuickSettingsTestSupport {
const QString powerService = QStringLiteral("org.freedesktop.UPower.PowerProfiles");
const QString powerPath = QStringLiteral("/org/freedesktop/UPower/PowerProfiles");
const QString propertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");

// power-profiles-daemon on the test's private bus.
class QuickSettingsFixture : public QDBusVirtualObject
{
public:
    explicit QuickSettingsFixture(QDBusConnection connection)
        : bus(std::move(connection))
    {
    }

    QDBusConnection bus;
    QString activeProfile = QStringLiteral("balanced");
    QStringList profiles{QStringLiteral("power-saver"), QStringLiteral("balanced"), QStringLiteral("performance")};
    QString degradation;
    QStringList profileWrites;
    bool refusePowerWrite = false;
    bool delayPowerWrites = false;
    bool delayPowerReads = false;
    QList<QDBusMessage> heldWrites;
    QList<QDBusMessage> heldReads;
    QList<QVariantMap> heldReadValues;

    QString introspect(const QString&) const override
    {
        return {};
    }

    QVariantMap powerValues() const
    {
        QList<QVariantMap> rows;
        for (const auto& id : profiles)
            rows.append({{QStringLiteral("Profile"), id}, {QStringLiteral("Driver"), QStringLiteral("fixture")}});
        return {{QStringLiteral("ActiveProfile"), activeProfile},
                {QStringLiteral("Profiles"), QVariant::fromValue(rows)},
                {QStringLiteral("PerformanceDegraded"), degradation}};
    }

    void changed()
    {
        auto message = QDBusMessage::createSignal(powerPath, propertiesInterface, QStringLiteral("PropertiesChanged"));
        message << powerService << QVariantMap{} << QStringList{};
        bus.send(message);
    }

    void finishPowerWrite(const QDBusMessage& message, bool refuse)
    {
        if (refuse) {
            bus.send(message.createErrorReply(QStringLiteral("org.freedesktop.DBus.Error.AccessDenied"),
                                              QStringLiteral("Fixture refused the profile")));
            return;
        }
        activeProfile = qvariant_cast<QDBusVariant>(message.arguments().at(2)).variant().toString();
        bus.send(message.createReply());
        changed();
    }

    bool handleMessage(const QDBusMessage& message, const QDBusConnection&) override
    {
        if (message.path() != powerPath)
            return false;
        if (message.interface() == propertiesInterface && message.member() == QLatin1String("GetAll")) {
            const auto values = powerValues();
            if (delayPowerReads) {
                message.setDelayedReply(true);
                heldReads.append(message);
                heldReadValues.append(values);
                return true;
            }
            bus.send(message.createReply(QVariantList{values}));
            return true;
        }
        if (message.member() == QLatin1String("Set")) {
            if (message.arguments().at(0).toString() != powerService
                || message.arguments().at(1).toString() != QLatin1String("ActiveProfile")) {
                bus.send(message.createErrorReply(QStringLiteral("org.freedesktop.DBus.Error.InvalidArgs"),
                                                  QStringLiteral("Unexpected profile property")));
                return true;
            }
            profileWrites.append(qvariant_cast<QDBusVariant>(message.arguments().at(2)).variant().toString());
            if (delayPowerWrites) {
                message.setDelayedReply(true);
                heldWrites.append(message);
            } else {
                finishPowerWrite(message, refusePowerWrite);
            }
            return true;
        }
        return false;
    }
};

// The night light's gamma backend, in memory: whether the compositor offers
// gamma control, and whether the night light holds the outputs.
class FakeGamma : public PhosphorServiceNightLight::GammaBackend
{
    Q_OBJECT

public:
    bool isAvailable() const override
    {
        return available;
    }
    void setActive(bool value) override
    {
        active = value;
    }
    void setWhitePoint(const PhosphorServiceNightLight::WhitePoint&) override
    {
    }
    void retry() override
    {
        ++retries;
    }
    void setAvailable(bool value)
    {
        available = value;
        Q_EMIT availableChanged();
    }

    bool available = true;
    bool active = false;
    int retries = 0;
};

QJsonObject savedSettings(const QString& path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? QJsonDocument::fromJson(file.readAll()).object() : QJsonObject{};
}
} // namespace QuickSettingsTestSupport

using namespace QuickSettingsTestSupport;
using PhosphorServiceNightLight::NightLight;

class TestQuickSettingsController : public QObject
{
    Q_OBJECT
    QProcess m_daemon;
    QString m_address;
    std::unique_ptr<QDBusConnection> m_service;
    std::unique_ptr<QDBusConnection> m_client;
    std::unique_ptr<QTemporaryDir> m_directory;
    std::unique_ptr<QuickSettingsFixture> m_fixture;
    // The night light's backend and clock in the controller controller() last
    // built. The clock is read through m_now, which a test moves on.
    FakeGamma* m_gamma = nullptr;
    QDateTime m_now;

    QString configPath() const
    {
        return m_directory->filePath(QStringLiteral("lambent/nightlight.json"));
    }
    std::unique_ptr<PhosphorShellApp::QuickSettingsController> controller(const QString& path = {})
    {
        auto gamma = std::make_unique<FakeGamma>();
        m_gamma = gamma.get();
        auto light = std::make_unique<NightLight>(std::move(gamma), [this] {
            return m_now;
        });
        // Changes apply at once, so a test reads the state it asked for.
        light->setFadeDuration(0);
        return std::make_unique<PhosphorShellApp::QuickSettingsController>(*m_client, std::move(light),
                                                                           path.isEmpty() ? configPath() : path);
    }

private Q_SLOTS:
    void initTestCase()
    {
        qDBusRegisterMetaType<QList<QVariantMap>>();
        // A private bus from the test bus config, not --session: that reads the
        // system's session.conf, which a build sandbox (Nix) does not have.
        m_daemon.start(QStringLiteral(LAMBENT_DBUS_DAEMON),
                       {QStringLiteral("--config-file=" LAMBENT_TEST_BUS_CONFIG), QStringLiteral("--nofork"),
                        QStringLiteral("--print-address=1")});
        QVERIFY(m_daemon.waitForReadyRead());
        m_address = QString::fromUtf8(m_daemon.readLine()).trimmed();
    }

    void init()
    {
        m_service = std::make_unique<QDBusConnection>(
            QDBusConnection::connectToBus(m_address, QStringLiteral("quick-settings-service")));
        m_client = std::make_unique<QDBusConnection>(
            QDBusConnection::connectToBus(m_address, QStringLiteral("quick-settings-client")));
        QVERIFY(m_service->isConnected());
        QVERIFY(m_client->isConnected());
        m_directory = std::make_unique<QTemporaryDir>();
        QVERIFY(m_directory->isValid());
        m_fixture = std::make_unique<QuickSettingsFixture>(*m_service);
        QVERIFY(m_service->registerVirtualObject(QStringLiteral("/"), m_fixture.get(), QDBusConnection::SubPath));
        QVERIFY(m_service->registerService(powerService));
        // Noon, so the custom 18:00 to 06:00 hours are in their day.
        m_now = QDateTime(QDate(2026, 5, 4), QTime(12, 0), QTimeZone::UTC);
    }

    void cleanup()
    {
        m_service->unregisterService(powerService);
        m_service->unregisterObject(QStringLiteral("/"), QDBusConnection::UnregisterTree);
        m_fixture.reset();
        m_client.reset();
        m_service.reset();
        QDBusConnection::disconnectFromBus(QStringLiteral("quick-settings-client"));
        QDBusConnection::disconnectFromBus(QStringLiteral("quick-settings-service"));
        m_directory.reset();
        m_gamma = nullptr;
    }

    void cleanupTestCase()
    {
        m_daemon.terminate();
        QVERIFY(m_daemon.waitForFinished());
    }

    void startsFromDefaultsAndOnlyWritesOnRequest()
    {
        auto owner = controller();
        auto& settings = *owner;
        QVERIFY(settings.nightLightAvailable());
        QVERIFY(settings.nightLightScheduleAvailable());
        QVERIFY(!settings.nightLightEnabled());
        QVERIFY(!settings.nightLightRunning());
        QCOMPARE(settings.nightLightSchedule(), QStringLiteral("custom"));
        QCOMPARE(settings.nightLightEvening(), QStringLiteral("18:00"));
        QCOMPARE(settings.nightLightMorning(), QStringLiteral("06:00"));
        QCOMPARE(settings.nightLightTemperature(), NightLight::DefaultNightTemperature);
        QVERIFY(!QFileInfo::exists(configPath()));
        QTRY_VERIFY(settings.powerAvailable());
        QVERIFY(!QFileInfo::exists(configPath()));
        QVERIFY(m_fixture->profileWrites.isEmpty());
    }

    void enablingRunsAndPersists()
    {
        {
            auto owner = controller();
            auto& settings = *owner;
            settings.setNightLightSchedule(QStringLiteral("manual"));
            QVERIFY(!settings.nightLightRunning());
            settings.toggleNightLight();
            QVERIFY(settings.nightLightEnabled());
            QVERIFY(settings.nightLightRunning());
            QVERIFY(m_gamma->active);
            QVERIFY(settings.nightLightError().isEmpty());
            const auto saved = savedSettings(configPath());
            QCOMPARE(saved.value(QLatin1String("enabled")).toBool(), true);
            QCOMPARE(saved.value(QLatin1String("schedule")).toString(), QStringLiteral("manual"));
        }
        auto owner = controller();
        QVERIFY(owner->nightLightEnabled());
        QCOMPARE(owner->nightLightSchedule(), QStringLiteral("manual"));
        QVERIFY(owner->nightLightRunning());
    }

    void savesTemperatureHoursAndLocationForTheNextStart()
    {
        {
            auto owner = controller();
            auto& settings = *owner;
            settings.setNightLightTemperature(3200);
            settings.setNightLightTimes(QStringLiteral("07:30"), QStringLiteral("21:15"));
            settings.setNightLightLocation(52.5, 13.4);
            settings.setNightLightSchedule(QStringLiteral("automatic"));
            QVERIFY(settings.nightLightError().isEmpty());
        }
        const auto saved = savedSettings(configPath());
        QCOMPARE(saved.value(QLatin1String("temperature")).toInt(), 3200);
        QCOMPARE(saved.value(QLatin1String("morning")).toString(), QStringLiteral("07:30"));
        QCOMPARE(saved.value(QLatin1String("evening")).toString(), QStringLiteral("21:15"));
        QCOMPARE(saved.value(QLatin1String("schedule")).toString(), QStringLiteral("automatic"));
        QCOMPARE(saved.value(QLatin1String("latitude")).toDouble(), 52.5);
        QCOMPARE(saved.value(QLatin1String("longitude")).toDouble(), 13.4);
        auto owner = controller();
        QCOMPARE(owner->nightLightTemperature(), 3200);
        QCOMPARE(owner->nightLightMorning(), QStringLiteral("07:30"));
        QCOMPARE(owner->nightLightEvening(), QStringLiteral("21:15"));
        QCOMPARE(owner->nightLightSchedule(), QStringLiteral("automatic"));
        QVERIFY(!owner->nightLightNeedsLocation());
    }

    void customHoursSwitchToTheCustomSchedule()
    {
        auto owner = controller();
        auto& settings = *owner;
        settings.setNightLightSchedule(QStringLiteral("manual"));
        settings.setNightLightTimes(QStringLiteral("05:00"), QStringLiteral("22:00"));
        QCOMPARE(settings.nightLightSchedule(), QStringLiteral("custom"));
        settings.toggleNightLight();
        QVERIFY(!settings.nightLightRunning());
        m_now = QDateTime(QDate(2026, 5, 4), QTime(23, 0), QTimeZone::UTC);
        settings.refreshNightLight();
        QVERIFY(settings.nightLightRunning());
    }

    void automaticScheduleSaysWhenItNeedsALocation()
    {
        auto owner = controller();
        auto& settings = *owner;
        QSignalSpy changed(&settings, &PhosphorShellApp::QuickSettingsController::changed);
        QVERIFY(!settings.nightLightNeedsLocation());
        settings.setNightLightSchedule(QStringLiteral("automatic"));
        QVERIFY(settings.nightLightNeedsLocation());
        QVERIFY(!changed.isEmpty());
        settings.toggleNightLight();
        m_now = QDateTime(QDate(2026, 5, 4), QTime(23, 0), QTimeZone::UTC);
        settings.refreshNightLight();
        // Without a location the sunset schedule is permanent day.
        QVERIFY(!settings.nightLightRunning());
        settings.setNightLightLocation(52.5, 13.4);
        QVERIFY(!settings.nightLightNeedsLocation());
        QVERIFY(settings.nightLightRunning());
    }

    void invalidRequestsNeverTouchTheSettings()
    {
        auto owner = controller();
        auto& settings = *owner;
        settings.setNightLightTemperature(900);
        QVERIFY(!settings.nightLightError().isEmpty());
        settings.setNightLightSchedule(QStringLiteral("sometimes"));
        QVERIFY(!settings.nightLightError().isEmpty());
        settings.setNightLightTimes(QStringLiteral("08:00"), QStringLiteral("08:00"));
        QVERIFY(!settings.nightLightError().isEmpty());
        settings.setNightLightTimes(QStringLiteral("25:00"), QStringLiteral("08:00"));
        QVERIFY(!settings.nightLightError().isEmpty());
        settings.setNightLightLocation(91, 0);
        QVERIFY(!settings.nightLightError().isEmpty());
        QVERIFY(!QFileInfo::exists(configPath()));
        QCOMPARE(settings.nightLightTemperature(), NightLight::DefaultNightTemperature);
        QCOMPARE(settings.nightLightSchedule(), QStringLiteral("custom"));
        settings.setNightLightTemperature(4000);
        QVERIFY(settings.nightLightError().isEmpty());
    }

    void unsavableSettingsReportAnError()
    {
        // The settings file's directory is a regular file, so nothing can be saved.
        QFile blocker(m_directory->filePath(QStringLiteral("blocked")));
        QVERIFY(blocker.open(QIODevice::WriteOnly));
        blocker.close();
        auto owner = controller(m_directory->filePath(QStringLiteral("blocked/nightlight.json")));
        owner->toggleNightLight();
        QVERIFY(owner->nightLightEnabled());
        QVERIFY(!owner->nightLightError().isEmpty());
    }

    void pauseHoldsOneInhibitionUntilResumed()
    {
        auto owner = controller();
        auto& settings = *owner;
        settings.setNightLightSchedule(QStringLiteral("manual"));
        settings.toggleNightLightPause();
        QVERIFY2(!settings.nightLightPaused(), "nothing to pause while the night light is off");
        settings.toggleNightLight();
        settings.toggleNightLightPause();
        QVERIFY(settings.nightLightPaused());
        QVERIFY(settings.nightLightInhibited());
        QVERIFY(!settings.nightLightRunning());
        settings.toggleNightLightPause();
        QVERIFY(!settings.nightLightPaused());
        QVERIFY(!settings.nightLightInhibited());
        QVERIFY(settings.nightLightRunning());
    }

    void scheduledPauseEndsAtTheNextTransition()
    {
        auto owner = controller();
        auto& settings = *owner;
        m_now = QDateTime(QDate(2026, 5, 4), QTime(23, 0), QTimeZone::UTC);
        settings.refreshNightLight();
        settings.toggleNightLight();
        QVERIFY(settings.nightLightRunning());
        settings.toggleNightLightPause();
        QVERIFY(settings.nightLightPaused());
        // Past the morning transition and into the next evening's.
        m_now = QDateTime(QDate(2026, 5, 5), QTime(19, 0), QTimeZone::UTC);
        settings.refreshNightLight();
        QVERIFY(!settings.nightLightPaused());
        QVERIFY(!settings.nightLightInhibited());
        QVERIFY(settings.nightLightRunning());
    }

    void disablingAPausedNightLightReleasesItsInhibition()
    {
        auto owner = controller();
        auto& settings = *owner;
        settings.setNightLightSchedule(QStringLiteral("manual"));
        settings.toggleNightLight();
        settings.toggleNightLightPause();
        QVERIFY(settings.nightLightPaused());
        settings.setNightLightEnabled(false);
        QVERIFY(!settings.nightLightPaused());
        QVERIFY(!settings.nightLightInhibited());
        settings.setNightLightEnabled(true);
        QVERIFY(settings.nightLightRunning());
    }

    void followsTheBackendsAvailability()
    {
        auto owner = controller();
        auto& settings = *owner;
        QSignalSpy changed(&settings, &PhosphorShellApp::QuickSettingsController::changed);
        m_gamma->setAvailable(false);
        QVERIFY(!settings.nightLightAvailable());
        QVERIFY(!changed.isEmpty());
        settings.toggleNightLight();
        settings.toggleNightLightPause();
        QVERIFY(!settings.nightLightPaused());
        m_gamma->setAvailable(true);
        QVERIFY(settings.nightLightAvailable());
        settings.refreshNightLight();
        QVERIFY(m_gamma->retries > 0);
    }

    void powerProfilesFollowServiceCapabilities()
    {
        m_fixture->profiles = {QStringLiteral("balanced"), QStringLiteral("future-profile"),
                               QStringLiteral("power-saver"), QStringLiteral("balanced")};
        auto owner = controller();
        auto& settings = *owner;
        QTRY_VERIFY(settings.powerAvailable());
        QCOMPARE(settings.powerProfiles(), QStringList({QStringLiteral("balanced"), QStringLiteral("power-saver")}));
        QCOMPARE(settings.powerProfile(), QStringLiteral("balanced"));
        settings.setPowerProfile(QStringLiteral("performance"));
        QVERIFY(!settings.powerError().isEmpty());
        QVERIFY(!settings.powerPending());
        QVERIFY(m_fixture->profileWrites.isEmpty());
        settings.setPowerProfile(QStringLiteral("power-saver"));
        QTRY_COMPARE(settings.powerProfile(), QStringLiteral("power-saver"));
        QVERIFY(settings.powerError().isEmpty());
        QCOMPARE(m_fixture->profileWrites, QStringList{QStringLiteral("power-saver")});
    }

    void degradedPerformanceRemainsSelectable()
    {
        m_fixture->degradation = QStringLiteral("high-operating-temperature");
        auto owner = controller();
        auto& settings = *owner;
        QTRY_VERIFY(settings.powerAvailable());
        QCOMPARE(settings.performanceDegraded(), m_fixture->degradation);
        settings.setPowerProfile(QStringLiteral("performance"));
        QTRY_COMPARE(settings.powerProfile(), QStringLiteral("performance"));
        QVERIFY(settings.powerError().isEmpty());
        QCOMPARE(m_fixture->profileWrites, QStringList{QStringLiteral("performance")});
    }

    void powerWriteFailureKeepsConfirmedProfileAndAllowsRetry()
    {
        auto owner = controller();
        auto& settings = *owner;
        QTRY_VERIFY(settings.powerAvailable());
        m_fixture->refusePowerWrite = true;
        settings.setPowerProfile(QStringLiteral("power-saver"));
        QTRY_VERIFY(!settings.powerPending());
        QVERIFY(!settings.powerError().isEmpty());
        QCOMPARE(settings.powerProfile(), QStringLiteral("balanced"));
        m_fixture->refusePowerWrite = false;
        settings.setPowerProfile(QStringLiteral("power-saver"));
        QTRY_COMPARE(settings.powerProfile(), QStringLiteral("power-saver"));
        QVERIFY(settings.powerError().isEmpty());
    }

    void duplicatePowerRequestsWaitForConfirmation()
    {
        auto owner = controller();
        auto& settings = *owner;
        QTRY_VERIFY(settings.powerAvailable());
        m_fixture->delayPowerWrites = true;
        settings.setPowerProfile(QStringLiteral("performance"));
        settings.setPowerProfile(QStringLiteral("performance"));
        settings.setPowerProfile(QStringLiteral("power-saver"));
        QTRY_COMPARE(m_fixture->heldWrites.size(), 1);
        QVERIFY(settings.powerPending());
        QCOMPARE(settings.powerProfile(), QStringLiteral("balanced"));
        m_fixture->finishPowerWrite(m_fixture->heldWrites.constFirst(), false);
        QTRY_COMPARE(settings.powerProfile(), QStringLiteral("performance"));
        QVERIFY(!settings.powerPending());
        QCOMPARE(m_fixture->profileWrites.size(), 1);
        settings.setPowerProfile(QStringLiteral("performance"));
        QCOMPARE(m_fixture->profileWrites.size(), 1);
    }

    void stalePowerReadCannotReplaceNewerState()
    {
        auto owner = controller();
        auto& settings = *owner;
        QTRY_VERIFY(settings.powerAvailable());
        m_fixture->delayPowerReads = true;
        settings.refreshPower();
        QTRY_COMPARE(m_fixture->heldReads.size(), 1);
        m_fixture->delayPowerReads = false;
        m_fixture->activeProfile = QStringLiteral("power-saver");
        settings.refreshPower();
        QTRY_COMPARE(settings.powerProfile(), QStringLiteral("power-saver"));
        m_service->send(
            m_fixture->heldReads.constFirst().createReply(QVariantList{m_fixture->heldReadValues.constFirst()}));
        QTest::qWait(30);
        QCOMPARE(settings.powerProfile(), QStringLiteral("power-saver"));
    }

    void powerRestartInvalidatesOldWriteWithoutClearingNewPendingRequest()
    {
        auto owner = controller();
        auto& settings = *owner;
        QTRY_VERIFY(settings.powerAvailable());
        m_fixture->delayPowerWrites = true;
        settings.setPowerProfile(QStringLiteral("power-saver"));
        QTRY_COMPARE(m_fixture->heldWrites.size(), 1);
        QVERIFY(m_service->unregisterService(powerService));
        QTRY_VERIFY(!settings.powerAvailable());
        QVERIFY(!settings.powerPending());
        QVERIFY(m_service->registerService(powerService));
        QTRY_VERIFY(settings.powerAvailable());
        settings.setPowerProfile(QStringLiteral("performance"));
        QTRY_COMPARE(m_fixture->heldWrites.size(), 2);
        m_fixture->finishPowerWrite(m_fixture->heldWrites.at(0), true);
        QTest::qWait(30);
        QVERIFY(settings.powerPending());
        QVERIFY(settings.powerError().isEmpty());
        m_fixture->finishPowerWrite(m_fixture->heldWrites.at(1), false);
        QTRY_COMPARE(settings.powerProfile(), QStringLiteral("performance"));
        QVERIFY(!settings.powerPending());
    }
};
QTEST_GUILESS_MAIN(TestQuickSettingsController)
#include "test_quick_settings_controller.moc"
