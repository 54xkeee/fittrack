#include "plans/planmanagementcontroller.h"
#include "storage/databasemanager.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QtTest>

namespace {

bool seedPlans(const QSqlDatabase &database, QString *errorMessage)
{
    const QStringList statements{
        QStringLiteral(
            "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode,recommended_sets,"
            "recommended_reps,rest_seconds) VALUES"
            "('bench','杠铃卧推','胸部','水平推','Standard',3,'8-12',120),"
            "('row','坐姿划船','背部','水平拉','Standard',4,'10',90)"),
        QStringLiteral(
            "INSERT INTO training_plan(id,name,is_system,is_read_only) "
            "VALUES('system','原版',1,1)"),
        QStringLiteral(
            "INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES"
            "('source-push','system','Push',0),"
            "('source-pull','system','Pull',1)"),
        QStringLiteral(
            "INSERT INTO plan_section(id,day_id,name,sort_order) VALUES"
            "('source-chest','source-push','胸部',0),"
            "('source-back','source-pull','背部',0)"),
        QStringLiteral(
            "INSERT INTO plan_exercise(id,day_id,section_id,exercise_id,sort_order,"
            "default_sets,default_reps,rest_seconds,notes) VALUES"
            "('source-pe1','source-push','source-chest','bench',0,3,'12,10,8',180,'正式组'),"
            "('source-pe2','source-push',NULL,'row',1,4,'10',90,''),"
            "('source-pe3','source-pull','source-back','row',0,4,'8-12',120,'保持稳定')"),
        QStringLiteral(
            "INSERT INTO plan_cardio(day_id,cardio_type,duration_seconds,incline,speed_kmh,notes) "
            "VALUES('source-push','TreadmillIncline',1800,9,5,'力量后完成')"),
    };

    for (const QString &statement : statements) {
        QSqlQuery query(database);
        if (!query.exec(statement)) {
            if (errorMessage) *errorMessage = query.lastError().text();
            return false;
        }
    }
    return true;
}

QVariant scalar(const QSqlDatabase &database, const QString &statement,
                const QVariant &binding = {})
{
    QSqlQuery query(database);
    query.prepare(statement);
    if (binding.isValid()) query.addBindValue(binding);
    if (!query.exec() || !query.next()) return {};
    return query.value(0);
}

} // namespace

