#include <QtTest>

#include "authentication.h"
#include "graderepository.h"
#include "studentdata.h"

class CoreTests : public QObject
{
    Q_OBJECT

private slots:
    void calculatesScores();
    void sortsAndUsesCompetitionRanking();
    void loadsAndValidatesCsv();
    void rejectsInvalidCsvWithoutReplacingData();
    void addsRemovesAndRoundTrips();
    void validatesCredentials();
};

void CoreTests::calculatesScores()
{
    StudentData student("231202501", "费涛皓", "男", 87, 94, 87);

    QCOMPARE(student.total(), 268.0);
    QCOMPARE(student.average(), 268.0 / 3.0);
}

void CoreTests::sortsAndUsesCompetitionRanking()
{
    QVector<StudentData> students{
        {"1", "A", "男", 100, 100, 100},
        {"2", "B", "女", 90, 90, 90},
        {"3", "C", "男", 90, 90, 90},
        {"4", "D", "女", 80, 80, 80},
    };

    sortAndRank(students);

    QCOMPARE(students[0].id(), QString("1"));
    QCOMPARE(students[0].rank(), 1);
    QCOMPARE(students[1].rank(), 2);
    QCOMPARE(students[2].rank(), 2);
    QCOMPARE(students[3].rank(), 4);
}

void CoreTests::loadsAndValidatesCsv()
{
    QTemporaryDir dir;
    const QString path = dir.filePath("grades.csv");
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Text));
    file.write("231202501,费涛皓,男,87,94,87,268,9\n"
               "231202502,郑航,女,64,74,72,210,51\n");
    file.close();

    GradeRepository repository;
    QString error;
    QVERIFY2(repository.load(path, &error), qPrintable(error));
    QCOMPARE(repository.students().size(), 2);
    QCOMPARE(repository.findById("231202501")->total(), 268.0);
    QCOMPARE(repository.students().first().rank(), 1);
}

void CoreTests::rejectsInvalidCsvWithoutReplacingData()
{
    QTemporaryDir dir;
    const QString goodPath = dir.filePath("good.csv");
    const QString badPath = dir.filePath("bad.csv");
    QFile good(goodPath);
    QVERIFY(good.open(QIODevice::WriteOnly | QIODevice::Text));
    good.write("231202501,A,男,80,80,80,240,1\n");
    good.close();
    QFile bad(badPath);
    QVERIFY(bad.open(QIODevice::WriteOnly | QIODevice::Text));
    bad.write("231202501,A,男,101,80,80,261,1\n");
    bad.close();

    GradeRepository repository;
    QString error;
    QVERIFY(repository.load(goodPath, &error));
    QVERIFY(!repository.load(badPath, &error));
    QCOMPARE(repository.students().size(), 1);
    QVERIFY(error.contains("第 1 行"));
}

void CoreTests::addsRemovesAndRoundTrips()
{
    GradeRepository repository;
    QString error;
    QVERIFY(repository.add({"231202501", "A", "男", 90, 90, 90}, &error));
    QVERIFY(!repository.add({"231202501", "B", "女", 80, 80, 80}, &error));
    QVERIFY(repository.add({"231202502", "B", "女", 80, 80, 80}, &error));
    QCOMPARE(repository.students().size(), 2);
    QVERIFY(repository.removeAt(1, &error));

    QTemporaryDir dir;
    const QString path = dir.filePath("export.csv");
    QVERIFY2(repository.save(path, &error), qPrintable(error));
    GradeRepository reloaded;
    QVERIFY2(reloaded.load(path, &error), qPrintable(error));
    QCOMPARE(reloaded.students().size(), 1);
    QCOMPARE(reloaded.students().first().id(), QString("231202501"));
}

void CoreTests::validatesCredentials()
{
    QVERIFY(isAdminCredentials("xmu123", "123456"));
    QVERIFY(!isAdminCredentials("xmu123", "bad"));
    QVERIFY(isStudentCredentials("231202501", "password01"));
    QVERIFY(isStudentCredentials("231202560", "password60"));
    QVERIFY(!isStudentCredentials("231202501", "password02"));
    QVERIFY(!isStudentCredentials("231202561", "password61"));
    QVERIFY(!isStudentCredentials("23120251", "password01"));
}

QTEST_APPLESS_MAIN(CoreTests)
#include "test_core.moc"
