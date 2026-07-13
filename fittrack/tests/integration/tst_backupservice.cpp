#include "backup/backupservice.h"
#include "storage/databasemanager.h"

#include <QFile>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>

class BackupServiceTest final : public QObject
{
    Q_OBJECT
private slots:
    void exportsAndRestoresCompleteJsonBackup();
    void rejectsOversizedJsonBackup();
};

void BackupServiceTest::exportsAndRestoresCompleteJsonBackup()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(directory.filePath(QStringLiteral("live.sqlite")), &error), qPrintable(error));
    QSqlQuery seed(manager.database());
    QVERIFY(seed.exec(QStringLiteral("INSERT INTO gym(id,name) VALUES('gym','学校健身房')")));
    QVERIFY(seed.exec(QStringLiteral(
        "INSERT INTO cardio_record(id,cardio_type,performed_at,duration_seconds,incline,speed_kmh,notes) "
        "VALUES('cardio','TreadmillIncline','2026-07-13T10:00:00Z',1800,9,5,'')")));

    fittrack::BackupService backup(manager.database());
    const QString jsonPath = directory.filePath(QStringLiteral("fittrack.json"));
    const QString sqlitePath = directory.filePath(QStringLiteral("fittrack.sqlite"));
    QVERIFY2(backup.exportJson(jsonPath), qPrintable(backup.errorMessage()));
    QVERIFY2(backup.exportDatabase(sqlitePath), qPrintable(backup.errorMessage()));
    QVERIFY(QFileInfo(sqlitePath).size() > 0);

    QVERIFY(seed.exec(QStringLiteral("DELETE FROM cardio_record")));
    QVERIFY(seed.exec(QStringLiteral("UPDATE gym SET name='已修改' WHERE id='gym'")));
    QVERIFY2(backup.restoreJson(jsonPath), qPrintable(backup.errorMessage()));
    QVERIFY(seed.exec(QStringLiteral("SELECT name FROM gym WHERE id='gym'")) && seed.next());
    QCOMPARE(seed.value(0).toString(), QStringLiteral("学校健身房"));
    QVERIFY(seed.exec(QStringLiteral("SELECT duration_seconds,distance_km FROM cardio_record WHERE id='cardio'")) && seed.next());
    QCOMPARE(seed.value(0).toInt(), 1800);
    QVERIFY(seed.value(1).isNull());

    const QString invalidPath = directory.filePath(QStringLiteral("invalid.json"));
    QFile invalid(invalidPath);
    QVERIFY(invalid.open(QIODevice::WriteOnly));
    invalid.write("{}");
    invalid.close();
    QVERIFY(!backup.restoreJson(invalidPath));
    QVERIFY(seed.exec(QStringLiteral("SELECT COUNT(*) FROM cardio_record")) && seed.next());
    QCOMPARE(seed.value(0).toInt(), 1);
}

void BackupServiceTest::rejectsOversizedJsonBackup()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(directory.filePath(QStringLiteral("live.sqlite")), &error), qPrintable(error));

    const QString path = directory.filePath(QStringLiteral("oversized.json"));
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    QVERIFY(file.resize(64 * 1024 * 1024 + 1));
    file.close();

    fittrack::BackupService backup(manager.database());
    QVERIFY(!backup.restoreJson(path));
    QVERIFY(backup.errorMessage().contains(QStringLiteral("64MB")));
}

QTEST_GUILESS_MAIN(BackupServiceTest)
#include "tst_backupservice.moc"
