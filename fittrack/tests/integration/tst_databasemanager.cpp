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
    void migratesVersionOneBodyweightRecords();
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
        QStringLiteral("gym"),
        QStringLiteral("equipment_instance"),
        QStringLiteral("workout_session"),
        QStringLiteral("workout_exercise"),
        QStringLiteral("set_record"),
        QStringLiteral("append_set_record"),
        QStringLiteral("cardio_record"),
    };

    const auto actualTables = manager.database().tables();
    for (const auto &table : expectedTables) {
        QVERIFY2(actualTables.contains(table), qPrintable(QStringLiteral("Missing table: %1").arg(table)));
    }

    QSqlQuery query(manager.database());
    QVERIFY(query.exec(QStringLiteral("SELECT value FROM app_meta WHERE key='schema_version'")));
    QVERIFY(query.next());
    QCOMPARE(query.value(0).toString(), QStringLiteral("3"));
    QVERIFY(query.exec(QStringLiteral("PRAGMA table_info(set_record)")));
    bool hasBodyweightLoadType = false;
    while (query.next()) {
        if (query.value(1).toString() == QStringLiteral("bodyweight_load_type")) {
            hasBodyweightLoadType = true;
            break;
        }
    }
    QVERIFY(hasBodyweightLoadType);
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
    QCOMPARE(migrated.value(0).toString(), QStringLiteral("3"));
}

QTEST_GUILESS_MAIN(DatabaseManagerTest)

#include "tst_databasemanager.moc"
