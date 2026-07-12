#include "training/workoutsessioncontroller.h"

#include <QDateTime>
#include <QRegularExpression>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace fittrack {
namespace {

QString newId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

int targetForSet(const QString &description, int setIndex)
{
    const auto parts = description.split(QLatin1Char(','), Qt::SkipEmptyParts);
    const QString part = parts.isEmpty() ? description : parts.at(qMin(setIndex, parts.size() - 1));
    const auto match = QRegularExpression(QStringLiteral("(\\d+)")).match(part);
    return match.hasMatch() ? match.captured(1).toInt() : 0;
}

} // namespace

WorkoutSessionController::WorkoutSessionController(const QSqlDatabase &database, QObject *parent)
    : QObject(parent)
    , m_database(database)
{
    loadPlanDays();
    loadSuggestedDay();
    loadGyms();
    refreshUnfinished();
}

QVariantList WorkoutSessionController::planDays() const { return m_planDays; }
QVariantMap WorkoutSessionController::suggestedDay() const { return m_suggestedDay; }
QVariantList WorkoutSessionController::gyms() const { return m_gyms; }
QVariantList WorkoutSessionController::equipment() const { return m_equipment; }
QVariantList WorkoutSessionController::exercises() const { return m_exercises; }
QString WorkoutSessionController::selectedGymId() const { return m_selectedGymId; }
QString WorkoutSessionController::sessionName() const { return m_sessionName; }
QString WorkoutSessionController::sessionNotes() const { return m_sessionNotes; }
bool WorkoutSessionController::active() const { return !m_sessionId.isEmpty(); }
bool WorkoutSessionController::hasUnfinished() const { return m_hasUnfinished; }
QString WorkoutSessionController::errorMessage() const { return m_errorMessage; }

void WorkoutSessionController::loadPlanDays()
{
    QVariantList days;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT d.id,d.name,p.name,p.is_system FROM plan_day d JOIN training_plan p ON p.id=d.plan_id "
        "ORDER BY p.is_system DESC,p.name,d.sort_order"));
    if (!query.exec()) {
        fail(query.lastError().text());
        return;
    }
    while (query.next()) {
        days.append(QVariantMap{
            {QStringLiteral("dayId"), query.value(0)},
            {QStringLiteral("name"), query.value(1)},
            {QStringLiteral("planName"), query.value(2)},
            {QStringLiteral("isSystem"), query.value(3).toBool()},
        });
    }
    m_planDays = days;
    emit planDaysChanged();
}

void WorkoutSessionController::loadSuggestedDay()
{
    QVariantList systemDays;
    QSqlQuery days(m_database);
    days.prepare(QStringLiteral(
        "SELECT id,name FROM plan_day WHERE plan_id='tan-chengyi-three-day-split' ORDER BY sort_order"));
    if (days.exec()) {
        while (days.next()) {
            systemDays.append(QVariantMap{{QStringLiteral("dayId"), days.value(0)},
                                          {QStringLiteral("name"), days.value(1)}});
        }
    }
    int nextIndex = 0;
    QSqlQuery last(m_database);
    last.prepare(QStringLiteral(
        "SELECT name FROM workout_session WHERE source_plan_id='tan-chengyi-three-day-split' "
        "AND status='completed' ORDER BY ended_at DESC LIMIT 1"));
    if (last.exec() && last.next()) {
        const QString lastName = last.value(0).toString();
        for (int index = 0; index < systemDays.size(); ++index) {
            if (systemDays.at(index).toMap().value(QStringLiteral("name")).toString() == lastName) {
                nextIndex = (index + 1) % systemDays.size();
                break;
            }
        }
    }
    m_suggestedDay = systemDays.isEmpty() ? QVariantMap{} : systemDays.at(nextIndex).toMap();
    emit suggestedDayChanged();
}

void WorkoutSessionController::refreshUnfinished()
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("SELECT 1 FROM workout_session WHERE status='active' LIMIT 1"));
    const bool value = query.exec() && query.next();
    if (m_hasUnfinished != value) {
        m_hasUnfinished = value;
        emit unfinishedChanged();
    }
}

void WorkoutSessionController::loadGyms()
{
    QVariantList gyms;
    QSqlQuery query(m_database);
    if (query.exec(QStringLiteral("SELECT id,name FROM gym ORDER BY name"))) {
        while (query.next()) {
            gyms.append(QVariantMap{
                {QStringLiteral("id"), query.value(0)},
                {QStringLiteral("name"), query.value(1)},
            });
        }
    }
    m_gyms = gyms;
    emit gymsChanged();
}

