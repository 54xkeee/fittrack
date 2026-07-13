#include "storage/databasemanager.h"
#include "training/workoutsessioncontroller.h"

#include <QSignalSpy>
#include <QSqlQuery>
#include <QtTest>

class WorkoutSessionControllerTest final : public QObject
{
    Q_OBJECT

private slots:
    void createsPersistsAndResumesWorkout();
    void suggestsNextTanDay();
};

void WorkoutSessionControllerTest::createsPersistsAndResumesWorkout()
{
    fittrack::DatabaseManager databaseManager;
    QString error;
    QVERIFY2(databaseManager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    auto database = databaseManager.database();

    QSqlQuery setup(database);
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode,recommended_sets,recommended_reps,rest_seconds) "
        "VALUES('bench','杠铃卧推','胸部','水平推','Standard',3,'8-12',120)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode,recommended_sets,recommended_reps,rest_seconds) "
        "VALUES('row','坐姿划船','背部','水平拉','Standard',4,'10',90)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO training_plan(id,name,is_system,is_read_only) VALUES('plan','测试计划',1,1)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES('push','plan','Push',0)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO plan_exercise(id,day_id,exercise_id,sort_order,default_sets,default_reps,rest_seconds,notes) "
        "VALUES('planned-bench','push','bench',0,3,'12,10,8',120,'正式组')")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO gym(id,name) VALUES('school-gym','学校健身房')")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO equipment_instance(id,gym_id,name,code,notes) "
        "VALUES('bench-1','school-gym','卧推架','1号','')")));

    fittrack::WorkoutSessionController controller(database);
    QCOMPARE(controller.planDays().size(), 1);
    QCOMPARE(controller.gyms().size(), 1);
    QVERIFY(controller.selectGym(QStringLiteral("school-gym")));
    QCOMPARE(controller.equipment().size(), 1);
    QVERIFY(controller.startPlanDay(QStringLiteral("push")));
    QVERIFY(controller.active());
    QCOMPARE(controller.exercises().size(), 1);
    QCOMPARE(controller.exercises().first().toMap().value(QStringLiteral("sets")).toList().size(), 3);
    QVERIFY(controller.setExerciseEquipment(0, QStringLiteral("bench-1")));
    QVERIFY(controller.configureExercise(0, 80.0, 8, 4));
    QVERIFY(controller.setSessionNotes(QStringLiteral("状态良好")));
    QVERIFY(controller.setExerciseNotes(0, QStringLiteral("握距稍窄")));
    QVERIFY(controller.setSetNotes(0, 0, QStringLiteral("动作稳定")));
    QCOMPARE(controller.exercises().first().toMap().value(QStringLiteral("sets")).toList().size(), 4);

    QSignalSpy completedSpy(&controller, &fittrack::WorkoutSessionController::setCompleted);
    QVERIFY(controller.completeSet(0, 0, 80.0, 8));
    QCOMPARE(completedSpy.count(), 1);
    QCOMPARE(completedSpy.first().first().toInt(), 120);

    QSignalSpy exercisesChangedSpy(&controller, &fittrack::WorkoutSessionController::exercisesChanged);
    QVERIFY(controller.updateCompletedSet(0, 0, 82.5, 6, true, QStringLiteral("Added")));
    QCOMPARE(exercisesChangedSpy.count(), 1);
    QCOMPARE(completedSpy.count(), 1);
    const auto correctedSet = controller.exercises().first().toMap()
                                  .value(QStringLiteral("sets")).toList().first().toMap();
    QCOMPARE(correctedSet.value(QStringLiteral("weightKg")).toDouble(), 82.5);
    QCOMPARE(correctedSet.value(QStringLiteral("actualReps")).toInt(), 6);
    QVERIFY(correctedSet.value(QStringLiteral("toFailure")).toBool());
    QCOMPARE(correctedSet.value(QStringLiteral("bodyweightLoadType")).toString(),
             QStringLiteral("Added"));
    QVERIFY(!controller.updateCompletedSet(99, 0, 80.0, 8));
    QVERIFY(!controller.errorMessage().isEmpty());
    QVERIFY(!controller.updateCompletedSet(0, 1, 80.0, 8));
    QVERIFY(!controller.errorMessage().isEmpty());

    QSqlQuery saved(database);
    QVERIFY(saved.exec(QStringLiteral(
        "SELECT weight_kg,actual_reps,completed FROM set_record WHERE set_order=0")));
    QVERIFY(saved.next());
    QCOMPARE(saved.value(0).toDouble(), 82.5);
    QCOMPARE(saved.value(1).toInt(), 6);
    QCOMPARE(saved.value(2).toInt(), 1);
    QSqlQuery notes(database);
    QVERIFY(notes.exec(QStringLiteral(
        "SELECT ws.notes,we.notes,s.notes FROM workout_session ws "
        "JOIN workout_exercise we ON we.session_id=ws.id "
        "JOIN set_record s ON s.workout_exercise_id=we.id WHERE s.set_order=0")));
    QVERIFY(notes.next());
    QCOMPARE(notes.value(0).toString(), QStringLiteral("状态良好"));
    QCOMPARE(notes.value(1).toString(), QStringLiteral("握距稍窄"));
    QCOMPARE(notes.value(2).toString(), QStringLiteral("动作稳定"));
    QVERIFY(!controller.configureExercise(0, 82.5, 8, 3));
    QVERIFY(controller.addAppendSet(0, 0, 80.0, 3, 5, true));
    QVERIFY(!controller.replaceExercise(0, QStringLiteral("row")));

    QSqlQuery appended(database);
    QVERIFY(appended.exec(QStringLiteral(
        "SELECT weight_kg,reps,rest_seconds,to_failure FROM append_set_record")));
    QVERIFY(appended.next());
    QCOMPARE(appended.value(0).toDouble(), 80.0);
    QCOMPARE(appended.value(1).toInt(), 3);
    QCOMPARE(appended.value(2).toInt(), 5);
    QCOMPARE(appended.value(3).toInt(), 1);

    fittrack::WorkoutSessionController restarted(database);
    QVERIFY(restarted.hasUnfinished());
    QVERIFY(restarted.resumeUnfinished());
    QCOMPARE(restarted.exercises().first().toMap()
                 .value(QStringLiteral("sets")).toList().first().toMap()
                 .value(QStringLiteral("completed")).toBool(), true);
    QVERIFY(restarted.finishWorkout());
    QVERIFY(!restarted.hasUnfinished());

    QVERIFY(restarted.selectGym(QStringLiteral("school-gym")));
    QVERIFY(restarted.startPlanDay(QStringLiteral("push")));
    QVERIFY(restarted.setExerciseEquipment(0, QStringLiteral("bench-1")));
    QCOMPARE(restarted.exercises().first().toMap()
                 .value(QStringLiteral("previousSets")).toList().size(), 1);
    QVERIFY(restarted.discardWorkout());

    fittrack::WorkoutSessionController freeController(database);
    QVERIFY(freeController.startFreeWorkout(QStringLiteral("自由胸部")));
    QVERIFY(freeController.addExercise(QStringLiteral("bench"), 2, QStringLiteral("10")));
    QVERIFY(freeController.addExercise(QStringLiteral("row"), 2, QStringLiteral("10")));
    QCOMPARE(freeController.exercises().size(), 2);
    QCOMPARE(freeController.exercises().first().toMap().value(QStringLiteral("sets")).toList().size(), 2);
    QVERIFY(freeController.moveExercise(1, 0));
    QCOMPARE(freeController.exercises().first().toMap().value(QStringLiteral("name")).toString(), QStringLiteral("坐姿划船"));
    QVERIFY(freeController.replaceExercise(0, QStringLiteral("bench")));
    QCOMPARE(freeController.exercises().first().toMap().value(QStringLiteral("name")).toString(), QStringLiteral("杠铃卧推"));
    QVERIFY(freeController.removeExercise(0));
    QCOMPARE(freeController.exercises().size(), 1);
    QVERIFY(freeController.saveCurrentAsPlan(
        QStringLiteral("我的胸部计划"), QStringLiteral("Push A"), QStringLiteral("胸部动作")));
    QCOMPARE(freeController.planDays().size(), 2);
    QSqlQuery personalPlan(database);
    QVERIFY(personalPlan.exec(QStringLiteral(
        "SELECT p.name,d.name,s.name,pe.default_sets FROM training_plan p "
        "JOIN plan_day d ON d.plan_id=p.id JOIN plan_section s ON s.day_id=d.id "
        "JOIN plan_exercise pe ON pe.day_id=d.id WHERE p.is_system=0")));
    QVERIFY(personalPlan.next());
    QCOMPARE(personalPlan.value(0).toString(), QStringLiteral("我的胸部计划"));
    QCOMPARE(personalPlan.value(1).toString(), QStringLiteral("Push A"));
    QCOMPARE(personalPlan.value(2).toString(), QStringLiteral("胸部动作"));
    QCOMPARE(personalPlan.value(3).toInt(), 2);

    fittrack::WorkoutSessionController recoveryController(database);
    QVERIFY(recoveryController.hasUnfinished());
    QVERIFY(recoveryController.finishUnfinished());
    QVERIFY(!recoveryController.hasUnfinished());
}

