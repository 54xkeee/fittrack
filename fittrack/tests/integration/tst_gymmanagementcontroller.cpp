#include "gyms/gymmanagementcontroller.h"
#include "storage/databasemanager.h"
#include "training/workoutsessioncontroller.h"

#include <QSqlQuery>
#include <QtTest>

class GymManagementControllerTest final : public QObject
{
    Q_OBJECT
private slots:
    void managesGymsAndArchivesReferencedEquipment();
};

void GymManagementControllerTest::managesGymsAndArchivesReferencedEquipment()
{
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    fittrack::GymManagementController controller(manager.database());
    fittrack::WorkoutSessionController workout(manager.database());
    QObject::connect(&controller, &fittrack::GymManagementController::catalogChanged,
                     &workout, &fittrack::WorkoutSessionController::reloadGymData);
    QSignalSpy catalogSpy(&controller, &fittrack::GymManagementController::catalogChanged);
    QSignalSpy planDaysSpy(&workout, &fittrack::WorkoutSessionController::planDaysChanged);
    QVERIFY(controller.gyms().isEmpty());
    controller.ensureLoaded();
    QVERIFY(controller.createGym(QStringLiteral("学校健身房")));
    QCOMPARE(catalogSpy.count(), 1);
    QCOMPARE(workout.gyms().size(), 1);
    const QString gymId = controller.selectedGymId();
    QVERIFY(!gymId.isEmpty());
    QVERIFY(workout.selectGym(gymId));
    QVERIFY(controller.selectGym(gymId));
    QCOMPARE(catalogSpy.count(), 1);
    QVERIFY(controller.createEquipment(QStringLiteral("高位下拉机"), QStringLiteral("1号"), QStringLiteral("座椅4档")));
    QCOMPARE(catalogSpy.count(), 2);
    QCOMPARE(controller.equipment().size(), 1);
    QCOMPARE(workout.equipment().size(), 1);
    const QString equipmentId = controller.equipment().first().toMap().value(QStringLiteral("id")).toString();
    QVERIFY(controller.updateEquipment(equipmentId, QStringLiteral("悍马高位下拉"), QStringLiteral("A")));
    QCOMPARE(catalogSpy.count(), 3);

    QSqlQuery seed(manager.database());
    QVERIFY(seed.exec(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,load_mode) "
        "VALUES('pulldown','高位下拉','背部','垂直拉','Standard')")));
    seed.prepare(QStringLiteral(
        "INSERT INTO workout_session(id,name,gym_id,started_at,ended_at,status) "
        "VALUES('session','Pull',?,'2026-07-13T10:00:00Z','2026-07-13T11:00:00Z','completed')"));
    seed.addBindValue(gymId);
    QVERIFY(seed.exec());
    seed.prepare(QStringLiteral(
        "INSERT INTO workout_exercise(id,session_id,exercise_id,equipment_instance_id,sort_order) "
        "VALUES('worked','session','pulldown',?,0)"));
    seed.addBindValue(equipmentId);
    QVERIFY(seed.exec());

    QVERIFY(controller.removeEquipment(equipmentId));
    QCOMPARE(catalogSpy.count(), 4);
    QCOMPARE(controller.equipment().size(), 0);
    QCOMPARE(workout.equipment().size(), 0);
    QSqlQuery verify(manager.database());
    verify.prepare(QStringLiteral("SELECT is_enabled FROM equipment_instance WHERE id=?"));
    verify.addBindValue(equipmentId);
    QVERIFY(verify.exec() && verify.next());
    QCOMPARE(verify.value(0).toInt(), 0);

    QVERIFY(controller.removeGym(gymId));
    QCOMPARE(catalogSpy.count(), 5);
    QCOMPARE(controller.gyms().size(), 0);
    QCOMPARE(workout.gyms().size(), 0);
    verify.prepare(QStringLiteral("SELECT is_enabled FROM gym WHERE id=?"));
    verify.addBindValue(gymId);
    QVERIFY(verify.exec() && verify.next());
    QCOMPARE(verify.value(0).toInt(), 0);
    QVERIFY(verify.exec(QStringLiteral("SELECT equipment_instance_id FROM workout_exercise WHERE id='worked'")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), equipmentId);
    QCOMPARE(planDaysSpy.count(), 0);
}

QTEST_GUILESS_MAIN(GymManagementControllerTest)
#include "tst_gymmanagementcontroller.moc"
