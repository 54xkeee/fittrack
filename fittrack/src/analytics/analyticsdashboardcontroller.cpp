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
    m_sevenDayOverview = buildOverview(7);
    m_overview = m_sevenDayOverview;
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
    QSqlQuery cardio(m_database);
    cardio.prepare(QStringLiteral(
        "SELECT COUNT(*),COALESCE(SUM(duration_seconds),0) FROM cardio_record")
        + (since.isEmpty() ? QString{} : QStringLiteral(" WHERE performed_at>=?")));
    bindPeriod(cardio, since);
    cardio.exec();
    cardio.next();

    double volume = 0.0;
    double highestWeight = 0.0;
    int highestReps = 0;
    int highestSetCount = 0;
    QString highestExercise;
    double bestOneRepMax = 0.0;
    QString bestOneRepMaxExercise;
    int completedSetCount = 0;
    QSqlQuery sets(m_database);
    sets.prepare(QStringLiteral(
        "SELECT s.id,s.weight_kg,s.actual_reps,s.both_sides,e.load_mode,e.name_zh,"
        "s.bodyweight_load_type,a.id,a.weight_kg,a.reps,a.rest_seconds "
        "FROM set_record s JOIN workout_exercise we ON we.id=s.workout_exercise_id "
        "JOIN workout_session ws ON ws.id=we.session_id JOIN exercise e ON e.id=we.exercise_id "
        "LEFT JOIN append_set_record a ON a.parent_set_id=s.id "
        "WHERE ws.status='completed' AND s.completed=1") + periodSql
        + QStringLiteral(" ORDER BY ws.ended_at,we.sort_order,we.id,s.set_order,s.id,a.rowid"));
    bindPeriod(sets, since);
    QString currentSetId;
    QString currentExercise;
    LoadMode currentMode = LoadMode::Standard;
    SetRecord currentRecord;
    auto flushSet = [&] {
        if (currentSetId.isEmpty())
            return;
        ++completedSetCount;
        volume += TrainingAnalytics::setVolume(currentRecord, currentMode);
        if (currentRecord.weightKg > highestWeight) {
            highestWeight = currentRecord.weightKg;
            highestReps = currentRecord.reps;
            highestSetCount = 1;
            highestExercise = currentExercise;
        } else if (qFuzzyCompare(currentRecord.weightKg, highestWeight)
                   && currentExercise == highestExercise) {
            ++highestSetCount;
            highestReps = qMax(highestReps, currentRecord.reps);
        }
        const auto estimate = TrainingAnalytics::estimatedOneRepMax(
            {currentRecord}, currentMode);
        if (estimate && *estimate > bestOneRepMax) {
            bestOneRepMax = *estimate;
            bestOneRepMaxExercise = currentExercise;
        }
    };
    if (sets.exec()) {
        while (sets.next()) {
            const QString setId = sets.value(0).toString();
            if (setId != currentSetId) {
                flushSet();
                currentSetId = setId;
                currentExercise = sets.value(5).toString();
                currentMode = modeFromString(sets.value(4).toString());
                currentRecord = {};
                currentRecord.weightKg = sets.value(1).toDouble();
                currentRecord.reps = sets.value(2).toInt();
                currentRecord.bothSides = sets.value(3).toBool();
                currentRecord.completed = true;
                currentRecord.bodyweightLoadType = bodyweightTypeFromString(
                    sets.value(6).toString());
            }
            if (!sets.value(7).isNull())
                currentRecord.appendSets.append({
                    sets.value(8).toDouble(), sets.value(9).toInt(),
                    sets.value(10).toInt(), true,
                });
        }
        flushSet();
    }
    return {
        {QStringLiteral("workoutCount"), sessions.value(0)},
        {QStringLiteral("setCount"), completedSetCount},
        {QStringLiteral("durationSeconds"), sessions.value(1)},
        {QStringLiteral("cardioCount"), cardio.value(0)},
        {QStringLiteral("cardioDurationSeconds"), cardio.value(1)},
        {QStringLiteral("totalVolume"), volume},
        {QStringLiteral("highestWeight"), highestWeight},
        {QStringLiteral("highestReps"), highestReps},
        {QStringLiteral("highestSetCount"), highestSetCount},
        {QStringLiteral("highestExercise"), highestExercise},
        {QStringLiteral("bestOneRepMax"), bestOneRepMax},
        {QStringLiteral("bestOneRepMaxExercise"), bestOneRepMaxExercise},
    };
}

void AnalyticsDashboardController::loadMuscles(int days)
{
    const QString since = cutoff(days);
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT em.role,m.name_zh,COUNT(DISTINCT s.id) FROM set_record s "
        "JOIN workout_exercise we ON we.id=s.workout_exercise_id "
        "JOIN workout_session ws ON ws.id=we.session_id "
        "JOIN exercise_muscle em ON em.exercise_id=we.exercise_id "
        "JOIN muscle m ON m.id=em.muscle_id "
        "WHERE ws.status='completed' AND s.completed=1")
        + (since.isEmpty() ? QString{} : QStringLiteral(" AND ws.ended_at>=?"))
        + QStringLiteral(
            " GROUP BY em.role,m.id ORDER BY em.role,COUNT(DISTINCT s.id) DESC,m.name_zh"));
    bindPeriod(query, since);
    m_primaryMuscles.clear();
    m_secondaryMuscles.clear();
    if (query.exec()) {
        while (query.next()) {
            QVariantMap item{{QStringLiteral("name"), query.value(1)},
                             {QStringLiteral("sets"), query.value(2)}};
            (query.value(0).toString() == QStringLiteral("primary")
                 ? m_primaryMuscles : m_secondaryMuscles).append(item);
        }
    }
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

    loadEquipment();
}

