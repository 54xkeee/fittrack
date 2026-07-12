#include "plans/planmanagementcontroller.h"
#include "storage/databasemanager.h"

#include <QSqlQuery>
#include <QtTest>

class PlanManagementControllerTest final : public QObject
{
    Q_OBJECT

private slots:
    void protectsSystemPlansAndManagesPersonalPlans();
};

void PlanManagementControllerTest::protectsSystemPlansAndManagesPersonalPlans()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    QSqlQuery setup(manager.database());
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode,recommended_sets,recommended_reps,rest_seconds) VALUES"
        "('bench','杠铃卧推','胸部','水平推','Standard',3,'8-12',120),"
        "('row','坐姿划船','背部','水平拉','Standard',4,'10',90)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO training_plan(id,name,is_system,is_read_only) VALUES('system','原版',1,1)")));
    QVERIFY(setup.exec(QStringLiteral(
        "INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES('system-day','system','Push',0)")));

    fittrack::PlanManagementController plans(manager.database());
    QCOMPARE(plans.plans().size(), 1);
    QVERIFY(plans.selectPlan(QStringLiteral("system")));
    QVERIFY(!plans.renamePlan(QStringLiteral("system"), QStringLiteral("修改")));
    QVERIFY(!plans.deletePlan(QStringLiteral("system")));
    QVERIFY(!plans.renameDay(QStringLiteral("system-day"), QStringLiteral("修改")));

    QVERIFY(plans.createPlan(QStringLiteral("我的计划")));
    const QString personalId = plans.selectedPlan().value(QStringLiteral("id")).toString();
    QVERIFY(!personalId.isEmpty());
    QVERIFY(plans.renamePlan(personalId, QStringLiteral("我的增肌计划")));
    QVERIFY(plans.addDay(personalId, QStringLiteral("Push A")));
    QCOMPARE(plans.selectedPlan().value(QStringLiteral("days")).toList().size(), 1);
    const QString dayId = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                              .toMap().value(QStringLiteral("id")).toString();
    QVERIFY(plans.renameDay(dayId, QStringLiteral("胸肩三头")));
    QCOMPARE(plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                 .toMap().value(QStringLiteral("name")).toString(), QStringLiteral("胸肩三头"));
    QVERIFY(plans.addExercise(dayId, QStringLiteral("bench")));
    QVERIFY(plans.addExercise(dayId, QStringLiteral("row")));
    auto exercises = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                         .toMap().value(QStringLiteral("exercises")).toList();
    QCOMPARE(exercises.size(), 2);
    const QString benchPlanExerciseId = exercises.first().toMap().value(QStringLiteral("id")).toString();
    QVERIFY(plans.updateExercise(benchPlanExerciseId, 5, QStringLiteral("6-8"), 180));
    exercises = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                    .toMap().value(QStringLiteral("exercises")).toList();
    QCOMPARE(exercises.first().toMap().value(QStringLiteral("sets")).toInt(), 5);
    QVERIFY(plans.moveExercise(dayId, 1, 0));
    exercises = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                    .toMap().value(QStringLiteral("exercises")).toList();
    QCOMPARE(exercises.first().toMap().value(QStringLiteral("name")).toString(), QStringLiteral("坐姿划船"));
    QVERIFY(plans.removeExercise(benchPlanExerciseId));
    QVERIFY(plans.deleteDay(dayId));
    QCOMPARE(plans.selectedPlan().value(QStringLiteral("days")).toList().size(), 0);
    QVERIFY(plans.deletePlan(personalId));
    QCOMPARE(plans.plans().size(), 1);
}

QTEST_GUILESS_MAIN(PlanManagementControllerTest)
#include "tst_planmanagementcontroller.moc"
