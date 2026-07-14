#include "training/workoutsessioncontroller.h"

#include <algorithm>
#include <QDateTime>
#include <QHash>
#include <QRegularExpression>
#include <QSet>
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
    loadStartupState();
}

QVariantList WorkoutSessionController::planDays() const { return m_planDays; }
QVariantMap WorkoutSessionController::suggestedDay() const { return m_suggestedDay; }
QVariantList WorkoutSessionController::gyms() const { return m_gyms; }
QVariantList WorkoutSessionController::equipment() const { return m_equipment; }
QVariantList WorkoutSessionController::exercises() const { return m_exercises; }
QVariantList WorkoutSessionController::activeSessions() const { return m_activeSessions; }
QVariantMap WorkoutSessionController::preparation() const { return m_preparation; }
bool WorkoutSessionController::preparing() const { return !m_preparation.isEmpty(); }
QString WorkoutSessionController::selectedGymId() const { return m_selectedGymId; }
QString WorkoutSessionController::sessionId() const { return m_sessionId; }
QString WorkoutSessionController::sessionName() const { return m_sessionName; }
QString WorkoutSessionController::sessionNotes() const { return m_sessionNotes; }
bool WorkoutSessionController::active() const { return !m_sessionId.isEmpty(); }
bool WorkoutSessionController::hasUnfinished() const { return m_hasUnfinished; }
QString WorkoutSessionController::sessionState() const
{
    if (m_activeSessionCount > 1) return QStringLiteral("RecoveryRequired");
    if (active()) return QStringLiteral("Active");
    if (m_hasUnfinished) return QStringLiteral("Recoverable");
    return QStringLiteral("Idle");
}
QString WorkoutSessionController::errorMessage() const { return m_errorMessage; }

void WorkoutSessionController::loadStartupState()
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT 0 AS kind,d.id,d.name,p.name,p.id,p.is_system,d.sort_order,"
        "CASE WHEN p.is_system=1 THEN 0 ELSE 1 END AS sort_group,"
        "p.name AS sort_asc,'' AS sort_desc,d.sort_order AS sort_number "
        "FROM plan_day d JOIN training_plan p ON p.id=d.plan_id "
        "UNION ALL "
        "SELECT 1,g.id,g.name,'','',0,0,0,g.name,'',0 "
        "FROM gym g WHERE g.is_enabled=1 "
        "UNION ALL "
        "SELECT 2,ws.id,ws.name,ws.started_at,'',"
        "(SELECT COUNT(*) FROM workout_exercise we WHERE we.session_id=ws.id),"
        "(SELECT COUNT(*) FROM set_record sr JOIN workout_exercise we "
        "ON we.id=sr.workout_exercise_id WHERE we.session_id=ws.id AND sr.completed=1),"
        "0,'',ws.started_at,0 "
        "FROM workout_session ws WHERE ws.status='active' "
        "UNION ALL "
        "SELECT 3,'',latest.name,'','',0,0,0,'','',0 FROM ("
        "SELECT name FROM workout_session "
        "WHERE source_plan_id='tan-chengyi-three-day-split' AND status='completed' "
        "ORDER BY ended_at DESC,id DESC LIMIT 1) latest "
        "ORDER BY kind,sort_group,sort_asc,sort_desc DESC,sort_number,id"));
    if (!query.exec()) {
        fail(query.lastError().text());
        return;
    }

    QVariantList planDays;
    QVariantList systemDays;
    QVariantList gyms;
    QVariantList activeSessions;
    QString lastSystemDayName;
    while (query.next()) {
        switch (query.value(0).toInt()) {
        case 0: {
            QVariantMap day{
                {QStringLiteral("dayId"), query.value(1)},
                {QStringLiteral("name"), query.value(2)},
                {QStringLiteral("planName"), query.value(3)},
                {QStringLiteral("isSystem"), query.value(5).toBool()},
            };
            planDays.append(day);
            if (query.value(4).toString()
                == QStringLiteral("tan-chengyi-three-day-split")) {
                systemDays.append(day);
            }
            break;
        }
        case 1:
            gyms.append(QVariantMap{{QStringLiteral("id"), query.value(1)},
                                    {QStringLiteral("name"), query.value(2)}});
            break;
        case 2:
            activeSessions.append(QVariantMap{
                {QStringLiteral("id"), query.value(1)},
                {QStringLiteral("name"), query.value(2)},
                {QStringLiteral("startedAt"), query.value(3)},
                {QStringLiteral("exerciseCount"), query.value(5)},
                {QStringLiteral("completedSetCount"), query.value(6)},
            });
            break;
        case 3:
            lastSystemDayName = query.value(2).toString();
            break;
        }
    }

    int nextSystemDay = 0;
    for (int index = 0; index < systemDays.size(); ++index) {
        if (systemDays.at(index).toMap().value(QStringLiteral("name")).toString()
            == lastSystemDayName) {
            nextSystemDay = (index + 1) % systemDays.size();
            break;
        }
    }
    m_planDays = planDays;
    m_suggestedDay = systemDays.isEmpty()
        ? QVariantMap{}
        : QVariantMap{{QStringLiteral("dayId"),
                       systemDays.at(nextSystemDay).toMap().value(QStringLiteral("dayId"))},
                      {QStringLiteral("name"),
                       systemDays.at(nextSystemDay).toMap().value(QStringLiteral("name"))}};
    m_gyms = gyms;
    emit planDaysChanged();
    emit suggestedDayChanged();
    emit gymsChanged();
    applyActiveSessions(activeSessions);
}

void WorkoutSessionController::applyActiveSessions(const QVariantList &activeSessions)
{
    const int count = activeSessions.size();
    const bool hasUnfinished = count > 0;
    const bool stateChanged = m_activeSessionCount != count;
    m_activeSessionCount = count;
    if (m_activeSessions != activeSessions) {
        m_activeSessions = activeSessions;
        emit activeSessionsChanged();
    }
    if (m_hasUnfinished != hasUnfinished) {
        m_hasUnfinished = hasUnfinished;
        emit unfinishedChanged();
    }
    if (stateChanged) emit sessionStateChanged();
}

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
    query.prepare(QStringLiteral(
        "SELECT ws.id,ws.name,ws.started_at,"
        "(SELECT COUNT(*) FROM workout_exercise we WHERE we.session_id=ws.id),"
        "(SELECT COUNT(*) FROM set_record sr JOIN workout_exercise we "
        "ON we.id=sr.workout_exercise_id WHERE we.session_id=ws.id AND sr.completed=1) "
        "FROM workout_session ws WHERE ws.status='active' "
        "ORDER BY ws.started_at DESC,ws.id"));
    QVariantList activeSessions;
    if (query.exec()) {
        while (query.next()) {
            activeSessions.append(QVariantMap{
                {QStringLiteral("id"), query.value(0)},
                {QStringLiteral("name"), query.value(1)},
                {QStringLiteral("startedAt"), query.value(2)},
                {QStringLiteral("exerciseCount"), query.value(3)},
                {QStringLiteral("completedSetCount"), query.value(4)},
            });
        }
    }
    applyActiveSessions(activeSessions);
}

void WorkoutSessionController::loadGyms()
{
    QVariantList gyms;
    QSqlQuery query(m_database);
    if (query.exec(QStringLiteral("SELECT id,name FROM gym WHERE is_enabled=1 ORDER BY name"))) {
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
            "SELECT id,name,code,notes FROM equipment_instance "
            "WHERE gym_id=? AND is_enabled=1 ORDER BY name,code"));
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
    query.prepare(QStringLiteral(
        "INSERT INTO gym(id,name,is_enabled) VALUES(?,?,1) "
        "ON CONFLICT(name) DO UPDATE SET is_enabled=1"));
    const QString id = newId();
    query.addBindValue(id);
    query.addBindValue(trimmed);
    if (!query.exec()) {
        return fail(query.lastError().text());
    }
    loadGyms();
    QSqlQuery selected(m_database);
    selected.prepare(QStringLiteral("SELECT id FROM gym WHERE name=? AND is_enabled=1"));
    selected.addBindValue(trimmed);
    return selected.exec() && selected.next() && selectGym(selected.value(0).toString());
}

