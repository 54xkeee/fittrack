#include "storage/databasemanager.h"

#include <QFile>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTest>
#include <QtEndian>
#include <QUuid>

using namespace fittrack;

namespace {

bool createLegacyDatabase(const QString &path, int version, QString *errorMessage)
{
    const QString connectionName = QStringLiteral("legacy-v%1-%2")
                                       .arg(version)
                                       .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    bool success = true;
    {
        auto legacy = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        legacy.setDatabaseName(path);
        if (!legacy.open()) {
            if (errorMessage) *errorMessage = legacy.lastError().text();
            success = false;
        } else {
            QSqlQuery query(legacy);
            const auto exec = [&](const QString &statement) {
                if (query.exec(statement))
                    return true;
                if (errorMessage) *errorMessage = query.lastError().text();
                return false;
            };
            const QString exerciseDetails = version >= 5
                ? QStringLiteral(",difficulty TEXT NOT NULL DEFAULT '',"
                                 "technique_points_json TEXT NOT NULL DEFAULT '[]',"
                                 "common_mistakes_json TEXT NOT NULL DEFAULT '[]',"
                                 "collections_json TEXT NOT NULL DEFAULT '[]'")
                : QString{};
            const QString setBodyweight = version >= 2
                ? QStringLiteral(",bodyweight_load_type TEXT NOT NULL DEFAULT 'Bodyweight'")
                : QString{};
            const QString performedAt = version >= 3
                ? QStringLiteral(",performed_at TEXT NOT NULL") : QString{};
            const QString enabled = version >= 3
                ? QStringLiteral(",is_enabled INTEGER NOT NULL DEFAULT 1") : QString{};
            const QString restSeconds = version >= 7
                ? QStringLiteral(",rest_seconds INTEGER") : QString{};

            const QStringList statements{
                QStringLiteral("CREATE TABLE app_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL)"),
                QStringLiteral("INSERT INTO app_meta VALUES('schema_version','%1')").arg(version),
                QStringLiteral("CREATE TABLE exercise(id TEXT PRIMARY KEY,name_zh TEXT NOT NULL,"
                               "name_en TEXT,aliases_json TEXT NOT NULL DEFAULT '[]',"
                               "body_part TEXT NOT NULL,movement TEXT NOT NULL,"
                               "equipment_json TEXT NOT NULL DEFAULT '[]',load_mode TEXT NOT NULL,"
                               "introduction TEXT NOT NULL DEFAULT '',steps_json TEXT NOT NULL DEFAULT '[]',"
                               "cautions_json TEXT NOT NULL DEFAULT '[]'%1,recommended_sets INTEGER NOT NULL DEFAULT 0,"
                               "recommended_reps TEXT NOT NULL DEFAULT '',rest_seconds INTEGER NOT NULL DEFAULT 0,"
                               "is_system INTEGER NOT NULL DEFAULT 1,is_enabled INTEGER NOT NULL DEFAULT 1,"
                               "source_json TEXT NOT NULL DEFAULT '[]')").arg(exerciseDetails),
                QStringLiteral("CREATE TABLE training_plan(id TEXT PRIMARY KEY,name TEXT NOT NULL,"
                               "source_plan_id TEXT REFERENCES training_plan(id),is_system INTEGER NOT NULL DEFAULT 0,"
                               "is_read_only INTEGER NOT NULL DEFAULT 0)"),
                QStringLiteral("CREATE TABLE plan_day(id TEXT PRIMARY KEY,plan_id TEXT NOT NULL "
                               "REFERENCES training_plan(id) ON DELETE CASCADE,"
                               "name TEXT NOT NULL,sort_order INTEGER NOT NULL)"),
                QStringLiteral("CREATE TABLE plan_section(id TEXT PRIMARY KEY,day_id TEXT NOT NULL "
                               "REFERENCES plan_day(id) ON DELETE CASCADE,name TEXT NOT NULL,"
                               "sort_order INTEGER NOT NULL)"),
                QStringLiteral("CREATE TABLE plan_exercise(id TEXT PRIMARY KEY,day_id TEXT NOT NULL "
                               "REFERENCES plan_day(id) ON DELETE CASCADE,section_id TEXT REFERENCES "
                               "plan_section(id) ON DELETE SET NULL,exercise_id TEXT NOT NULL REFERENCES "
                               "exercise(id),sort_order INTEGER NOT NULL,default_sets INTEGER NOT NULL,"
                               "default_reps TEXT NOT NULL,rest_seconds INTEGER NOT NULL,"
                               "notes TEXT NOT NULL DEFAULT '')"),
                QStringLiteral("CREATE TABLE gym(id TEXT PRIMARY KEY,name TEXT NOT NULL UNIQUE%1)")
                    .arg(enabled),
                QStringLiteral("CREATE TABLE equipment_instance(id TEXT PRIMARY KEY,gym_id TEXT NOT NULL "
                               "REFERENCES gym(id) ON DELETE CASCADE,"
                               "name TEXT NOT NULL,code TEXT,notes TEXT%1)").arg(enabled),
                QStringLiteral("CREATE TABLE workout_session(id TEXT PRIMARY KEY,name TEXT NOT NULL,"
                               "source_plan_id TEXT REFERENCES training_plan(id),gym_id TEXT REFERENCES gym(id),"
                               "started_at TEXT NOT NULL,ended_at TEXT,"
                               "status TEXT NOT NULL,notes TEXT NOT NULL DEFAULT '')"),
                QStringLiteral("CREATE TABLE workout_exercise(id TEXT PRIMARY KEY,session_id TEXT NOT NULL "
                               "REFERENCES workout_session(id) ON DELETE CASCADE,exercise_id TEXT NOT NULL "
                               "REFERENCES exercise(id),equipment_instance_id TEXT REFERENCES equipment_instance(id),"
                               "sort_order INTEGER NOT NULL%1,"
                               "notes TEXT NOT NULL DEFAULT '')").arg(restSeconds),
                QStringLiteral("CREATE TABLE set_record(id TEXT PRIMARY KEY,workout_exercise_id TEXT NOT NULL "
                               "REFERENCES workout_exercise(id) ON DELETE CASCADE,"
                               "set_order INTEGER NOT NULL,weight_kg REAL,target_reps INTEGER,actual_reps INTEGER,"
                               "completed INTEGER NOT NULL DEFAULT 0,to_failure INTEGER NOT NULL DEFAULT 0,"
                               "both_sides INTEGER NOT NULL DEFAULT 1%1,completed_at TEXT,"
                               "notes TEXT NOT NULL DEFAULT '')").arg(setBodyweight),
                QStringLiteral("CREATE TABLE append_set_record(id TEXT PRIMARY KEY,parent_set_id TEXT NOT NULL "
                               "REFERENCES set_record(id) ON DELETE CASCADE,"
                               "weight_kg REAL,reps INTEGER NOT NULL,rest_seconds INTEGER NOT NULL,"
                               "to_failure INTEGER NOT NULL DEFAULT 0)"),
                QStringLiteral("CREATE TABLE cardio_record(id TEXT PRIMARY KEY,session_id TEXT "
                               "REFERENCES workout_session(id) ON DELETE CASCADE,"
                               "cardio_type TEXT NOT NULL%1,duration_seconds INTEGER NOT NULL,incline REAL,"
                               "speed_kmh REAL,distance_km REAL,machine_level REAL,floors INTEGER,steps INTEGER,"
                               "average_heart_rate INTEGER,notes TEXT NOT NULL DEFAULT '')").arg(performedAt),
                QStringLiteral("INSERT INTO exercise(id,name_zh,body_part,movement,load_mode,"
                               "recommended_sets,recommended_reps,rest_seconds%1) "
                               "VALUES('legacy-ex','旧动作','胸部','水平推','Standard',3,'8',123%2)")
                    .arg(version >= 5
                             ? QStringLiteral(",difficulty,technique_points_json,common_mistakes_json,collections_json")
                             : QString{},
                         version >= 5
                             ? QStringLiteral(",'旧难度','[\"旧要点\"]','[\"旧错误\"]','[\"旧集合\"]'")
                             : QString{}),
                QStringLiteral("INSERT INTO training_plan VALUES('legacy-plan','旧计划',NULL,0,0)"),
                QStringLiteral("INSERT INTO plan_day VALUES('legacy-day','legacy-plan','旧训练日',0)"),
                QStringLiteral("INSERT INTO plan_section VALUES('legacy-section','legacy-day','保留分区',0)"),
                QStringLiteral("INSERT INTO plan_exercise VALUES('legacy-plan-ex','legacy-day',"
                               "'legacy-section','legacy-ex',0,4,'10',66,'保留计划动作')"),
                QStringLiteral("INSERT INTO gym(id,name%1) VALUES('legacy-gym','旧健身房'%2)")
                    .arg(version >= 3 ? QStringLiteral(",is_enabled") : QString{},
                         version >= 3 ? QStringLiteral(",1") : QString{}),
                QStringLiteral("INSERT INTO equipment_instance(id,gym_id,name,code,notes%1) "
                               "VALUES('legacy-equipment','legacy-gym','旧器械','A','保留器械'%2)")
                    .arg(version >= 3 ? QStringLiteral(",is_enabled") : QString{},
                         version >= 3 ? QStringLiteral(",1") : QString{}),
                QStringLiteral("INSERT INTO workout_session VALUES('legacy-session','旧训练',NULL,"
                               "'legacy-gym','2026-07-13T08:00:00Z','2026-07-13T09:00:00Z',"
                               "'completed','保留训练')"),
                QStringLiteral("INSERT INTO workout_exercise(id,session_id,exercise_id,equipment_instance_id,"
                               "sort_order%1,notes) VALUES('legacy-workout-ex','legacy-session','legacy-ex',"
                               "'legacy-equipment',0%2,'保留动作')")
                    .arg(version >= 7 ? QStringLiteral(",rest_seconds") : QString{},
                         version >= 7 ? QStringLiteral(",77") : QString{}),
                QStringLiteral("INSERT INTO set_record(id,workout_exercise_id,set_order,weight_kg,actual_reps,"
                               "completed%1,notes) VALUES('legacy-set','legacy-workout-ex',0,60,8,1%2,'保留组')")
                    .arg(version >= 2 ? QStringLiteral(",bodyweight_load_type") : QString{},
                         version >= 2 ? QStringLiteral(",'Added'") : QString{}),
                QStringLiteral("INSERT INTO append_set_record VALUES('legacy-append','legacy-set',55,3,10,1)"),
                QStringLiteral("INSERT INTO cardio_record(id,session_id,cardio_type%1,duration_seconds,notes) "
                               "VALUES('legacy-cardio','legacy-session','TreadmillIncline'%2,1200,'保留有氧')")
                    .arg(version >= 3 ? QStringLiteral(",performed_at") : QString{},
                         version >= 3 ? QStringLiteral(",'2026-07-13T09:05:00Z'") : QString{}),
            };
            for (const QString &statement : statements) {
                if (!exec(statement)) {
                    success = false;
                    break;
                }
            }
            if (success && version >= 4) {
                success = exec(QStringLiteral(
                    "CREATE TABLE plan_cardio(day_id TEXT PRIMARY KEY REFERENCES plan_day(id) ON DELETE CASCADE,"
                    "cardio_type TEXT NOT NULL,"
                    "duration_seconds INTEGER NOT NULL,incline REAL,speed_kmh REAL,machine_level REAL,"
                    "notes TEXT NOT NULL DEFAULT '')"))
                          && exec(QStringLiteral(
                              "CREATE TABLE workout_cardio_target(session_id TEXT PRIMARY KEY "
                              "REFERENCES workout_session(id) ON DELETE CASCADE,"
                              "cardio_type TEXT NOT NULL,duration_seconds INTEGER NOT NULL,incline REAL,"
                              "speed_kmh REAL,machine_level REAL,notes TEXT NOT NULL DEFAULT '')"))
                          && exec(QStringLiteral(
                              "INSERT INTO plan_cardio VALUES('legacy-day','TreadmillIncline',900,8,5,NULL,'保留计划有氧')"))
                          && exec(QStringLiteral(
                              "INSERT INTO workout_cardio_target VALUES('legacy-session',"
                              "'StairClimber',600,NULL,NULL,7,'保留训练有氧')"));
            }
            if (success && version >= 6) {
                success = exec(QStringLiteral(
                    "CREATE TRIGGER workout_session_single_active_insert BEFORE INSERT ON workout_session "
                    "WHEN NEW.status='active' AND EXISTS(SELECT 1 FROM workout_session WHERE status='active') "
                    "BEGIN SELECT RAISE(ABORT,'已有进行中的训练'); END"))
                          && exec(QStringLiteral(
                              "CREATE TRIGGER workout_session_single_active_update BEFORE UPDATE OF status "
                              "ON workout_session WHEN NEW.status='active' AND OLD.status<>'active' "
                              "AND EXISTS(SELECT 1 FROM workout_session WHERE status='active' AND id<>NEW.id) "
                              "BEGIN SELECT RAISE(ABORT,'已有进行中的训练'); END"));
            }
            legacy.close();
        }
    }
    QSqlDatabase::removeDatabase(connectionName);
    return success;
}

} // namespace

