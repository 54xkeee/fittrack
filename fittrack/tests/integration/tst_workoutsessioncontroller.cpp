#include "storage/databasemanager.h"
#include "training/workoutsessioncontroller.h"

#include <QSignalSpy>
#include <QSqlQuery>
#include <QtTest>

namespace {

void seedStartablePlan(const QSqlDatabase &database)
{
    QSqlQuery query(database);
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode) "
        "VALUES('bench','杠铃卧推','胸部','水平推','Standard')")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO training_plan(id,name,is_system,is_read_only) "
        "VALUES('plan','测试计划',1,1)")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES"
        "('day-a','plan','训练 A',0),('day-b','plan','训练 B',1)")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO plan_exercise(id,day_id,exercise_id,sort_order,default_sets,default_reps,rest_seconds) "
        "VALUES('exercise-a','day-a','bench',0,1,'8',120),"
        "('exercise-b','day-b','bench',0,1,'8',120)")));
}

int activeCount(const QSqlDatabase &database)
{
    QSqlQuery query(database);
    if (!query.exec(QStringLiteral(
            "SELECT COUNT(*) FROM workout_session WHERE status='active'"))
        || !query.next()) {
        return -1;
    }
    return query.value(0).toInt();
}

} // namespace

class WorkoutSessionControllerTest final : public QObject
{
    Q_OBJECT

private slots:
    void createsPersistsAndResumesWorkout();
    void suggestsNextTanDay();
    void reportsConflictWithoutCreatingAnotherWorkout();
    void switchesWorkoutAtomically();
    void requiresRecoveryForMultipleLegacyActiveWorkouts();
    void preparesWithoutWritingAndCommitsSnapshot();
    void keepsPreparationWhenCommitFails();
    void configuresParametersWithoutRemovingCompletedSets();
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
        "INSERT INTO plan_cardio(day_id,cardio_type,duration_seconds,incline,speed_kmh,notes) "
        "VALUES('push','TreadmillIncline',1800,9,5,'力量后完成')")));
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
    QVERIFY(controller.setTargetReps(0, 1, 10));
    QCOMPARE(controller.exercises().first().toMap().value(QStringLiteral("sets")).toList().at(1)
                 .toMap().value(QStringLiteral("targetReps")).toInt(), 10);
    QVERIFY(!controller.setTargetReps(0, 1, 0));
    QVERIFY(controller.setSessionNotes(QStringLiteral("状态良好")));
    QVERIFY(controller.setExerciseNotes(0, QStringLiteral("握距稍窄")));
    QVERIFY(controller.setSetNotes(0, 0, QStringLiteral("动作稳定")));
    QCOMPARE(controller.exercises().first().toMap().value(QStringLiteral("sets")).toList().size(), 4);
    QSqlQuery cardioTarget(database);
    QVERIFY(cardioTarget.exec(QStringLiteral(
        "SELECT cardio_type,duration_seconds,incline,speed_kmh,notes FROM workout_cardio_target")));
    QVERIFY(cardioTarget.next());
    QCOMPARE(cardioTarget.value(0).toString(), QStringLiteral("TreadmillIncline"));
    QCOMPARE(cardioTarget.value(1).toInt(), 1800);
    QCOMPARE(cardioTarget.value(2).toDouble(), 9.0);
    QCOMPARE(cardioTarget.value(3).toDouble(), 5.0);
    QCOMPARE(cardioTarget.value(4).toString(), QStringLiteral("力量后完成"));

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

void WorkoutSessionControllerTest::reportsConflictWithoutCreatingAnotherWorkout()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    seedStartablePlan(manager.database());

    fittrack::WorkoutSessionController first(manager.database());
    const QVariantMap started = first.requestStartPlanDay(QStringLiteral("day-a"));
    QCOMPARE(started.value(QStringLiteral("status")).toString(), QStringLiteral("started"));
    const QString sessionId = first.sessionId();

    fittrack::WorkoutSessionController restarted(manager.database());
    QCOMPARE(restarted.sessionState(), QStringLiteral("Recoverable"));
    const QVariantMap conflict = restarted.requestStartPlanDay(QStringLiteral("day-b"));
    QCOMPARE(conflict.value(QStringLiteral("status")).toString(), QStringLiteral("conflict"));
    QCOMPARE(conflict.value(QStringLiteral("currentSessionId")).toString(), sessionId);
    QCOMPARE(conflict.value(QStringLiteral("currentSessionName")).toString(), QStringLiteral("训练 A"));
    QCOMPARE(conflict.value(QStringLiteral("requestedName")).toString(), QStringLiteral("训练 B"));
    QCOMPARE(conflict.value(QStringLiteral("activeSessionCount")).toInt(), 1);
    QVERIFY(restarted.errorMessage().isEmpty());
    QCOMPARE(activeCount(manager.database()), 1);

    QVERIFY(restarted.continueExistingWorkout());
    QCOMPARE(restarted.sessionId(), sessionId);
    QCOMPARE(restarted.sessionState(), QStringLiteral("Active"));
}