bool WorkoutSessionController::selectGym(const QString &gymId)
{
    clearError();
    if (!gymId.isEmpty()) {
        QSqlQuery check(m_database);
        check.prepare(QStringLiteral("SELECT 1 FROM gym WHERE id=? AND is_enabled=1"));
        check.addBindValue(gymId);
        if (!check.exec() || !check.next()) {
            return fail(QStringLiteral("找不到健身房"));
        }
    }
    if (m_selectedGymId == gymId) {
        return true;
    }
    if (active()) {
        if (!m_database.transaction()) {
            return fail(m_database.lastError().text());
        }
        QSqlQuery update(m_database);
        update.prepare(QStringLiteral("UPDATE workout_session SET gym_id=? WHERE id=?"));
        update.addBindValue(gymId.isEmpty() ? QVariant{} : QVariant(gymId));
        update.addBindValue(m_sessionId);
        if (!update.exec()) {
            m_database.rollback();
            return fail(update.lastError().text());
        }
        QSqlQuery clearEquipment(m_database);
        clearEquipment.prepare(QStringLiteral(
            "UPDATE workout_exercise SET equipment_instance_id=NULL WHERE session_id=?"));
        clearEquipment.addBindValue(m_sessionId);
        if (!clearEquipment.exec()) {
            m_database.rollback();
            return fail(clearEquipment.lastError().text());
        }
        if (!m_database.commit()) {
            const QString message = m_database.lastError().text();
            m_database.rollback();
            return fail(message);
        }
    }
    m_selectedGymId = gymId;
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
            "SELECT 1 FROM equipment_instance WHERE id=? AND gym_id=? AND is_enabled=1"));
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

bool WorkoutSessionController::setTargetReps(int exerciseIndex, int setIndex, int targetReps)
{
    clearError();
    if (!active()) {
        return fail(QStringLiteral("没有进行中的训练"));
    }
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()
        || targetReps < 1 || targetReps > 999) {
        return fail(QStringLiteral("目标次数无效"));
    }
    const auto sets = m_exercises.at(exerciseIndex).toMap().value(QStringLiteral("sets")).toList();
    if (setIndex < 0 || setIndex >= sets.size()) {
        return fail(QStringLiteral("组序号无效"));
    }
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral(
        "UPDATE set_record SET target_reps=? WHERE id=? AND workout_exercise_id IN ("
        "SELECT we.id FROM workout_exercise we JOIN workout_session ws ON ws.id=we.session_id "
        "WHERE ws.id=? AND ws.status='active')"));
    update.addBindValue(targetReps);
    update.addBindValue(sets.at(setIndex).toMap().value(QStringLiteral("id")));
    update.addBindValue(m_sessionId);
    if (!update.exec()) {
        return fail(update.lastError().text());
    }
    if (update.numRowsAffected() != 1) {
        return fail(QStringLiteral("找不到当前训练组"));
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

int WorkoutSessionController::activeSessionCount() const
{
    QSqlQuery query(m_database);
    return query.exec(QStringLiteral(
               "SELECT COUNT(*) FROM workout_session WHERE status='active'"))
               && query.next()
           ? query.value(0).toInt()
           : 0;
}

QVariantMap WorkoutSessionController::activeSessionSummary() const
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT id,name,started_at FROM workout_session WHERE status='active' "
        "ORDER BY started_at DESC,id LIMIT 1"));
    if (!query.exec() || !query.next()) return {};
    return QVariantMap{
        {QStringLiteral("currentSessionId"), query.value(0)},
        {QStringLiteral("currentSessionName"), query.value(1)},
        {QStringLiteral("currentStartedAt"), query.value(2)},
    };
}

QVariantMap WorkoutSessionController::requestStart(
    const QString &kind, const QString &targetId, const QString &displayName)
{
    clearError();
    const int count = activeSessionCount();
    refreshUnfinished();
    if (count > 0) {
        QVariantMap result = activeSessionSummary();
        result.insert(QStringLiteral("status"),
                      count > 1 ? QStringLiteral("recoveryRequired")
                                : QStringLiteral("conflict"));
        result.insert(QStringLiteral("activeSessionCount"), count);
        result.insert(QStringLiteral("requestedKind"), kind);
        result.insert(QStringLiteral("requestedTargetId"), targetId);
        result.insert(QStringLiteral("requestedName"), displayName);
        return result;
    }

    const bool started = kind == QStringLiteral("plan")
        ? startPlanDay(targetId)
        : startFreeWorkout(displayName);
    return QVariantMap{
        {QStringLiteral("status"), started ? QStringLiteral("started")
                                            : QStringLiteral("error")},
        {QStringLiteral("message"), m_errorMessage},
    };
}

QVariantMap WorkoutSessionController::requestStartPlanDay(const QString &dayId)
{
    QSqlQuery day(m_database);
    day.prepare(QStringLiteral("SELECT name FROM plan_day WHERE id=?"));
    day.addBindValue(dayId);
    if (!day.exec() || !day.next()) {
        fail(QStringLiteral("找不到训练日"));
        return QVariantMap{{QStringLiteral("status"), QStringLiteral("error")},
                           {QStringLiteral("message"), m_errorMessage}};
    }
    return requestStart(QStringLiteral("plan"), dayId, day.value(0).toString());
}

QVariantMap WorkoutSessionController::requestStartSuggestedDay()
{
    const QString dayId = m_suggestedDay.value(QStringLiteral("dayId")).toString();
    if (dayId.isEmpty()) {
        fail(QStringLiteral("没有可开始的推荐训练"));
        return QVariantMap{{QStringLiteral("status"), QStringLiteral("error")},
                           {QStringLiteral("message"), m_errorMessage}};
    }
    return requestStartPlanDay(dayId);
}

QVariantMap WorkoutSessionController::requestStartFreeWorkout(const QString &name)
{
    const QString displayName = name.trimmed().isEmpty() ? QStringLiteral("自由训练")
                                                         : name.trimmed();
    return requestStart(QStringLiteral("free"), QString{}, displayName);
}

QVariantMap WorkoutSessionController::requestPrepare(
    const QString &kind, const QString &targetId, const QString &displayName)
{
    clearError();
    const int count = activeSessionCount();
    refreshUnfinished();
    if (count > 0) {
        QVariantMap result = activeSessionSummary();
        result.insert(QStringLiteral("status"),
                      count > 1 ? QStringLiteral("recoveryRequired")
                                : QStringLiteral("conflict"));
        result.insert(QStringLiteral("activeSessionCount"), count);
        result.insert(QStringLiteral("requestedKind"), kind);
        result.insert(QStringLiteral("requestedTargetId"), targetId);
        result.insert(QStringLiteral("requestedName"), displayName);
        result.insert(QStringLiteral("prepareAfterResolve"), true);
        return result;
    }

    const bool prepared = kind == QStringLiteral("plan")
        ? preparePlanDay(targetId)
        : prepareFreeWorkout(displayName);
    return QVariantMap{
        {QStringLiteral("status"), prepared ? QStringLiteral("prepared")
                                             : QStringLiteral("error")},
        {QStringLiteral("message"), m_errorMessage},
    };
}

QVariantMap WorkoutSessionController::requestPreparePlanDay(const QString &dayId)
{
    QSqlQuery day(m_database);
    day.prepare(QStringLiteral("SELECT name FROM plan_day WHERE id=?"));
    day.addBindValue(dayId);
    if (!day.exec() || !day.next()) {
        fail(QStringLiteral("找不到训练日"));
        return QVariantMap{{QStringLiteral("status"), QStringLiteral("error")},
                           {QStringLiteral("message"), m_errorMessage}};
    }
    return requestPrepare(QStringLiteral("plan"), dayId, day.value(0).toString());
}

QVariantMap WorkoutSessionController::requestPrepareSuggestedDay()
{
    const QString dayId = m_suggestedDay.value(QStringLiteral("dayId")).toString();
    if (dayId.isEmpty()) {
        fail(QStringLiteral("没有可开始的推荐训练"));
        return QVariantMap{{QStringLiteral("status"), QStringLiteral("error")},
                           {QStringLiteral("message"), m_errorMessage}};
    }
    return requestPreparePlanDay(dayId);
}