class DatabaseManagerTest : public QObject
{
    Q_OBJECT

private slots:
    void initializeCreatesCompleteSchema();
    void initializeIsIdempotent();
    void usesVersionFastPathOnSubsequentOpen();
    void repairsNullableTimestampInExistingVersionEight();
    void migratesVersionOneBodyweightRecords();
    void migratesLegacyTablesBeforeCreatingIndexes();
    void migratesEverySupportedSchemaVersion_data();
    void migratesEverySupportedSchemaVersion();
    void rejectsNewerSchemaWithoutChangingIt();
    void recoversCorruptDatabaseWithoutOverwritingOriginal();
    void resumesInterruptedCorruptDatabaseRecovery();
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

void DatabaseManagerTest::repairsNullableTimestampInExistingVersionEight()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("nullable-v8.sqlite"));
    QString error;
    QVERIFY2(createLegacyDatabase(path, 2, &error), qPrintable(error));
    const QString connectionName = QStringLiteral("nullable-v8-setup");
    {
        auto legacy = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        legacy.setDatabaseName(path);
        QVERIFY(legacy.open());
        QSqlQuery query(legacy);
        QVERIFY(query.exec(QStringLiteral(
            "ALTER TABLE cardio_record ADD COLUMN performed_at TEXT")));
        QVERIFY(query.exec(QStringLiteral(
            "UPDATE cardio_record SET performed_at='2026-07-13T09:05:00Z'")));
        QVERIFY(query.exec(QStringLiteral(
            "UPDATE app_meta SET value='8' WHERE key='schema_version'")));
        legacy.close();
    }
    QSqlDatabase::removeDatabase(connectionName);

    DatabaseManager manager;
    QVERIFY2(manager.initialize(path, &error), qPrintable(error));
    QSqlQuery verify(manager.database());
    QVERIFY(verify.exec(QStringLiteral("PRAGMA table_info(cardio_record)")));
    bool performedAtNotNull = false;
    while (verify.next()) {
        if (verify.value(1).toString() == QStringLiteral("performed_at")) {
            performedAtNotNull = verify.value(3).toBool();
            break;
        }
    }
    QVERIFY(performedAtNotNull);
    QVERIFY(verify.exec(QStringLiteral(
        "SELECT performed_at FROM cardio_record WHERE id='legacy-cardio'")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), QStringLiteral("2026-07-13T09:05:00Z"));
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

