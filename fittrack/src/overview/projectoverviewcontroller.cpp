#include "overview/projectoverviewcontroller.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace fittrack {

ProjectOverviewController::ProjectOverviewController(QSqlDatabase database, QObject *parent)
    : QObject(parent)
    , m_database(std::move(database))
{
    reload();
}

QVariantMap ProjectOverviewController::summary() const
{
    return m_summary;
}

QString ProjectOverviewController::errorMessage() const
{
    return m_errorMessage;
}

qint64 ProjectOverviewController::tableCount(const QString &table, const QString &where) const
{
    QSqlQuery query(m_database);
    const QString statement = QStringLiteral("SELECT COUNT(*) FROM %1%2")
                                  .arg(table, where.isEmpty() ? QString() : QStringLiteral(" WHERE ") + where);
    if (!query.exec(statement) || !query.next())
        return 0;
    return query.value(0).toLongLong();
}

void ProjectOverviewController::reload()
{
    QSqlQuery version(m_database);
    QString schemaVersion = QStringLiteral("?");
    if (version.exec(QStringLiteral("SELECT value FROM app_meta WHERE key='schema_version'"))
        && version.next()) {
        schemaVersion = version.value(0).toString();
    }

    QSqlQuery integrity(m_database);
    bool integrityOk = integrity.exec(QStringLiteral("PRAGMA quick_check(1)"))
                       && integrity.next()
                       && integrity.value(0).toString() == QStringLiteral("ok");

    QSqlQuery foreignKeys(m_database);
    bool foreignKeysOk = foreignKeys.exec(QStringLiteral("PRAGMA foreign_key_check"))
                         && !foreignKeys.next();

    QSqlQuery latest(m_database);
    QString latestWorkout;
    if (latest.exec(QStringLiteral(
            "SELECT ended_at FROM workout_session WHERE status='completed' "
            "ORDER BY ended_at DESC LIMIT 1"))
        && latest.next()) {
        latestWorkout = latest.value(0).toString();
    }

    m_summary = {
        {QStringLiteral("schemaVersion"), schemaVersion},
        {QStringLiteral("exerciseCount"), tableCount(QStringLiteral("exercise"))},
        {QStringLiteral("planCount"), tableCount(QStringLiteral("training_plan"))},
        {QStringLiteral("planDayCount"), tableCount(QStringLiteral("plan_day"))},
        {QStringLiteral("workoutCount"), tableCount(QStringLiteral("workout_session"),
                                                     QStringLiteral("status='completed'"))},
        {QStringLiteral("activeWorkoutCount"), tableCount(QStringLiteral("workout_session"),
                                                           QStringLiteral("status='active'"))},
        {QStringLiteral("setCount"), tableCount(QStringLiteral("set_record"),
                                                 QStringLiteral("completed=1"))},
        {QStringLiteral("cardioCount"), tableCount(QStringLiteral("cardio_record"))},
        {QStringLiteral("gymCount"), tableCount(QStringLiteral("gym"),
                                                 QStringLiteral("is_enabled=1"))},
        {QStringLiteral("equipmentCount"), tableCount(QStringLiteral("equipment_instance"),
                                                       QStringLiteral("is_enabled=1"))},
        {QStringLiteral("integrityOk"), integrityOk && foreignKeysOk},
        {QStringLiteral("latestWorkout"), latestWorkout},
    };
    emit summaryChanged();
}

void ProjectOverviewController::setError(const QString &message)
{
    if (m_errorMessage == message)
        return;
    m_errorMessage = message;
    emit errorMessageChanged();
}

bool ProjectOverviewController::execute(const QString &statement, const QVariantList &values)
{
    QSqlQuery query(m_database);
    if (!query.prepare(statement)) {
        setError(query.lastError().text());
        return false;
    }
    for (const QVariant &value : values)
        query.addBindValue(value);
    if (!query.exec()) {
        setError(query.lastError().text());
        return false;
    }
    return true;
}

