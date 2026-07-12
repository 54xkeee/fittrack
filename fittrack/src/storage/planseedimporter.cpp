#include "storage/planseedimporter.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>

namespace fittrack {
namespace {

bool setError(QString *errorMessage, const QString &message)
{
    if (errorMessage) {
        *errorMessage = message;
    }
    return false;
}

bool execute(QSqlQuery &query, QString *errorMessage)
{
    return query.exec() || setError(errorMessage, query.lastError().text());
}

} // namespace

bool PlanSeedImporter::importDocument(
    const QSqlDatabase &database,
    const QByteArray &documentBytes,
    QString *errorMessage)
{
    QJsonParseError parseError;
    const auto document = QJsonDocument::fromJson(documentBytes, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        return setError(errorMessage, QStringLiteral("训练计划必须是 JSON 对象：%1").arg(parseError.errorString()));
    }

    const auto plan = document.object();
    const QString planId = plan.value(QStringLiteral("id")).toString().trimmed();
    const QString planName = plan.value(QStringLiteral("name")).toString().trimmed();
    const auto days = plan.value(QStringLiteral("days")).toArray();
    if (planId.isEmpty() || planName.isEmpty() || days.isEmpty()) {
        return setError(errorMessage, QStringLiteral("训练计划缺少 id、name 或 days"));
    }

    QSqlDatabase db = database;
    for (const auto &dayValue : days) {
        const auto day = dayValue.toObject();
        if (day.value(QStringLiteral("id")).toString().isEmpty()
            || day.value(QStringLiteral("name")).toString().isEmpty()) {
            return setError(errorMessage, QStringLiteral("训练日缺少 id 或 name"));
        }
        for (const auto &exerciseValue : day.value(QStringLiteral("exercises")).toArray()) {
            const QString exerciseId = exerciseValue.toObject().value(QStringLiteral("exerciseId")).toString();
            QSqlQuery check(db);
            check.prepare(QStringLiteral("SELECT 1 FROM exercise WHERE id=?"));
            check.addBindValue(exerciseId);
            if (!check.exec() || !check.next()) {
                return setError(errorMessage, QStringLiteral("训练计划引用了不存在的动作：%1").arg(exerciseId));
            }
        }
    }

    if (!db.transaction()) {
        return setError(errorMessage, db.lastError().text());
    }

    QSqlQuery planQuery(db);
    planQuery.prepare(QStringLiteral(
        "INSERT INTO training_plan(id,name,is_system,is_read_only) VALUES(?,?,1,1) "
        "ON CONFLICT(id) DO UPDATE SET name=excluded.name,is_system=1,is_read_only=1"));
    planQuery.addBindValue(planId);
    planQuery.addBindValue(planName);
    if (!execute(planQuery, errorMessage)) {
        db.rollback();
        return false;
    }

    QSqlQuery clearDays(db);
    clearDays.prepare(QStringLiteral("DELETE FROM plan_day WHERE plan_id=?"));
    clearDays.addBindValue(planId);
    if (!execute(clearDays, errorMessage)) {
        db.rollback();
        return false;
    }

    int dayOrder = 0;
    for (const auto &dayValue : days) {
        const auto day = dayValue.toObject();
        const QString dayId = day.value(QStringLiteral("id")).toString();

        QSqlQuery dayQuery(db);
        dayQuery.prepare(QStringLiteral("INSERT INTO plan_day(id,plan_id,name,sort_order) VALUES(?,?,?,?)"));
        dayQuery.addBindValue(dayId);
        dayQuery.addBindValue(planId);
        dayQuery.addBindValue(day.value(QStringLiteral("name")).toString());
        dayQuery.addBindValue(dayOrder++);
        if (!execute(dayQuery, errorMessage)) {
            db.rollback();
            return false;
        }

        int exerciseOrder = 0;
        for (const auto &exerciseValue : day.value(QStringLiteral("exercises")).toArray()) {
            const auto exercise = exerciseValue.toObject();
            QSqlQuery exerciseQuery(db);
            exerciseQuery.prepare(QStringLiteral("INSERT INTO plan_exercise(id,day_id,exercise_id,sort_order,default_sets,default_reps,rest_seconds,notes) VALUES(?,?,?,?,?,?,?,?)"));
            exerciseQuery.addBindValue(QStringLiteral("%1-%2").arg(dayId).arg(exerciseOrder + 1));
            exerciseQuery.addBindValue(dayId);
            exerciseQuery.addBindValue(exercise.value(QStringLiteral("exerciseId")).toString());
            exerciseQuery.addBindValue(exerciseOrder++);
            exerciseQuery.addBindValue(exercise.value(QStringLiteral("sets")).toInt());
            exerciseQuery.addBindValue(exercise.value(QStringLiteral("reps")).toString());
            exerciseQuery.addBindValue(exercise.value(QStringLiteral("restSeconds")).toInt());
            exerciseQuery.addBindValue(exercise.value(QStringLiteral("notes")).toString());
            if (!execute(exerciseQuery, errorMessage)) {
                db.rollback();
                return false;
            }
        }
    }

    if (!db.commit()) {
        return setError(errorMessage, db.lastError().text());
    }
    return true;
}

} // namespace fittrack
