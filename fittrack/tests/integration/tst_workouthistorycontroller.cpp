#include "history/workouthistorycontroller.h"
#include "storage/databasemanager.h"

#include <QSignalSpy>
#include <QSqlQuery>
#include <QtTest>

class WorkoutHistoryControllerTest final : public QObject
{
    Q_OBJECT

private slots:
    void summarizesCompletedWorkout();
};

void WorkoutHistoryControllerTest::summarizesCompletedWorkout()
{
    fittrack::DatabaseManager databaseManager;
    QString error;
    QVERIFY2(databaseManager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    auto database = databaseManager.database();
    QSqlQuery query(database);
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO muscle(id,name_zh,body_part) VALUES('chest','胸大肌','胸部')")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode) "
        "VALUES('incline-db','上斜哑铃卧推','胸部','水平推','DumbbellPair')")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO exercise_muscle(exercise_id,muscle_id,role) VALUES('incline-db','chest','primary')")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,ended_at,status,notes) "
        "VALUES('session','Push','2026-07-13T08:00:00Z','2026-07-13T08:10:00Z','completed','状态良好')")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_exercise(id,session_id,exercise_id,sort_order) "
        "VALUES('worked','session','incline-db',0)")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO set_record(id,workout_exercise_id,set_order,weight_kg,actual_reps,completed) "
        "VALUES('set','worked',0,20,10,1)")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO append_set_record(id,parent_set_id,weight_kg,reps,rest_seconds) "
        "VALUES('append','set',20,2,5)")));

    fittrack::WorkoutHistoryController history(database);
    QCOMPARE(history.sessions().size(), 1);
    QVERIFY(history.selectSession(QStringLiteral("session")));
    const auto summary = history.selectedSession();
    QCOMPARE(summary.value(QStringLiteral("duration")).toString(), QStringLiteral("10分"));
    QCOMPARE(summary.value(QStringLiteral("setCount")).toInt(), 1);
    QCOMPARE(summary.value(QStringLiteral("totalVolume")).toDouble(), 480.0);
    QCOMPARE(summary.value(QStringLiteral("highestWeight")).toDouble(), 20.0);
    QCOMPARE(summary.value(QStringLiteral("highestWeightReps")).toInt(), 10);
    QCOMPARE(summary.value(QStringLiteral("highestWeightSetCount")).toInt(), 1);
    QVERIFY(qAbs(summary.value(QStringLiteral("bestOneRepMax")).toDouble() - 26.6667) < 0.001);
    QCOMPARE(summary.value(QStringLiteral("primaryMuscles")).toList().first().toMap()
                 .value(QStringLiteral("sets")).toInt(), 1);
    QCOMPARE(summary.value(QStringLiteral("exercises")).toList().first().toMap()
                 .value(QStringLiteral("sets")).toList().size(), 1);

    const QString setId = summary.value(QStringLiteral("exercises")).toList().first().toMap()
                              .value(QStringLiteral("sets")).toList().first().toMap()
                              .value(QStringLiteral("id")).toString();
    QCOMPARE(setId, QStringLiteral("set"));
    QSignalSpy selectedChangedSpy(&history, &fittrack::WorkoutHistoryController::selectedSessionChanged);
    QVERIFY(history.updateCompletedSet(setId, 30.0, 8, true, QStringLiteral("Assisted")));
    QCOMPARE(selectedChangedSpy.count(), 1);
    const auto corrected = history.selectedSession();
    QCOMPARE(corrected.value(QStringLiteral("totalVolume")).toDouble(), 560.0);
    QCOMPARE(corrected.value(QStringLiteral("highestWeight")).toDouble(), 30.0);
    QCOMPARE(corrected.value(QStringLiteral("highestWeightReps")).toInt(), 8);
    QVERIFY(qAbs(corrected.value(QStringLiteral("bestOneRepMax")).toDouble() - 38.0) < 0.001);
    const auto correctedSet = corrected.value(QStringLiteral("exercises")).toList().first().toMap()
                                  .value(QStringLiteral("sets")).toList().first().toMap();
    QCOMPARE(correctedSet.value(QStringLiteral("weightKg")).toDouble(), 30.0);
    QCOMPARE(correctedSet.value(QStringLiteral("reps")).toInt(), 8);
    QVERIFY(correctedSet.value(QStringLiteral("toFailure")).toBool());
    QCOMPARE(correctedSet.value(QStringLiteral("bodyweightLoadType")).toString(),
             QStringLiteral("Assisted"));

    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,ended_at,status) "
        "VALUES('other-session','Pull','2026-07-13T09:00:00Z','2026-07-13T09:10:00Z','completed')")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_exercise(id,session_id,exercise_id,sort_order) "
        "VALUES('other-worked','other-session','incline-db',0)")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO set_record(id,workout_exercise_id,set_order,weight_kg,actual_reps,completed) "
        "VALUES('other-set','other-worked',0,22.5,10,1)")));
    QVERIFY(!history.updateCompletedSet(QStringLiteral("other-set"), 40.0, 5));
    QVERIFY(!history.errorMessage().isEmpty());
    QVERIFY(!history.updateCompletedSet(QStringLiteral("missing-set"), 40.0, 5));
    QVERIFY(!history.errorMessage().isEmpty());

    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) "
        "VALUES('active-session','Active','2026-07-13T10:00:00Z','active')")));
    QVERIFY(!history.deleteSession(QStringLiteral("active-session")));
    QVERIFY(!history.errorMessage().isEmpty());
    QVERIFY(history.deleteSession(QStringLiteral("session")));
    QVERIFY(history.selectedSession().isEmpty());
    QCOMPARE(history.sessions().size(), 1);

    QVERIFY(query.exec(QStringLiteral(
        "SELECT COUNT(*) FROM workout_exercise WHERE id='worked'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 0);
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM set_record WHERE id='set'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 0);
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM append_set_record WHERE id='append'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 0);
    QVERIFY(!history.deleteSession(QStringLiteral("missing-session")));
    QVERIFY(!history.errorMessage().isEmpty());
}

QTEST_GUILESS_MAIN(WorkoutHistoryControllerTest)
#include "tst_workouthistorycontroller.moc"
