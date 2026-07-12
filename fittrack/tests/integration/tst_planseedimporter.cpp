#include "storage/databasemanager.h"
#include "storage/exerciseseedimporter.h"
#include "storage/planseedimporter.h"

#include <QFile>
#include <QSqlQuery>
#include <QTest>

using namespace fittrack;

class PlanSeedImporterTest : public QObject
{
    Q_OBJECT

private slots:
    void importsReadOnlyThreeDaySplit();
};

void PlanSeedImporterTest::importsReadOnlyThreeDaySplit()
{
    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));

    QList<QByteArray> exerciseDocuments;
    for (const auto &fileName : {"exercises-push.json", "exercises-pull.json", "exercises-legs.json"}) {
        QFile file(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/") + QString::fromLatin1(fileName));
        QVERIFY2(file.open(QIODevice::ReadOnly), qPrintable(file.errorString()));
        exerciseDocuments.append(file.readAll());
    }
    QVERIFY2(ExerciseSeedImporter::importDocuments(manager.database(), exerciseDocuments, &error), qPrintable(error));

    QFile planFile(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/tan-three-day-split.json"));
    QVERIFY2(planFile.open(QIODevice::ReadOnly), qPrintable(planFile.errorString()));
    QVERIFY2(PlanSeedImporter::importDocument(manager.database(), planFile.readAll(), &error), qPrintable(error));

    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("SELECT is_system,is_read_only FROM training_plan WHERE id='tan-chengyi-three-day-split'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 1);
    QCOMPARE(query.value(1).toInt(), 1);

    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM plan_day")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 3);
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM plan_exercise")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 15);

    QVERIFY(query.exec(QStringLiteral("SELECT default_sets,default_reps FROM plan_exercise WHERE id='tan-push-1'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 3);
    QCOMPARE(query.value(1).toString(), QStringLiteral("12,10,8"));
}

QTEST_GUILESS_MAIN(PlanSeedImporterTest)

#include "tst_planseedimporter.moc"