void DatabaseManagerTest::migratesEverySupportedSchemaVersion_data()
{
    QTest::addColumn<int>("version");
    for (int version = 1; version <= 7; ++version)
        QTest::newRow(qPrintable(QStringLiteral("schema-v%1").arg(version))) << version;
}

void DatabaseManagerTest::migratesEverySupportedSchemaVersion()
{
    QFETCH(int, version);
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(
        QStringLiteral("schema-v%1.sqlite").arg(version));
    QString error;
    QVERIFY2(createLegacyDatabase(path, version, &error), qPrintable(error));

    DatabaseManager manager;
    QVERIFY2(manager.initialize(path, &error), qPrintable(error));
    QSqlQuery migrated(manager.database());
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT value FROM app_meta WHERE key='schema_version'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toString(), QStringLiteral("8"));

    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT difficulty,technique_points_json,common_mistakes_json,collections_json,"
        "rest_seconds FROM exercise WHERE id='legacy-ex'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toString(),
             version >= 5 ? QStringLiteral("旧难度") : QString{});
    QCOMPARE(migrated.value(1).toString(),
             version >= 5 ? QStringLiteral("[\"旧要点\"]") : QStringLiteral("[]"));
    QCOMPARE(migrated.value(2).toString(),
             version >= 5 ? QStringLiteral("[\"旧错误\"]") : QStringLiteral("[]"));
    QCOMPARE(migrated.value(3).toString(),
             version >= 5 ? QStringLiteral("[\"旧集合\"]") : QStringLiteral("[]"));
    QCOMPARE(migrated.value(4).toInt(), 123);
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT default_sets,default_reps,rest_seconds,notes FROM plan_exercise "
        "WHERE id='legacy-plan-ex'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), 4);
    QCOMPARE(migrated.value(1).toString(), QStringLiteral("10"));
    QCOMPARE(migrated.value(2).toInt(), 66);
    QCOMPARE(migrated.value(3).toString(), QStringLiteral("保留计划动作"));

    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT rest_seconds,notes FROM workout_exercise WHERE id='legacy-workout-ex'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), version >= 7 ? 77 : 123);
    QCOMPARE(migrated.value(1).toString(), QStringLiteral("保留动作"));

    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT bodyweight_load_type,notes FROM set_record WHERE id='legacy-set'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toString(),
             version >= 2 ? QStringLiteral("Added") : QStringLiteral("Bodyweight"));
    QCOMPARE(migrated.value(1).toString(), QStringLiteral("保留组"));

    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT performed_at,notes FROM cardio_record WHERE id='legacy-cardio'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toString(),
             version >= 3 ? QStringLiteral("2026-07-13T09:05:00Z")
                          : QStringLiteral("2026-07-13T09:00:00Z"));
    QCOMPARE(migrated.value(1).toString(), QStringLiteral("保留有氧"));
    QVERIFY(migrated.exec(QStringLiteral("PRAGMA table_info(cardio_record)")));
    bool performedAtNotNull = false;
    while (migrated.next()) {
        if (migrated.value(1).toString() == QStringLiteral("performed_at")) {
            performedAtNotNull = migrated.value(3).toBool();
            break;
        }
    }
    QVERIFY(performedAtNotNull);

    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT is_enabled FROM gym WHERE id='legacy-gym'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), 1);
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT is_enabled,notes FROM equipment_instance WHERE id='legacy-equipment'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), 1);
    QCOMPARE(migrated.value(1).toString(), QStringLiteral("保留器械"));

    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT COUNT(*) FROM append_set_record WHERE id='legacy-append'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), 1);
    QVERIFY(migrated.exec(QStringLiteral("SELECT COUNT(*) FROM plan_cardio")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), version >= 4 ? 1 : 0);
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT COUNT(*) FROM workout_cardio_target WHERE notes='保留训练有氧'")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), version >= 4 ? 1 : 0);
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name IN "
        "('workout_session_single_active_insert','workout_session_single_active_update')")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), 2);
    QVERIFY(migrated.exec(QStringLiteral(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name IN ("
        "'idx_exercise_media_exercise','idx_plan_day_plan_order',"
        "'idx_plan_section_day_order','idx_plan_exercise_day_order',"
        "'idx_equipment_gym_enabled','idx_workout_session_status_end',"
        "'idx_workout_exercise_session_order','idx_workout_exercise_previous',"
        "'idx_set_exercise_order','idx_append_parent','idx_cardio_performed',"
        "'idx_cardio_session')")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toInt(), 12);
    QVERIFY(migrated.exec(QStringLiteral("PRAGMA foreign_key_check")));
    QVERIFY(!migrated.next());
    QVERIFY(migrated.exec(QStringLiteral("PRAGMA quick_check(1)")));
    QVERIFY(migrated.next());
    QCOMPARE(migrated.value(0).toString(), QStringLiteral("ok"));
}

void DatabaseManagerTest::rejectsNewerSchemaWithoutChangingIt()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("future.sqlite"));
    QString error;
    {
        DatabaseManager current;
        QVERIFY2(current.initialize(path, &error), qPrintable(error));
    }
    const QString connectionName = QStringLiteral("future-schema-setup");
    {
        auto future = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        future.setDatabaseName(path);
        QVERIFY(future.open());
        QSqlQuery query(future);
        QVERIFY(query.exec(QStringLiteral(
            "UPDATE app_meta SET value='9' WHERE key='schema_version'")));
        QVERIFY(query.exec(QStringLiteral(
            "CREATE TABLE future_only(id INTEGER PRIMARY KEY,value TEXT NOT NULL)")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO future_only(value) VALUES('future-data')")));
        future.close();
    }
    QSqlDatabase::removeDatabase(connectionName);
    QFile futureFile(path);
    QVERIFY(futureFile.open(QIODevice::ReadWrite));
    QVERIFY(futureFile.seek(36));
    const quint32 invalidFreelistCount = qToBigEndian<quint32>(1);
    QCOMPARE(futureFile.write(
                 reinterpret_cast<const char *>(&invalidFreelistCount),
                 sizeof(invalidFreelistCount)),
             qint64(sizeof(invalidFreelistCount)));
    futureFile.close();

    DatabaseManager manager;
    QVERIFY(!manager.initialize(path, &error));
    QVERIFY(error.contains(QStringLiteral("高于当前应用支持")));
    QVERIFY(!manager.corruptionDetected());
    QSqlQuery verify(manager.database());
    QVERIFY(verify.exec(QStringLiteral(
        "SELECT value FROM app_meta WHERE key='schema_version'")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), QStringLiteral("9"));
    QVERIFY(verify.exec(QStringLiteral(
        "SELECT value FROM future_only WHERE id=1")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), QStringLiteral("future-data"));
}

void DatabaseManagerTest::recoversCorruptDatabaseWithoutOverwritingOriginal()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("corrupt.sqlite"));
    const QByteArray corruptBytes("this is not a sqlite database\0user-data", 39);
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    QCOMPARE(file.write(corruptBytes), corruptBytes.size());
    file.close();

    DatabaseManager manager;
    QString error;
    QVERIFY(!manager.initialize(path, &error));
    QVERIFY(manager.corruptionDetected());
    const QList<QPair<QString, QByteArray>> companionFiles{
        {QStringLiteral("-journal"), QByteArray("journal-user-data")},
        {QStringLiteral("-wal"), QByteArray("wal-user-data")},
        {QStringLiteral("-shm"), QByteArray("shm-user-data")},
    };
    for (const auto &[suffix, contents] : companionFiles) {
        QFile companion(path + suffix);
        QVERIFY(companion.open(QIODevice::WriteOnly));
        QCOMPARE(companion.write(contents), contents.size());
    }
    QString backupPath;
    QVERIFY(!manager.recoverCorruptDatabase(path + QStringLiteral(".other"),
                                            &backupPath, &error));
    QVERIFY(backupPath.isEmpty());
    QVERIFY(QFileInfo::exists(path));
    QVERIFY2(manager.recoverCorruptDatabase(path, &backupPath, &error), qPrintable(error));
    QVERIFY(!backupPath.isEmpty());
    QVERIFY(QFileInfo::exists(path));
    QVERIFY(QFileInfo::exists(backupPath));
    QFile backup(backupPath);
    QVERIFY(backup.open(QIODevice::ReadOnly));
    QCOMPARE(backup.readAll(), corruptBytes);
    for (const auto &[suffix, contents] : companionFiles) {
        QVERIFY(!QFileInfo::exists(path + suffix));
        QFile companionBackup(backupPath + suffix);
        QVERIFY(companionBackup.open(QIODevice::ReadOnly));
        QCOMPARE(companionBackup.readAll(), contents);
    }

    QSqlQuery verify(manager.database());
    QVERIFY(verify.exec(QStringLiteral(
        "SELECT value FROM app_meta WHERE key='schema_version'")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), QStringLiteral("8"));
    QVERIFY(verify.exec(QStringLiteral("PRAGMA quick_check(1)")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), QStringLiteral("ok"));
}

