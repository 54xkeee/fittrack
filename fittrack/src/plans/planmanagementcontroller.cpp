#include "plans/planmanagementcontroller.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QHash>
#include <QSet>
#include <QUuid>

namespace fittrack {
namespace {

QString newId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

} // namespace

PlanManagementController::PlanManagementController(const QSqlDatabase &database, QObject *parent)
    : QObject(parent), m_database(database)
{
}

QVariantList PlanManagementController::plans() const { return m_plans; }
QVariantMap PlanManagementController::selectedPlan() const { return m_selectedPlan; }
QString PlanManagementController::errorMessage() const { return m_errorMessage; }

void PlanManagementController::ensureLoaded()
{
    if (!m_loaded)
        reload();
}

void PlanManagementController::reload()
{
    m_loaded = true;
    QVariantList result;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT p.id,p.name,p.is_system,p.is_read_only,COUNT(DISTINCT d.id),COUNT(DISTINCT pe.id) "
        "FROM training_plan p LEFT JOIN plan_day d ON d.plan_id=p.id "
        "LEFT JOIN plan_exercise pe ON pe.day_id=d.id GROUP BY p.id "
        "ORDER BY p.is_system DESC,p.name"));
    if (query.exec()) {
        while (query.next()) {
            result.append(QVariantMap{
                {QStringLiteral("id"), query.value(0)},
                {QStringLiteral("name"), query.value(1)},
                {QStringLiteral("isSystem"), query.value(2).toBool()},
                {QStringLiteral("isReadOnly"), query.value(3).toBool()},
                {QStringLiteral("dayCount"), query.value(4)},
                {QStringLiteral("exerciseCount"), query.value(5)},
            });
        }
    }
    m_plans = result;
    emit plansChanged();
    const QString selectedId = m_selectedPlan.value(QStringLiteral("id")).toString();
    if (!selectedId.isEmpty()) {
        selectPlan(selectedId);
    } else if (!m_plans.isEmpty()) {
        selectPlan(m_plans.first().toMap().value(QStringLiteral("id")).toString());
    }
}

