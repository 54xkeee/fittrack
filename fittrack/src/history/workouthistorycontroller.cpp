#include "history/workouthistorycontroller.h"

#include "analytics/traininganalytics.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>

namespace fittrack {
namespace {

LoadMode loadModeFromString(const QString &value)
{
    if (value == QStringLiteral("DumbbellPair")) return LoadMode::DumbbellPair;
    if (value == QStringLiteral("Unilateral")) return LoadMode::Unilateral;
    if (value == QStringLiteral("Bodyweight")) return LoadMode::Bodyweight;
    return LoadMode::Standard;
}

BodyweightLoadType bodyweightTypeFromString(const QString &value)
{
    if (value == QStringLiteral("Added")) return BodyweightLoadType::Added;
    if (value == QStringLiteral("Assisted")) return BodyweightLoadType::Assisted;
    return BodyweightLoadType::Bodyweight;
}

QString durationText(const QDateTime &started, const QDateTime &ended)
{
    const qint64 seconds = qMax<qint64>(0, started.secsTo(ended));
    return QStringLiteral("%1分").arg(seconds / 60);
}

} // namespace

WorkoutHistoryController::WorkoutHistoryController(const QSqlDatabase &database, QObject *parent)
    : QObject(parent)
    , m_database(database)
{
    reload();
}

QVariantList WorkoutHistoryController::sessions() const { return m_sessions; }
QVariantMap WorkoutHistoryController::selectedSession() const { return m_selectedSession; }
QString WorkoutHistoryController::errorMessage() const { return m_errorMessage; }

void WorkoutHistoryController::reload()
{
    QVariantList sessions;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT ws.id,ws.name,ws.started_at,ws.ended_at,COALESCE(g.name,''),"
        "(SELECT COUNT(*) FROM workout_exercise we WHERE we.session_id=ws.id),"
        "(SELECT COUNT(*) FROM set_record s JOIN workout_exercise we ON we.id=s.workout_exercise_id "
        " WHERE we.session_id=ws.id AND s.completed=1) "
        "FROM workout_session ws LEFT JOIN gym g ON g.id=ws.gym_id "
        "WHERE ws.status='completed' ORDER BY ws.ended_at DESC"));
    if (query.exec()) {
        while (query.next()) {
            sessions.append(QVariantMap{
                {QStringLiteral("id"), query.value(0)},
                {QStringLiteral("name"), query.value(1)},
                {QStringLiteral("startedAt"), query.value(2)},
                {QStringLiteral("endedAt"), query.value(3)},
                {QStringLiteral("gymName"), query.value(4)},
                {QStringLiteral("exerciseCount"), query.value(5)},
                {QStringLiteral("setCount"), query.value(6)},
            });
        }
    }
    m_sessions = sessions;
    emit sessionsChanged();
}