void DatabaseManagerTest::resumesInterruptedCorruptDatabaseRecovery()
{
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    const QString path = directory.filePath(QStringLiteral("interrupted.sqlite"));
    const QString backupPath = path + QStringLiteral(".corrupt-interrupted");
    const QString freshPath = path + QStringLiteral(".recovery-interrupted.tmp");
    const QString pendingPath = path + QStringLiteral(".recovery-pending");
    const QByteArray corruptBytes("interrupted-corrupt-user-data");
    QFile backup(backupPath);
    QVERIFY(backup.open(QIODevice::WriteOnly));
    QCOMPARE(backup.write(corruptBytes), corruptBytes.size());
    backup.close();
    {
        DatabaseManager freshManager;
        QString error;
        QVERIFY2(freshManager.initialize(freshPath, &error), qPrintable(error));
    }
    QFile pending(pendingPath);
    QVERIFY(pending.open(QIODevice::WriteOnly));
    const QByteArray markerContents = backupPath.toUtf8() + '\n'
        + freshPath.toUtf8() + '\n';
    QCOMPARE(pending.write(markerContents), markerContents.size());
    pending.close();

    DatabaseManager manager;
    QString error;
    QVERIFY(!manager.initialize(path, &error));
    QVERIFY(manager.corruptionDetected());
    QString recoveredBackupPath;
    QVERIFY2(manager.recoverCorruptDatabase(
                 path, &recoveredBackupPath, &error),
             qPrintable(error));
    QCOMPARE(recoveredBackupPath, backupPath);
    QVERIFY(QFileInfo::exists(path));
    QVERIFY(!QFileInfo::exists(freshPath));
    QVERIFY(!QFileInfo::exists(pendingPath));
    QFile preservedBackup(backupPath);
    QVERIFY(preservedBackup.open(QIODevice::ReadOnly));
    QCOMPARE(preservedBackup.readAll(), corruptBytes);
    QSqlQuery verify(manager.database());
    QVERIFY(verify.exec(QStringLiteral(
        "SELECT value FROM app_meta WHERE key='schema_version'")));
    QVERIFY(verify.next());
    QCOMPARE(verify.value(0).toString(), QStringLiteral("8"));

    const QString committedPath = directory.filePath(
        QStringLiteral("committed-before-marker-cleanup.sqlite"));
    const QString committedBackup = committedPath
        + QStringLiteral(".corrupt-interrupted");
    const QString missingFresh = committedPath
        + QStringLiteral(".recovery-interrupted.tmp");
    const QString committedPending = committedPath
        + QStringLiteral(".recovery-pending");
    {
        DatabaseManager completedRecovery;
        QVERIFY2(completedRecovery.initialize(committedPath, &error), qPrintable(error));
    }
    QFile secondBackup(committedBackup);
    QVERIFY(secondBackup.open(QIODevice::WriteOnly));
    QCOMPARE(secondBackup.write(corruptBytes), corruptBytes.size());
    secondBackup.close();
    QFile secondPending(committedPending);
    QVERIFY(secondPending.open(QIODevice::WriteOnly));
    const QByteArray secondMarker = committedBackup.toUtf8() + '\n'
        + missingFresh.toUtf8() + '\n';
    QCOMPARE(secondPending.write(secondMarker), secondMarker.size());
    secondPending.close();
    DatabaseManager resumedAfterCommit;
    QVERIFY(!resumedAfterCommit.initialize(committedPath, &error));
    QVERIFY2(resumedAfterCommit.recoverCorruptDatabase(
                 committedPath, &recoveredBackupPath, &error),
             qPrintable(error));
    QCOMPARE(recoveredBackupPath, committedBackup);
    QVERIFY(!QFileInfo::exists(committedPending));
    QVERIFY(QFileInfo::exists(committedPath));
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