void WorkoutSessionController::loadEquipment()
{
    QVariantList equipment;
    if (!m_selectedGymId.isEmpty()) {
        QSqlQuery query(m_database);
        query.prepare(QStringLiteral(
            "SELECT id,name,code,notes FROM equipment_instance WHERE gym_id=? ORDER BY name,code"));
        query.addBindValue(m_selectedGymId);
        if (query.exec()) {
            while (query.next()) {
                const QString code = query.value(2).toString();
                equipment.append(QVariantMap{
                    {QStringLiteral("id"), query.value(0)},
                    {QStringLiteral("name"), query.value(1)},
                    {QStringLiteral("code"), code},
                    {QStringLiteral("displayName"), code.isEmpty()
                         ? query.value(1).toString()
                         : QStringLiteral("%1 · %2").arg(query.value(1).toString(), code)},
                    {QStringLiteral("notes"), query.value(3)},
                });
            }
        }
    }
    m_equipment = equipment;
    emit equipmentChanged();
}

bool WorkoutSessionController::addGym(const QString &name)
{
    clearError();
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return fail(QStringLiteral("健身房名称不能为空"));
    }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("INSERT INTO gym(id,name) VALUES(?,?)"));
    const QString id = newId();
    query.addBindValue(id);
    query.addBindValue(trimmed);
    if (!query.exec()) {
        return fail(query.lastError().text());
    }
    loadGyms();
    return selectGym(id);
}

bool WorkoutSessionController::selectGym(const QString &gymId)
{
    clearError();
    if (!gymId.isEmpty()) {
        QSqlQuery check(m_database);
        check.prepare(QStringLiteral("SELECT 1 FROM gym WHERE id=?"));
        check.addBindValue(gymId);
        if (!check.exec() || !check.next()) {
            return fail(QStringLiteral("找不到健身房"));
        }
    }
    if (m_selectedGymId == gymId) {
        return true;
    }
    m_selectedGymId = gymId;
    if (active()) {
        QSqlQuery update(m_database);
        update.prepare(QStringLiteral("UPDATE workout_session SET gym_id=? WHERE id=?"));
        update.addBindValue(gymId.isEmpty() ? QVariant{} : QVariant(gymId));
        update.addBindValue(m_sessionId);
        if (!update.exec()) {
            return fail(update.lastError().text());
        }
        QSqlQuery clearEquipment(m_database);
        clearEquipment.prepare(QStringLiteral(
            "UPDATE workout_exercise SET equipment_instance_id=NULL WHERE session_id=?"));
        clearEquipment.addBindValue(m_sessionId);
        if (!clearEquipment.exec()) {
            return fail(clearEquipment.lastError().text());
        }
    }
    loadEquipment();
    emit selectedGymChanged();
    if (active()) {
        return loadSession(m_sessionId);
    }
    return true;
}

bool WorkoutSessionController::addEquipment(
    const QString &name, const QString &code, const QString &notes)
{
    clearError();
    if (m_selectedGymId.isEmpty()) {
        return fail(QStringLiteral("请先选择健身房"));
    }
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return fail(QStringLiteral("器械名称不能为空"));
    }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO equipment_instance(id,gym_id,name,code,notes) VALUES(?,?,?,?,?)"));
    query.addBindValue(newId());
    query.addBindValue(m_selectedGymId);
    query.addBindValue(trimmed);
    query.addBindValue(code.trimmed());
    query.addBindValue(notes.trimmed());
    if (!query.exec()) {
        return fail(query.lastError().text());
    }
    loadEquipment();
    return true;
}