bool PlanManagementController::selectPlan(const QString &planId)
{
    clearError();
    QSqlQuery plan(m_database);
    plan.prepare(QStringLiteral(
        "SELECT id,name,is_system,is_read_only FROM training_plan WHERE id=?"));
    plan.addBindValue(planId);
    if (!plan.exec() || !plan.next()) return fail(QStringLiteral("找不到训练计划"));
    const QString selectedId = plan.value(0).toString();
    const QString selectedName = plan.value(1).toString();
    const bool isSystem = plan.value(2).toBool();
    const bool isReadOnly = plan.value(3).toBool();

    QVariantList days;
    QSqlQuery day(m_database);
    day.prepare(QStringLiteral(
        "SELECT d.id,d.name,d.sort_order,COUNT(pe.id) FROM plan_day d "
        "LEFT JOIN plan_exercise pe ON pe.day_id=d.id WHERE d.plan_id=? "
        "GROUP BY d.id ORDER BY d.sort_order,d.id"));
    day.addBindValue(planId);
    if (!day.exec()) return fail(day.lastError().text());
    while (day.next()) {
        days.append(QVariantMap{
            {QStringLiteral("id"), day.value(0)},
            {QStringLiteral("name"), day.value(1)},
            {QStringLiteral("exerciseCount"), day.value(3)},
        });
    }

    QHash<QString, QVariantList> sectionsByDay;
    QSqlQuery section(m_database);
    section.prepare(QStringLiteral(
        "SELECT s.day_id,s.id,s.name FROM plan_section s "
        "JOIN plan_day d ON d.id=s.day_id WHERE d.plan_id=? "
        "ORDER BY d.sort_order,d.id,s.sort_order,s.id"));
    section.addBindValue(planId);
    if (!section.exec()) return fail(section.lastError().text());
    while (section.next()) {
        sectionsByDay[section.value(0).toString()].append(QVariantMap{
            {QStringLiteral("id"), section.value(1)},
            {QStringLiteral("name"), section.value(2)},
        });
    }

    QHash<QString, QVariantMap> cardioByDay;
    QSqlQuery cardioQuery(m_database);
    cardioQuery.prepare(QStringLiteral(
        "SELECT c.day_id,c.cardio_type,c.duration_seconds,c.incline,c.speed_kmh,"
        "c.machine_level,c.notes FROM plan_cardio c "
        "JOIN plan_day d ON d.id=c.day_id WHERE d.plan_id=?"));
    cardioQuery.addBindValue(planId);
    if (!cardioQuery.exec()) return fail(cardioQuery.lastError().text());
    while (cardioQuery.next()) {
        cardioByDay.insert(cardioQuery.value(0).toString(), QVariantMap{
            {QStringLiteral("type"), cardioQuery.value(1)},
            {QStringLiteral("durationMinutes"), cardioQuery.value(2).toInt() / 60},
            {QStringLiteral("incline"), cardioQuery.value(3)},
            {QStringLiteral("speedKmh"), cardioQuery.value(4)},
            {QStringLiteral("machineLevel"), cardioQuery.value(5)},
            {QStringLiteral("notes"), cardioQuery.value(6)},
        });
    }

    QHash<QString, QVariantList> exercisesByDay;
    QSqlQuery exercise(m_database);
    exercise.prepare(QStringLiteral(
        "SELECT pe.day_id,e.name_zh,pe.default_sets,pe.default_reps,pe.notes,"
        "pe.id,pe.exercise_id,e.recommended_sets,e.recommended_reps,e.rest_seconds,"
        "pe.rest_seconds,pe.section_id,COALESCE(s.name,'') "
        "FROM plan_exercise pe JOIN plan_day d ON d.id=pe.day_id "
        "JOIN exercise e ON e.id=pe.exercise_id "
        "LEFT JOIN plan_section s ON s.id=pe.section_id "
        "WHERE d.plan_id=? ORDER BY d.sort_order,d.id,pe.sort_order,pe.id"));
    exercise.addBindValue(planId);
    if (!exercise.exec()) return fail(exercise.lastError().text());
    while (exercise.next()) {
        exercisesByDay[exercise.value(0).toString()].append(QVariantMap{
            {QStringLiteral("name"), exercise.value(1)},
            {QStringLiteral("sets"), exercise.value(2)},
            {QStringLiteral("reps"), exercise.value(3)},
            {QStringLiteral("notes"), exercise.value(4)},
            {QStringLiteral("id"), exercise.value(5)},
            {QStringLiteral("exerciseId"), exercise.value(6)},
            {QStringLiteral("recommendedSets"), exercise.value(7)},
            {QStringLiteral("recommendedReps"), exercise.value(8)},
            {QStringLiteral("recommendedRestSeconds"), exercise.value(9)},
            {QStringLiteral("restSeconds"), exercise.value(10)},
            {QStringLiteral("sectionId"), exercise.value(11)},
            {QStringLiteral("sectionName"), exercise.value(12)},
        });
    }

    for (QVariant &value : days) {
        QVariantMap dayData = value.toMap();
        const QString dayId = dayData.value(QStringLiteral("id")).toString();
        dayData.insert(QStringLiteral("sections"), sectionsByDay.value(dayId));
        dayData.insert(QStringLiteral("exercises"), exercisesByDay.value(dayId));
        dayData.insert(QStringLiteral("cardio"), cardioByDay.value(dayId));
        value = dayData;
    }
    m_selectedPlan = QVariantMap{
        {QStringLiteral("id"), selectedId},
        {QStringLiteral("name"), selectedName},
        {QStringLiteral("isSystem"), isSystem},
        {QStringLiteral("isReadOnly"), isReadOnly},
        {QStringLiteral("days"), days},
    };
    emit selectedPlanChanged();
    return true;
}