QVariantMap WorkoutSessionController::requestPrepareFreeWorkout(const QString &name)
{
    const QString displayName = name.trimmed().isEmpty() ? QStringLiteral("自由训练")
                                                         : name.trimmed();
    return requestPrepare(QStringLiteral("free"), QString{}, displayName);
}

QVariantMap WorkoutSessionController::exerciseDefaults(const QString &exerciseId) const
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT id,name_zh,recommended_sets,recommended_reps,rest_seconds "
        "FROM exercise WHERE id=? AND is_enabled=1"));
    query.addBindValue(exerciseId);
    if (!query.exec() || !query.next()) return {};
    return QVariantMap{
        {QStringLiteral("exerciseId"), query.value(0)},
        {QStringLiteral("name"), query.value(1)},
        {QStringLiteral("sets"), qMax(1, query.value(2).toInt())},
        {QStringLiteral("reps"), query.value(3).toString().trimmed().isEmpty()
                                     ? QStringLiteral("8-12") : query.value(3)},
        {QStringLiteral("restSeconds"), qBound(0, query.value(4).toInt(), 600)},
    };
}

bool WorkoutSessionController::preparePlanDay(const QString &dayId)
{
    QSqlQuery day(m_database);
    day.prepare(QStringLiteral(
        "SELECT d.name,d.plan_id,p.name,p.is_read_only FROM plan_day d "
        "JOIN training_plan p ON p.id=d.plan_id WHERE d.id=?"));
    day.addBindValue(dayId);
    if (!day.exec() || !day.next()) return fail(QStringLiteral("找不到训练日"));

    QVariantList exercises;
    QSqlQuery planned(m_database);
    planned.prepare(QStringLiteral(
        "SELECT pe.id,pe.exercise_id,e.name_zh,pe.default_sets,pe.default_reps,"
        "pe.rest_seconds,pe.notes FROM plan_exercise pe "
        "JOIN exercise e ON e.id=pe.exercise_id WHERE pe.day_id=? "
        "ORDER BY pe.sort_order,pe.id"));
    planned.addBindValue(dayId);
    if (!planned.exec()) return fail(planned.lastError().text());
    while (planned.next()) {
        const int sets = qBound(1, planned.value(3).toInt(), 20);
        const QString reps = planned.value(4).toString();
        const int restSeconds = qBound(0, planned.value(5).toInt(), 600);
        exercises.append(QVariantMap{
            {QStringLiteral("draftId"), newId()},
            {QStringLiteral("sourcePlanExerciseId"), planned.value(0)},
            {QStringLiteral("exerciseId"), planned.value(1)},
            {QStringLiteral("name"), planned.value(2)},
            {QStringLiteral("sets"), sets},
            {QStringLiteral("reps"), reps},
            {QStringLiteral("restSeconds"), restSeconds},
            {QStringLiteral("defaultSets"), sets},
            {QStringLiteral("defaultReps"), reps},
            {QStringLiteral("defaultRestSeconds"), restSeconds},
            {QStringLiteral("notes"), planned.value(6)},
            {QStringLiteral("modified"), false},
        });
    }

    QVariantMap cardio;
    QSqlQuery cardioQuery(m_database);
    cardioQuery.prepare(QStringLiteral(
        "SELECT cardio_type,duration_seconds,incline,speed_kmh,machine_level,notes "
        "FROM plan_cardio WHERE day_id=?"));
    cardioQuery.addBindValue(dayId);
    if (!cardioQuery.exec()) return fail(cardioQuery.lastError().text());
    if (cardioQuery.next()) {
        cardio = QVariantMap{
            {QStringLiteral("type"), cardioQuery.value(0)},
            {QStringLiteral("durationSeconds"), cardioQuery.value(1)},
            {QStringLiteral("incline"), cardioQuery.value(2)},
            {QStringLiteral("speedKmh"), cardioQuery.value(3)},
            {QStringLiteral("machineLevel"), cardioQuery.value(4)},
            {QStringLiteral("notes"), cardioQuery.value(5)},
        };
    }

    m_preparation = QVariantMap{
        {QStringLiteral("kind"), QStringLiteral("plan")},
        {QStringLiteral("name"), day.value(0)},
        {QStringLiteral("sourceDayId"), dayId},
        {QStringLiteral("sourcePlanId"), day.value(1)},
        {QStringLiteral("sourcePlanName"), day.value(2)},
        {QStringLiteral("sourcePlanReadOnly"), day.value(3).toBool()},
        {QStringLiteral("exercises"), exercises},
        {QStringLiteral("cardio"), cardio},
    };
    emit preparationChanged();
    return true;
}

bool WorkoutSessionController::prepareFreeWorkout(const QString &name)
{
    m_preparation = QVariantMap{
        {QStringLiteral("kind"), QStringLiteral("free")},
        {QStringLiteral("name"), name.trimmed().isEmpty() ? QStringLiteral("自由训练")
                                                            : name.trimmed()},
        {QStringLiteral("sourceDayId"), QString{}},
        {QStringLiteral("sourcePlanId"), QString{}},
        {QStringLiteral("sourcePlanName"), QString{}},
        {QStringLiteral("sourcePlanReadOnly"), false},
        {QStringLiteral("exercises"), QVariantList{}},
        {QStringLiteral("cardio"), QVariantMap{}},
    };
    emit preparationChanged();
    return true;
}

int WorkoutSessionController::preparedExerciseIndex(const QString &draftExerciseId) const
{
    const QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    for (int index = 0; index < exercises.size(); ++index) {
        if (exercises.at(index).toMap().value(QStringLiteral("draftId")).toString()
            == draftExerciseId) return index;
    }
    return -1;
}

bool WorkoutSessionController::updatePreparedExercise(
    const QString &draftExerciseId, int sets, const QString &reps, int restSeconds)
{
    clearError();
    const int index = preparedExerciseIndex(draftExerciseId);
    const QString trimmedReps = reps.trimmed();
    if (index < 0) return fail(QStringLiteral("找不到准备中的动作"));
    if (sets < 1 || sets > 20 || trimmedReps.isEmpty()
        || restSeconds < 0 || restSeconds > 600) {
        return fail(QStringLiteral("动作参数无效"));
    }
    QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    QVariantMap exercise = exercises.at(index).toMap();
    exercise.insert(QStringLiteral("sets"), sets);
    exercise.insert(QStringLiteral("reps"), trimmedReps);
    exercise.insert(QStringLiteral("restSeconds"), restSeconds);
    exercise.insert(QStringLiteral("modified"),
                    sets != exercise.value(QStringLiteral("defaultSets")).toInt()
                    || trimmedReps != exercise.value(QStringLiteral("defaultReps")).toString()
                    || restSeconds != exercise.value(QStringLiteral("defaultRestSeconds")).toInt());
    exercises[index] = exercise;
    m_preparation.insert(QStringLiteral("exercises"), exercises);
    emit preparationChanged();
    return true;
}

bool WorkoutSessionController::restorePreparedExerciseDefaults(const QString &draftExerciseId)
{
    const int index = preparedExerciseIndex(draftExerciseId);
    if (index < 0) return fail(QStringLiteral("找不到准备中的动作"));
    QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    QVariantMap exercise = exercises.at(index).toMap();
    exercise.insert(QStringLiteral("sets"), exercise.value(QStringLiteral("defaultSets")));
    exercise.insert(QStringLiteral("reps"), exercise.value(QStringLiteral("defaultReps")));
    exercise.insert(QStringLiteral("restSeconds"), exercise.value(QStringLiteral("defaultRestSeconds")));
    exercise.insert(QStringLiteral("modified"), false);
    exercises[index] = exercise;
    m_preparation.insert(QStringLiteral("exercises"), exercises);
    emit preparationChanged();
    return true;
}

