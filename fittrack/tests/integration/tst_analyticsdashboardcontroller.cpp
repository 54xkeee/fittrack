#include "analytics/analyticsdashboardcontroller.h"
#include "storage/databasemanager.h"

#include <QDateTime>
#include <QSqlQuery>
#include <QtTest>

class AnalyticsDashboardControllerTest final : public QObject
{
    Q_OBJECT

private slots:
    void filtersPeriodsAndBuildsTrends();
};

void AnalyticsDashboardControllerTest::filtersPeriodsAndBuildsTrends()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    auto db = manager.database();
    QSqlQuery q(db);
    QVERIFY(q.exec(QStringLiteral("INSERT INTO muscle(id,name_zh,body_part) VALUES('chest','胸大肌','胸部')")));
    QVERIFY(q.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode) "
        "VALUES('incline-db','上斜哑铃卧推','胸部','水平推','DumbbellPair')")));
    QVERIFY(q.exec(QStringLiteral(
        "INSERT INTO exercise_muscle(exercise_id,muscle_id,role) VALUES('incline-db','chest','primary')")));
    QVERIFY(q.exec(QStringLiteral("INSERT INTO gym(id,name) VALUES('gym','学校健身房')")));
    QVERIFY(q.exec(QStringLiteral(
        "INSERT INTO equipment_instance(id,gym_id,name,code) VALUES('bench','gym','上斜凳','1号')")));

    const QDateTime now = QDateTime::currentDateTimeUtc();
    const QString recentStart = now.addSecs(-3600).toString(Qt::ISODate);
    const QString recentEnd = now.toString(Qt::ISODate);
    const QString oldStart = now.addDays(-20).addSecs(-3600).toString(Qt::ISODate);
    const QString oldEnd = now.addDays(-20).toString(Qt::ISODate);
    QVERIFY(q.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,gym_id,started_at,ended_at,status) "
        "VALUES('recent','Push','gym','%1','%2','completed')").arg(recentStart, recentEnd)));
    QVERIFY(q.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,gym_id,started_at,ended_at,status) "
        "VALUES('old','Push','gym','%1','%2','completed')").arg(oldStart, oldEnd)));
    QVERIFY(q.exec(QStringLiteral(
        "INSERT INTO workout_exercise(id,session_id,exercise_id,equipment_instance_id,sort_order) VALUES"
        "('recent-ex','recent','incline-db','bench',0),('old-ex','old','incline-db','bench',0)")));
    QVERIFY(q.exec(QStringLiteral(
        "INSERT INTO set_record(id,workout_exercise_id,set_order,weight_kg,actual_reps,completed) VALUES"
        "('recent-set','recent-ex',0,20,10,1),('old-set','old-ex',0,22,8,1)")));
    QVERIFY(q.exec(QStringLiteral(
        "INSERT INTO append_set_record(id,parent_set_id,weight_kg,reps,rest_seconds) "
        "VALUES('recent-append','recent-set',20,2,5)")));

    fittrack::AnalyticsDashboardController analytics(db);
    QCOMPARE(analytics.sevenDayOverview().value(QStringLiteral("workoutCount")).toInt(), 1);
    QCOMPARE(analytics.overview().value(QStringLiteral("totalVolume")).toDouble(), 480.0);
    QCOMPARE(analytics.trend().size(), 1);
    QCOMPARE(analytics.trend().first().toMap().value(QStringLiteral("volume")).toDouble(), 480.0);
    QCOMPARE(analytics.trend().first().toMap().value(QStringLiteral("highestSetCount")).toInt(), 1);
    QCOMPARE(analytics.primaryMuscles().first().toMap().value(QStringLiteral("sets")).toInt(), 1);

    analytics.setPeriodDays(30);
    QCOMPARE(analytics.overview().value(QStringLiteral("workoutCount")).toInt(), 2);
    QCOMPARE(analytics.overview().value(QStringLiteral("setCount")).toInt(), 2);
    QCOMPARE(analytics.overview().value(QStringLiteral("totalVolume")).toDouble(), 832.0);
    QCOMPARE(analytics.trend().size(), 2);
    QCOMPARE(analytics.gyms().size(), 1);
    QCOMPARE(analytics.equipment().size(), 1);

    analytics.setGymFilter(QStringLiteral("gym"));
    analytics.setEquipmentFilter(QStringLiteral("bench"));
    QCOMPARE(analytics.trend().size(), 2);
    analytics.setPeriodDays(-1);
    QCOMPARE(analytics.overview().value(QStringLiteral("workoutCount")).toInt(), 2);
}

QTEST_GUILESS_MAIN(AnalyticsDashboardControllerTest)
#include "tst_analyticsdashboardcontroller.moc"
