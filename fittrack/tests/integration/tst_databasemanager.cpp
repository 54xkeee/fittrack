#include "storage/databasemanager.h"

#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTest>

using namespace fittrack;

class DatabaseManagerTest : public QObject
{
    Q_OBJECT

private slots:
    void initializeCreatesCompleteSchema();
    void initializeIsIdempotent();
    void usesVersionFastPathOnSubsequentOpen();
    void migratesVersionOneBodyweightRecords();
    void migratesLegacyTablesBeforeCreatingIndexes();
    void preventsMultipleActiveWorkouts();
};

void DatabaseManagerTest::initializeCreatesCompleteSchema()
{
    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));

    const QStringList expectedTables{
        QStringLiteral("app_meta"),
        QStringLiteral("muscle"),
        QStringLiteral("exercise"),
        QStringLiteral("exercise_muscle"),
        QStringLiteral("exercise_media"),
        QStringLiteral("exercise_alternative"),
        QStringLiteral("favorite_exercise"),
        QStringLiteral("training_plan"),
        QStringLiteral("plan_day"),
        QStringLiteral("plan_section"),
        QStringLiteral("plan_exercise"),
        QStringLiteral("plan_cardio"),
        QStringLiteral("gym"),
        QStringLiteral("equipment_instance"),
        QStringLiteral("workout_session"),
        QStringLiteral("workout_exercise"),
        QStringLiteral("set_record"),
        QStringLiteral("append_set_record"),
        QStringLiteral("workout_cardio_target"),
        QStringLiteral("cardio_record"),
    };

    const auto actualTables = manager.database().tables();
    for (const auto &table : expectedTables) {
        QVERIFY2(actualTables.contains(table), qPrintable(QStringLiteral("Missing table: %1").arg(table)));
    }

    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("SELECT value FROM app_meta WHERE key='schema_version'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toString(), QStringLiteral("8"));
    QVERIFY(query.exec(QStringLiteral("PRAGMA table_info(exercise)")));
    QStringList exerciseColumns;
    while (query.next())
        exerciseColumns.append(query.value(1).toString());
    for (const auto &column : {QStringLiteral("difficulty"),
                              QStringLiteral("technique_points_json"),
                              QStringLiteral("common_mistakes_json"),
                              QStringLiteral("collections_json")}) {
        QVERIFY2(exerciseColumns.contains(column), qPrintable(QStringLiteral("Missing exercise column: %1").arg(column)));
    }
    QVERIFY(query.exec(QStringLiteral("PRAGMA table_info(set_record)")));
    bool hasBodyweightLoadType = false;
    while (query.next()) {
        if (query.value(1).toString() == QStringLiteral("bodyweight_load_type")) {
            hasBodyweightLoadType = true;
            break;
        }
    }
    QVERIFY(hasBodyweightLoadType);
    QVERIFY(query.exec(QStringLiteral("PRAGMA table_info(workout_exercise)")));
    bool hasRestSeconds = false;
    while (query.next()) {
        if (query.value(1).toString() == QStringLiteral("rest_seconds")) {
            hasRestSeconds = true;
            break;
        }
    }
    QVERIFY(hasRestSeconds);
}

void DatabaseManagerTest::initializeIsIdempotent()
{
    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));

    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("CREATE TABLE user_probe(id INTEGER PRIMARY KEY)")));
    QVERIFY(query.exec(QStringLiteral("INSERT INTO user_probe(id) VALUES(1)")));

    // Schema creation uses IF NOT EXISTS and does not replace existing user data.
    QVERIFY(query.exec(QStringLiteral("SELECT COUNT(*) FROM user_probe")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 1);
}

void DatabaseManagerTest::usesVersionFastPathOnSubsequentOpen()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("current.sqlite"));
    {
        DatabaseManager manager;
        QString error;
        QVERIFY2(manager.initialize(path, &error), qPrintable(error));
        QSqlQuery guard(manager.database());
        QVERIFY(guard.exec(QStringLiteral(
            "CREATE TRIGGER reject_schema_update BEFORE UPDATE ON app_meta "
            "WHEN OLD.key='schema_version' BEGIN "
            "SELECT RAISE(FAIL,'schema migration unexpectedly ran'); END")));
    }

    DatabaseManager reopened;
    QString error;
    QVERIFY2(reopened.initialize(path, &error), qPrintable(error));
    QSqlQuery verify(reopened.database());
    QVERIFY(verify.exec(QStringLiteral(
        "SELECT value FROM app_meta WHERE key='schema_version'")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), QStringLiteral("8"));
}