class PlanManagementControllerTest final : public QObject
{
    Q_OBJECT

private slots:
    void protectsSystemPlansAndManagesPersonalPlans();
    void copiesCompletePlanIntoPersonalScope();
    void usesDefaultCopyNameAndRejectsMissingPlan();
    void rollsBackCopyWhenAChildInsertFails();
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
        "('row','坐姿划船','背部','水平拉','Standard',4,'10',90),"
        "('squat','杠铃深蹲','臀腿','深蹲','Standard',4,'8-12',180)")));
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
    QVERIFY2(plans.setCardio(dayId, QStringLiteral("TreadmillIncline"), 30, 9, 5),
             qPrintable(plans.errorMessage()));
    auto cardio = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                      .toMap().value(QStringLiteral("cardio")).toMap();
    QCOMPARE(cardio.value(QStringLiteral("type")).toString(), QStringLiteral("TreadmillIncline"));
    QCOMPARE(cardio.value(QStringLiteral("durationMinutes")).toInt(), 30);
    QVERIFY(plans.setCardio(dayId, QStringLiteral("StairClimber"), 20, -1, -1, 8,
                            QStringLiteral("收尾")));
    cardio = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                 .toMap().value(QStringLiteral("cardio")).toMap();
    QCOMPARE(cardio.value(QStringLiteral("type")).toString(), QStringLiteral("StairClimber"));
    QCOMPARE(cardio.value(QStringLiteral("machineLevel")).toDouble(), 8.0);
    QVERIFY(!plans.setCardio(dayId, QStringLiteral("Unknown"), 20));
    QVERIFY(plans.removeCardio(dayId));
    QVERIFY(plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                .toMap().value(QStringLiteral("cardio")).toMap().isEmpty());
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
    QVERIFY(plans.replaceExercise(benchPlanExerciseId, QStringLiteral("squat")));
    exercises = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                    .toMap().value(QStringLiteral("exercises")).toList();
    QCOMPARE(exercises.first().toMap().value(QStringLiteral("id")).toString(), benchPlanExerciseId);
    QCOMPARE(exercises.first().toMap().value(QStringLiteral("name")).toString(), QStringLiteral("杠铃深蹲"));
    QCOMPARE(exercises.first().toMap().value(QStringLiteral("sets")).toInt(), 5);
    QCOMPARE(exercises.first().toMap().value(QStringLiteral("reps")).toString(), QStringLiteral("6-8"));
    QCOMPARE(exercises.first().toMap().value(QStringLiteral("restSeconds")).toInt(), 180);
    QVERIFY(!plans.replaceExercise(QStringLiteral("missing"), QStringLiteral("bench")));
    QVERIFY(plans.addSection(dayId, QStringLiteral("主要动作")));
    auto sections = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                        .toMap().value(QStringLiteral("sections")).toList();
    QCOMPARE(sections.size(), 1);
    const QString sectionId = sections.first().toMap().value(QStringLiteral("id")).toString();
    QVERIFY(plans.renameSection(sectionId, QStringLiteral("复合动作")));
    QVERIFY(plans.setExerciseSection(benchPlanExerciseId, sectionId));
    exercises = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                    .toMap().value(QStringLiteral("exercises")).toList();
    QCOMPARE(exercises.first().toMap().value(QStringLiteral("sectionName")).toString(),
             QStringLiteral("复合动作"));
    QVERIFY(!plans.setExerciseSection(benchPlanExerciseId, QStringLiteral("missing")));
    QVERIFY(plans.deleteSection(sectionId));
    exercises = plans.selectedPlan().value(QStringLiteral("days")).toList().first()
                    .toMap().value(QStringLiteral("exercises")).toList();
    QVERIFY(exercises.first().toMap().value(QStringLiteral("sectionId")).toString().isEmpty());
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

