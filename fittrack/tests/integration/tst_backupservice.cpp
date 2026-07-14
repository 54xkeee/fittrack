#include "backup/backupservice.h"
#include "storage/databasemanager.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>

class BackupServiceTest final : public QObject
{
    Q_OBJECT
private slots:
    void exportsAndRestoresCompleteJsonBackup();
    void rejectsOversizedJsonBackup();
    void rejectsUnknownColumnsWithoutChangingData();
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
        "INSERT INTO training_plan(id,name,is_system,is_read_only) VALUES('plan','个人计划',0,0)")));
    QVERIFY(seed.exec(QStringLiteral(
        "INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES('day','plan','Push',0)")));
    QVERIFY(seed.exec(QStringLiteral(
        "INSERT INTO plan_cardio(day_id,cardio_type,duration_seconds,incline,speed_kmh,notes) "
        "VALUES('day','TreadmillIncline',1800,9,5,'计划目标')")));
    QVERIFY(seed.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) "
        "VALUES('session','Push','2026-07-13T09:00:00Z','completed')")));
    QVERIFY(seed.exec(QStringLiteral(
        "INSERT INTO workout_cardio_target(session_id,cardio_type,duration_seconds,incline,speed_kmh,notes) "
        "VALUES('session','TreadmillIncline',1800,9,5,'训练快照')")));
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
    QVERIFY(seed.exec(QStringLiteral("DELETE FROM plan_cardio")));
    QVERIFY(seed.exec(QStringLiteral("DELETE FROM workout_cardio_target")));
    QVERIFY(seed.exec(QStringLiteral("UPDATE gym SET name='已修改' WHERE id='gym'")));
    QVERIFY2(backup.restoreJson(jsonPath), qPrintable(backup.errorMessage()));
    QVERIFY(seed.exec(QStringLiteral("SELECT name FROM gym WHERE id='gym'")) && seed.next());
    QCOMPARE(seed.value(0).toString(), QStringLiteral("学校健身房"));
    QVERIFY(seed.exec(QStringLiteral("SELECT duration_seconds,distance_km FROM cardio_record WHERE id='cardio'")) && seed.next());
    QCOMPARE(seed.value(0).toInt(), 1800);
    QVERIFY(seed.value(1).isNull());
    QVERIFY(seed.exec(QStringLiteral(
        "SELECT duration_seconds,notes FROM plan_cardio WHERE day_id='day'")) && seed.next());
    QCOMPARE(seed.value(0).toInt(), 1800);
    QCOMPARE(seed.value(1).toString(), QStringLiteral("计划目标"));
    QVERIFY(seed.exec(QStringLiteral(
        "SELECT duration_seconds,notes FROM workout_cardio_target WHERE session_id='session'"))
            && seed.next());
    QCOMPARE(seed.value(0).toInt(), 1800);
    QCOMPARE(seed.value(1).toString(), QStringLiteral("训练快照"));

    QFile oldBackup(jsonPath);
    QVERIFY(oldBackup.open(QIODevice::ReadOnly));
    QJsonObject oldRoot = QJsonDocument::fromJson(oldBackup.readAll()).object();
    oldBackup.close();
    QJsonObject oldTables = oldRoot.value(QStringLiteral("tables")).toObject();
    oldTables.remove(QStringLiteral("plan_cardio"));
    oldTables.remove(QStringLiteral("workout_cardio_target"));
    QJsonArray oldMetadata = oldTables.value(QStringLiteral("app_meta")).toArray();
    for (qsizetype index = 0; index < oldMetadata.size(); ++index) {
        QJsonObject row = oldMetadata.at(index).toObject();
        if (row.value(QStringLiteral("key")).toString() == QStringLiteral("schema_version")) {
            row.insert(QStringLiteral("value"), QStringLiteral("3"));
            oldMetadata.replace(index, row);
        }
    }
    oldTables.insert(QStringLiteral("app_meta"), oldMetadata);
    oldRoot.insert(QStringLiteral("tables"), oldTables);
    const QString oldPath = directory.filePath(QStringLiteral("fittrack-old.json"));
    QFile oldFile(oldPath);
    QVERIFY(oldFile.open(QIODevice::WriteOnly));
    QVERIFY(oldFile.write(QJsonDocument(oldRoot).toJson()) > 0);
    oldFile.close();
    QVERIFY2(backup.restoreJson(oldPath), qPrintable(backup.errorMessage()));
    QVERIFY(seed.exec(QStringLiteral("SELECT COUNT(*) FROM plan_cardio")) && seed.next());
    QCOMPARE(seed.value(0).toInt(), 0);
    QVERIFY(seed.exec(QStringLiteral(
        "SELECT value FROM app_meta WHERE key='schema_version'")) && seed.next());
    QCOMPARE(seed.value(0).toString(), QStringLiteral("8"));

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

void BackupServiceTest::rejectsUnknownColumnsWithoutChangingData()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    fittrack::DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(directory.filePath(QStringLiteral("live.sqlite")), &error),
             qPrintable(error));
    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("INSERT INTO gym(id,name) VALUES('gym','原始值')")));

    fittrack::BackupService backup(manager.database());
    const QString path = directory.filePath(QStringLiteral("unknown-column.json"));
    QVERIFY2(backup.exportJson(path), qPrintable(backup.errorMessage()));

    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadOnly));
    QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    file.close();
    QJsonObject tableData = root.value(QStringLiteral("tables")).toObject();
    QJsonArray gyms = tableData.value(QStringLiteral("gym")).toArray();
    QJsonObject gym = gyms.first().toObject();
    gym.insert(QStringLiteral("name) VALUES('injected'); --"), QStringLiteral("攻击值"));
    gyms.replace(0, gym);
    tableData.insert(QStringLiteral("gym"), gyms);
    root.insert(QStringLiteral("tables"), tableData);
    QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate));
    QVERIFY(file.write(QJsonDocument(root).toJson()) > 0);
    file.close();

    QVERIFY(query.exec(QStringLiteral("UPDATE gym SET name='当前值' WHERE id='gym'")));
    QVERIFY(!backup.restoreJson(path));
    QVERIFY(backup.errorMessage().contains(QStringLiteral("未知字段")));
    QVERIFY(query.exec(QStringLiteral("SELECT name FROM gym WHERE id='gym'")) && query.next());
    QCOMPARE(query.value(0).toString(), QStringLiteral("当前值"));
}

QTEST_GUILESS_MAIN(BackupServiceTest)
#include "tst_backupservice.moc"