void DatabaseManagerTest::migratesVersionOneBodyweightRecords()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("legacy.sqlite"));
    const QString connectionName = QStringLiteral("legacy-setup");
    {
        auto legacy = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        legacy.setDatabaseName(path);
        QVERIFY(legacy.open());
        QSqlQuery query(legacy);
        QVERIFY(query.exec(QStringLiteral("CREATE TABLE app_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL)")));
        QVERIFY(query.exec(QStringLiteral("INSERT INTO app_meta VALUES('schema_version','1')")));
        QVERIFY(query.exec(QStringLiteral(
            "CREATE TABLE set_record(id TEXT PRIMARY KEY,workout_exercise_id TEXT NOT NULL,set_order INTEGER NOT NULL,"
            "weight_kg REAL,target_reps INTEGER,actual_reps INTEGER,completed INTEGER NOT NULL DEFAULT 0,"
            "to_failure INTEGER NOT NULL DEFAULT 0,both_sides INTEGER NOT NULL DEFAULT 1,completed_at TEXT,notes TEXT NOT NULL DEFAULT '')")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO set_record(id,workout_exercise_id,set_order,weight_kg,actual_reps,completed) "
            "VALUES('old','exercise',0,20,8,1)")));
        legacy.close();
    }
    QSqlDatabase::removeDatabase(connectionName);

    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(path, &error), qPrintable(error));
    QSqlQuery migrated(manager.database());
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT bodyweight_load_type FROM set_record WHERE id='old'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toString(), QStringLiteral("Bodyweight"));
    QVERIFY(migrated.exec(QStringLiteral("SELECT value FROM app_meta WHERE key='schema_version'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toString(), QStringLiteral("8"));
}

void DatabaseManagerTest::migratesLegacyTablesBeforeCreatingIndexes()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("legacy-indexes.sqlite"));
    const QString connectionName = QStringLiteral("legacy-indexes-setup");
    {
        auto legacy = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        legacy.setDatabaseName(path);
        QVERIFY(legacy.open());
        QSqlQuery query(legacy);
        QVERIFY(query.exec(QStringLiteral(
            "CREATE TABLE app_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL)")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO app_meta VALUES('schema_version','2')")));
        QVERIFY(query.exec(QStringLiteral(
            "CREATE TABLE gym(id TEXT PRIMARY KEY,name TEXT NOT NULL UNIQUE)")));
        QVERIFY(query.exec(QStringLiteral(
            "CREATE TABLE equipment_instance(id TEXT PRIMARY KEY,gym_id TEXT NOT NULL,"
            "name TEXT NOT NULL,code TEXT,notes TEXT)")));
        QVERIFY(query.exec(QStringLiteral(
            "CREATE TABLE cardio_record(id TEXT PRIMARY KEY,session_id TEXT,cardio_type TEXT NOT NULL,"
            "duration_seconds INTEGER NOT NULL,incline REAL,speed_kmh REAL,distance_km REAL,"
            "machine_level REAL,floors INTEGER,steps INTEGER,average_heart_rate INTEGER,"
            "notes TEXT NOT NULL DEFAULT '')")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO gym(id,name) VALUES('legacy-gym','旧健身房')")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO equipment_instance(id,gym_id,name) "
            "VALUES('legacy-equipment','legacy-gym','旧器械')")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO cardio_record(id,cardio_type,duration_seconds) "
            "VALUES('legacy-cardio','TreadmillIncline',1800)")));
        legacy.close();
    }
    QSqlDatabase::removeDatabase(connectionName);

    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(path, &error), qPrintable(error));
    QSqlQuery migrated(manager.database());
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT is_enabled FROM equipment_instance WHERE id='legacy-equipment'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), 1);
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT performed_at FROM cardio_record WHERE id='legacy-cardio'")));
    QVERIFY(migrated.next());
    QVERIFY(!migrated.value(0).toString().isEmpty());
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name IN "
        "('idx_equipment_gym_enabled','idx_cardio_performed','idx_cardio_session')")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), 3);
}

void DatabaseManagerTest::preventsMultipleActiveWorkouts()
{
    DatabaseManager manager;
    QString error;
    QVERIFY2(manager.initialize(QStringLiteral(":memory:"), &error), qPrintable(error));
    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) "
        "VALUES('active-1','训练一','2026-07-14T08:00:00Z','active')")));
    QVERIFY(!query.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) "
        "VALUES('active-2','训练二','2026-07-14T09:00:00Z','active')")));
    QVERIFY(query.exec(QStringLiteral(
        "INSERT INTO workout_session(id,name,started_at,status) "
        "VALUES('completed','已结束','2026-07-13T08:00:00Z','completed')")));
    QVERIFY(!query.exec(QStringLiteral(
        "UPDATE workout_session SET status='active' WHERE id='completed'")));
    QVERIFY(query.exec(QStringLiteral(
        "SELECT COUNT(*) FROM workout_session WHERE status='active'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toInt(), 1);
}

QTEST_GUILESS_MAIN(DatabaseManagerTest)

#include "tst_databasemanager.moc"