void PlanManagementControllerTest::copiesCompletePlanIntoPersonalScope()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    QVERIFY2(seedPlans(manager.database(), &error), qPrintable(error));

    fittrack::PlanManagementController plans(manager.database());
    QVERIFY(plans.copyPlan(QStringLiteral("system"), QStringLiteral("我的三分化")));
    const QString copyId = plans.selectedPlan().value(QStringLiteral("id")).toString();
    QVERIFY(!copyId.isEmpty());
    QVERIFY(copyId != QStringLiteral("system"));

    QSqlQuery copiedPlan(manager.database());
    copiedPlan.prepare(QStringLiteral(
        "SELECT name,source_plan_id,is_system,is_read_only FROM training_plan WHERE id=?"));
    copiedPlan.addBindValue(copyId);
    QVERIFY(copiedPlan.exec());
    QVERIFY(copiedPlan.next());
    QCOMPARE(copiedPlan.value(0).toString(), QStringLiteral("我的三分化"));
    QCOMPARE(copiedPlan.value(1).toString(), QStringLiteral("system"));
    QCOMPARE(copiedPlan.value(2).toInt(), 0);
    QCOMPARE(copiedPlan.value(3).toInt(), 0);

    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM training_plan")).toInt(), 2);
    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM plan_day")).toInt(), 4);
    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM plan_section")).toInt(), 4);
    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM plan_exercise")).toInt(), 6);
    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM plan_cardio")).toInt(), 2);
    QCOMPARE(scalar(manager.database(),
                    QStringLiteral("SELECT COUNT(*) FROM plan_day WHERE plan_id=?"), copyId).toInt(), 2);

    QSqlQuery days(manager.database());
    days.prepare(QStringLiteral(
        "SELECT name,sort_order,id FROM plan_day WHERE plan_id=? ORDER BY sort_order"));
    days.addBindValue(copyId);
    QVERIFY(days.exec());
    QVERIFY(days.next());
    QCOMPARE(days.value(0).toString(), QStringLiteral("Push"));
    QCOMPARE(days.value(1).toInt(), 0);
    QVERIFY(days.value(2).toString() != QStringLiteral("source-push"));
    QVERIFY(days.next());
    QCOMPARE(days.value(0).toString(), QStringLiteral("Pull"));
    QCOMPARE(days.value(1).toInt(), 1);
    QVERIFY(days.value(2).toString() != QStringLiteral("source-pull"));
    QVERIFY(!days.next());

    QSqlQuery sections(manager.database());
    sections.prepare(QStringLiteral(
        "SELECT d.name,s.name,s.sort_order,s.id FROM plan_section s "
        "JOIN plan_day d ON d.id=s.day_id WHERE d.plan_id=? ORDER BY d.sort_order,s.sort_order"));
    sections.addBindValue(copyId);
    QVERIFY(sections.exec());
    QVERIFY(sections.next());
    QCOMPARE(sections.value(0).toString(), QStringLiteral("Push"));
    QCOMPARE(sections.value(1).toString(), QStringLiteral("胸部"));
    QCOMPARE(sections.value(2).toInt(), 0);
    QVERIFY(sections.value(3).toString() != QStringLiteral("source-chest"));
    QVERIFY(sections.next());
    QCOMPARE(sections.value(0).toString(), QStringLiteral("Pull"));
    QCOMPARE(sections.value(1).toString(), QStringLiteral("背部"));
    QVERIFY(sections.value(3).toString() != QStringLiteral("source-back"));
    QVERIFY(!sections.next());

    QSqlQuery exercises(manager.database());
    exercises.prepare(QStringLiteral(
        "SELECT d.name,s.name,pe.exercise_id,pe.sort_order,pe.default_sets,pe.default_reps,"
        "pe.rest_seconds,pe.notes FROM plan_exercise pe "
        "JOIN plan_day d ON d.id=pe.day_id LEFT JOIN plan_section s ON s.id=pe.section_id "
        "WHERE d.plan_id=? ORDER BY d.sort_order,pe.sort_order"));
    exercises.addBindValue(copyId);
    QVERIFY(exercises.exec());
    QVERIFY(exercises.next());
    QCOMPARE(exercises.value(0).toString(), QStringLiteral("Push"));
    QCOMPARE(exercises.value(1).toString(), QStringLiteral("胸部"));
    QCOMPARE(exercises.value(2).toString(), QStringLiteral("bench"));
    QCOMPARE(exercises.value(3).toInt(), 0);
    QCOMPARE(exercises.value(4).toInt(), 3);
    QCOMPARE(exercises.value(5).toString(), QStringLiteral("12,10,8"));
    QCOMPARE(exercises.value(6).toInt(), 180);
    QCOMPARE(exercises.value(7).toString(), QStringLiteral("正式组"));
    QVERIFY(exercises.next());
    QCOMPARE(exercises.value(0).toString(), QStringLiteral("Push"));
    QVERIFY(exercises.value(1).isNull());
    QCOMPARE(exercises.value(2).toString(), QStringLiteral("row"));
    QCOMPARE(exercises.value(3).toInt(), 1);
    QVERIFY(exercises.next());
    QCOMPARE(exercises.value(0).toString(), QStringLiteral("Pull"));
    QCOMPARE(exercises.value(1).toString(), QStringLiteral("背部"));
    QCOMPARE(exercises.value(5).toString(), QStringLiteral("8-12"));
    QCOMPARE(exercises.value(7).toString(), QStringLiteral("保持稳定"));
    QVERIFY(!exercises.next());

    QCOMPARE(scalar(manager.database(), QStringLiteral(
        "SELECT COUNT(*) FROM plan_exercise pe JOIN plan_day d ON d.id=pe.day_id "
        "JOIN plan_section s ON s.id=pe.section_id WHERE d.plan_id=? AND s.day_id<>pe.day_id"),
        copyId).toInt(), 0);
    QCOMPARE(scalar(manager.database(), QStringLiteral(
        "SELECT COUNT(*) FROM plan_exercise pe JOIN plan_day d ON d.id=pe.day_id "
        "WHERE d.plan_id=? AND pe.id LIKE 'source-%'"), copyId).toInt(), 0);

    QCOMPARE(scalar(manager.database(), QStringLiteral(
        "SELECT COUNT(*) FROM plan_day WHERE plan_id='system'" )).toInt(), 2);
    QCOMPARE(scalar(manager.database(), QStringLiteral(
        "SELECT COUNT(*) FROM plan_exercise pe JOIN plan_day d ON d.id=pe.day_id "
        "WHERE d.plan_id='system'" )).toInt(), 3);
    QCOMPARE(scalar(manager.database(), QStringLiteral(
        "SELECT COUNT(*) FROM plan_cardio pc JOIN plan_day d ON d.id=pc.day_id "
        "WHERE d.plan_id=?"), copyId).toInt(), 1);
    QCOMPARE(scalar(manager.database(), QStringLiteral(
        "SELECT default_reps FROM plan_exercise WHERE id='source-pe1'" )).toString(),
        QStringLiteral("12,10,8"));
}