bool WorkoutSessionController::addPreparedExercise(const QString &exerciseId)
{
    clearError();
    if (!preparing()) return fail(QStringLiteral("没有训练准备草稿"));
    QVariantMap exercise = exerciseDefaults(exerciseId);
    if (exercise.isEmpty()) return fail(QStringLiteral("找不到动作"));
    exercise.insert(QStringLiteral("draftId"), newId());
    exercise.insert(QStringLiteral("sourcePlanExerciseId"), QString{});
    exercise.insert(QStringLiteral("defaultSets"), exercise.value(QStringLiteral("sets")));
    exercise.insert(QStringLiteral("defaultReps"), exercise.value(QStringLiteral("reps")));
    exercise.insert(QStringLiteral("defaultRestSeconds"), exercise.value(QStringLiteral("restSeconds")));
    exercise.insert(QStringLiteral("notes"), QString{});
    exercise.insert(QStringLiteral("modified"), false);
    QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    exercises.append(exercise);
    m_preparation.insert(QStringLiteral("exercises"), exercises);
    emit preparationChanged();
    return true;
}

bool WorkoutSessionController::replacePreparedExercise(
    const QString &draftExerciseId, const QString &exerciseId)
{
    clearError();
    const int index = preparedExerciseIndex(draftExerciseId);
    QVariantMap replacement = exerciseDefaults(exerciseId);
    if (index < 0) return fail(QStringLiteral("找不到准备中的动作"));
    if (replacement.isEmpty()) return fail(QStringLiteral("找不到替换动作"));
    replacement.insert(QStringLiteral("draftId"), draftExerciseId);
    replacement.insert(QStringLiteral("sourcePlanExerciseId"), QString{});
    replacement.insert(QStringLiteral("defaultSets"), replacement.value(QStringLiteral("sets")));
    replacement.insert(QStringLiteral("defaultReps"), replacement.value(QStringLiteral("reps")));
    replacement.insert(QStringLiteral("defaultRestSeconds"), replacement.value(QStringLiteral("restSeconds")));
    replacement.insert(QStringLiteral("notes"), QString{});
    replacement.insert(QStringLiteral("modified"), true);
    QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    exercises[index] = replacement;
    m_preparation.insert(QStringLiteral("exercises"), exercises);
    emit preparationChanged();
    return true;
}

bool WorkoutSessionController::movePreparedExercise(const QString &draftExerciseId, int toIndex)
{
    clearError();
    QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    const int fromIndex = preparedExerciseIndex(draftExerciseId);
    if (fromIndex < 0 || toIndex < 0 || toIndex >= exercises.size())
        return fail(QStringLiteral("动作序号无效"));
    exercises.move(fromIndex, toIndex);
    m_preparation.insert(QStringLiteral("exercises"), exercises);
    emit preparationChanged();
    return true;
}

bool WorkoutSessionController::reorderPreparedExercises(
    const QStringList &orderedDraftExerciseIds)
{
    clearError();
    const QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    QHash<QString, QVariant> byId;
    for (const QVariant &value : exercises) {
        const QString id = value.toMap().value(QStringLiteral("draftId")).toString();
        if (id.isEmpty() || byId.contains(id))
            return fail(QStringLiteral("准备动作标识无效"));
        byId.insert(id, value);
    }
    const QSet<QString> orderedSet(orderedDraftExerciseIds.cbegin(),
                                   orderedDraftExerciseIds.cend());
    if (orderedDraftExerciseIds.size() != exercises.size()
        || orderedSet.size() != orderedDraftExerciseIds.size()
        || orderedSet != QSet<QString>(byId.keyBegin(), byId.keyEnd())) {
        return fail(QStringLiteral("动作顺序与训练准备不一致"));
    }
    QVariantList reordered;
    reordered.reserve(orderedDraftExerciseIds.size());
    for (const QString &id : orderedDraftExerciseIds)
        reordered.append(byId.value(id));
    m_preparation.insert(QStringLiteral("exercises"), reordered);
    emit preparationChanged();
    return true;
}

bool WorkoutSessionController::removePreparedExercise(const QString &draftExerciseId)
{
    clearError();
    const int index = preparedExerciseIndex(draftExerciseId);
    if (index < 0) return fail(QStringLiteral("找不到准备中的动作"));
    QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    exercises.removeAt(index);
    m_preparation.insert(QStringLiteral("exercises"), exercises);
    emit preparationChanged();
    return true;
}

bool WorkoutSessionController::savePreparationAsPlan(
    const QString &planName, const QString &dayName)
{
    clearError();
    const QString trimmedPlan = planName.trimmed();
    const QString trimmedDay = dayName.trimmed();
    const QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    if (!preparing() || trimmedPlan.isEmpty() || trimmedDay.isEmpty() || exercises.isEmpty())
        return fail(QStringLiteral("个人计划信息不完整"));
    if (!m_database.transaction()) return fail(m_database.lastError().text());
    const auto rollback = [this](const QString &message) {
        m_database.rollback();
        return fail(message);
    };
    const QString planId = newId();
    const QString dayId = newId();
    QSqlQuery plan(m_database);
    plan.prepare(QStringLiteral(
        "INSERT INTO training_plan(id,name,source_plan_id,is_system,is_read_only) VALUES(?,?,?,0,0)"));
    plan.addBindValue(planId);
    plan.addBindValue(trimmedPlan);
    const QString sourcePlanId = m_preparation.value(QStringLiteral("sourcePlanId")).toString();
    plan.addBindValue(sourcePlanId.isEmpty() ? QVariant{} : QVariant(sourcePlanId));
    if (!plan.exec()) return rollback(plan.lastError().text());
    QSqlQuery day(m_database);
    day.prepare(QStringLiteral("INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES(?,?,?,0)"));
    day.addBindValue(dayId);
    day.addBindValue(planId);
    day.addBindValue(trimmedDay);
    if (!day.exec()) return rollback(day.lastError().text());
    for (int index = 0; index < exercises.size(); ++index) {
        const QVariantMap exercise = exercises.at(index).toMap();
        QSqlQuery insert(m_database);
        insert.prepare(QStringLiteral(
            "INSERT INTO plan_exercise(id,day_id,exercise_id,sort_order,default_sets,"
            "default_reps,rest_seconds,notes) VALUES(?,?,?,?,?,?,?,?)"));
        insert.addBindValue(newId());
        insert.addBindValue(dayId);
        insert.addBindValue(exercise.value(QStringLiteral("exerciseId")));
        insert.addBindValue(index);
        insert.addBindValue(exercise.value(QStringLiteral("sets")));
        insert.addBindValue(exercise.value(QStringLiteral("reps")));
        insert.addBindValue(exercise.value(QStringLiteral("restSeconds")));
        insert.addBindValue(exercise.value(QStringLiteral("notes")));
        if (!insert.exec()) return rollback(insert.lastError().text());
    }
    const QVariantMap cardio = m_preparation.value(QStringLiteral("cardio")).toMap();
    if (!cardio.isEmpty()) {
        QSqlQuery insertCardio(m_database);
        insertCardio.prepare(QStringLiteral(
            "INSERT INTO plan_cardio(day_id,cardio_type,duration_seconds,incline,speed_kmh,"
            "machine_level,notes) VALUES(?,?,?,?,?,?,?)"));
        insertCardio.addBindValue(dayId);
        insertCardio.addBindValue(cardio.value(QStringLiteral("type")));
        insertCardio.addBindValue(cardio.value(QStringLiteral("durationSeconds")));
        insertCardio.addBindValue(cardio.value(QStringLiteral("incline")));
        insertCardio.addBindValue(cardio.value(QStringLiteral("speedKmh")));
        insertCardio.addBindValue(cardio.value(QStringLiteral("machineLevel")));
        insertCardio.addBindValue(cardio.value(QStringLiteral("notes")));
        if (!insertCardio.exec()) return rollback(insertCardio.lastError().text());
    }
    if (!m_database.commit()) return fail(m_database.lastError().text());
    loadPlanDays();
    return true;
}

