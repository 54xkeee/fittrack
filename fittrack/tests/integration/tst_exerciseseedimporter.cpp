#include "storage/databasemanager.h"
#include "storage/exerciseseedimporter.h"

#include <QFile>
#include <QSqlQuery>
#include <QTest>

using namespace fittrack;

class ExerciseSeedImporterTest : public QObject
{
    Q_OBJECT

private slots:
    void importsExercisesMusclesMediaAndAlternatives();
    void rejectsMissingAlternativeWithoutPartialWrite();
    void importsBundledExerciseData();
};

void ExerciseSeedImporterTest::importsExercisesMusclesMediaAndAlternatives()
{
    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));

    const QByteArray data = R"json([
      {
        "id":"barbell_bench_press","nameZh":"杠铃卧推","nameEn":"Barbell Bench Press",
        "aliases":[],"bodyPart":"胸部","movement":"水平推","equipment":["杠铃"],
        "loadMode":"Standard","primaryMuscles":["中胸"],"secondaryMuscles":["肱三头肌"],
        "introduction":"胸部复合推举。","steps":["稳定躺卧","推起杠铃"],"cautions":["保持控制"],
        "recommendedSets":4,"recommendedReps":"8-12","restSeconds":180,
        "alternatives":["incline_dumbbell_press"],
        "media":[{"type":"externalVideo","url":"https://example.com/bench","title":"教学","source":"Example"}],
        "sources":[{"title":"来源","url":"https://example.com/source","type":"reference"}]
      },
      {
        "id":"incline_dumbbell_press","nameZh":"上斜哑铃卧推","nameEn":"Incline Dumbbell Press",
        "aliases":[],"bodyPart":"胸部","movement":"水平推","equipment":["哑铃"],
        "loadMode":"DumbbellPair","primaryMuscles":["上胸"],"secondaryMuscles":["肱三头肌"],
        "introduction":"上胸推举。","steps":["调整训练凳","推起哑铃"],"cautions":["保持控制"],
        "recommendedSets":4,"recommendedReps":"8-12","restSeconds":120,
        "alternatives":["barbell_bench_press"],"media":[],"sources":[]
      }
    ])json";

    QVERIFY2(ExerciseSeedImporter::importDocuments(manager.database(), {data}, &error), qPrintable(error));

    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM exercise")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 2);
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM exercise_muscle")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 4);
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM exercise_alternative")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 2);
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM exercise_media")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 1);
}

void ExerciseSeedImporterTest::rejectsMissingAlternativeWithoutPartialWrite()
{
    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));

    const QByteArray data = R"json([{
      "id":"broken","nameZh":"错误动作","bodyPart":"其他","movement":"其他","loadMode":"Standard",
      "alternatives":["missing"]
    }])json";

    QVERIFY(!ExerciseSeedImporter::importDocuments(manager.database(), {data}, &error));
    QVERIFY(error.contains(QStringLiteral("不存在")));

    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM exercise")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 0);
}

void ExerciseSeedImporterTest::importsBundledExerciseData()
{
    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));

    QList<QByteArray> documents;
    const QStringList fileNames{
        QStringLiteral("exercises-push.json"),
        QStringLiteral("exercises-pull.json"),
        QStringLiteral("exercises-legs.json"),
    };
    for (const auto &fileName : fileNames) {
        QFile file(QStringLiteral(FITTRACK_SOURCE_DIR "/resources/data/") + fileName);
        QVERIFY2(file.open(QIODevice::ReadOnly), qPrintable(file.errorString()));
        documents.append(file.readAll());
    }

    QVERIFY2(ExerciseSeedImporter::importDocuments(manager.database(), documents, &error), qPrintable(error));

    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM exercise")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 32);
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM exercise WHERE body_part IN ('Back','Biceps')")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 0);
    QVERIFY(query.exec(QStringLiteral(
        "SELECT COUNT(*) FROM exercise WHERE json_array_length(steps_json)=4 "
        "AND json_array_length(cautions_json)=3")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 32);
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM exercise_media")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 20);
    QVERIFY(query.exec(QStringLiteral(
        "SELECT COUNT(*) FROM exercise_media WHERE local_path='' OR external_url='' OR license=''")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 0);
}

QTEST_GUILESS_MAIN(ExerciseSeedImporterTest)

#include "tst_exerciseseedimporter.moc"
