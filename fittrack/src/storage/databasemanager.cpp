#include "storage/databasemanager.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QUuid>

namespace fittrack {

DatabaseManager::DatabaseManager()
    : m_connectionName(QStringLiteral("fittrack-%1").arg(
          QUuid::createUuid().toString(QUuid::WithoutBraces)))
{
}

DatabaseManager::~DatabaseManager()
{
    if (!QSqlDatabase::contains(m_connectionName)) {
        return;
    }

    {
        auto db = QSqlDatabase::database(m_connectionName, false);
        db.close();
    }
    QSqlDatabase::removeDatabase(m_connectionName);
}

bool DatabaseManager::initialize(const QString &databasePath, QString *errorMessage)
{
    auto db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    db.setDatabaseName(databasePath);
    if (!db.open()) {
        if (errorMessage) {
            *errorMessage = db.lastError().text();
        }
        return false;
    }

    if (!execute(QStringLiteral("PRAGMA foreign_keys = ON"), errorMessage)) {
        return false;
    }
    return createSchema(errorMessage);
}

QSqlDatabase DatabaseManager::database() const
{
    return QSqlDatabase::database(m_connectionName);
}

bool DatabaseManager::execute(const QString &statement, QString *errorMessage)
{
    QSqlQuery query(database());
    if (query.exec(statement)) {
        return true;
    }
    if (errorMessage) {
        *errorMessage = query.lastError().text();
    }
    return false;
}

bool DatabaseManager::createSchema(QString *errorMessage)
{
    const QStringList statements{
        QStringLiteral("CREATE TABLE IF NOT EXISTS app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS muscle (id TEXT PRIMARY KEY, name_zh TEXT NOT NULL UNIQUE, body_part TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise (id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, name_en TEXT, aliases_json TEXT NOT NULL DEFAULT '[]', body_part TEXT NOT NULL, movement TEXT NOT NULL, equipment_json TEXT NOT NULL DEFAULT '[]', load_mode TEXT NOT NULL, introduction TEXT NOT NULL DEFAULT '', steps_json TEXT NOT NULL DEFAULT '[]', cautions_json TEXT NOT NULL DEFAULT '[]', recommended_sets INTEGER NOT NULL DEFAULT 0, recommended_reps TEXT NOT NULL DEFAULT '', rest_seconds INTEGER NOT NULL DEFAULT 0, is_system INTEGER NOT NULL DEFAULT 1, is_enabled INTEGER NOT NULL DEFAULT 1, source_json TEXT NOT NULL DEFAULT '[]')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_muscle (exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, muscle_id TEXT NOT NULL REFERENCES muscle(id), role TEXT NOT NULL CHECK(role IN ('primary','secondary')), PRIMARY KEY(exercise_id, muscle_id, role))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_media (id INTEGER PRIMARY KEY AUTOINCREMENT, exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, media_type TEXT NOT NULL, local_path TEXT, external_url TEXT, title TEXT, source TEXT, license TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_alternative (exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, alternative_id TEXT NOT NULL REFERENCES exercise(id), PRIMARY KEY(exercise_id, alternative_id))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS favorite_exercise (exercise_id TEXT PRIMARY KEY REFERENCES exercise(id) ON DELETE CASCADE, created_at TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS training_plan (id TEXT PRIMARY KEY, name TEXT NOT NULL, source_plan_id TEXT REFERENCES training_plan(id), is_system INTEGER NOT NULL DEFAULT 0, is_read_only INTEGER NOT NULL DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_day (id TEXT PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES training_plan(id) ON DELETE CASCADE, name TEXT NOT NULL, sort_order INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_section (id TEXT PRIMARY KEY, day_id TEXT NOT NULL REFERENCES plan_day(id) ON DELETE CASCADE, name TEXT NOT NULL, sort_order INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_exercise (id TEXT PRIMARY KEY, day_id TEXT NOT NULL REFERENCES plan_day(id) ON DELETE CASCADE, section_id TEXT REFERENCES plan_section(id) ON DELETE SET NULL, exercise_id TEXT NOT NULL REFERENCES exercise(id), sort_order INTEGER NOT NULL, default_sets INTEGER NOT NULL, default_reps TEXT NOT NULL, rest_seconds INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS gym (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS equipment_instance (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL REFERENCES gym(id) ON DELETE CASCADE, name TEXT NOT NULL, code TEXT, notes TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS workout_session (id TEXT PRIMARY KEY, name TEXT NOT NULL, source_plan_id TEXT REFERENCES training_plan(id), gym_id TEXT REFERENCES gym(id), started_at TEXT NOT NULL, ended_at TEXT, status TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS workout_exercise (id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES workout_session(id) ON DELETE CASCADE, exercise_id TEXT NOT NULL REFERENCES exercise(id), equipment_instance_id TEXT REFERENCES equipment_instance(id), sort_order INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS set_record (id TEXT PRIMARY KEY, workout_exercise_id TEXT NOT NULL REFERENCES workout_exercise(id) ON DELETE CASCADE, set_order INTEGER NOT NULL, weight_kg REAL, target_reps INTEGER, actual_reps INTEGER, completed INTEGER NOT NULL DEFAULT 0, to_failure INTEGER NOT NULL DEFAULT 0, both_sides INTEGER NOT NULL DEFAULT 1, bodyweight_load_type TEXT NOT NULL DEFAULT 'Bodyweight', completed_at TEXT, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS append_set_record (id TEXT PRIMARY KEY, parent_set_id TEXT NOT NULL REFERENCES set_record(id) ON DELETE CASCADE, weight_kg REAL, reps INTEGER NOT NULL, rest_seconds INTEGER NOT NULL, to_failure INTEGER NOT NULL DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS cardio_record (id TEXT PRIMARY KEY, session_id TEXT REFERENCES workout_session(id) ON DELETE CASCADE, cardio_type TEXT NOT NULL, duration_seconds INTEGER NOT NULL, incline REAL, speed_kmh REAL, distance_km REAL, machine_level REAL, floors INTEGER, steps INTEGER, average_heart_rate INTEGER, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("INSERT OR IGNORE INTO app_meta(key, value) VALUES('schema_version', '2')"),
    };

    auto db = database();
    if (!db.transaction()) {
        if (errorMessage) {
            *errorMessage = db.lastError().text();
        }
        return false;
    }

    for (const auto &statement : statements) {
        if (!execute(statement, errorMessage)) {
            db.rollback();
            return false;
        }
    }

    bool hasBodyweightLoadType = false;
    QSqlQuery columns(db);
    if (!columns.exec(QStringLiteral("PRAGMA table_info(set_record)"))) {
        db.rollback();
        return false;
    }
    while (columns.next()) {
        if (columns.value(1).toString() == QStringLiteral("bodyweight_load_type")) {
            hasBodyweightLoadType = true;
            break;
        }
    }
    if (!hasBodyweightLoadType
        && !execute(QStringLiteral(
            "ALTER TABLE set_record ADD COLUMN bodyweight_load_type TEXT NOT NULL DEFAULT 'Bodyweight'"),
            errorMessage)) {
        db.rollback();
        return false;
    }
    if (!execute(QStringLiteral(
        "INSERT INTO app_meta(key,value) VALUES('schema_version','2') "
        "ON CONFLICT(key) DO UPDATE SET value='2'"), errorMessage)) {
        db.rollback();
        return false;
    }

    if (!db.commit()) {
        if (errorMessage) {
            *errorMessage = db.lastError().text();
        }
        return false;
    }
    return true;
}

} // namespace fittrack