void WorkoutSessionControllerTest::suggestsNextTanDay()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY(manager.initialize(QStringLiteral(":memory:"), &error));
    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode) "
        "VALUES('bench','杠铃卧推','胸部','水平推','Standard')")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO training_plan(id,name,is_system,is_read_only) "
        "VALUES('tan-chengyi-three-day-split','三分化',1,1)")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES"
        "('push','tan-chengyi-three-day-split','Push',0),"
        "('pull','tan-chengyi-three-day-split','Pull',1)")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO plan_exercise(id,day_id,exercise_id,sort_order,default_sets,default_reps,rest_seconds) "
        "VALUES('push-bench','push','bench',0,1,'8',120),"
        "('pull-bench','pull','bench',0,1,'8',120)")));

    fittrack::WorkoutSessionController controller(manager.database());
    QCOMPARE(controller.suggestedDay().value(QStringLiteral("dayId")).toString(), QStringLiteral("push"));
    QVERIFY(controller.startSuggestedDay());
    QVERIFY(controller.finishWorkout());
    QCOMPARE(controller.suggestedDay().value(QStringLiteral("dayId")).toString(), QStringLiteral("pull"));
}

QTEST_GUILESS_MAIN(WorkoutSessionControllerTest)
#include "tst_workoutsessioncontroller.moc"