bool ProjectOverviewController::createDemoData()
{
    setError(QString());
    if (tableCount(QStringLiteral("workout_session"), QStringLiteral("status='active'")) > 0) {
        setError(tr("请先结束或放弃正在进行的训练，再载入演示数据。"));
        return false;
    }

    QSqlQuery exerciseQuery(m_database);
    if (!exerciseQuery.exec(QStringLiteral(
            "SELECT id FROM exercise ORDER BY id LIMIT 3"))) {
        setError(exerciseQuery.lastError().text());
        return false;
    }
    QStringList exerciseIds;
    while (exerciseQuery.next())
        exerciseIds.append(exerciseQuery.value(0).toString());
    if (exerciseIds.size() < 3) {
        setError(tr("动作库数据不足，无法生成演示训练。"));
        return false;
    }

    if (!m_database.transaction()) {
        setError(m_database.lastError().text());
        return false;
    }
    const auto rollback = [this] {
        m_database.rollback();
        return false;
    };

    if (!execute(QStringLiteral(
            "INSERT INTO gym(id,name,is_enabled) VALUES('demo-gym','演示健身房',1) "
            "ON CONFLICT(id) DO UPDATE SET name=excluded.name,is_enabled=1"))
        || !execute(QStringLiteral(
            "INSERT INTO equipment_instance(id,gym_id,name,code,notes,is_enabled) "
            "VALUES('demo-rack','demo-gym','演示深蹲架','A-08','演示数据使用器械',1) "
            "ON CONFLICT(id) DO UPDATE SET name=excluded.name,code=excluded.code,"
            "notes=excluded.notes,is_enabled=1"))
        || !execute(QStringLiteral("DELETE FROM workout_session WHERE id LIKE 'demo-session-%'"))
        || !execute(QStringLiteral("DELETE FROM cardio_record WHERE id LIKE 'demo-cardio-%'"))) {
        return rollback();
    }

    const QDateTime now = QDateTime::currentDateTimeUtc();
    for (int sessionIndex = 0; sessionIndex < 8; ++sessionIndex) {
        const QString sessionId = QStringLiteral("demo-session-%1").arg(sessionIndex + 1);
        const QDateTime endedAt = now.addDays(-((7 - sessionIndex) * 3)).addSecs(-3600);
        const QDateTime startedAt = endedAt.addSecs(-70 * 60);
        if (!execute(QStringLiteral(
                "INSERT INTO workout_session(id,name,gym_id,started_at,ended_at,status,notes) "
                "VALUES(?,?,?,?,?,'completed',?)"),
                     {sessionId, tr("演示力量训练 %1").arg(sessionIndex + 1),
                      QStringLiteral("demo-gym"), startedAt.toString(Qt::ISODate),
                      endedAt.toString(Qt::ISODate), tr("用于展示历史、趋势和训练容量。")})) {
            return rollback();
        }

        for (int exerciseIndex = 0; exerciseIndex < exerciseIds.size(); ++exerciseIndex) {
            const QString workoutExerciseId = QStringLiteral("demo-exercise-%1-%2")
                                                  .arg(sessionIndex + 1)
                                                  .arg(exerciseIndex + 1);
            if (!execute(QStringLiteral(
                    "INSERT INTO workout_exercise(id,session_id,exercise_id,equipment_instance_id,"
                    "sort_order,rest_seconds,notes) VALUES(?,?,?,?,?,?,?)"),
                         {workoutExerciseId, sessionId, exerciseIds.at(exerciseIndex),
                          QStringLiteral("demo-rack"), exerciseIndex, 90,
                          tr("演示训练动作记录")})) {
                return rollback();
            }
            for (int setIndex = 0; setIndex < 3; ++setIndex) {
                const qreal weight = 35.0 + exerciseIndex * 10.0
                                     + sessionIndex * 2.5 + setIndex * 2.5;
                if (!execute(QStringLiteral(
                        "INSERT INTO set_record(id,workout_exercise_id,set_order,weight_kg,"
                        "target_reps,actual_reps,completed,to_failure,both_sides,"
                        "bodyweight_load_type,completed_at,notes) "
                        "VALUES(?,?,?,?,?,?,1,?,?,?,?,'')"),
                             {QStringLiteral("demo-set-%1-%2-%3")
                                  .arg(sessionIndex + 1)
                                  .arg(exerciseIndex + 1)
                                  .arg(setIndex + 1),
                              workoutExerciseId, setIndex, weight, 10,
                              10 - (setIndex == 2 ? 1 : 0), setIndex == 2 ? 1 : 0,
                              1, QStringLiteral("Bodyweight"),
                              endedAt.addSecs(-(exerciseIndex * 8 + setIndex) * 60)
                                  .toString(Qt::ISODate)})) {
                    return rollback();
                }
            }
        }

        if (!execute(QStringLiteral(
                "INSERT INTO cardio_record(id,session_id,cardio_type,performed_at,duration_seconds,"
                "incline,speed_kmh,distance_km,machine_level,floors,steps,average_heart_rate,notes) "
                "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)"),
                     {QStringLiteral("demo-cardio-%1").arg(sessionIndex + 1), sessionId,
                      QStringLiteral("TreadmillIncline"), endedAt.toString(Qt::ISODate),
                      18 * 60 + sessionIndex * 30, 8.0, 5.2, 1.6 + sessionIndex * 0.1,
                      QVariant{}, QVariant{}, QVariant{}, 132 + sessionIndex,
                      tr("演示有氧记录")})) {
            return rollback();
        }
    }

    if (!m_database.commit()) {
        setError(m_database.lastError().text());
        return false;
    }
    reload();
    emit demoDataCreated();
    return true;
}

} // namespace fittrack