void WorkoutSessionControllerTest::switchesWorkoutAtomically()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    seedStartablePlan(manager.database());

    fittrack::WorkoutSessionController controller(manager.database());
    QVERIFY(controller.startPlanDay(QStringLiteral("day-a")));
    const QString firstId = controller.sessionId();
    QVERIFY(!controller.switchToPlanDay(QStringLiteral("missing"), false));
    QCOMPARE(activeCount(manager.database()), 1);
    QSqlQuery stillActive(manager.database());
    QVERIFY(stillActive.exec(QStringLiteral(
        "SELECT status FROM workout_session WHERE id='%1'").arg(firstId)));
    QVERIFY(stillActive.next());
    QCOMPARE(stillActive.value(0).toString(), QStringLiteral("active"));

    QVERIFY(controller.switchToPlanDay(QStringLiteral("day-b"), false));
    QVERIFY(controller.sessionId() != firstId);
    QCOMPARE(controller.sessionName(), QStringLiteral("训练 B"));
    QCOMPARE(activeCount(manager.database()), 1);
    QSqlQuery completed(manager.database());
    completed.prepare(QStringLiteral("SELECT status FROM workout_session WHERE id=?"));
    completed.addBindValue(firstId);
    QVERIFY(completed.exec());
    QVERIFY(completed.next());
    QCOMPARE(completed.value(0).toString(), QStringLiteral("completed"));

    const QString secondId = controller.sessionId();
    QVERIFY(controller.switchToFreeWorkout(QStringLiteral("自由训练"), true));
    QCOMPARE(activeCount(manager.database()), 1);
    QSqlQuery discarded(manager.database());
    discarded.prepare(QStringLiteral("SELECT 1 FROM workout_session WHERE id=?"));
    discarded.addBindValue(secondId);
    QVERIFY(discarded.exec());
    QVERIFY(!discarded.next());
}