void PlanManagementControllerTest::usesDefaultCopyNameAndRejectsMissingPlan()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    QVERIFY2(seedPlans(manager.database(), &error), qPrintable(error));

    fittrack::PlanManagementController plans(manager.database());
    QVERIFY(plans.copyPlan(QStringLiteral("system"), QStringLiteral("   ")));
    QCOMPARE(plans.selectedPlan().value(QStringLiteral("name")).toString(),
             QStringLiteral("原版个人版"));
    QCOMPARE(plans.selectedPlan().value(QStringLiteral("isSystem")).toBool(), false);
    QCOMPARE(plans.selectedPlan().value(QStringLiteral("isReadOnly")).toBool(), false);

    const int countBeforeFailure = plans.plans().size();
    QVERIFY(!plans.copyPlan(QStringLiteral("missing"), QStringLiteral("不应创建")));
    QVERIFY(!plans.errorMessage().isEmpty());
    QCOMPARE(plans.plans().size(), countBeforeFailure);
}

void PlanManagementControllerTest::rollsBackCopyWhenAChildInsertFails()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    QVERIFY2(seedPlans(manager.database(), &error), qPrintable(error));

    QSqlQuery trigger(manager.database());
    QVERIFY(trigger.exec(QStringLiteral(
        "CREATE TRIGGER force_copy_failure BEFORE INSERT ON plan_exercise "
        "BEGIN SELECT RAISE(ABORT,'forced copy failure'); END")));

    const int planCount = scalar(manager.database(),
                                 QStringLiteral("SELECT COUNT(*) FROM training_plan")).toInt();
    const int dayCount = scalar(manager.database(),
                                QStringLiteral("SELECT COUNT(*) FROM plan_day")).toInt();
    const int sectionCount = scalar(manager.database(),
                                    QStringLiteral("SELECT COUNT(*) FROM plan_section")).toInt();
    const int exerciseCount = scalar(manager.database(),
                                     QStringLiteral("SELECT COUNT(*) FROM plan_exercise")).toInt();

    fittrack::PlanManagementController plans(manager.database());
    QVERIFY(!plans.copyPlan(QStringLiteral("system"), QStringLiteral("会失败的副本")));
    QVERIFY(!plans.errorMessage().isEmpty());
    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM training_plan")).toInt(),
             planCount);
    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM plan_day")).toInt(),
             dayCount);
    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM plan_section")).toInt(),
             sectionCount);
    QCOMPARE(scalar(manager.database(), QStringLiteral("SELECT COUNT(*) FROM plan_exercise")).toInt(),
             exerciseCount);
    QCOMPARE(scalar(manager.database(), QStringLiteral(
        "SELECT COUNT(*) FROM training_plan WHERE name='会失败的副本'" )).toInt(), 0);
    QCOMPARE(plans.selectedPlan().value(QStringLiteral("id")).toString(), QStringLiteral("system"));
}

QTEST_GUILESS_MAIN(PlanManagementControllerTest)
#include "tst_planmanagementcontroller.moc"