bool PlanManagementController::editablePlan(const QString &planId) const
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT 1 FROM training_plan WHERE id=? AND is_system=0 AND is_read_only=0"));
    query.addBindValue(planId);
    return query.exec() && query.next();
}

QString PlanManagementController::editableDayPlanId(const QString &dayId) const
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT p.id FROM plan_day d JOIN training_plan p ON p.id=d.plan_id "
        "WHERE d.id=? AND p.is_system=0 AND p.is_read_only=0"));
    query.addBindValue(dayId);
    return query.exec() && query.next() ? query.value(0).toString() : QString{};
}

QString PlanManagementController::editableExercisePlanId(const QString &planExerciseId) const
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT p.id FROM plan_exercise pe JOIN plan_day d ON d.id=pe.day_id "
        "JOIN training_plan p ON p.id=d.plan_id WHERE pe.id=? AND p.is_system=0 AND p.is_read_only=0"));
    query.addBindValue(planExerciseId);
    return query.exec() && query.next() ? query.value(0).toString() : QString{};
}

QString PlanManagementController::editableSectionPlanId(const QString &sectionId) const
{
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT p.id FROM plan_section s JOIN plan_day d ON d.id=s.day_id "
        "JOIN training_plan p ON p.id=d.plan_id "
        "WHERE s.id=? AND p.is_system=0 AND p.is_read_only=0"));
    query.addBindValue(sectionId);
    return query.exec() && query.next() ? query.value(0).toString() : QString{};
}

bool PlanManagementController::createPlan(const QString &name)
{
    clearError();
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) return fail(QStringLiteral("计划名称不能为空"));
    const QString id = newId();
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO training_plan(id,name,is_system,is_read_only) VALUES(?,?,0,0)"));
    query.addBindValue(id);
    query.addBindValue(trimmed);
    if (!query.exec()) return fail(query.lastError().text());
    reload();
    return selectPlan(id);
}