bool WorkoutHistoryController::selectSession(const QString &sessionId)
{
    clearError();
    QSqlQuery session(m_database);
    session.prepare(QStringLiteral(
        "SELECT ws.name,ws.started_at,ws.ended_at,ws.notes,COALESCE(g.name,'') "
        "FROM workout_session ws LEFT JOIN gym g ON g.id=ws.gym_id "
        "WHERE ws.id=? AND ws.status='completed'"));
    session.addBindValue(sessionId);
    if (!session.exec()) {
        return fail(session.lastError().text());
    }
    if (!session.next()) {
        return fail(QStringLiteral("找不到已完成训练"));
    }

    const QDateTime started = QDateTime::fromString(session.value(1).toString(), Qt::ISODate);
    const QDateTime ended = QDateTime::fromString(session.value(2).toString(), Qt::ISODate);
    QVariantList exercises;
    double totalVolume = 0.0;
    int completedSetCount = 0;
    double highestWeight = 0.0;
    int highestWeightReps = 0;
    int highestWeightSetCount = 0;
    QString highestWeightExercise;
    double bestOneRepMax = 0.0;
    QString bestOneRepMaxExercise;

    QSqlQuery exercise(m_database);
    exercise.prepare(QStringLiteral(
        "SELECT we.id,e.name_zh,e.load_mode,COALESCE(eq.name || CASE WHEN eq.code IS NULL OR eq.code='' "
        "THEN '' ELSE ' · ' || eq.code END,''),we.notes "
        "FROM workout_exercise we JOIN exercise e ON e.id=we.exercise_id "
        "LEFT JOIN equipment_instance eq ON eq.id=we.equipment_instance_id "
        "WHERE we.session_id=? ORDER BY we.sort_order"));
    exercise.addBindValue(sessionId);
    if (!exercise.exec()) {
        return fail(exercise.lastError().text());
    }
    while (exercise.next()) {
        QVector<SetRecord> records;
        QVariantList setDetails;
        QSqlQuery sets(m_database);
        sets.prepare(QStringLiteral(
            "SELECT id,weight_kg,actual_reps,both_sides,to_failure,notes,bodyweight_load_type FROM set_record "
            "WHERE workout_exercise_id=? AND completed=1 ORDER BY set_order"));
        sets.addBindValue(exercise.value(0));
        if (!sets.exec()) {
            return fail(sets.lastError().text());
        }
        while (sets.next()) {
            SetRecord record;
            record.weightKg = sets.value(1).toDouble();
            record.reps = sets.value(2).toInt();
            record.completed = true;
            record.bothSides = sets.value(3).toBool();
            record.bodyweightLoadType = bodyweightTypeFromString(sets.value(6).toString());

            QVariantList appendDetails;
            QSqlQuery append(m_database);
            append.prepare(QStringLiteral(
                "SELECT weight_kg,reps,rest_seconds,to_failure FROM append_set_record "
                "WHERE parent_set_id=? ORDER BY rowid"));
            append.addBindValue(sets.value(0));
            if (!append.exec()) {
                return fail(append.lastError().text());
            }
            while (append.next()) {
                record.appendSets.append({
                    append.value(0).toDouble(), append.value(1).toInt(),
                    append.value(2).toInt(), true,
                });
                appendDetails.append(QVariantMap{
                    {QStringLiteral("weightKg"), append.value(0)},
                    {QStringLiteral("reps"), append.value(1)},
                    {QStringLiteral("restSeconds"), append.value(2)},
                    {QStringLiteral("toFailure"), append.value(3).toBool()},
                });
            }
            records.append(record);
            ++completedSetCount;
            setDetails.append(QVariantMap{
                {QStringLiteral("id"), sets.value(0)},
                {QStringLiteral("weightKg"), sets.value(1)},
                {QStringLiteral("reps"), sets.value(2)},
                {QStringLiteral("toFailure"), sets.value(4).toBool()},
                {QStringLiteral("notes"), sets.value(5)},
                {QStringLiteral("bodyweightLoadType"), sets.value(6)},
                {QStringLiteral("appendSets"), appendDetails},
            });
        }

        const LoadMode mode = loadModeFromString(exercise.value(2).toString());
        const double exerciseVolume = TrainingAnalytics::totalVolume(records, mode);
        totalVolume += exerciseVolume;
        const auto highest = TrainingAnalytics::highestWeight(records);
        if (highest && highest->weightKg > highestWeight) {
            highestWeight = highest->weightKg;
            highestWeightReps = highest->bestReps;
            highestWeightSetCount = highest->setCount;
            highestWeightExercise = exercise.value(1).toString();
        }
        const auto oneRepMax = TrainingAnalytics::estimatedOneRepMax(records, mode);
        if (oneRepMax && *oneRepMax > bestOneRepMax) {
            bestOneRepMax = *oneRepMax;
            bestOneRepMaxExercise = exercise.value(1).toString();
        }
        exercises.append(QVariantMap{
            {QStringLiteral("name"), exercise.value(1)},
            {QStringLiteral("equipmentName"), exercise.value(3)},
            {QStringLiteral("notes"), exercise.value(4)},
            {QStringLiteral("volume"), exerciseVolume},
            {QStringLiteral("sets"), setDetails},
        });
    }

    QVariantList primaryMuscles;
    QVariantList secondaryMuscles;
    QSqlQuery muscles(m_database);
    muscles.prepare(QStringLiteral(
        "SELECT m.name_zh,em.role,COUNT(DISTINCT s.id) FROM workout_session ws "
        "JOIN workout_exercise we ON we.session_id=ws.id "
        "JOIN set_record s ON s.workout_exercise_id=we.id AND s.completed=1 "
        "JOIN exercise_muscle em ON em.exercise_id=we.exercise_id "
        "JOIN muscle m ON m.id=em.muscle_id WHERE ws.id=? GROUP BY m.id,em.role ORDER BY COUNT(DISTINCT s.id) DESC"));
    muscles.addBindValue(sessionId);
    if (muscles.exec()) {
        while (muscles.next()) {
            QVariantMap item{
                {QStringLiteral("name"), muscles.value(0)},
                {QStringLiteral("sets"), muscles.value(2)},
            };
            (muscles.value(1).toString() == QStringLiteral("primary")
                 ? primaryMuscles : secondaryMuscles).append(item);
        }
    }

    m_selectedSession = QVariantMap{
        {QStringLiteral("id"), sessionId},
        {QStringLiteral("name"), session.value(0)},
        {QStringLiteral("startedAt"), session.value(1)},
        {QStringLiteral("endedAt"), session.value(2)},
        {QStringLiteral("duration"), durationText(started, ended)},
        {QStringLiteral("notes"), session.value(3)},
        {QStringLiteral("gymName"), session.value(4)},
        {QStringLiteral("exerciseCount"), exercises.size()},
        {QStringLiteral("setCount"), completedSetCount},
        {QStringLiteral("totalVolume"), totalVolume},
        {QStringLiteral("highestWeight"), highestWeight},
        {QStringLiteral("highestWeightReps"), highestWeightReps},
        {QStringLiteral("highestWeightSetCount"), highestWeightSetCount},
        {QStringLiteral("highestWeightExercise"), highestWeightExercise},
        {QStringLiteral("bestOneRepMax"), bestOneRepMax},
        {QStringLiteral("bestOneRepMaxExercise"), bestOneRepMaxExercise},
        {QStringLiteral("primaryMuscles"), primaryMuscles},
        {QStringLiteral("secondaryMuscles"), secondaryMuscles},
        {QStringLiteral("exercises"), exercises},
    };
    emit selectedSessionChanged();
    return true;
}

