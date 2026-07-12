#include "analytics/analyticsdashboardcontroller.h"

#include "analytics/traininganalytics.h"

#include <QDateTime>
#include <QSqlQuery>

namespace fittrack {
namespace {

LoadMode modeFromString(const QString &value)
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

void bindPeriod(QSqlQuery &query, const QString &cutoff)
{
    if (!cutoff.isEmpty()) query.addBindValue(cutoff);
}

} // namespace

AnalyticsDashboardController::AnalyticsDashboardController(
    const QSqlDatabase &database, QObject *parent)
    : QObject(parent), m_database(database)
{
    reload();
}

int AnalyticsDashboardController::periodDays() const { return m_periodDays; }
QVariantMap AnalyticsDashboardController::sevenDayOverview() const { return m_sevenDayOverview; }
QVariantMap AnalyticsDashboardController::overview() const { return m_overview; }
QVariantList AnalyticsDashboardController::exercises() const { return m_exercises; }
QVariantList AnalyticsDashboardController::gyms() const { return m_gyms; }
QVariantList AnalyticsDashboardController::equipment() const { return m_equipment; }
QVariantList AnalyticsDashboardController::trend() const { return m_trend; }
QVariantList AnalyticsDashboardController::primaryMuscles() const { return m_primaryMuscles; }
QVariantList AnalyticsDashboardController::secondaryMuscles() const { return m_secondaryMuscles; }
QString AnalyticsDashboardController::selectedExerciseId() const { return m_selectedExerciseId; }
QString AnalyticsDashboardController::gymFilterId() const { return m_gymFilterId; }
QString AnalyticsDashboardController::equipmentFilterId() const { return m_equipmentFilterId; }

QString AnalyticsDashboardController::cutoff(int days) const
{
    return days > 0 ? QDateTime::currentDateTimeUtc().addDays(-days).toString(Qt::ISODate) : QString{};
}

QVariantMap AnalyticsDashboardController::buildOverview(int days) const
{
    const QString since = cutoff(days);
    const QString periodSql = since.isEmpty() ? QString{} : QStringLiteral(" AND ws.ended_at>=?");
    QSqlQuery sessions(m_database);
    sessions.prepare(QStringLiteral(
        "SELECT COUNT(*),COALESCE(SUM(CAST((julianday(ws.ended_at)-julianday(ws.started_at))*86400 AS INTEGER)),0) "
        "FROM workout_session ws WHERE ws.status='completed'") + periodSql);
    bindPeriod(sessions, since);
    sessions.exec();
    sessions.next();
    QSqlQuery setCount(m_database);
    setCount.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM set_record s JOIN workout_exercise we ON we.id=s.workout_exercise_id "
        "JOIN workout_session ws ON ws.id=we.session_id WHERE ws.status='completed' AND s.completed=1") + periodSql);
    bindPeriod(setCount, since);
    setCount.exec();
    setCount.next();

    double volume = 0.0;
    double highestWeight = 0.0;
    int highestReps = 0;
    int highestSetCount = 0;
    QString highestExercise;
    double bestOneRepMax = 0.0;
    QString bestOneRepMaxExercise;
    QSqlQuery sets(m_database);
    sets.prepare(QStringLiteral(
        "SELECT s.id,s.weight_kg,s.actual_reps,s.both_sides,e.load_mode,e.name_zh,s.bodyweight_load_type "
        "FROM set_record s JOIN workout_exercise we ON we.id=s.workout_exercise_id "
        "JOIN workout_session ws ON ws.id=we.session_id JOIN exercise e ON e.id=we.exercise_id "
        "WHERE ws.status='completed' AND s.completed=1") + periodSql);
    bindPeriod(sets, since);
    if (sets.exec()) {
        while (sets.next()) {
            SetRecord record;
            record.weightKg = sets.value(1).toDouble();
            record.reps = sets.value(2).toInt();
            record.bothSides = sets.value(3).toBool();
            record.completed = true;
            record.bodyweightLoadType = bodyweightTypeFromString(sets.value(6).toString());
            QSqlQuery append(m_database);
            append.prepare(QStringLiteral(
                "SELECT weight_kg,reps,rest_seconds FROM append_set_record WHERE parent_set_id=?"));
            append.addBindValue(sets.value(0));
            if (append.exec()) {
                while (append.next()) {
                    record.appendSets.append({append.value(0).toDouble(), append.value(1).toInt(),
                                             append.value(2).toInt(), true});
                }
            }
            const LoadMode mode = modeFromString(sets.value(4).toString());
            volume += TrainingAnalytics::setVolume(record, mode);
            if (record.weightKg > highestWeight) {
                highestWeight = record.weightKg;
                highestReps = record.reps;
                highestSetCount = 1;
                highestExercise = sets.value(5).toString();
            } else if (qFuzzyCompare(record.weightKg, highestWeight)
                       && sets.value(5).toString() == highestExercise) {
                ++highestSetCount;
                highestReps = qMax(highestReps, record.reps);
            }
            const auto estimate = TrainingAnalytics::estimatedOneRepMax({record}, mode);
            if (estimate && *estimate > bestOneRepMax) {
                bestOneRepMax = *estimate;
                bestOneRepMaxExercise = sets.value(5).toString();
            }
        }
    }
    return {
        {QStringLiteral("workoutCount"), sessions.value(0)},
        {QStringLiteral("setCount"), setCount.value(0)},
        {QStringLiteral("durationSeconds"), sessions.value(1)},
        {QStringLiteral("totalVolume"), volume},
        {QStringLiteral("highestWeight"), highestWeight},
        {QStringLiteral("highestReps"), highestReps},
        {QStringLiteral("highestSetCount"), highestSetCount},
        {QStringLiteral("highestExercise"), highestExercise},
        {QStringLiteral("bestOneRepMax"), bestOneRepMax},
        {QStringLiteral("bestOneRepMaxExercise"), bestOneRepMaxExercise},
    };
}

