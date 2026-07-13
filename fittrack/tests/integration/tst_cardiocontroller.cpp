#include "cardio/cardiocontroller.h"
#include "storage/databasemanager.h"

#include <QSqlQuery>
#include <QtTest>

class CardioControllerTest final : public QObject
{
    Q_OBJECT
private slots:
    void recordsStandaloneAndAttachedCardioWithNullOptionals();
};

void CardioControllerTest::recordsStandaloneAndAttachedCardioWithNullOptionals()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    QSqlQuery seed(manager.database());
    QVERIFY(seed.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,ended_at,status) "
        "VALUES('strength','Push','2026-07-13T10:00:00Z','2026-07-13T11:00:00Z','completed')")));
    QVERIFY(seed.exec(QStringLiteral(
        "INSERT INTO workout_cardio_target(session_id,cardio_type,duration_seconds,incline,speed_kmh,notes) "
        "VALUES('strength','TreadmillIncline',1800,9,5,'计划目标')")));

    fittrack::CardioController controller(manager.database());
    controller.setPendingSession(QStringLiteral("strength"));
    QCOMPARE(controller.pendingTarget().value(QStringLiteral("type")).toString(),
             QStringLiteral("TreadmillIncline"));
    QCOMPARE(controller.pendingTarget().value(QStringLiteral("durationMinutes")).toInt(), 30);
    QCOMPARE(controller.pendingTarget().value(QStringLiteral("notes")).toString(),
             QStringLiteral("计划目标"));
    QVERIFY2(controller.addTreadmill(30), qPrintable(controller.errorMessage()));
    QCOMPARE(controller.pendingSessionId(), QString{});
    QVERIFY(controller.pendingTarget().isEmpty());
    QCOMPARE(controller.records().size(), 1);
    const QVariantMap treadmill = controller.records().first().toMap();
    QCOMPARE(treadmill.value(QStringLiteral("type")).toString(), QStringLiteral("TreadmillIncline"));
    QCOMPARE(treadmill.value(QStringLiteral("durationMinutes")).toInt(), 30);
    QCOMPARE(treadmill.value(QStringLiteral("incline")).toDouble(), 9.0);
    QCOMPARE(treadmill.value(QStringLiteral("speedKmh")).toDouble(), 5.0);
    QVERIFY(treadmill.value(QStringLiteral("distanceKm")).isNull());
    QCOMPARE(treadmill.value(QStringLiteral("sessionName")).toString(), QStringLiteral("Push"));

    QVERIFY(controller.addStairClimber(20, 8, 45, -1, 138, QStringLiteral("稳定")));
    QCOMPARE(controller.records().size(), 2);
    const QVariantMap overview = controller.overview(7);
    QCOMPARE(overview.value(QStringLiteral("count")).toInt(), 2);
    QCOMPARE(overview.value(QStringLiteral("durationMinutes")).toInt(), 50);
    QCOMPARE(overview.value(QStringLiteral("treadmillCount")).toInt(), 1);
    QCOMPARE(overview.value(QStringLiteral("stairCount")).toInt(), 1);
    QVERIFY(!controller.addTreadmill(0));

    QSqlQuery verify(manager.database());
    QVERIFY(verify.exec(QStringLiteral(
        "SELECT session_id,performed_at,distance_km,average_heart_rate FROM cardio_record "
        "WHERE cardio_type='TreadmillIncline'")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), QStringLiteral("strength"));
    QVERIFY(!verify.value(1).toString().isEmpty());
    QVERIFY(verify.value(2).isNull());
    QVERIFY(verify.value(3).isNull());
}

QTEST_GUILESS_MAIN(CardioControllerTest)
#include "tst_cardiocontroller.moc"