bool WorkoutSessionController::commitPreparation()
{
    clearError();
    if (!preparing()) return fail(QStringLiteral("没有训练准备草稿"));
    if (activeSessionCount() > 0) return fail(QStringLiteral("已有进行中的训练"));
    const QVariantList exercises = m_preparation.value(QStringLiteral("exercises")).toList();
    if (exercises.isEmpty()) return fail(QStringLiteral("请至少添加一个动作"));
    if (!m_database.transaction()) return fail(m_database.lastError().text());
    const auto rollback = [this](const QString &message) {
        m_database.rollback();
        return fail(message);
    };
    const QString sessionId = newId();
    QSqlQuery session(m_database);
    session.prepare(QStringLiteral(
        "INSERT INTO workout_session(id,name,source_plan_id,gym_id,started_at,status) "
        "VALUES(?,?,?,?,?,'active')"));
    session.addBindValue(sessionId);
    session.addBindValue(m_preparation.value(QStringLiteral("name")));
    const QString sourcePlanId = m_preparation.value(QStringLiteral("sourcePlanId")).toString();
    session.addBindValue(sourcePlanId.isEmpty() ? QVariant{} : QVariant(sourcePlanId));
    session.addBindValue(m_selectedGymId.isEmpty() ? QVariant{} : QVariant(m_selectedGymId));
    session.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    if (!session.exec()) return rollback(session.lastError().text());
    for (int index = 0; index < exercises.size(); ++index) {
        const QVariantMap exercise = exercises.at(index).toMap();
        const QString workoutExerciseId = newId();
        QSqlQuery insertExercise(m_database);
        insertExercise.prepare(QStringLiteral(
            "INSERT INTO workout_exercise(id,session_id,exercise_id,sort_order,rest_seconds,notes) "
            "VALUES(?,?,?,?,?,?)"));
        insertExercise.addBindValue(workoutExerciseId);
        insertExercise.addBindValue(sessionId);
        insertExercise.addBindValue(exercise.value(QStringLiteral("exerciseId")));
        insertExercise.addBindValue(index);
        insertExercise.addBindValue(exercise.value(QStringLiteral("restSeconds")));
        insertExercise.addBindValue(exercise.value(QStringLiteral("notes")));
        if (!insertExercise.exec()) return rollback(insertExercise.lastError().text());
        const int setCount = exercise.value(QStringLiteral("sets")).toInt();
        const QString reps = exercise.value(QStringLiteral("reps")).toString();
        for (int setIndex = 0; setIndex < setCount; ++setIndex) {
            QSqlQuery insertSet(m_database);
            insertSet.prepare(QStringLiteral(
                "INSERT INTO set_record(id,workout_exercise_id,set_order,target_reps) "
                "VALUES(?,?,?,?)"));
            insertSet.addBindValue(newId());
            insertSet.addBindValue(workoutExerciseId);
            insertSet.addBindValue(setIndex);
            const int target = targetForSet(reps, setIndex);
            insertSet.addBindValue(target > 0 ? QVariant(target) : QVariant{});
            if (!insertSet.exec()) return rollback(insertSet.lastError().text());
        }
    }
    const QVariantMap cardio = m_preparation.value(QStringLiteral("cardio")).toMap();
    if (!cardio.isEmpty()) {
        QSqlQuery cardioTarget(m_database);
        cardioTarget.prepare(QStringLiteral(
            "INSERT INTO workout_cardio_target(session_id,cardio_type,duration_seconds,incline,"
            "speed_kmh,machine_level,notes) VALUES(?,?,?,?,?,?,?)"));
        cardioTarget.addBindValue(sessionId);
        cardioTarget.addBindValue(cardio.value(QStringLiteral("type")));
        cardioTarget.addBindValue(cardio.value(QStringLiteral("durationSeconds")));
        cardioTarget.addBindValue(cardio.value(QStringLiteral("incline")));
        cardioTarget.addBindValue(cardio.value(QStringLiteral("speedKmh")));
        cardioTarget.addBindValue(cardio.value(QStringLiteral("machineLevel")));
        cardioTarget.addBindValue(cardio.value(QStringLiteral("notes")));
        if (!cardioTarget.exec()) return rollback(cardioTarget.lastError().text());
    }
    if (!m_database.commit()) return fail(m_database.lastError().text());
    m_preparation.clear();
    emit preparationChanged();
    return loadSession(sessionId);
}

void WorkoutSessionController::cancelPreparation()
{
    if (m_preparation.isEmpty()) return;
    m_preparation.clear();
    emit preparationChanged();
}

bool WorkoutSessionController::continueExistingWorkout()
{
    clearError();
    const int count = activeSessionCount();
    if (count > 1) return fail(QStringLiteral("检测到多条未完成训练，请先完成恢复处理"));
    if (count == 0) return fail(QStringLiteral("没有未完成训练"));
    if (active()) return true;
    return resumeUnfinished();
}

bool WorkoutSessionController::resolveCurrentWorkout(bool discardCurrent)
{
    clearError();
    if (activeSessionCount() != 1)
        return fail(QStringLiteral("无法确定要结束的训练"));
    QSqlQuery query(m_database);
    if (discardCurrent) {
        query.prepare(QStringLiteral(
            "DELETE FROM workout_session WHERE status='active'"));
    } else {
        query.prepare(QStringLiteral(
            "UPDATE workout_session SET status='completed',ended_at=? WHERE status='active'"));
        query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    }
    if (!query.exec() || query.numRowsAffected() != 1)
        return fail(query.lastError().text().isEmpty()
                        ? QStringLiteral("无法结束当前训练") : query.lastError().text());
    m_sessionId.clear();
    m_sessionName.clear();
    m_sessionNotes.clear();
    m_exercises.clear();
    emit exercisesChanged();
    emit sessionChanged();
    refreshUnfinished();
    loadSuggestedDay();
    return true;
}

bool WorkoutSessionController::recoverActiveSessions(
    const QString &keepSessionId, bool discardOthers)
{
    clearError();
    if (activeSessionCount() < 2) {
        refreshUnfinished();
        return fail(QStringLiteral("当前不需要多训练恢复"));
    }

    QSqlQuery selected(m_database);
    selected.prepare(QStringLiteral(
        "SELECT 1 FROM workout_session WHERE id=? AND status='active'"));
    selected.addBindValue(keepSessionId);
    if (!selected.exec() || !selected.next()) {
        return fail(QStringLiteral("请选择一条仍在进行的训练"));
    }

    if (!m_database.transaction()) return fail(m_database.lastError().text());
    QSqlQuery resolve(m_database);
    if (discardOthers) {
        resolve.prepare(QStringLiteral(
            "DELETE FROM workout_session WHERE status='active' AND id<>?"));
        resolve.addBindValue(keepSessionId);
    } else {
        resolve.prepare(QStringLiteral(
            "UPDATE workout_session SET status='completed',ended_at=COALESCE(ended_at,?) "
            "WHERE status='active' AND id<>?"));
        resolve.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
        resolve.addBindValue(keepSessionId);
    }
    if (!resolve.exec()) {
        m_database.rollback();
        return fail(resolve.lastError().text());
    }
    if (!m_database.commit()) return fail(m_database.lastError().text());
    return loadSession(keepSessionId);
}

bool WorkoutSessionController::insertPlanDaySession(const QString &dayId, QString *sessionId)
{
    if (!sessionId) return fail(QStringLiteral("无法创建训练"));

    QSqlQuery day(m_database);
    day.prepare(QStringLiteral("SELECT d.name,d.plan_id FROM plan_day d WHERE d.id=?"));
    day.addBindValue(dayId);
    if (!day.exec() || !day.next()) {
        return fail(QStringLiteral("找不到训练日"));
    }
    const QString name = day.value(0).toString();
    const QString planId = day.value(1).toString();
    *sessionId = newId();

    QSqlQuery session(m_database);
    session.prepare(QStringLiteral(
        "INSERT INTO workout_session(id,name,source_plan_id,gym_id,started_at,status) VALUES(?,?,?,?,?, 'active')"));
    session.addBindValue(*sessionId);
    session.addBindValue(name);
    session.addBindValue(planId);
    session.addBindValue(m_selectedGymId.isEmpty() ? QVariant{} : QVariant(m_selectedGymId));
    session.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    if (!session.exec()) {
        return fail(session.lastError().text());
    }

    QSqlQuery planned(m_database);
    planned.prepare(QStringLiteral(
        "SELECT exercise_id,sort_order,default_sets,default_reps,rest_seconds,notes "
        "FROM plan_exercise WHERE day_id=? ORDER BY sort_order,id"));
    planned.addBindValue(dayId);
    if (!planned.exec()) {
        return fail(planned.lastError().text());
    }
    while (planned.next()) {
        const QString workoutExerciseId = newId();
        QSqlQuery exercise(m_database);
        exercise.prepare(QStringLiteral(
            "INSERT INTO workout_exercise(id,session_id,exercise_id,sort_order,rest_seconds,notes) "
            "VALUES(?,?,?,?,?,?)"));
        exercise.addBindValue(workoutExerciseId);
        exercise.addBindValue(*sessionId);
        exercise.addBindValue(planned.value(0));
        exercise.addBindValue(planned.value(1));
        exercise.addBindValue(planned.value(4));
        exercise.addBindValue(planned.value(5));
        if (!exercise.exec()) {
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
                return fail(set.lastError().text());
            }
        }
    }
    QSqlQuery cardioTarget(m_database);
    cardioTarget.prepare(QStringLiteral(
        "INSERT INTO workout_cardio_target(session_id,cardio_type,duration_seconds,incline,"
        "speed_kmh,machine_level,notes) "
        "SELECT ?,cardio_type,duration_seconds,incline,speed_kmh,machine_level,notes "
        "FROM plan_cardio WHERE day_id=?"));
    cardioTarget.addBindValue(*sessionId);
    cardioTarget.addBindValue(dayId);
    if (!cardioTarget.exec()) {
        return fail(cardioTarget.lastError().text());
    }
    return true;
}