QVariantList AnalyticsDashboardController::buildMuscles(int days, const QString &role) const
{
    const QString since = cutoff(days);
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT m.name_zh,COUNT(DISTINCT s.id) FROM set_record s "
        "JOIN workout_exercise we ON we.id=s.workout_exercise_id "
        "JOIN workout_session ws ON ws.id=we.session_id "
        "JOIN exercise_muscle em ON em.exercise_id=we.exercise_id "
        "JOIN muscle m ON m.id=em.muscle_id "
        "WHERE ws.status='completed' AND s.completed=1 AND em.role=?")
        + (since.isEmpty() ? QString{} : QStringLiteral(" AND ws.ended_at>=?"))
        + QStringLiteral(" GROUP BY m.id ORDER BY COUNT(DISTINCT s.id) DESC,m.name_zh"));
    query.addBindValue(role);
    bindPeriod(query, since);
    QVariantList result;
    if (query.exec()) {
        while (query.next()) {
            result.append(QVariantMap{{QStringLiteral("name"), query.value(0)},
                                      {QStringLiteral("sets"), query.value(1)}});
        }
    }
    return result;
}

void AnalyticsDashboardController::loadOptions()
{
    m_exercises.clear();
    QSqlQuery exercises(m_database);
    if (exercises.exec(QStringLiteral(
            "SELECT DISTINCT e.id,e.name_zh FROM exercise e JOIN workout_exercise we ON we.exercise_id=e.id "
            "JOIN workout_session ws ON ws.id=we.session_id WHERE ws.status='completed' ORDER BY e.name_zh"))) {
        while (exercises.next()) {
            m_exercises.append(QVariantMap{{QStringLiteral("id"), exercises.value(0)},
                                           {QStringLiteral("name"), exercises.value(1)}});
        }
    }
    if (m_selectedExerciseId.isEmpty() && !m_exercises.isEmpty())
        m_selectedExerciseId = m_exercises.first().toMap().value(QStringLiteral("id")).toString();

    m_gyms.clear();
    QSqlQuery gyms(m_database);
    if (gyms.exec(QStringLiteral(
            "SELECT DISTINCT g.id,g.name FROM gym g JOIN workout_session ws ON ws.gym_id=g.id "
            "WHERE ws.status='completed' ORDER BY g.name"))) {
        while (gyms.next()) {
            m_gyms.append(QVariantMap{{QStringLiteral("id"), gyms.value(0)},
                                      {QStringLiteral("name"), gyms.value(1)}});
        }
    }

    m_equipment.clear();
    QSqlQuery equipment(m_database);
    equipment.prepare(QStringLiteral(
        "SELECT DISTINCT eq.id,eq.name || CASE WHEN eq.code IS NULL OR eq.code='' THEN '' ELSE ' · ' || eq.code END "
        "FROM equipment_instance eq JOIN workout_exercise we ON we.equipment_instance_id=eq.id "
        "JOIN workout_session ws ON ws.id=we.session_id WHERE ws.status='completed' AND we.exercise_id=? "
        "AND (?='' OR ws.gym_id=?) ORDER BY 2"));
    equipment.addBindValue(m_selectedExerciseId);
    const QString gymFilter = m_gymFilterId.isEmpty() ? QStringLiteral("") : m_gymFilterId;
    equipment.addBindValue(gymFilter);
    equipment.addBindValue(gymFilter);
    if (equipment.exec()) {
        while (equipment.next()) {
            m_equipment.append(QVariantMap{{QStringLiteral("id"), equipment.value(0)},
                                           {QStringLiteral("name"), equipment.value(1)}});
        }
    }
}

