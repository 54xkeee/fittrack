#include "exercises/exerciselistmodel.h"
#include "storage/databasemanager.h"
#include "storage/exerciseseedimporter.h"

#include <QFile>
#include <QSqlQuery>
#include <QTest>

using namespace fittrack;

class ExerciseListModelTest : public QObject
{
    Q_OBJECT

private slots:
    void exposesAllBundledExercises();
    void filtersByAliasAndBodyPart();
    void managesFavoritesFiltersAndCustomExercises();

private:
    static QList<QByteArray> documents();
};

QList<QByteArray> ExerciseListModelTest::documents()
{
    QList<QByteArray> result;
    for (const auto &fileName : {"exercises-push.json", "exercises-pull.json", "exercises-legs.json"}) {
        QFile file(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/") + QString::fromLatin1(fileName));
        if (file.open(QIODevice::ReadOnly)) {
            result.append(file.readAll());
        }
    }
    return result;
}

void ExerciseListModelTest::exposesAllBundledExercises()
{
    DatabaseManager manager;
    QString error;
    QVERIFY(manager.initialize(QStringLiteral(":memory:"), &error));
    QVERIFY(ExerciseSeedImporter::importDocuments(manager.database(), documents(), &error));

    ExerciseListModel model(manager.database());
    QCOMPARE(model.rowCount(), 32);
    int benchRow = -1;
    for (int row = 0; row < model.rowCount(); ++row) {
        if (model.data(model.index(row), ExerciseListModel::ExerciseIdRole).toString()
            == QStringLiteral("barbell-bench-press")) {
            benchRow = row;
            break;
        }
    }
    QVERIFY(benchRow >= 0);
    const QModelIndex bench = model.index(benchRow);
    QVERIFY(!model.data(bench, ExerciseListModel::IntroductionRole).toString().isEmpty());
    QCOMPARE(model.data(bench, ExerciseListModel::StepsRole).toList().size(), 4);
    QCOMPARE(model.data(bench, ExerciseListModel::CautionsRole).toList().size(), 3);
    QVERIFY(model.data(bench, ExerciseListModel::MediaUrlRole).toString().startsWith(QStringLiteral("qrc:/images/")));
    QVERIFY(!model.data(bench, ExerciseListModel::MediaLicenseRole).toString().isEmpty());
}

void ExerciseListModelTest::filtersByAliasAndBodyPart()
{
    DatabaseManager manager;
    QString error;
    QVERIFY(manager.initialize(QStringLiteral(":memory:"), &error));
    QVERIFY(ExerciseSeedImporter::importDocuments(manager.database(), documents(), &error));

    ExerciseListModel model(manager.database());
    model.setSearchText(QStringLiteral("保加利亚深蹲"));
    QCOMPARE(model.rowCount(), 1);
    QCOMPARE(model.data(model.index(0), ExerciseListModel::NameRole).toString(), QStringLiteral("保加利亚分腿蹲"));

    model.setSearchText({});
    model.setBodyPart(QStringLiteral("背部"));
    QCOMPARE(model.rowCount(), 10);
}

void ExerciseListModelTest::managesFavoritesFiltersAndCustomExercises()
{
    DatabaseManager manager;
    QString error;
    QVERIFY(manager.initialize(QStringLiteral(":memory:"), &error));
    const auto seedDocuments = documents();
    QVERIFY(ExerciseSeedImporter::importDocuments(manager.database(), seedDocuments, &error));
    ExerciseListModel model(manager.database(), seedDocuments);

    QVERIFY(model.toggleFavorite(QStringLiteral("barbell-bench-press")));
    model.setFavoritesOnly(true);
    QCOMPARE(model.rowCount(), 1);
    QCOMPARE(model.data(model.index(0), ExerciseListModel::IsFavoriteRole).toBool(), true);
    model.setFavoritesOnly(false);

    model.setMovementFilter(QStringLiteral("水平拉"));
    QVERIFY(model.rowCount() > 0);
    for (int row = 0; row < model.rowCount(); ++row)
        QCOMPARE(model.data(model.index(row), ExerciseListModel::MovementRole).toString(), QStringLiteral("水平拉"));
    model.setMovementFilter({});
    model.setEquipmentFilter(QStringLiteral("杠铃"));
    QVERIFY(model.rowCount() > 0);
    model.setEquipmentFilter({});

    QVERIFY(model.createCustomExercise(QStringLiteral("学校推胸机"), QStringLiteral("中胸"),
        QStringLiteral("水平推"), QStringLiteral("固定器械"), QStringLiteral("自定义轨迹。"),
        3, QStringLiteral("8-12"), 90));
    model.setSearchText(QStringLiteral("学校推胸机"));
    QCOMPARE(model.rowCount(), 1);
    const QString customId = model.data(model.index(0), ExerciseListModel::ExerciseIdRole).toString();
    QCOMPARE(model.data(model.index(0), ExerciseListModel::IsSystemRole).toBool(), false);
    QVERIFY(model.data(model.index(0), ExerciseListModel::PrimaryMusclesRole).toStringList()
                .contains(QStringLiteral("中胸")));
    QVERIFY(model.updateCustomExercise(customId, QStringLiteral("学校推胸机A"), QStringLiteral("中胸"),
        QStringLiteral("水平推"), QStringLiteral("固定器械"), QStringLiteral("座椅四档。"),
        4, QStringLiteral("10"), 120));
    model.setSearchText(QStringLiteral("学校推胸机A"));
    QCOMPARE(model.rowCount(), 1);
    QSqlQuery history(manager.database());
    QVERIFY(history.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) VALUES('history','历史训练','2026-07-13T00:00:00Z','active')")));
    history.prepare(QStringLiteral(
        "INSERT INTO workout_exercise(id,session_id,exercise_id,sort_order) VALUES('history-ex','history',?,0)"));
    history.addBindValue(customId);
    QVERIFY(history.exec());
    QVERIFY(model.deleteCustomExercise(customId));
    QCOMPARE(model.rowCount(), 0);
    QSqlQuery archived(manager.database());
    archived.prepare(QStringLiteral("SELECT is_enabled FROM exercise WHERE id=?"));
    archived.addBindValue(customId);
    QVERIFY(archived.exec());
    QVERIFY(archived.next());
    QCOMPARE(archived.value(0).toInt(), 0);

    QSqlQuery damage(manager.database());
    QVERIFY(damage.exec(QStringLiteral(
        "UPDATE exercise SET name_zh='被修改' WHERE id='barbell-bench-press'")));
    QVERIFY(model.restoreSystemExercises());
    model.setSearchText(QStringLiteral("杠铃卧推"));
    QCOMPARE(model.rowCount(), 1);
}

QTEST_GUILESS_MAIN(ExerciseListModelTest)

#include "tst_exerciselistmodel.moc"
