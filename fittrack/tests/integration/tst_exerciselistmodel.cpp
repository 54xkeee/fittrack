#include "exercises/exerciselistmodel.h"
#include "storage/databasemanager.h"
#include "storage/exerciseseedimporter.h"

#include <QFile>
#include <QTest>

using namespace fittrack;

class ExerciseListModelTest : public QObject
{
    Q_OBJECT

private slots:
    void exposesAllBundledExercises();
    void filtersByAliasAndBodyPart();

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

QTEST_GUILESS_MAIN(ExerciseListModelTest)

#include "tst_exerciselistmodel.moc"