bool WorkoutHistoryController::updateCompletedSet(
    const QString &setId, double weightKg, int actualReps, bool toFailure,
    const QString &bodyweightLoadType)
{
    clearError();
    const QString sessionId = m_selectedSession.value(QStringLiteral("id")).toString();
    if (sessionId.isEmpty()) {
        return fail(QStringLiteral("请先选择已完成训练"));
    }
    if (setId.isEmpty() || weightKg < 0 || actualReps < 0) {
        return fail(QStringLiteral("组数据无效"));
    }
    if (bodyweightLoadType != QStringLiteral("Bodyweight")
        && bodyweightLoadType != QStringLiteral("Added")
        && bodyweightLoadType != QStringLiteral("Assisted")) {
        return fail(QStringLiteral("自重负重类型无效"));
    }

    QSqlQuery update(m_database);
    update.prepare(QStringLiteral(
        "UPDATE set_record SET weight_kg=?,actual_reps=?,to_failure=?,bodyweight_load_type=? "
        "WHERE id=? AND completed=1 AND workout_exercise_id IN ("
        "SELECT we.id FROM workout_exercise we JOIN workout_session ws ON ws.id=we.session_id "
        "WHERE ws.id=? AND ws.status='completed')"));
    update.addBindValue(weightKg);
    update.addBindValue(actualReps);
    update.addBindValue(toFailure ? 1 : 0);
    update.addBindValue(bodyweightLoadType);
    update.addBindValue(setId);
    update.addBindValue(sessionId);
    if (!update.exec()) {
        return fail(update.lastError().text());
    }
    if (update.numRowsAffected() != 1) {
        return fail(QStringLiteral("该组不属于当前已完成训练"));
    }
    return selectSession(sessionId);
}

bool WorkoutHistoryController::deleteSession(const QString &sessionId)
{
    clearError();
    if (sessionId.isEmpty()) {
        return fail(QStringLiteral("训练记录编号无效"));
    }

    QSqlQuery remove(m_database);
    remove.prepare(QStringLiteral(
        "DELETE FROM workout_session WHERE id=? AND status='completed'"));
    remove.addBindValue(sessionId);
    if (!remove.exec()) {
        return fail(remove.lastError().text());
    }
    if (remove.numRowsAffected() != 1) {
        return fail(QStringLiteral("找不到可删除的已完成训练"));
    }

    if (m_selectedSession.value(QStringLiteral("id")).toString() == sessionId) {
        m_selectedSession.clear();
        emit selectedSessionChanged();
    }
    reload();
    return true;
}

bool WorkoutHistoryController::fail(const QString &message)
{
    if (m_errorMessage != message) {
        m_errorMessage = message;
        emit errorMessageChanged();
    }
    return false;
}

void WorkoutHistoryController::clearError()
{
    if (!m_errorMessage.isEmpty()) {
        m_errorMessage.clear();
        emit errorMessageChanged();
    }
}

} // namespace fittrack