void WorkoutSessionControllerTest::requiresRecoveryForMultipleLegacyActiveWorkouts()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    seedStartablePlan(manager.database());
    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("DROP TRIGGER workout_session_single_active_insert")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) VALUES"
        "('legacy-a','旧训练 A','2026-07-14T08:00:00Z','active'),"
        "('legacy-b','旧训练 B','2026-07-14T09:00:00Z','active')")));

    fittrack::WorkoutSessionController controller(manager.database());
    QCOMPARE(controller.sessionState(), QStringLiteral("RecoveryRequired"));
    const QVariantMap result = controller.requestStartPlanDay(QStringLiteral("day-a"));
    QCOMPARE(result.value(QStringLiteral("status")).toString(), QStringLiteral("recoveryRequired"));
    QCOMPARE(result.value(QStringLiteral("activeSessionCount")).toInt(), 2);
    QVERIFY(!controller.continueExistingWorkout());
    QVERIFY(!controller.resumeUnfinished());
    QCOMPARE(activeCount(manager.database()), 2);

    QVERIFY(controller.recoverActiveSessions(QStringLiteral("legacy-a"), false));
    QCOMPARE(controller.sessionId(), QStringLiteral("legacy-a"));
    QCOMPARE(controller.sessionState(), QStringLiteral("Active"));
    QCOMPARE(activeCount(manager.database()), 1);
    QVERIFY(query.exec(QStringLiteral(
        "SELECT status,ended_at FROM workout_session WHERE id='legacy-b'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toString(), QStringLiteral("completed"));
    QVERIFY(!query.value(1).toString().isEmpty());

    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) "
        "VALUES('legacy-c','旧训练 C','2026-07-14T10:00:00Z','active')")));
    controller.reloadAfterRestore();
    QCOMPARE(controller.sessionState(), QStringLiteral("RecoveryRequired"));
    QVERIFY(controller.recoverActiveSessions(QStringLiteral("legacy-c"), true));
    QCOMPARE(controller.sessionId(), QStringLiteral("legacy-c"));
    QCOMPARE(activeCount(manager.database()), 1);
    QVERIFY(query.exec(QStringLiteral(
        "SELECT COUNT(*) FROM workout_session WHERE id='legacy-a'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 0);
}

void WorkoutSessionControllerTest::preparesWithoutWritingAndCommitsSnapshot()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    seedStartablePlan(manager.database());
    fittrack::WorkoutSessionController controller(manager.database());

    const QVariantMap prepared = controller.requestPreparePlanDay(QStringLiteral("day-a"));
    QCOMPARE(prepared.value(QStringLiteral("status")).toString(), QStringLiteral("prepared"));
    QVERIFY(controller.preparing());
    QCOMPARE(activeCount(manager.database()), 0);
    QSqlQuery count(manager.database());
    QVERIFY(count.exec(QStringLiteral("SELECT COUNT(*) FROM workout_session")));
    QVERIFY(count.next());
    QCOMPARE(count.value(0).toInt(), 0);

    QVariantMap draftExercise = controller.preparation()
                                    .value(QStringLiteral("exercises")).toList().first().toMap();
    const QString draftId = draftExercise.value(QStringLiteral("draftId")).toString();
    QCOMPARE(draftExercise.value(QStringLiteral("restSeconds")).toInt(), 120);
    QVERIFY(controller.updatePreparedExercise(draftId, 4, QStringLiteral("12,10,8,6"), 45));
    draftExercise = controller.preparation()
                        .value(QStringLiteral("exercises")).toList().first().toMap();
    QVERIFY(draftExercise.value(QStringLiteral("modified")).toBool());
    QVERIFY(controller.restorePreparedExerciseDefaults(draftId));
    draftExercise = controller.preparation()
                        .value(QStringLiteral("exercises")).toList().first().toMap();
    QCOMPARE(draftExercise.value(QStringLiteral("sets")).toInt(), 1);
    QCOMPARE(draftExercise.value(QStringLiteral("restSeconds")).toInt(), 120);

    QVERIFY(controller.addPreparedExercise(QStringLiteral("bench")));
    QVariantList preparedExercises = controller.preparation()
                                         .value(QStringLiteral("exercises")).toList();
    QCOMPARE(preparedExercises.size(), 2);
    const QString addedDraftId = preparedExercises.at(1).toMap()
                                     .value(QStringLiteral("draftId")).toString();
    QVERIFY(controller.movePreparedExercise(addedDraftId, 0));
    preparedExercises = controller.preparation()
                            .value(QStringLiteral("exercises")).toList();
    QCOMPARE(preparedExercises.first().toMap()
                 .value(QStringLiteral("draftId")).toString(), addedDraftId);
    QVERIFY(controller.removePreparedExercise(addedDraftId));
    QCOMPARE(controller.preparation().value(QStringLiteral("exercises")).toList().size(), 1);

    controller.cancelPreparation();
    QVERIFY(!controller.preparing());
    QVERIFY(count.exec(QStringLiteral("SELECT COUNT(*) FROM workout_session")));
    QVERIFY(count.next());
    QCOMPARE(count.value(0).toInt(), 0);

    QCOMPARE(controller.requestPreparePlanDay(QStringLiteral("day-a"))
                 .value(QStringLiteral("status")).toString(), QStringLiteral("prepared"));
    draftExercise = controller.preparation()
                        .value(QStringLiteral("exercises")).toList().first().toMap();
    QVERIFY(controller.updatePreparedExercise(
        draftExercise.value(QStringLiteral("draftId")).toString(),
        4, QStringLiteral("12,10,8,6"), 45));
    QVERIFY(controller.savePreparationAsPlan(
        QStringLiteral("准备草稿计划"), QStringLiteral("Push B")));
    QSqlQuery savedPlan(manager.database());
    QVERIFY(savedPlan.exec(QStringLiteral(
        "SELECT pe.default_sets,pe.default_reps,pe.rest_seconds FROM plan_exercise pe "
        "JOIN plan_day d ON d.id=pe.day_id JOIN training_plan p ON p.id=d.plan_id "
        "WHERE p.name='准备草稿计划'")));
    QVERIFY(savedPlan.next());
    QCOMPARE(savedPlan.value(0).toInt(), 4);
    QCOMPARE(savedPlan.value(1).toString(), QStringLiteral("12,10,8,6"));
    QCOMPARE(savedPlan.value(2).toInt(), 45);

    QVERIFY(controller.commitPreparation());
    QVERIFY(!controller.preparing());
    QVERIFY(controller.active());
    QCOMPARE(activeCount(manager.database()), 1);
    const QVariantMap activeExercise = controller.exercises().first().toMap();
    QCOMPARE(activeExercise.value(QStringLiteral("restSeconds")).toInt(), 45);
    const QVariantList sets = activeExercise.value(QStringLiteral("sets")).toList();
    QCOMPARE(sets.size(), 4);
    QCOMPARE(sets.at(0).toMap().value(QStringLiteral("targetReps")).toInt(), 12);
    QCOMPARE(sets.at(3).toMap().value(QStringLiteral("targetReps")).toInt(), 6);
}

void WorkoutSessionControllerTest::keepsPreparationWhenCommitFails()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    seedStartablePlan(manager.database());
    fittrack::WorkoutSessionController controller(manager.database());
    QCOMPARE(controller.requestPreparePlanDay(QStringLiteral("day-a"))
                 .value(QStringLiteral("status")).toString(), QStringLiteral("prepared"));
    QSqlQuery trigger(manager.database());
    QVERIFY(trigger.exec(QStringLiteral(
        "CREATE TRIGGER fail_prepared_exercise BEFORE INSERT ON workout_exercise "
        "BEGIN SELECT RAISE(ABORT,'forced preparation failure'); END")));
    QVERIFY(!controller.commitPreparation());
    QVERIFY(controller.preparing());
    QCOMPARE(activeCount(manager.database()), 0);
    QSqlQuery count(manager.database());
    QVERIFY(count.exec(QStringLiteral("SELECT COUNT(*) FROM workout_session")));
    QVERIFY(count.next());
    QCOMPARE(count.value(0).toInt(), 0);
}