bool PlanManagementController::copyPlan(const QString &planId, const QString &newName)
{
    clearError();

    QSqlQuery sourcePlan(m_database);
    sourcePlan.prepare(QStringLiteral("SELECT name FROM training_plan WHERE id=?"));
    sourcePlan.addBindValue(planId);
    if (!sourcePlan.exec()) return fail(sourcePlan.lastError().text());
    if (!sourcePlan.next()) return fail(QStringLiteral("找不到训练计划"));

    QString copyName = newName.trimmed();
    if (copyName.isEmpty())
        copyName = sourcePlan.value(0).toString() + QStringLiteral("个人版");

    if (!m_database.transaction()) return fail(m_database.lastError().text());
    const auto rollbackFailure = [this](const QString &message) {
        m_database.rollback();
        return fail(message);
    };

    const QString copiedPlanId = newId();
    QSqlQuery insertPlan(m_database);
    insertPlan.prepare(QStringLiteral(
        "INSERT INTO training_plan(id,name,source_plan_id,is_system,is_read_only) "
        "VALUES(?,?,?,0,0)"));
    insertPlan.addBindValue(copiedPlanId);
    insertPlan.addBindValue(copyName);
    insertPlan.addBindValue(planId);
    if (!insertPlan.exec()) return rollbackFailure(insertPlan.lastError().text());

    QSqlQuery sourceDays(m_database);
    sourceDays.prepare(QStringLiteral(
        "SELECT id,name,sort_order FROM plan_day WHERE plan_id=? ORDER BY sort_order,id"));
    sourceDays.addBindValue(planId);
    if (!sourceDays.exec()) return rollbackFailure(sourceDays.lastError().text());

    while (sourceDays.next()) {
        const QString sourceDayId = sourceDays.value(0).toString();
        const QString copiedDayId = newId();

        QSqlQuery insertDay(m_database);
        insertDay.prepare(QStringLiteral(
            "INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES(?,?,?,?)"));
        insertDay.addBindValue(copiedDayId);
        insertDay.addBindValue(copiedPlanId);
        insertDay.addBindValue(sourceDays.value(1));
        insertDay.addBindValue(sourceDays.value(2));
        if (!insertDay.exec()) return rollbackFailure(insertDay.lastError().text());

        QHash<QString, QString> copiedSectionIds;
        QSqlQuery sourceSections(m_database);
        sourceSections.prepare(QStringLiteral(
            "SELECT id,name,sort_order FROM plan_section WHERE day_id=? ORDER BY sort_order,id"));
        sourceSections.addBindValue(sourceDayId);
        if (!sourceSections.exec()) return rollbackFailure(sourceSections.lastError().text());
        while (sourceSections.next()) {
            const QString sourceSectionId = sourceSections.value(0).toString();
            const QString copiedSectionId = newId();
            QSqlQuery insertSection(m_database);
            insertSection.prepare(QStringLiteral(
                "INSERT INTO plan_section(id,day_id,name,sort_order) VALUES(?,?,?,?)"));
            insertSection.addBindValue(copiedSectionId);
            insertSection.addBindValue(copiedDayId);
            insertSection.addBindValue(sourceSections.value(1));
            insertSection.addBindValue(sourceSections.value(2));
            if (!insertSection.exec()) return rollbackFailure(insertSection.lastError().text());
            copiedSectionIds.insert(sourceSectionId, copiedSectionId);
        }

        QSqlQuery sourceExercises(m_database);
        sourceExercises.prepare(QStringLiteral(
            "SELECT exercise_id,section_id,sort_order,default_sets,default_reps,rest_seconds,notes "
            "FROM plan_exercise WHERE day_id=? ORDER BY sort_order,id"));
        sourceExercises.addBindValue(sourceDayId);
        if (!sourceExercises.exec()) return rollbackFailure(sourceExercises.lastError().text());
        while (sourceExercises.next()) {
            const QVariant sourceSectionId = sourceExercises.value(1);
            QVariant copiedSectionId;
            if (!sourceSectionId.isNull()) {
                const auto section = copiedSectionIds.constFind(sourceSectionId.toString());
                if (section == copiedSectionIds.cend())
                    return rollbackFailure(QStringLiteral("计划分组数据不完整"));
                copiedSectionId = *section;
            }

            QSqlQuery insertExercise(m_database);
            insertExercise.prepare(QStringLiteral(
                "INSERT INTO plan_exercise(id,day_id,section_id,exercise_id,sort_order,"
                "default_sets,default_reps,rest_seconds,notes) VALUES(?,?,?,?,?,?,?,?,?)"));
            insertExercise.addBindValue(newId());
            insertExercise.addBindValue(copiedDayId);
            insertExercise.addBindValue(copiedSectionId);
            insertExercise.addBindValue(sourceExercises.value(0));
            insertExercise.addBindValue(sourceExercises.value(2));
            insertExercise.addBindValue(sourceExercises.value(3));
            insertExercise.addBindValue(sourceExercises.value(4));
            insertExercise.addBindValue(sourceExercises.value(5));
            insertExercise.addBindValue(sourceExercises.value(6));
            if (!insertExercise.exec()) return rollbackFailure(insertExercise.lastError().text());
        }


        QSqlQuery copyCardio(m_database);
        copyCardio.prepare(QStringLiteral(
            "INSERT INTO plan_cardio(day_id,cardio_type,duration_seconds,incline,speed_kmh,"
            "machine_level,notes) "
            "SELECT ?,cardio_type,duration_seconds,incline,speed_kmh,machine_level,notes "
            "FROM plan_cardio WHERE day_id=?"));
        copyCardio.addBindValue(copiedDayId);
        copyCardio.addBindValue(sourceDayId);
        if (!copyCardio.exec()) return rollbackFailure(copyCardio.lastError().text());
    }

    if (!m_database.commit()) return rollbackFailure(m_database.lastError().text());
    reload();
    return selectPlan(copiedPlanId);
}