bool WorkoutSessionController::insertFreeWorkout(const QString &name, QString *sessionId)
{
    if (!sessionId) return fail(QStringLiteral("无法创建训练"));
    *sessionId = newId();
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO workout_session(id,name,gym_id,started_at,status) VALUES(?,?,?,?,'active')"));
    query.addBindValue(*sessionId);
    query.addBindValue(name.trimmed().isEmpty() ? QStringLiteral("自由训练") : name.trimmed());
    query.addBindValue(m_selectedGymId.isEmpty() ? QVariant{} : QVariant(m_selectedGymId));
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    return query.exec() || fail(query.lastError().text());
}

bool WorkoutSessionController::startPlanDay(const QString &dayId)
{
    clearError();
    if (activeSessionCount() > 0) {
        refreshUnfinished();
        return fail(QStringLiteral("已有进行中的训练"));
    }
    if (!m_database.transaction()) return fail(m_database.lastError().text());
    QString sessionId;
    if (!insertPlanDaySession(dayId, &sessionId)) {
        m_database.rollback();
        return false;
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
    if (activeSessionCount() > 0) {
        refreshUnfinished();
        return fail(QStringLiteral("已有进行中的训练"));
    }
    if (!m_database.transaction()) return fail(m_database.lastError().text());
    QString sessionId;
    if (!insertFreeWorkout(name, &sessionId)) {
        m_database.rollback();
        return false;
    }
    if (!m_database.commit()) return fail(m_database.lastError().text());
    return loadSession(sessionId);
}

bool WorkoutSessionController::switchWorkout(
    const QString &kind, const QString &targetId, const QString &displayName, bool discardCurrent)
{
    clearError();
    const int count = activeSessionCount();
    if (count != 1) {
        refreshUnfinished();
        return fail(count > 1 ? QStringLiteral("检测到多条未完成训练，请先完成恢复处理")
                              : QStringLiteral("没有可切换的进行中训练"));
    }

    QSqlQuery current(m_database);
    current.prepare(QStringLiteral(
        "SELECT id FROM workout_session WHERE status='active' ORDER BY started_at DESC,id LIMIT 1"));
    if (!current.exec() || !current.next()) return fail(QStringLiteral("无法读取当前训练"));
    const QString currentId = current.value(0).toString();

    if (!m_database.transaction()) return fail(m_database.lastError().text());
    QSqlQuery resolve(m_database);
    if (discardCurrent) {
        resolve.prepare(QStringLiteral("DELETE FROM workout_session WHERE id=? AND status='active'"));
        resolve.addBindValue(currentId);
    } else {
        resolve.prepare(QStringLiteral(
            "UPDATE workout_session SET status='completed',ended_at=? "
            "WHERE id=? AND status='active'"));
        resolve.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
        resolve.addBindValue(currentId);
    }
    if (!resolve.exec() || resolve.numRowsAffected() != 1) {
        m_database.rollback();
        return fail(resolve.lastError().text().isEmpty()
                        ? QStringLiteral("无法处理当前训练")
                        : resolve.lastError().text());
    }

    QString newSessionId;
    const bool inserted = kind == QStringLiteral("plan")
        ? insertPlanDaySession(targetId, &newSessionId)
        : insertFreeWorkout(displayName, &newSessionId);
    if (!inserted) {
        m_database.rollback();
        return false;
    }
    if (!m_database.commit()) return fail(m_database.lastError().text());
    return loadSession(newSessionId);
}

bool WorkoutSessionController::switchToPlanDay(const QString &dayId, bool discardCurrent)
{
    return switchWorkout(QStringLiteral("plan"), dayId, QString{}, discardCurrent);
}

bool WorkoutSessionController::switchToFreeWorkout(const QString &name, bool discardCurrent)
{
    const QString displayName = name.trimmed().isEmpty() ? QStringLiteral("自由训练")
                                                         : name.trimmed();
    return switchWorkout(QStringLiteral("free"), QString{}, displayName, discardCurrent);
}

void WorkoutSessionController::dismissError()
{
    clearError();
}

bool WorkoutSessionController::addExercise(const QString &exerciseId, int setCount, const QString &targetReps)
{
    clearError();
    if (!active()) {
        return fail(QStringLiteral("请先开始训练"));
    }
    QSqlQuery info(m_database);
    info.prepare(QStringLiteral(
        "SELECT recommended_sets,recommended_reps,rest_seconds FROM exercise WHERE id=?"));
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
        "INSERT INTO workout_exercise(id,session_id,exercise_id,sort_order,rest_seconds) "
        "VALUES(?,?,?,(SELECT COALESCE(MAX(sort_order),-1)+1 FROM workout_exercise "
        "WHERE session_id=?),?)"));
    exercise.addBindValue(workoutExerciseId);
    exercise.addBindValue(m_sessionId);
    exercise.addBindValue(exerciseId);
    exercise.addBindValue(m_sessionId);
    exercise.addBindValue(qBound(0, info.value(2).toInt(), 600));
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
        "SELECT recommended_sets,recommended_reps,rest_seconds FROM exercise "
        "WHERE id=? AND is_enabled=1"));
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
        "UPDATE workout_exercise SET exercise_id=?,rest_seconds=?,notes='' WHERE id=?"));
    update.addBindValue(exerciseId);
    update.addBindValue(qBound(0, info.value(2).toInt(), 600));
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
        const QString message = m_database.lastError().text();
        m_database.rollback();
        return fail(message);
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
    QStringList orderedIds;
    orderedIds.reserve(reordered.size());
    for (const QVariant &value : reordered)
        orderedIds.append(value.toMap().value(QStringLiteral("id")).toString());
    return reorderExercises(orderedIds);
}