void AnalyticsDashboardController::loadEquipment()
{
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
        "SELECT we.id,ws.ended_at,e.load_mode,s.id,s.weight_kg,s.actual_reps,s.both_sides,"
        "s.bodyweight_load_type,a.id,a.weight_kg,a.reps,a.rest_seconds "
        "FROM workout_exercise we JOIN workout_session ws ON ws.id=we.session_id "
        "JOIN exercise e ON e.id=we.exercise_id "
        "LEFT JOIN set_record s ON s.workout_exercise_id=we.id AND s.completed=1 "
        "LEFT JOIN append_set_record a ON a.parent_set_id=s.id "
        "WHERE ws.status='completed' AND we.exercise_id=? AND (?='' OR ws.gym_id=?) "
        "AND (?='' OR we.equipment_instance_id=?)")
        + (since.isEmpty() ? QString{} : QStringLiteral(" AND ws.ended_at>=?"))
        + QStringLiteral(
            " ORDER BY ws.ended_at,we.id,s.set_order,s.id,a.rowid"));
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

    QString currentWorkoutId;
    QString currentDate;
    QString currentSetId;
    LoadMode currentMode = LoadMode::Standard;
    QVector<SetRecord> records;
    SetRecord currentRecord;
    bool hasCurrentSet = false;
    auto flushSet = [&] {
        if (!hasCurrentSet)
            return;
        records.append(currentRecord);
        hasCurrentSet = false;
    };
    auto flushWorkout = [&] {
        if (currentWorkoutId.isEmpty())
            return;
        flushSet();
        const auto highest = TrainingAnalytics::highestWeight(records);
        const auto estimate = TrainingAnalytics::estimatedOneRepMax(records, currentMode);
        m_trend.append(QVariantMap{
            {QStringLiteral("date"), currentDate},
            {QStringLiteral("highestWeight"), highest ? highest->weightKg : 0.0},
            {QStringLiteral("highestReps"), highest ? highest->bestReps : 0},
            {QStringLiteral("highestSetCount"), highest ? highest->setCount : 0},
            {QStringLiteral("oneRepMax"), estimate ? *estimate : 0.0},
            {QStringLiteral("volume"), TrainingAnalytics::totalVolume(records, currentMode)},
        });
        records.clear();
        currentSetId.clear();
    };
    while (query.next()) {
        const QString workoutId = query.value(0).toString();
        if (workoutId != currentWorkoutId) {
            flushWorkout();
            currentWorkoutId = workoutId;
            currentDate = query.value(1).toString();
            currentMode = modeFromString(query.value(2).toString());
        }
        const QString setId = query.value(3).toString();
        if (setId.isEmpty())
            continue;
        if (!hasCurrentSet || setId != currentSetId) {
            flushSet();
            currentSetId = setId;
            hasCurrentSet = true;
            currentRecord = {};
            currentRecord.weightKg = query.value(4).toDouble();
            currentRecord.reps = query.value(5).toInt();
            currentRecord.completed = true;
            currentRecord.bothSides = query.value(6).toBool();
            currentRecord.bodyweightLoadType = bodyweightTypeFromString(
                query.value(7).toString());
        }
        if (!query.value(8).isNull())
            currentRecord.appendSets.append({
                query.value(9).toDouble(), query.value(10).toInt(),
                query.value(11).toInt(), true,
            });
    }
    flushWorkout();
}

void AnalyticsDashboardController::ensureLoaded()
{
    if (m_loaded)
        return;
    m_loaded = true;
    m_overview = m_periodDays == 7 ? m_sevenDayOverview : buildOverview(m_periodDays);
    loadMuscles(m_periodDays);
    loadOptions();
    loadTrend();
    emit dataChanged();
}

void AnalyticsDashboardController::reload()
{
    m_sevenDayOverview = buildOverview(7);
    if (m_loaded) {
        m_overview = m_periodDays == 7 ? m_sevenDayOverview : buildOverview(m_periodDays);
        loadMuscles(m_periodDays);
        loadOptions();
        loadTrend();
    } else {
        m_overview = m_sevenDayOverview;
    }
    emit dataChanged();
}

void AnalyticsDashboardController::setPeriodDays(int days)
{
    if ((days != 7 && days != 30 && days != -1) || m_periodDays == days) return;
    m_periodDays = days;
    if (m_loaded)
        reload();
    else
        ensureLoaded();
}

void AnalyticsDashboardController::selectExercise(const QString &exerciseId)
{
    ensureLoaded();
    if (m_selectedExerciseId == exerciseId)
        return;
    m_selectedExerciseId = exerciseId;
    m_equipmentFilterId.clear();
    loadEquipment();
    loadTrend();
    emit dataChanged();
}

void AnalyticsDashboardController::setGymFilter(const QString &gymId)
{
    ensureLoaded();
    if (m_gymFilterId == gymId)
        return;
    m_gymFilterId = gymId;
    m_equipmentFilterId.clear();
    loadEquipment();
    loadTrend();
    emit dataChanged();
}

void AnalyticsDashboardController::setEquipmentFilter(const QString &equipmentId)
{
    ensureLoaded();
    if (m_equipmentFilterId == equipmentId)
        return;
    m_equipmentFilterId = equipmentId;
    loadTrend();
    emit dataChanged();
}

} // namespace fittrack