void WorkoutSessionControllerTest::configuresParametersWithoutRemovingCompletedSets()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    QSqlQuery setup(manager.database());
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode,recommended_sets,recommended_reps,rest_seconds) "
        "VALUES('bench','杠铃卧推','胸部','水平推','Standard',4,'8-12',120)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO training_plan(id,name,is_system,is_read_only) "
        "VALUES('plan','测试计划',1,1)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES('day','plan','训练日',0)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO plan_exercise(id,day_id,exercise_id,sort_order,default_sets,default_reps,rest_seconds) "
        "VALUES('planned','day','bench',0,4,'12,10,8,6',120)")));

    fittrack::WorkoutSessionController controller(manager.database());
    QVERIFY(controller.startPlanDay(QStringLiteral("day")));
    QVERIFY(controller.completeSet(0, 3, 80.0, 6));
    QVERIFY(!controller.configureExerciseParameters(
        0, 75.0, QStringLiteral("10,9,8"), 3, 75));
    QVERIFY(controller.errorMessage().contains(QStringLiteral("已经完成")));
    QCOMPARE(controller.exercises().first().toMap()
                 .value(QStringLiteral("sets")).toList().size(), 4);

    QVERIFY(controller.configureExerciseParameters(
        0, 75.0, QStringLiteral("12,10,8,6,5"), 5, 75));
    const QVariantMap configured = controller.exercises().first().toMap();
    QCOMPARE(configured.value(QStringLiteral("restSeconds")).toInt(), 75);
    const QVariantList configuredSets = configured.value(QStringLiteral("sets")).toList();
    QCOMPARE(configuredSets.size(), 5);
    QCOMPARE(configuredSets.at(0).toMap().value(QStringLiteral("weightKg")).toDouble(), 75.0);
    QCOMPARE(configuredSets.at(3).toMap().value(QStringLiteral("completed")).toBool(), true);
    QCOMPARE(configuredSets.at(3).toMap().value(QStringLiteral("weightKg")).toDouble(), 80.0);
    QCOMPARE(configuredSets.at(3).toMap().value(QStringLiteral("actualReps")).toInt(), 6);

    QVERIFY(controller.configureExerciseParameters(
        0, 70.0, QStringLiteral("10"), 4, 60));
    QCOMPARE(controller.exercises().first().toMap()
                 .value(QStringLiteral("sets")).toList().size(), 4);
    QSqlQuery persisted(manager.database());
    QVERIFY(persisted.exec(QStringLiteral(
        "SELECT rest_seconds FROM workout_exercise LIMIT 1")));
    QVERIFY(persisted.next());
    QCOMPARE(persisted.value(0).toInt(), 60);
}

QTEST_GUILESS_MAIN(WorkoutSessionControllerTest)
#include "tst_workoutsessioncontroller.moc"