bool WorkoutSessionController::reorderExercises(
    const QStringList &orderedWorkoutExerciseIds)
{
    clearError();
    QStringList existingIds;
    existingIds.reserve(m_exercises.size());
    for (const QVariant &value : m_exercises)
        existingIds.append(value.toMap().value(QStringLiteral("id")).toString());
    const QSet<QString> orderedSet(orderedWorkoutExerciseIds.cbegin(),
                                   orderedWorkoutExerciseIds.cend());
    const QSet<QString> existingSet(existingIds.cbegin(), existingIds.cend());
    if (orderedWorkoutExerciseIds.size() != existingIds.size()
        || orderedSet.size() != orderedWorkoutExerciseIds.size()
        || orderedSet != existingSet) {
        return fail(QStringLiteral("动作顺序与当前训练不一致"));
    }
    if (!m_database.transaction()) {
        return fail(m_database.lastError().text());
    }
    for (int index = 0; index < orderedWorkoutExerciseIds.size(); ++index) {
        QSqlQuery update(m_database);
        update.prepare(QStringLiteral("UPDATE workout_exercise SET sort_order=? WHERE id=?"));
        update.addBindValue(index);
        update.addBindValue(orderedWorkoutExerciseIds.at(index));
        if (!update.exec()) {
            m_database.rollback();
            return fail(update.lastError().text());
        }
    }
    if (!m_database.commit()) {
        m_database.rollback();
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
    if (!m_database.transaction()) {
        return fail(m_database.lastError().text());
    }
    QSqlQuery remove(m_database);
    remove.prepare(QStringLiteral("DELETE FROM workout_exercise WHERE id=?"));
    remove.addBindValue(workoutExerciseId);
    if (!remove.exec()) {
        m_database.rollback();
        return fail(remove.lastError().text());
    }
    int sortOrder = 0;
    for (const QVariant &value : std::as_const(m_exercises)) {
        const QString id = value.toMap().value(QStringLiteral("id")).toString();
        if (id == workoutExerciseId)
            continue;
        QSqlQuery update(m_database);
        update.prepare(QStringLiteral("UPDATE workout_exercise SET sort_order=? WHERE id=?"));
        update.addBindValue(sortOrder++);
        update.addBindValue(id);
        if (!update.exec()) {
            m_database.rollback();
            return fail(update.lastError().text());
        }
    }
    if (!m_database.commit()) {
        m_database.rollback();
        return fail(m_database.lastError().text());
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

bool WorkoutSessionController::updateCompletedSet(
    int exerciseIndex, int setIndex, double weightKg, int actualReps, bool toFailure,
    const QString &bodyweightLoadType)
{
    clearError();
    if (!active()) {
        return fail(QStringLiteral("没有进行中的训练"));
    }
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size()
        || actualReps < 0 || weightKg < 0) {
        return fail(QStringLiteral("组数据无效"));
    }
    if (bodyweightLoadType != QStringLiteral("Bodyweight")
        && bodyweightLoadType != QStringLiteral("Added")
        && bodyweightLoadType != QStringLiteral("Assisted")) {
        return fail(QStringLiteral("自重负重类型无效"));
    }

    const auto sets = m_exercises.at(exerciseIndex).toMap().value(QStringLiteral("sets")).toList();
    if (setIndex < 0 || setIndex >= sets.size()) {
        return fail(QStringLiteral("组序号无效"));
    }
    const auto set = sets.at(setIndex).toMap();
    if (!set.value(QStringLiteral("completed")).toBool()) {
        return fail(QStringLiteral("只能修改已完成组"));
    }

    QSqlQuery update(m_database);
    update.prepare(QStringLiteral(
        "UPDATE set_record SET weight_kg=?,actual_reps=?,to_failure=?,bodyweight_load_type=? "
        "WHERE id=? AND completed=1 AND workout_exercise_id IN ("
        "SELECT we.id FROM workout_exercise we JOIN workout_session ws ON ws.id=we.session_id "
        "WHERE ws.id=? AND ws.status='active')"));
    update.addBindValue(weightKg);
    update.addBindValue(actualReps);
    update.addBindValue(toFailure ? 1 : 0);
    update.addBindValue(bodyweightLoadType);
    update.addBindValue(set.value(QStringLiteral("id")));
    update.addBindValue(m_sessionId);
    if (!update.exec()) {
        return fail(update.lastError().text());
    }
    if (update.numRowsAffected() != 1) {
        return fail(QStringLiteral("找不到当前训练中的已完成组"));
    }
    return loadSession(m_sessionId);
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

bool WorkoutSessionController::configureExerciseParameters(
    int exerciseIndex, double weightKg, const QString &targetReps,
    int setCount, int restSeconds)
{
    clearError();
    const QString reps = targetReps.trimmed();
    if (exerciseIndex < 0 || exerciseIndex >= m_exercises.size() || weightKg < 0
        || reps.isEmpty() || setCount < 1 || setCount > 20
        || restSeconds < 0 || restSeconds > 600) {
        return fail(QStringLiteral("训练组参数无效"));
    }
    const QString workoutExerciseId = m_exercises.at(exerciseIndex).toMap()
                                          .value(QStringLiteral("id")).toString();
    QSqlQuery protectedSets(m_database);
    protectedSets.prepare(QStringLiteral(
        "SELECT COUNT(*) FROM set_record WHERE workout_exercise_id=? "
        "AND completed=1 AND set_order>=?"));
    protectedSets.addBindValue(workoutExerciseId);
    protectedSets.addBindValue(setCount);
    if (!protectedSets.exec() || !protectedSets.next())
        return fail(protectedSets.lastError().text());
    if (protectedSets.value(0).toInt() > 0)
        return fail(QStringLiteral("不能删除已经完成的训练组"));

    if (!m_database.transaction()) return fail(m_database.lastError().text());
    const auto rollback = [this](const QString &message) {
        m_database.rollback();
        return fail(message);
    };
    QSqlQuery updateRest(m_database);
    updateRest.prepare(QStringLiteral(
        "UPDATE workout_exercise SET rest_seconds=? WHERE id=?"));
    updateRest.addBindValue(restSeconds);
    updateRest.addBindValue(workoutExerciseId);
    if (!updateRest.exec()) return rollback(updateRest.lastError().text());

    QSqlQuery removeTrailing(m_database);
    removeTrailing.prepare(QStringLiteral(
        "DELETE FROM set_record WHERE workout_exercise_id=? AND set_order>=? AND completed=0"));
    removeTrailing.addBindValue(workoutExerciseId);
    removeTrailing.addBindValue(setCount);
    if (!removeTrailing.exec()) return rollback(removeTrailing.lastError().text());

    for (int index = 0; index < setCount; ++index) {
        const int target = targetForSet(reps, index);
        QSqlQuery existing(m_database);
        existing.prepare(QStringLiteral(
            "SELECT id,completed FROM set_record WHERE workout_exercise_id=? AND set_order=?"));
        existing.addBindValue(workoutExerciseId);
        existing.addBindValue(index);
        if (!existing.exec()) return rollback(existing.lastError().text());
        if (existing.next()) {
            if (!existing.value(1).toBool()) {
                QSqlQuery update(m_database);
                update.prepare(QStringLiteral(
                    "UPDATE set_record SET weight_kg=?,target_reps=? WHERE id=?"));
                update.addBindValue(weightKg);
                update.addBindValue(target > 0 ? QVariant(target) : QVariant{});
                update.addBindValue(existing.value(0));
                if (!update.exec()) return rollback(update.lastError().text());
            }
        } else {
            QSqlQuery insert(m_database);
            insert.prepare(QStringLiteral(
                "INSERT INTO set_record(id,workout_exercise_id,set_order,weight_kg,target_reps) "
                "VALUES(?,?,?,?,?)"));
            insert.addBindValue(newId());
            insert.addBindValue(workoutExerciseId);
            insert.addBindValue(index);
            insert.addBindValue(weightKg);
            insert.addBindValue(target > 0 ? QVariant(target) : QVariant{});
            if (!insert.exec()) return rollback(insert.lastError().text());
        }
    }
    if (!m_database.commit()) return fail(m_database.lastError().text());
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
    const int count = m_activeSessions.size();
    if (count > 1) {
        return fail(QStringLiteral("检测到多条未完成训练，请先完成恢复处理"));
    }
    if (count == 0) {
        return fail(QStringLiteral("没有未完成训练"));
    }
    return loadSession(m_activeSessions.constFirst().toMap()
                           .value(QStringLiteral("id")).toString());
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

void WorkoutSessionController::reloadReferenceData()
{
    loadPlanDays();
    loadSuggestedDay();
    loadGyms();
}

void WorkoutSessionController::reloadGymData()
{
    loadGyms();
    if (!active() && !m_selectedGymId.isEmpty()) {
        const bool selectedStillExists = std::any_of(
            m_gyms.cbegin(), m_gyms.cend(), [this](const QVariant &gym) {
                return gym.toMap().value(QStringLiteral("id")).toString() == m_selectedGymId;
            });
        if (!selectedStillExists) {
            m_selectedGymId.clear();
            emit selectedGymChanged();
        }
    }
    loadEquipment();
}

void WorkoutSessionController::reloadAfterRestore()
{
    const bool wasActive = active();
    m_selectedGymId.clear();
    m_sessionId.clear();
    m_sessionName.clear();
    m_sessionNotes.clear();
    m_equipment.clear();
    m_exercises.clear();
    emit equipmentChanged();
    emit exercisesChanged();
    emit sessionChanged();
    if (wasActive) emit sessionStateChanged();
    loadStartupState();
}

bool WorkoutSessionController::loadSession(const QString &sessionId)
{
    const bool wasActive = active();
    QVariantList exercises;
    QVariantList equipment;
    QString sessionName;
    QString sessionGymId;
    QString sessionNotes;
    QSqlQuery exercise(m_database);
    exercise.prepare(QStringLiteral(
        "WITH target_session AS ("
        "SELECT id,name,gym_id,notes FROM workout_session WHERE id=? AND status='active') "
        "SELECT 0 AS kind,ts.name,ts.gym_id,ts.notes,we.id,e.name_zh,e.load_mode,"
        "e.recommended_reps,COALESCE(we.rest_seconds,e.rest_seconds),we.notes,e.id,"
        "we.equipment_instance_id,COALESCE(eq.name || CASE WHEN eq.code IS NULL "
        "OR eq.code='' THEN '' ELSE ' · ' || eq.code END,''),COALESCE(we.sort_order,0) "
        "FROM target_session ts LEFT JOIN workout_exercise we ON we.session_id=ts.id "
        "LEFT JOIN exercise e ON e.id=we.exercise_id "
        "LEFT JOIN equipment_instance eq ON eq.id=we.equipment_instance_id "
        "UNION ALL "
        "SELECT 1,ts.name,ts.gym_id,ts.notes,eq.id,eq.name,COALESCE(eq.code,''),"
        "COALESCE(eq.notes,''),NULL,'','','','',0 "
        "FROM target_session ts JOIN equipment_instance eq ON eq.gym_id=ts.gym_id "
        "AND eq.is_enabled=1 ORDER BY 1,14,6,5"));
    exercise.addBindValue(sessionId);
    if (!exercise.exec())
        return fail(exercise.lastError().text());

    bool foundSession = false;
    while (exercise.next()) {
        foundSession = true;
        sessionName = exercise.value(1).toString();
        sessionGymId = exercise.value(2).toString();
        sessionNotes = exercise.value(3).toString();
        if (exercise.value(0).toInt() == 0) {
            const QString workoutExerciseId = exercise.value(4).toString();
            if (workoutExerciseId.isEmpty())
                continue;
            exercises.append(QVariantMap{
                {QStringLiteral("id"), workoutExerciseId},
                {QStringLiteral("name"), exercise.value(5)},
                {QStringLiteral("loadMode"), exercise.value(6)},
                {QStringLiteral("recommendedReps"), exercise.value(7)},
                {QStringLiteral("restSeconds"), exercise.value(8)},
                {QStringLiteral("notes"), exercise.value(9)},
                {QStringLiteral("exerciseId"), exercise.value(10)},
                {QStringLiteral("equipmentId"), exercise.value(11)},
                {QStringLiteral("equipmentName"), exercise.value(12)},
            });
            continue;
        }

        const QString code = exercise.value(6).toString();
        equipment.append(QVariantMap{
            {QStringLiteral("id"), exercise.value(4)},
            {QStringLiteral("name"), exercise.value(5)},
            {QStringLiteral("code"), code},
            {QStringLiteral("displayName"), code.isEmpty()
                 ? exercise.value(5).toString()
                 : QStringLiteral("%1 · %2").arg(exercise.value(5).toString(), code)},
            {QStringLiteral("notes"), exercise.value(7)},
        });
    }
    if (!foundSession) {
        return fail(QStringLiteral("无法加载训练"));
    }

    QHash<QString, QVariantList> setsByExercise;
    QSqlQuery set(m_database);
    set.prepare(QStringLiteral(
        "SELECT s.workout_exercise_id,s.id,s.set_order,s.weight_kg,s.target_reps,"
        "s.actual_reps,s.completed,s.to_failure,s.notes,s.bodyweight_load_type,"
        "a.id,a.weight_kg,a.reps,a.rest_seconds,a.to_failure "
        "FROM set_record s JOIN workout_exercise we ON we.id=s.workout_exercise_id "
        "LEFT JOIN append_set_record a ON a.parent_set_id=s.id "
        "WHERE we.session_id=? "
        "ORDER BY we.sort_order,we.id,s.set_order,s.id,a.rowid,a.id"));
    set.addBindValue(sessionId);
    if (!set.exec())
        return fail(set.lastError().text());

    QString currentExerciseId;
    QString currentSetId;
    QVariantMap currentSet;
    QVariantList currentAppendSets;
    const auto flushSet = [&] {
        if (currentSetId.isEmpty())
            return;
        currentSet.insert(QStringLiteral("appendSets"), currentAppendSets);
        setsByExercise[currentExerciseId].append(currentSet);
    };
    while (set.next()) {
        const QString setId = set.value(1).toString();
        if (setId != currentSetId) {
            flushSet();
            currentExerciseId = set.value(0).toString();
            currentSetId = setId;
            currentAppendSets.clear();
            currentSet = QVariantMap{
                {QStringLiteral("id"), set.value(1)},
                {QStringLiteral("number"), set.value(2).toInt() + 1},
                {QStringLiteral("weightKg"), set.value(3)},
                {QStringLiteral("targetReps"), set.value(4)},
                {QStringLiteral("actualReps"), set.value(5)},
                {QStringLiteral("completed"), set.value(6).toBool()},
                {QStringLiteral("toFailure"), set.value(7).toBool()},
                {QStringLiteral("notes"), set.value(8)},
                {QStringLiteral("bodyweightLoadType"), set.value(9)},
            };
        }
        if (!set.value(10).isNull()) {
            currentAppendSets.append(QVariantMap{
                {QStringLiteral("weightKg"), set.value(11)},
                {QStringLiteral("reps"), set.value(12)},
                {QStringLiteral("restSeconds"), set.value(13)},
                {QStringLiteral("toFailure"), set.value(14).toBool()},
            });
        }
    }
    flushSet();

    QHash<QString, QVariantList> previousSetsByExercise;
    QSqlQuery previous(m_database);
    previous.prepare(QStringLiteral(
        "SELECT current_we.id,previous_set.weight_kg,previous_set.actual_reps "
        "FROM workout_exercise current_we "
        "JOIN workout_exercise previous_we ON previous_we.id=("
        "SELECT candidate.id FROM workout_exercise candidate "
        "JOIN workout_session previous_session ON previous_session.id=candidate.session_id "
        "WHERE candidate.exercise_id=current_we.exercise_id "
        "AND previous_session.status='completed' "
        "AND previous_session.id<>current_we.session_id "
        "AND candidate.equipment_instance_id IS current_we.equipment_instance_id "
        "ORDER BY previous_session.ended_at DESC,candidate.id LIMIT 1) "
        "JOIN set_record previous_set ON previous_set.workout_exercise_id=previous_we.id "
        "AND previous_set.completed=1 WHERE current_we.session_id=? "
        "ORDER BY current_we.sort_order,current_we.id,previous_set.set_order,previous_set.id"));
    previous.addBindValue(sessionId);
    if (!previous.exec())
        return fail(previous.lastError().text());
    while (previous.next()) {
        previousSetsByExercise[previous.value(0).toString()].append(QVariantMap{
            {QStringLiteral("weightKg"), previous.value(1)},
            {QStringLiteral("reps"), previous.value(2)},
        });
    }

    for (QVariant &item : exercises) {
        QVariantMap loadedExercise = item.toMap();
        const QString workoutExerciseId = loadedExercise.value(QStringLiteral("id")).toString();
        loadedExercise.insert(
            QStringLiteral("previousSets"), previousSetsByExercise.value(workoutExerciseId));
        loadedExercise.insert(QStringLiteral("sets"), setsByExercise.value(workoutExerciseId));
        item = loadedExercise;
    }

    m_sessionId = sessionId;
    m_sessionName = sessionName;
    m_sessionNotes = sessionNotes;
    if (m_selectedGymId != sessionGymId) {
        m_selectedGymId = sessionGymId;
        emit selectedGymChanged();
    }
    if (m_equipment != equipment) {
        m_equipment = equipment;
        emit equipmentChanged();
    }
    m_exercises = exercises;
    emit exercisesChanged();
    emit sessionChanged();
    if (!wasActive) emit sessionStateChanged();
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
