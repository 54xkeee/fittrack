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
    QSqlQuery version(db);
    if (version.exec(QStringLiteral(
            "SELECT value FROM app_meta WHERE key='schema_version'"))
        && version.next() && version.value(0).toString() == QStringLiteral("8")) {
        return true;
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
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise (id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, name_en TEXT, aliases_json TEXT NOT NULL DEFAULT '[]', body_part TEXT NOT NULL, movement TEXT NOT NULL, equipment_json TEXT NOT NULL DEFAULT '[]', load_mode TEXT NOT NULL, introduction TEXT NOT NULL DEFAULT '', steps_json TEXT NOT NULL DEFAULT '[]', cautions_json TEXT NOT NULL DEFAULT '[]', difficulty TEXT NOT NULL DEFAULT '', technique_points_json TEXT NOT NULL DEFAULT '[]', common_mistakes_json TEXT NOT NULL DEFAULT '[]', collections_json TEXT NOT NULL DEFAULT '[]', recommended_sets INTEGER NOT NULL DEFAULT 0, recommended_reps TEXT NOT NULL DEFAULT '', rest_seconds INTEGER NOT NULL DEFAULT 0, is_system INTEGER NOT NULL DEFAULT 1, is_enabled INTEGER NOT NULL DEFAULT 1, source_json TEXT NOT NULL DEFAULT '[]')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_muscle (exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, muscle_id TEXT NOT NULL REFERENCES muscle(id), role TEXT NOT NULL CHECK(role IN ('primary','secondary')), PRIMARY KEY(exercise_id, muscle_id, role))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_media (id INTEGER PRIMARY KEY AUTOINCREMENT, exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, media_type TEXT NOT NULL, local_path TEXT, external_url TEXT, title TEXT, source TEXT, license TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_alternative (exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, alternative_id TEXT NOT NULL REFERENCES exercise(id), PRIMARY KEY(exercise_id, alternative_id))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS favorite_exercise (exercise_id TEXT PRIMARY KEY REFERENCES exercise(id) ON DELETE CASCADE, created_at TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS training_plan (id TEXT PRIMARY KEY, name TEXT NOT NULL, source_plan_id TEXT REFERENCES training_plan(id), is_system INTEGER NOT NULL DEFAULT 0, is_read_only INTEGER NOT NULL DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_day (id TEXT PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES training_plan(id) ON DELETE CASCADE, name TEXT NOT NULL, sort_order INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_section (id TEXT PRIMARY KEY, day_id TEXT NOT NULL REFERENCES plan_day(id) ON DELETE CASCADE, name TEXT NOT NULL, sort_order INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_exercise (id TEXT PRIMARY KEY, day_id TEXT NOT NULL REFERENCES plan_day(id) ON DELETE CASCADE, section_id TEXT REFERENCES plan_section(id) ON DELETE SET NULL, exercise_id TEXT NOT NULL REFERENCES exercise(id), sort_order INTEGER NOT NULL, default_sets INTEGER NOT NULL, default_reps TEXT NOT NULL, rest_seconds INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_cardio (day_id TEXT PRIMARY KEY REFERENCES plan_day(id) ON DELETE CASCADE, cardio_type TEXT NOT NULL CHECK(cardio_type IN ('TreadmillIncline','StairClimber')), duration_seconds INTEGER NOT NULL CHECK(duration_seconds > 0), incline REAL, speed_kmh REAL, machine_level REAL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS gym (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, is_enabled INTEGER NOT NULL DEFAULT 1)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS equipment_instance (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL REFERENCES gym(id) ON DELETE CASCADE, name TEXT NOT NULL, code TEXT, notes TEXT, is_enabled INTEGER NOT NULL DEFAULT 1)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS workout_session (id TEXT PRIMARY KEY, name TEXT NOT NULL, source_plan_id TEXT REFERENCES training_plan(id), gym_id TEXT REFERENCES gym(id), started_at TEXT NOT NULL, ended_at TEXT, status TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS workout_exercise (id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES workout_session(id) ON DELETE CASCADE, exercise_id TEXT NOT NULL REFERENCES exercise(id), equipment_instance_id TEXT REFERENCES equipment_instance(id), sort_order INTEGER NOT NULL, rest_seconds INTEGER, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS set_record (id TEXT PRIMARY KEY, workout_exercise_id TEXT NOT NULL REFERENCES workout_exercise(id) ON DELETE CASCADE, set_order INTEGER NOT NULL, weight_kg REAL, target_reps INTEGER, actual_reps INTEGER, completed INTEGER NOT NULL DEFAULT 0, to_failure INTEGER NOT NULL DEFAULT 0, both_sides INTEGER NOT NULL DEFAULT 1, bodyweight_load_type TEXT NOT NULL DEFAULT 'Bodyweight', completed_at TEXT, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS append_set_record (id TEXT PRIMARY KEY, parent_set_id TEXT NOT NULL REFERENCES set_record(id) ON DELETE CASCADE, weight_kg REAL, reps INTEGER NOT NULL, rest_seconds INTEGER NOT NULL, to_failure INTEGER NOT NULL DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS workout_cardio_target (session_id TEXT PRIMARY KEY REFERENCES workout_session(id) ON DELETE CASCADE, cardio_type TEXT NOT NULL CHECK(cardio_type IN ('TreadmillIncline','StairClimber')), duration_seconds INTEGER NOT NULL CHECK(duration_seconds > 0), incline REAL, speed_kmh REAL, machine_level REAL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS cardio_record (id TEXT PRIMARY KEY, session_id TEXT REFERENCES workout_session(id) ON DELETE CASCADE, cardio_type TEXT NOT NULL, performed_at TEXT NOT NULL, duration_seconds INTEGER NOT NULL, incline REAL, speed_kmh REAL, distance_km REAL, machine_level REAL, floors INTEGER, steps INTEGER, average_heart_rate INTEGER, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TRIGGER IF NOT EXISTS workout_session_single_active_insert "
                       "BEFORE INSERT ON workout_session WHEN NEW.status='active' "
                       "AND EXISTS(SELECT 1 FROM workout_session WHERE status='active') "
                       "BEGIN SELECT RAISE(ABORT, '已有进行中的训练'); END"),
        QStringLiteral("CREATE TRIGGER IF NOT EXISTS workout_session_single_active_update "
                       "BEFORE UPDATE OF status ON workout_session WHEN NEW.status='active' "
                       "AND OLD.status<>'active' AND EXISTS(SELECT 1 FROM workout_session "
                       "WHERE status='active' AND id<>NEW.id) "
                       "BEGIN SELECT RAISE(ABORT, '已有进行中的训练'); END"),
        QStringLiteral("INSERT OR IGNORE INTO app_meta(key, value) VALUES('schema_version', '8')"),
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

    const auto hasColumn = [&db](const QString &table, const QString &column) {
        QSqlQuery columns(db);
        if (!columns.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table))) {
            return false;
        }
        while (columns.next()) {
            if (columns.value(1).toString() == column) return true;
        }
        return false;
    };
    if (!hasColumn(QStringLiteral("set_record"), QStringLiteral("bodyweight_load_type"))
        && !execute(QStringLiteral(
            "ALTER TABLE set_record ADD COLUMN bodyweight_load_type TEXT NOT NULL DEFAULT 'Bodyweight'"),
            errorMessage)) {
        db.rollback();
        return false;
    }
    if (!hasColumn(QStringLiteral("cardio_record"), QStringLiteral("performed_at"))) {
        if (!execute(QStringLiteral("ALTER TABLE cardio_record ADD COLUMN performed_at TEXT"), errorMessage)
            || !execute(QStringLiteral(
                "UPDATE cardio_record SET performed_at=COALESCE("
                "(SELECT ended_at FROM workout_session WHERE id=cardio_record.session_id),"
                "strftime('%Y-%m-%dT%H:%M:%SZ','now')) WHERE performed_at IS NULL"), errorMessage)) {
            db.rollback();
            return false;
        }
    }
    if (!hasColumn(QStringLiteral("gym"), QStringLiteral("is_enabled"))
        && !execute(QStringLiteral(
            "ALTER TABLE gym ADD COLUMN is_enabled INTEGER NOT NULL DEFAULT 1"), errorMessage)) {
        db.rollback();
        return false;
    }
    if (!hasColumn(QStringLiteral("equipment_instance"), QStringLiteral("is_enabled"))
        && !execute(QStringLiteral(
            "ALTER TABLE equipment_instance ADD COLUMN is_enabled INTEGER NOT NULL DEFAULT 1"), errorMessage)) {
        db.rollback();
        return false;
    }
    if (!hasColumn(QStringLiteral("workout_exercise"), QStringLiteral("rest_seconds"))) {
        if (!execute(QStringLiteral(
                "ALTER TABLE workout_exercise ADD COLUMN rest_seconds INTEGER"), errorMessage)
            || !execute(QStringLiteral(
                "UPDATE workout_exercise SET rest_seconds=(SELECT rest_seconds FROM exercise "
                "WHERE exercise.id=workout_exercise.exercise_id) WHERE rest_seconds IS NULL"),
                errorMessage)) {
            db.rollback();
            return false;
        }
    }
    const QList<QPair<QString, QString>> exerciseColumns{
        {QStringLiteral("difficulty"), QStringLiteral("TEXT NOT NULL DEFAULT ''")},
        {QStringLiteral("technique_points_json"), QStringLiteral("TEXT NOT NULL DEFAULT '[]'")},
        {QStringLiteral("common_mistakes_json"), QStringLiteral("TEXT NOT NULL DEFAULT '[]'")},
        {QStringLiteral("collections_json"), QStringLiteral("TEXT NOT NULL DEFAULT '[]'")},
    };
    for (const auto &[column, definition] : exerciseColumns) {
        if (!hasColumn(QStringLiteral("exercise"), column)
            && !execute(QStringLiteral("ALTER TABLE exercise ADD COLUMN %1 %2")
                            .arg(column, definition), errorMessage)) {
            db.rollback();
            return false;
        }
    }
    const QStringList indexStatements{
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_exercise_media_exercise ON exercise_media(exercise_id,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_plan_day_plan_order ON plan_day(plan_id,sort_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_plan_section_day_order ON plan_section(day_id,sort_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_plan_exercise_day_order ON plan_exercise(day_id,sort_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_equipment_gym_enabled ON equipment_instance(gym_id,is_enabled,name,code)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_workout_session_status_end ON workout_session(status,ended_at DESC,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_workout_exercise_session_order ON workout_exercise(session_id,sort_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_workout_exercise_previous ON workout_exercise(exercise_id,equipment_instance_id,session_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_set_exercise_order ON set_record(workout_exercise_id,set_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_append_parent ON append_set_record(parent_set_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_cardio_performed ON cardio_record(performed_at DESC,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_cardio_session ON cardio_record(session_id)"),
    };
    for (const QString &statement : indexStatements) {
        if (!execute(statement, errorMessage)) {
            db.rollback();
            return false;
        }
    }
    if (!execute(QStringLiteral(
        "INSERT INTO app_meta(key,value) VALUES('schema_version','8') "
        "ON CONFLICT(key) DO UPDATE SET value='8'"), errorMessage)) {
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