bool WorkoutSessionController::setExerciseEquipment(int exerciseIndex, const QString &equipmentId)
{
    clearError();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()) {
        return fail(QStringLiteral("动作序号无效"));
    }
    if (!equipmentId.isEmpty()) {
        QSqlQuery check(m_database);
        check.prepare(QStringLiteral(
            "SELECT 1 FROM equipment_instance WHERE id=? AND gym_id=?"));
        check.addBindValue(equipmentId);
        check.addBindValue(m_selectedGymId);
        if (!check.exec() || !check.next()) {
            return fail(QStringLiteral("器械不属于当前健身房"));
        }
    }
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral(
        "UPDATE workout_exercise SET equipment_instance_id=? WHERE id=?"));
    update.addBindValue(equipmentId.isEmpty() ? QVariant{} : QVariant(equipmentId));
    update.addBindValue(m_exercises.at(exerciseIndex).toMap().value(QStringLiteral("id")));
    if (!update.exec()) {
        return fail(update.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::setSessionNotes(const QString &notes)
{
    clearError();
    if (!active()) {
        return fail(QStringLiteral("没有进行中的训练"));
    }
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral("UPDATE workout_session SET notes=? WHERE id=?"));
    update.addBindValue(notes.trimmed());
    update.addBindValue(m_sessionId);
    if (!update.exec()) {
        return fail(update.lastError().text());
    }
    m_sessionNotes = notes.trimmed();
    emit sessionChanged();
    return true;
}

bool WorkoutSessionController::setExerciseNotes(int exerciseIndex, const QString &notes)
{
    clearError();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()) {
        return fail(QStringLiteral("动作序号无效"));
    }
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral("UPDATE workout_exercise SET notes=? WHERE id=?"));
    update.addBindValue(notes.trimmed());
    update.addBindValue(m_exercises.at(exerciseIndex).toMap().value(QStringLiteral("id")));
    if (!update.exec()) {
        return fail(update.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::setSetNotes(int exerciseIndex, int setIndex, const QString &notes)
{
    clearError();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()) {
        return fail(QStringLiteral("动作序号无效"));
    }
    const auto sets = m_exercises.at(exerciseIndex).toMap().value(QStringLiteral("sets")).toList();
    if (setIndex < 0 || setIndex >= sets.size()) {
        return fail(QStringLiteral("组序号无效"));
    }
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral("UPDATE set_record SET notes=? WHERE id=?"));
    update.addBindValue(notes.trimmed());
    update.addBindValue(sets.at(setIndex).toMap().value(QStringLiteral("id")));
    if (!update.exec()) {
        return fail(update.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::saveCurrentAsPlan(
    const QString &planName, const QString &dayName, const QString &sectionName)
{
    clearError();
    if (!active() || m_exercises.isEmpty()) {
        return fail(QStringLiteral("当前训练没有可保存的动作"));
    }
    const QString trimmedPlanName = planName.trimmed();
    const QString trimmedDayName = dayName.trimmed();
    if (trimmedPlanName.isEmpty() || trimmedDayName.isEmpty()) {
        return fail(QStringLiteral("计划名称和训练日名称不能为空"));
    }

    const QString planId = newId();
    const QString dayId = newId();
    const QString sectionId = sectionName.trimmed().isEmpty() ? QString{} : newId();
    if (!m_database.transaction()) {
        return fail(m_database.lastError().text());
    }
    QSqlQuery plan(m_database);
    plan.prepare(QStringLiteral(
        "INSERT INTO training_plan(id,name,is_system,is_read_only) VALUES(?,?,0,0)"));
    plan.addBindValue(planId);
    plan.addBindValue(trimmedPlanName);
    if (!plan.exec()) {
        m_database.rollback();
        return fail(plan.lastError().text());
    }
    QSqlQuery day(m_database);
    day.prepare(QStringLiteral("INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES(?,?,?,0)"));
    day.addBindValue(dayId);
    day.addBindValue(planId);
    day.addBindValue(trimmedDayName);
    if (!day.exec()) {
        m_database.rollback();
        return fail(day.lastError().text());
    }
    if (!sectionId.isEmpty()) {
        QSqlQuery section(m_database);
        section.prepare(QStringLiteral(
            "INSERT INTO plan_section(id,day_id,name,sort_order) VALUES(?,?,?,0)"));
        section.addBindValue(sectionId);
        section.addBindValue(dayId);
        section.addBindValue(sectionName.trimmed());
        if (!section.exec()) {
            m_database.rollback();
            return fail(section.lastError().text());
        }
    }

    for (int index = 0; index < m_exercises.size(); ++index) {
        const auto workoutExercise = m_exercises.at(index).toMap();
        const auto sets = workoutExercise.value(QStringLiteral("sets")).toList();
        QStringList targets;
        for (const auto &setValue : sets) {
            const QVariant target = setValue.toMap().value(QStringLiteral("targetReps"));
            if (!target.isNull()) {
                targets.append(target.toString());
            }
        }
        QSqlQuery planned(m_database);
        planned.prepare(QStringLiteral(
            "INSERT INTO plan_exercise(id,day_id,section_id,exercise_id,sort_order,default_sets,default_reps,rest_seconds,notes) "
            "VALUES(?,?,?,?,?,?,?,?,?)"));
        planned.addBindValue(newId());
        planned.addBindValue(dayId);
        planned.addBindValue(sectionId.isEmpty() ? QVariant{} : QVariant(sectionId));
        planned.addBindValue(workoutExercise.value(QStringLiteral("exerciseId")));
        planned.addBindValue(index);
        planned.addBindValue(sets.size());
        planned.addBindValue(targets.join(QLatin1Char(',')));
        planned.addBindValue(workoutExercise.value(QStringLiteral("restSeconds")));
        planned.addBindValue(workoutExercise.value(QStringLiteral("notes")));
        if (!planned.exec()) {
            m_database.rollback();
            return fail(planned.lastError().text());
        }
    }
    if (!m_database.commit()) {
        return fail(m_database.lastError().text());
    }
    loadPlanDays();
    return true;
}

bool WorkoutSessionController::startPlanDay(const QString &dayId)
{
    clearError();
    if (active()) {
        return fail(QStringLiteral("请先结束当前训练"));
    }

    QSqlQuery day(m_database);
    day.prepare(QStringLiteral("SELECT d.name,d.plan_id FROM plan_day d WHERE d.id=?"));
    day.addBindValue(dayId);
    if (!day.exec() || !day.next()) {
        return fail(QStringLiteral("找不到训练日"));
    }
    const QString name = day.value(0).toString();
    const QString planId = day.value(1).toString();
    const QString sessionId = newId();

    if (!m_database.transaction()) {
        return fail(m_database.lastError().text());
    }
    QSqlQuery session(m_database);
    session.prepare(QStringLiteral(
        "INSERT INTO workout_session(id,name,source_plan_id,gym_id,started_at,status) VALUES(?,?,?,?,?, 'active')"));
    session.addBindValue(sessionId);
    session.addBindValue(name);
    session.addBindValue(planId);
    session.addBindValue(m_selectedGymId.isEmpty() ? QVariant{} : QVariant(m_selectedGymId));
    session.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    if (!session.exec()) {
        m_database.rollback();
        return fail(session.lastError().text());
    }

    QSqlQuery planned(m_database);
    planned.prepare(QStringLiteral(
        "SELECT exercise_id,sort_order,default_sets,default_reps,rest_seconds,notes "
        "FROM plan_exercise WHERE day_id=? ORDER BY sort_order"));
    planned.addBindValue(dayId);
    if (!planned.exec()) {
        m_database.rollback();
        return fail(planned.lastError().text());
    }
    while (planned.next()) {
        const QString workoutExerciseId = newId();
        QSqlQuery exercise(m_database);
        exercise.prepare(QStringLiteral(
            "INSERT INTO workout_exercise(id,session_id,exercise_id,sort_order,notes) VALUES(?,?,?,?,?)"));
        exercise.addBindValue(workoutExerciseId);
        exercise.addBindValue(sessionId);
        exercise.addBindValue(planned.value(0));
        exercise.addBindValue(planned.value(1));
        exercise.addBindValue(planned.value(5));
        if (!exercise.exec()) {
            m_database.rollback();
            return fail(exercise.lastError().text());
        }

        const int setCount = planned.value(2).toInt();
        const QString reps = planned.value(3).toString();
        for (int index = 0; index < setCount; ++index) {
            QSqlQuery set(m_database);
            set.prepare(QStringLiteral(
                "INSERT INTO set_record(id,workout_exercise_id,set_order,target_reps) VALUES(?,?,?,?)"));
            set.addBindValue(newId());
            set.addBindValue(workoutExerciseId);
            set.addBindValue(index);
            const int target = targetForSet(reps, index);
            set.addBindValue(target > 0 ? QVariant(target) : QVariant{});
            if (!set.exec()) {
                m_database.rollback();
                return fail(set.lastError().text());
            }
        }
    }
    if (!m_database.commit()) {
        return fail(m_database.lastError().text());
    }
    return loadSession(sessionId);
}

bool WorkoutSessionController::startSuggestedDay()
{
    const QString dayId = m_suggestedDay.value(QStringLiteral("dayId")).toString();
    return !dayId.isEmpty() && startPlanDay(dayId);
}

bool WorkoutSessionController::startFreeWorkout(const QString &name)
{
    clearError();
    if (active()) {
        return fail(QStringLiteral("请先结束当前训练"));
    }
    const QString sessionId = newId();
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO workout_session(id,name,gym_id,started_at,status) VALUES(?,?,?,?,'active')"));
    query.addBindValue(sessionId);
    query.addBindValue(name.trimmed().isEmpty() ? QStringLiteral("自由训练") : name.trimmed());
    query.addBindValue(m_selectedGymId.isEmpty() ? QVariant{} : QVariant(m_selectedGymId));
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    if (!query.exec()) {
        return fail(query.lastError().text());
    }
    return loadSession(sessionId);
}

bool WorkoutSessionController::addExercise(const QString &exerciseId, int setCount, const QString &targetReps)
{
    clearError();
    if (!active()) {
        return fail(QStringLiteral("请先开始训练"));
    }
    QSqlQuery info(m_database);
    info.prepare(QStringLiteral("SELECT recommended_sets,recommended_reps FROM exercise WHERE id=?"));
    info.addBindValue(exerciseId);
    if (!info.exec() || !info.next()) {
        return fail(QStringLiteral("找不到动作"));
    }
    const int actualSetCount = setCount > 0 ? setCount : qMax(1, info.value(0).toInt());
    const QString reps = targetReps.trimmed().isEmpty() ? info.value(1).toString() : targetReps.trimmed();

    if (!m_database.transaction()) {
        return fail(m_database.lastError().text());
    }
    const QString workoutExerciseId = newId();
    QSqlQuery exercise(m_database);
    exercise.prepare(QStringLiteral(
        "INSERT INTO workout_exercise(id,session_id,exercise_id,sort_order) "
        "VALUES(?,?,?,(SELECT COUNT(*) FROM workout_exercise WHERE session_id=?))"));
    exercise.addBindValue(workoutExerciseId);
    exercise.addBindValue(m_sessionId);
    exercise.addBindValue(exerciseId);
    exercise.addBindValue(m_sessionId);
    if (!exercise.exec()) {
        m_database.rollback();
        return fail(exercise.lastError().text());
    }
    for (int index = 0; index < actualSetCount; ++index) {
        QSqlQuery set(m_database);
        set.prepare(QStringLiteral(
            "INSERT INTO set_record(id,workout_exercise_id,set_order,target_reps) VALUES(?,?,?,?)"));
        set.addBindValue(newId());
        set.addBindValue(workoutExerciseId);
        set.addBindValue(index);
        const int target = targetForSet(reps, index);
        set.addBindValue(target > 0 ? QVariant(target) : QVariant{});
        if (!set.exec()) {
            m_database.rollback();
            return fail(set.lastError().text());
        }
    }
    if (!m_database.commit()) {
        return fail(m_database.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::replaceExercise(int exerciseIndex, const QString &exerciseId)
{
    clearError();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()) {
        return fail(QStringLiteral("动作序号无效"));
    }
    const QString workoutExerciseId = m_exercises.at(exerciseIndex).toMap()
                                          .value(QStringLiteral("id")).toString();
    QSqlQuery info(m_database);
    info.prepare(QStringLiteral(
        "SELECT recommended_sets,recommended_reps FROM exercise WHERE id=? AND is_enabled=1"));
    info.addBindValue(exerciseId);
    if (!info.exec() || !info.next()) {
        return fail(QStringLiteral("找不到替换动作"));
    }
    QSqlQuery completed(m_database);
    completed.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM set_record WHERE workout_exercise_id=? AND completed=1"));
    completed.addBindValue(workoutExerciseId);
    if (!completed.exec() || !completed.next()) {
        return fail(completed.lastError().text());
    }
    if (completed.value(0).toInt() > 0) {
        return fail(QStringLiteral("该动作已有完成组，不能替换"));
    }

    if (!m_database.transaction()) {
        return fail(m_database.lastError().text());
    }
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral(
        "UPDATE workout_exercise SET exercise_id=?,notes='' WHERE id=?"));
    update.addBindValue(exerciseId);
    update.addBindValue(workoutExerciseId);
    if (!update.exec()) {
        m_database.rollback();
        return fail(update.lastError().text());
    }
    QSqlQuery clear(m_database);
    clear.prepare(QStringLiteral("DELETE FROM set_record WHERE workout_exercise_id=?"));
    clear.addBindValue(workoutExerciseId);
    if (!clear.exec()) {
        m_database.rollback();
        return fail(clear.lastError().text());
    }
    const int setCount = qMax(1, info.value(0).toInt());
    const QString reps = info.value(1).toString();
    for (int index = 0; index < setCount; ++index) {
        QSqlQuery set(m_database);
        set.prepare(QStringLiteral(
            "INSERT INTO set_record(id,workout_exercise_id,set_order,target_reps) VALUES(?,?,?,?)"));
        set.addBindValue(newId());
        set.addBindValue(workoutExerciseId);
        set.addBindValue(index);
        const int target = targetForSet(reps, index);
        set.addBindValue(target > 0 ? QVariant(target) : QVariant{});
        if (!set.exec()) {
            m_database.rollback();
            return fail(set.lastError().text());
        }
    }
    if (!m_database.commit()) {
        return fail(m_database.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::moveExercise(int fromIndex, int toIndex)
{
    clearError();
    if (fromIndex < 0 || fromIndex >= m_exercises.size()
        || toIndex < 0 || toIndex >= m_exercises.size()) {
        return fail(QStringLiteral("动作序号无效"));
    }
    if (fromIndex == toIndex) {
        return true;
    }
    QVariantList reordered = m_exercises;
    reordered.move(fromIndex, toIndex);
    if (!m_database.transaction()) {
        return fail(m_database.lastError().text());
    }
    for (int index = 0; index < reordered.size(); ++index) {
        QSqlQuery update(m_database);
        update.prepare(QStringLiteral("UPDATE workout_exercise SET sort_order=? WHERE id=?"));
        update.addBindValue(index);
        update.addBindValue(reordered.at(index).toMap().value(QStringLiteral("id")));
        if (!update.exec()) {
            m_database.rollback();
            return fail(update.lastError().text());
        }
    }
    if (!m_database.commit()) {
        return fail(m_database.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::removeExercise(int exerciseIndex)
{
    clearError();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()) {
        return fail(QStringLiteral("动作序号无效"));
    }
    const QString workoutExerciseId = m_exercises.at(exerciseIndex).toMap()
                                          .value(QStringLiteral("id")).toString();
    QSqlQuery completed(m_database);
    completed.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM set_record WHERE workout_exercise_id=? AND completed=1"));
    completed.addBindValue(workoutExerciseId);
    if (!completed.exec() || !completed.next()) {
        return fail(completed.lastError().text());
    }
    if (completed.value(0).toInt() > 0) {
        return fail(QStringLiteral("该动作已有完成组，不能删除"));
    }
    QSqlQuery remove(m_database);
    remove.prepare(QStringLiteral("DELETE FROM workout_exercise WHERE id=?"));
    remove.addBindValue(workoutExerciseId);
    if (!remove.exec()) {
        return fail(remove.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::completeSet(
    int exerciseIndex, int setIndex, double weightKg, int actualReps, bool toFailure,
    const QString &bodyweightLoadType)
{
    clearError();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size() || actualReps < 0 || weightKg < 0) {
        return fail(QStringLiteral("组数据无效"));
    }
    const auto exercise = m_exercises.at(exerciseIndex).toMap();
    const auto sets = exercise.value(QStringLiteral("sets")).toList();
    if (setIndex < 0 || setIndex >= sets.size()) {
        return fail(QStringLiteral("组序号无效"));
    }
    const QString setId = sets.at(setIndex).toMap().value(QStringLiteral("id")).toString();
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "UPDATE set_record SET weight_kg=?,actual_reps=?,completed=1,to_failure=?,bodyweight_load_type=?,completed_at=? WHERE id=?"));
    query.addBindValue(weightKg);
    query.addBindValue(actualReps);
    query.addBindValue(toFailure ? 1 : 0);
    const QString normalizedBodyweightLoad = bodyweightLoadType == QStringLiteral("Added")
            || bodyweightLoadType == QStringLiteral("Assisted")
        ? bodyweightLoadType : QStringLiteral("Bodyweight");
    query.addBindValue(normalizedBodyweightLoad);
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    query.addBindValue(setId);
    if (!query.exec()) {
        return fail(query.lastError().text());
    }
    const int restSeconds = exercise.value(QStringLiteral("restSeconds")).toInt();
    if (!loadSession(m_sessionId)) {
        return false;
    }
    emit setCompleted(restSeconds);
    return true;
}

bool WorkoutSessionController::configureExercise(
    int exerciseIndex, double weightKg, int targetReps, int setCount)
{
    clearError();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()
        || weightKg < 0 || targetReps < 0 || setCount < 1 || setCount > 99) {
        return fail(QStringLiteral("快速组数据无效"));
    }
    const QString workoutExerciseId = m_exercises.at(exerciseIndex).toMap()
                                          .value(QStringLiteral("id")).toString();
    QSqlQuery completed(m_database);
    completed.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM set_record WHERE workout_exercise_id=? AND completed=1"));
    completed.addBindValue(workoutExerciseId);
    if (!completed.exec() || !completed.next()) {
        return fail(completed.lastError().text());
    }
    if (completed.value(0).toInt() > 0) {
        return fail(QStringLiteral("已有完成组，不能重新生成组卡"));
    }

    if (!m_database.transaction()) {
        return fail(m_database.lastError().text());
    }
    QSqlQuery clear(m_database);
    clear.prepare(QStringLiteral("DELETE FROM set_record WHERE workout_exercise_id=?"));
    clear.addBindValue(workoutExerciseId);
    if (!clear.exec()) {
        m_database.rollback();
        return fail(clear.lastError().text());
    }
    for (int index = 0; index < setCount; ++index) {
        QSqlQuery set(m_database);
        set.prepare(QStringLiteral(
            "INSERT INTO set_record(id,workout_exercise_id,set_order,weight_kg,target_reps) VALUES(?,?,?,?,?)"));
        set.addBindValue(newId());
        set.addBindValue(workoutExerciseId);
        set.addBindValue(index);
        set.addBindValue(weightKg);
        set.addBindValue(targetReps);
        if (!set.exec()) {
            m_database.rollback();
            return fail(set.lastError().text());
        }
    }
    if (!m_database.commit()) {
        return fail(m_database.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::addAppendSet(
    int exerciseIndex, int setIndex, double weightKg, int reps, int restSeconds, bool toFailure)
{
    clearError();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()
        || weightKg < 0 || reps < 0 || restSeconds < 0) {
        return fail(QStringLiteral("追加组数据无效"));
    }
    const auto sets = m_exercises.at(exerciseIndex).toMap().value(QStringLiteral("sets")).toList();
    if (setIndex < 0 || setIndex >= sets.size()) {
        return fail(QStringLiteral("组序号无效"));
    }
    const auto parent = sets.at(setIndex).toMap();
    if (!parent.value(QStringLiteral("completed")).toBool()) {
        return fail(QStringLiteral("请先完成主组"));
    }

    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO append_set_record(id,parent_set_id,weight_kg,reps,rest_seconds,to_failure) "
        "VALUES(?,?,?,?,?,?)"));
    query.addBindValue(newId());
    query.addBindValue(parent.value(QStringLiteral("id")));
    query.addBindValue(weightKg);
    query.addBindValue(reps);
    query.addBindValue(restSeconds);
    query.addBindValue(toFailure ? 1 : 0);
    if (!query.exec()) {
        return fail(query.lastError().text());
    }
    return loadSession(m_sessionId);
}

bool WorkoutSessionController::resumeUnfinished()
{
    clearError();
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT id FROM workout_session WHERE status='active' ORDER BY started_at DESC LIMIT 1"));
    if (!query.exec() || !query.next()) {
        return fail(QStringLiteral("没有未完成训练"));
    }
    return loadSession(query.value(0).toString());
}

bool WorkoutSessionController::finishUnfinished()
{
    if (!resumeUnfinished()) {
        return false;
    }
    return finishWorkout();
}

bool WorkoutSessionController::discardUnfinished()
{
    if (!resumeUnfinished()) {
        return false;
    }
    return discardWorkout();
}

bool WorkoutSessionController::finishWorkout()
{
    clearError();
    if (!active()) {
        return false;
    }
    const QString completedSessionId = m_sessionId;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("UPDATE workout_session SET status='completed',ended_at=? WHERE id=?"));
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    query.addBindValue(m_sessionId);
    if (!query.exec()) {
        return fail(query.lastError().text());
    }
    m_sessionId.clear();
    m_sessionName.clear();
    m_sessionNotes.clear();
    m_exercises.clear();
    emit exercisesChanged();
    emit sessionChanged();
    refreshUnfinished();
    loadSuggestedDay();
    emit workoutFinished(completedSessionId);
    return true;
}

bool WorkoutSessionController::discardWorkout()
{
    clearError();
    if (!active()) {
        return false;
    }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("DELETE FROM workout_session WHERE id=?"));
    query.addBindValue(m_sessionId);
    if (!query.exec()) {
        return fail(query.lastError().text());
    }
    m_sessionId.clear();
    m_sessionName.clear();
    m_sessionNotes.clear();
    m_exercises.clear();
    emit exercisesChanged();
    emit sessionChanged();
    refreshUnfinished();
    return true;
}

bool WorkoutSessionController::loadSession(const QString &sessionId)
{
    QSqlQuery session(m_database);
    session.prepare(QStringLiteral("SELECT name,gym_id,notes FROM workout_session WHERE id=? AND status='active'"));
    session.addBindValue(sessionId);
    if (!session.exec() || !session.next()) {
        return fail(QStringLiteral("无法加载训练"));
    }

    QVariantList exercises;
    QSqlQuery exercise(m_database);
    exercise.prepare(QStringLiteral(
        "SELECT we.id,e.name_zh,e.load_mode,e.recommended_reps,e.rest_seconds,we.notes,"
        "e.id,we.equipment_instance_id,COALESCE(eq.name || CASE WHEN eq.code IS NULL OR eq.code='' THEN '' ELSE ' · ' || eq.code END,'') "
        "FROM workout_exercise we JOIN exercise e ON e.id=we.exercise_id "
        "LEFT JOIN equipment_instance eq ON eq.id=we.equipment_instance_id "
        "WHERE we.session_id=? ORDER BY we.sort_order"));
    exercise.addBindValue(sessionId);
    if (!exercise.exec()) {
        return fail(exercise.lastError().text());
    }
    while (exercise.next()) {
        QVariantList sets;
        QSqlQuery set(m_database);
        set.prepare(QStringLiteral(
            "SELECT id,set_order,weight_kg,target_reps,actual_reps,completed,to_failure,notes,bodyweight_load_type "
            "FROM set_record WHERE workout_exercise_id=? ORDER BY set_order"));
        set.addBindValue(exercise.value(0));
        if (!set.exec()) {
            return fail(set.lastError().text());
        }
        while (set.next()) {
            QVariantList appendSets;
            QSqlQuery append(m_database);
            append.prepare(QStringLiteral(
                "SELECT weight_kg,reps,rest_seconds,to_failure FROM append_set_record "
                "WHERE parent_set_id=? ORDER BY rowid"));
            append.addBindValue(set.value(0));
            if (!append.exec()) {
                return fail(append.lastError().text());
            }
            while (append.next()) {
                appendSets.append(QVariantMap{
                    {QStringLiteral("weightKg"), append.value(0)},
                    {QStringLiteral("reps"), append.value(1)},
                    {QStringLiteral("restSeconds"), append.value(2)},
                    {QStringLiteral("toFailure"), append.value(3).toBool()},
                });
            }
            sets.append(QVariantMap{
                {QStringLiteral("id"), set.value(0)},
                {QStringLiteral("number"), set.value(1).toInt() + 1},
                {QStringLiteral("weightKg"), set.value(2)},
                {QStringLiteral("targetReps"), set.value(3)},
                {QStringLiteral("actualReps"), set.value(4)},
                {QStringLiteral("completed"), set.value(5).toBool()},
                {QStringLiteral("toFailure"), set.value(6).toBool()},
                {QStringLiteral("notes"), set.value(7)},
                {QStringLiteral("bodyweightLoadType"), set.value(8)},
                {QStringLiteral("appendSets"), appendSets},
            });
        }
        QVariantList previousSets;
        QSqlQuery previousSession(m_database);
        previousSession.prepare(QStringLiteral(
            "SELECT we.id FROM workout_exercise we JOIN workout_session ws ON ws.id=we.session_id "
            "WHERE we.exercise_id=? AND ws.status='completed' AND ws.id<>? "
            "AND ((we.equipment_instance_id=? ) OR (we.equipment_instance_id IS NULL AND ? IS NULL)) "
            "ORDER BY ws.ended_at DESC LIMIT 1"));
        previousSession.addBindValue(exercise.value(6));
        previousSession.addBindValue(sessionId);
        const QVariant equipmentId = exercise.value(7);
        previousSession.addBindValue(equipmentId);
        previousSession.addBindValue(equipmentId);
        if (previousSession.exec() && previousSession.next()) {
            QSqlQuery previous(m_database);
            previous.prepare(QStringLiteral(
                "SELECT weight_kg,actual_reps FROM set_record "
                "WHERE workout_exercise_id=? AND completed=1 ORDER BY set_order"));
            previous.addBindValue(previousSession.value(0));
            if (previous.exec()) {
                while (previous.next()) {
                    previousSets.append(QVariantMap{
                        {QStringLiteral("weightKg"), previous.value(0)},
                        {QStringLiteral("reps"), previous.value(1)},
                    });
                }
            }
        }
        exercises.append(QVariantMap{
            {QStringLiteral("id"), exercise.value(0)},
            {QStringLiteral("name"), exercise.value(1)},
            {QStringLiteral("loadMode"), exercise.value(2)},
            {QStringLiteral("recommendedReps"), exercise.value(3)},
            {QStringLiteral("restSeconds"), exercise.value(4)},
            {QStringLiteral("notes"), exercise.value(5)},
            {QStringLiteral("exerciseId"), exercise.value(6)},
            {QStringLiteral("equipmentId"), exercise.value(7)},
            {QStringLiteral("equipmentName"), exercise.value(8)},
            {QStringLiteral("previousSets"), previousSets},
            {QStringLiteral("sets"), sets},
        });
    }

    m_sessionId = sessionId;
    m_sessionName = session.value(0).toString();
    m_sessionNotes = session.value(2).toString();
    const QString sessionGymId = session.value(1).toString();
    if (m_selectedGymId != sessionGymId) {
        m_selectedGymId = sessionGymId;
        loadEquipment();
        emit selectedGymChanged();
    }
    m_exercises = exercises;
    emit exercisesChanged();
    emit sessionChanged();
    refreshUnfinished();
    return true;
}

bool WorkoutSessionController::fail(const QString &message)
{
    if (m_errorMessage != message) {
        m_errorMessage = message;
        emit errorMessageChanged();
    }
    return false;
}

void WorkoutSessionController::clearError()
{
    if (!m_errorMessage.isEmpty()) {
        m_errorMessage.clear();
        emit errorMessageChanged();
    }
}

} // namespace fittrack