void AnalyticsDashboardController::loadTrend()
{
    m_trend.clear();
    if (m_selectedExerciseId.isEmpty()) return;
    const QString since = cutoff(m_periodDays);
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT we.id,ws.ended_at FROM workout_exercise we JOIN workout_session ws ON ws.id=we.session_id "
        "WHERE ws.status='completed' AND we.exercise_id=? AND (?='' OR ws.gym_id=?) "
        "AND (?='' OR we.equipment_instance_id=?)")
        + (since.isEmpty() ? QString{} : QStringLiteral(" AND ws.ended_at>=?"))
        + QStringLiteral(" ORDER BY ws.ended_at"));
    query.addBindValue(m_selectedExerciseId);
    const QString gymFilter = m_gymFilterId.isEmpty() ? QStringLiteral("") : m_gymFilterId;
    const QString equipmentFilter = m_equipmentFilterId.isEmpty()
        ? QStringLiteral("") : m_equipmentFilterId;
    query.addBindValue(gymFilter);
    query.addBindValue(gymFilter);
    query.addBindValue(equipmentFilter);
    query.addBindValue(equipmentFilter);
    bindPeriod(query, since);
    if (!query.exec()) return;
    while (query.next()) {
        QVector<SetRecord> records;
        QSqlQuery sets(m_database);
        sets.prepare(QStringLiteral(
            "SELECT id,weight_kg,actual_reps,both_sides,bodyweight_load_type FROM set_record "
            "WHERE workout_exercise_id=? AND completed=1 ORDER BY set_order"));
        sets.addBindValue(query.value(0));
        if (sets.exec()) {
            while (sets.next()) {
                SetRecord record{sets.value(1).toDouble(), sets.value(2).toInt(), true,
                                 sets.value(3).toBool(), {}};
                record.bodyweightLoadType = bodyweightTypeFromString(sets.value(4).toString());
                QSqlQuery append(m_database);
                append.prepare(QStringLiteral(
                    "SELECT weight_kg,reps,rest_seconds FROM append_set_record WHERE parent_set_id=?"));
                append.addBindValue(sets.value(0));
                if (append.exec()) {
                    while (append.next()) {
                        record.appendSets.append({append.value(0).toDouble(), append.value(1).toInt(),
                                                 append.value(2).toInt(), true});
                    }
                }
                records.append(record);
            }
        }
        QSqlQuery modeQuery(m_database);
        modeQuery.prepare(QStringLiteral(
            "SELECT e.load_mode FROM workout_exercise we JOIN exercise e ON e.id=we.exercise_id WHERE we.id=?"));
        modeQuery.addBindValue(query.value(0));
        modeQuery.exec();
        modeQuery.next();
        const LoadMode mode = modeFromString(modeQuery.value(0).toString());
        const auto highest = TrainingAnalytics::highestWeight(records);
        const auto estimate = TrainingAnalytics::estimatedOneRepMax(records, mode);
        m_trend.append(QVariantMap{
            {QStringLiteral("date"), query.value(1)},
            {QStringLiteral("highestWeight"), highest ? highest->weightKg : 0.0},
            {QStringLiteral("highestReps"), highest ? highest->bestReps : 0},
            {QStringLiteral("highestSetCount"), highest ? highest->setCount : 0},
            {QStringLiteral("oneRepMax"), estimate ? *estimate : 0.0},
            {QStringLiteral("volume"), TrainingAnalytics::totalVolume(records, mode)},
        });
    }
}

void AnalyticsDashboardController::reload()
{
    m_sevenDayOverview = buildOverview(7);
    m_overview = buildOverview(m_periodDays);
    m_primaryMuscles = buildMuscles(m_periodDays, QStringLiteral("primary"));
    m_secondaryMuscles = buildMuscles(m_periodDays, QStringLiteral("secondary"));
    loadOptions();
    loadTrend();
    emit dataChanged();
}

void AnalyticsDashboardController::setPeriodDays(int days)
{
    if (days != 7 && days != 30 && days != -1) return;
    m_periodDays = days;
    reload();
}

void AnalyticsDashboardController::selectExercise(const QString &exerciseId)
{
    m_selectedExerciseId = exerciseId;
    m_equipmentFilterId.clear();
    loadOptions();
    loadTrend();
    emit dataChanged();
}

void AnalyticsDashboardController::setGymFilter(const QString &gymId)
{
    m_gymFilterId = gymId;
    m_equipmentFilterId.clear();
    loadOptions();
    loadTrend();
    emit dataChanged();
}

void AnalyticsDashboardController::setEquipmentFilter(const QString &equipmentId)
{
    m_equipmentFilterId = equipmentId;
    loadTrend();
    emit dataChanged();
}

} // namespace fittrack