bool PlanManagementController::renamePlan(const QString &planId, const QString &name)
{
    clearError();
    const QString trimmed = name.trimmed();
    if (!editablePlan(planId)) return fail(QStringLiteral("系统计划不能修改"));
    if (trimmed.isEmpty()) return fail(QStringLiteral("计划名称不能为空"));
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("UPDATE training_plan SET name=? WHERE id=?"));
    query.addBindValue(trimmed);
    query.addBindValue(planId);
    if (!query.exec()) return fail(query.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::deletePlan(const QString &planId)
{
    clearError();
    if (!editablePlan(planId)) return fail(QStringLiteral("系统计划不能删除"));
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("DELETE FROM training_plan WHERE id=?"));
    query.addBindValue(planId);
    if (!query.exec()) return fail(query.lastError().text());
    m_selectedPlan.clear();
    emit selectedPlanChanged();
    reload();
    return true;
}

bool PlanManagementController::addDay(const QString &planId, const QString &name)
{
    clearError();
    const QString trimmed = name.trimmed();
    if (!editablePlan(planId)) return fail(QStringLiteral("系统计划不能修改"));
    if (trimmed.isEmpty()) return fail(QStringLiteral("训练日名称不能为空"));
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO plan_day(id,plan_id,name,sort_order) "
        "VALUES(?,?,?,(SELECT COUNT(*) FROM plan_day WHERE plan_id=?))"));
    query.addBindValue(newId());
    query.addBindValue(planId);
    query.addBindValue(trimmed);
    query.addBindValue(planId);
    if (!query.exec()) return fail(query.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::renameDay(const QString &dayId, const QString &name)
{
    clearError();
    const QString trimmed = name.trimmed();
    QSqlQuery owner(m_database);
    owner.prepare(QStringLiteral("SELECT plan_id FROM plan_day WHERE id=?"));
    owner.addBindValue(dayId);
    if (!owner.exec() || !owner.next() || !editablePlan(owner.value(0).toString()))
        return fail(QStringLiteral("系统训练日不能修改"));
    if (trimmed.isEmpty()) return fail(QStringLiteral("训练日名称不能为空"));
    const QString planId = owner.value(0).toString();
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral("UPDATE plan_day SET name=? WHERE id=?"));
    update.addBindValue(trimmed);
    update.addBindValue(dayId);
    if (!update.exec()) return fail(update.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::deleteDay(const QString &dayId)
{
    clearError();
    QSqlQuery owner(m_database);
    owner.prepare(QStringLiteral("SELECT plan_id FROM plan_day WHERE id=?"));
    owner.addBindValue(dayId);
    if (!owner.exec() || !owner.next() || !editablePlan(owner.value(0).toString()))
        return fail(QStringLiteral("系统训练日不能删除"));
    const QString planId = owner.value(0).toString();
    QSqlQuery remove(m_database);
    remove.prepare(QStringLiteral("DELETE FROM plan_day WHERE id=?"));
    remove.addBindValue(dayId);
    if (!remove.exec()) return fail(remove.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::setCardio(const QString &dayId, const QString &cardioType,
                                         int durationMinutes, double incline,
                                         double speedKmh, double machineLevel,
                                         const QString &notes)
{
    clearError();
    const QString planId = editableDayPlanId(dayId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统训练日不能修改"));
    if (durationMinutes < 1 || durationMinutes > 600)
        return fail(QStringLiteral("有氧时长无效"));
    const bool treadmill = cardioType == QStringLiteral("TreadmillIncline");
    const bool stair = cardioType == QStringLiteral("StairClimber");
    if (!treadmill && !stair) return fail(QStringLiteral("有氧类型无效"));
    if (treadmill && (incline < 0.0 || incline > 30.0 || speedKmh <= 0.0 || speedKmh > 30.0))
        return fail(QStringLiteral("跑步机参数无效"));
    if (stair && machineLevel > 100.0)
        return fail(QStringLiteral("爬楼机等级无效"));

    QSqlQuery upsert(m_database);
    upsert.prepare(QStringLiteral(
        "INSERT INTO plan_cardio(day_id,cardio_type,duration_seconds,incline,speed_kmh,"
        "machine_level,notes) VALUES(?,?,?,?,?,?,?) "
        "ON CONFLICT(day_id) DO UPDATE SET cardio_type=excluded.cardio_type,"
        "duration_seconds=excluded.duration_seconds,incline=excluded.incline,"
        "speed_kmh=excluded.speed_kmh,machine_level=excluded.machine_level,notes=excluded.notes"));
    upsert.addBindValue(dayId);
    upsert.addBindValue(cardioType);
    upsert.addBindValue(durationMinutes * 60);
    upsert.addBindValue(treadmill ? QVariant(incline) : QVariant{});
    upsert.addBindValue(treadmill ? QVariant(speedKmh) : QVariant{});
    upsert.addBindValue(stair && machineLevel >= 0.0 ? QVariant(machineLevel) : QVariant{});
    const QString trimmedNotes = notes.trimmed();
    upsert.addBindValue(trimmedNotes.isNull() ? QStringLiteral("") : trimmedNotes);
    if (!upsert.exec()) return fail(upsert.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::removeCardio(const QString &dayId)
{
    clearError();
    const QString planId = editableDayPlanId(dayId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统训练日不能修改"));
    QSqlQuery remove(m_database);
    remove.prepare(QStringLiteral("DELETE FROM plan_cardio WHERE day_id=?"));
    remove.addBindValue(dayId);
    if (!remove.exec()) return fail(remove.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::addSection(const QString &dayId, const QString &name)
{
    clearError();
    const QString planId = editableDayPlanId(dayId);
    const QString trimmed = name.trimmed();
    if (planId.isEmpty()) return fail(QStringLiteral("系统训练日不能修改"));
    if (trimmed.isEmpty()) return fail(QStringLiteral("分组名称不能为空"));
    QSqlQuery insert(m_database);
    insert.prepare(QStringLiteral(
        "INSERT INTO plan_section(id,day_id,name,sort_order) "
        "VALUES(?,?,?,(SELECT COUNT(*) FROM plan_section WHERE day_id=?))"));
    insert.addBindValue(newId());
    insert.addBindValue(dayId);
    insert.addBindValue(trimmed);
    insert.addBindValue(dayId);
    if (!insert.exec()) return fail(insert.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::renameSection(const QString &sectionId, const QString &name)
{
    clearError();
    const QString planId = editableSectionPlanId(sectionId);
    const QString trimmed = name.trimmed();
    if (planId.isEmpty()) return fail(QStringLiteral("系统计划分组不能修改"));
    if (trimmed.isEmpty()) return fail(QStringLiteral("分组名称不能为空"));
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral("UPDATE plan_section SET name=? WHERE id=?"));
    update.addBindValue(trimmed);
    update.addBindValue(sectionId);
    if (!update.exec()) return fail(update.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::deleteSection(const QString &sectionId)
{
    clearError();
    const QString planId = editableSectionPlanId(sectionId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统计划分组不能删除"));
    QSqlQuery remove(m_database);
    remove.prepare(QStringLiteral("DELETE FROM plan_section WHERE id=?"));
    remove.addBindValue(sectionId);
    if (!remove.exec()) return fail(remove.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::addExercise(const QString &dayId, const QString &exerciseId)
{
    clearError();
    const QString planId = editableDayPlanId(dayId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统训练日不能修改"));
    QSqlQuery exercise(m_database);
    exercise.prepare(QStringLiteral(
        "SELECT recommended_sets,recommended_reps,rest_seconds FROM exercise "
        "WHERE id=? AND is_enabled=1"));
    exercise.addBindValue(exerciseId);
    if (!exercise.exec() || !exercise.next()) return fail(QStringLiteral("找不到动作"));
    QSqlQuery insert(m_database);
    insert.prepare(QStringLiteral(
        "INSERT INTO plan_exercise(id,day_id,exercise_id,sort_order,default_sets,default_reps,rest_seconds) "
        "VALUES(?,?,?,(SELECT COUNT(*) FROM plan_exercise WHERE day_id=?),?,?,?)"));
    insert.addBindValue(newId());
    insert.addBindValue(dayId);
    insert.addBindValue(exerciseId);
    insert.addBindValue(dayId);
    insert.addBindValue(qMax(1, exercise.value(0).toInt()));
    insert.addBindValue(exercise.value(1));
    insert.addBindValue(exercise.value(2));
    if (!insert.exec()) return fail(insert.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::updateExercise(
    const QString &planExerciseId, int sets, const QString &reps, int restSeconds)
{
    clearError();
    const QString planId = editableExercisePlanId(planExerciseId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统计划动作不能修改"));
    if (sets < 1 || reps.trimmed().isEmpty() || restSeconds < 0)
        return fail(QStringLiteral("动作参数无效"));
    QSqlQuery update(m_database);
    update.prepare(QStringLiteral(
        "UPDATE plan_exercise SET default_sets=?,default_reps=?,rest_seconds=? WHERE id=?"));
    update.addBindValue(sets);
    update.addBindValue(reps.trimmed());
    update.addBindValue(restSeconds);
    update.addBindValue(planExerciseId);
    if (!update.exec()) return fail(update.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::replaceExercise(const QString &planExerciseId,
                                                const QString &exerciseId)
{
    clearError();
    const QString planId = editableExercisePlanId(planExerciseId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统计划动作不能替换"));

    QSqlQuery exercise(m_database);
    exercise.prepare(QStringLiteral("SELECT 1 FROM exercise WHERE id=? AND is_enabled=1"));
    exercise.addBindValue(exerciseId);
    if (!exercise.exec()) return fail(exercise.lastError().text());
    if (!exercise.next()) return fail(QStringLiteral("找不到可用动作"));

    QSqlQuery update(m_database);
    update.prepare(QStringLiteral("UPDATE plan_exercise SET exercise_id=? WHERE id=?"));
    update.addBindValue(exerciseId);
    update.addBindValue(planExerciseId);
    if (!update.exec()) return fail(update.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::setExerciseSection(const QString &planExerciseId,
                                                   const QString &sectionId)
{
    clearError();
    const QString planId = editableExercisePlanId(planExerciseId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统计划动作不能修改"));

    QVariant sectionValue;
    if (!sectionId.isEmpty()) {
        QSqlQuery owner(m_database);
        owner.prepare(QStringLiteral(
            "SELECT 1 FROM plan_exercise pe JOIN plan_section s ON s.day_id=pe.day_id "
            "WHERE pe.id=? AND s.id=?"));
        owner.addBindValue(planExerciseId);
        owner.addBindValue(sectionId);
        if (!owner.exec()) return fail(owner.lastError().text());
        if (!owner.next()) return fail(QStringLiteral("分组不属于当前训练日"));
        sectionValue = sectionId;
    }

    QSqlQuery update(m_database);
    update.prepare(QStringLiteral("UPDATE plan_exercise SET section_id=? WHERE id=?"));
    update.addBindValue(sectionValue);
    update.addBindValue(planExerciseId);
    if (!update.exec()) return fail(update.lastError().text());
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::removeExercise(const QString &planExerciseId)
{
    clearError();
    const QString planId = editableExercisePlanId(planExerciseId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统计划动作不能删除"));
    QSqlQuery owner(m_database);
    owner.prepare(QStringLiteral("SELECT day_id FROM plan_exercise WHERE id=?"));
    owner.addBindValue(planExerciseId);
    if (!owner.exec() || !owner.next()) return fail(owner.lastError().text());
    const QString dayId = owner.value(0).toString();
    if (!m_database.transaction()) return fail(m_database.lastError().text());
    QSqlQuery remove(m_database);
    remove.prepare(QStringLiteral("DELETE FROM plan_exercise WHERE id=?"));
    remove.addBindValue(planExerciseId);
    if (!remove.exec()) {
        m_database.rollback();
        return fail(remove.lastError().text());
    }
    QSqlQuery remaining(m_database);
    remaining.prepare(QStringLiteral(
        "SELECT id FROM plan_exercise WHERE day_id=? ORDER BY sort_order,id"));
    remaining.addBindValue(dayId);
    if (!remaining.exec()) {
        m_database.rollback();
        return fail(remaining.lastError().text());
    }
    int index = 0;
    while (remaining.next()) {
        QSqlQuery update(m_database);
        update.prepare(QStringLiteral("UPDATE plan_exercise SET sort_order=? WHERE id=?"));
        update.addBindValue(index++);
        update.addBindValue(remaining.value(0));
        if (!update.exec()) {
            m_database.rollback();
            return fail(update.lastError().text());
        }
    }
    if (!m_database.commit()) {
        m_database.rollback();
        return fail(m_database.lastError().text());
    }
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::moveExercise(const QString &dayId, int fromIndex, int toIndex)
{
    clearError();
    const QString planId = editableDayPlanId(dayId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统计划动作不能排序"));
    QSqlQuery list(m_database);
    list.prepare(QStringLiteral(
        "SELECT id FROM plan_exercise WHERE day_id=? ORDER BY sort_order,id"));
    list.addBindValue(dayId);
    if (!list.exec()) return fail(list.lastError().text());
    QStringList ids;
    while (list.next()) ids.append(list.value(0).toString());
    if (fromIndex < 0 || fromIndex >= ids.size() || toIndex < 0 || toIndex >= ids.size())
        return fail(QStringLiteral("动作序号无效"));
    ids.move(fromIndex, toIndex);
    return reorderExercises(dayId, ids);
}

bool PlanManagementController::reorderExercises(
    const QString &dayId, const QStringList &orderedExerciseIds)
{
    clearError();
    const QString planId = editableDayPlanId(dayId);
    if (planId.isEmpty()) return fail(QStringLiteral("系统计划动作不能排序"));
    QSqlQuery list(m_database);
    list.prepare(QStringLiteral(
        "SELECT id FROM plan_exercise WHERE day_id=? ORDER BY sort_order,id"));
    list.addBindValue(dayId);
    if (!list.exec()) return fail(list.lastError().text());
    QStringList existingIds;
    while (list.next()) existingIds.append(list.value(0).toString());
    const QSet<QString> orderedSet(orderedExerciseIds.cbegin(), orderedExerciseIds.cend());
    const QSet<QString> existingSet(existingIds.cbegin(), existingIds.cend());
    if (orderedExerciseIds.size() != existingIds.size()
        || orderedSet.size() != orderedExerciseIds.size()
        || orderedSet != existingSet) {
        return fail(QStringLiteral("动作顺序与当前训练日不一致"));
    }
    if (!m_database.transaction()) return fail(m_database.lastError().text());
    for (int index = 0; index < orderedExerciseIds.size(); ++index) {
        QSqlQuery update(m_database);
        update.prepare(QStringLiteral("UPDATE plan_exercise SET sort_order=? WHERE id=?"));
        update.addBindValue(index);
        update.addBindValue(orderedExerciseIds.at(index));
        if (!update.exec()) {
            m_database.rollback();
            return fail(update.lastError().text());
        }
    }
    if (!m_database.commit()) {
        m_database.rollback();
        return fail(m_database.lastError().text());
    }
    reload();
    return selectPlan(planId);
}

bool PlanManagementController::fail(const QString &message)
{
    if (m_errorMessage != message) {
        m_errorMessage = message;
        emit errorMessageChanged();
    }
    return false;
}

void PlanManagementController::clearError()
{
    if (!m_errorMessage.isEmpty()) {
        m_errorMessage.clear();
        emit errorMessageChanged();
    }
}

} // namespace fittrack
