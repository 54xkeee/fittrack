#include "storage/exerciseseedimporter.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>

namespace fittrack {
namespace {

QString compactJson(const QJsonValue &value)
{
    if (value.isArray()) {
        return QString::fromUtf8(QJsonDocument(value.toArray()).toJson(QJsonDocument::Compact));
    }
    if (value.isObject()) {
        return QString::fromUtf8(QJsonDocument(value.toObject()).toJson(QJsonDocument::Compact));
    }
    return QStringLiteral("[]");
}

bool fail(QString *errorMessage, const QString &message)
{
    if (errorMessage) {
        *errorMessage = message;
    }
    return false;
}

bool execute(QSqlQuery &query, QString *errorMessage)
{
    if (query.exec()) {
        return true;
    }
    return fail(errorMessage, query.lastError().text());
}

} // namespace

bool ExerciseSeedImporter::importDocuments(
    const QSqlDatabase &database,
    const QList<QByteArray> &documents,
    QString *errorMessage)
{
    QList<QJsonObject> exercises;
    QSet<QString> exerciseIds;

    for (const auto &bytes : documents) {
        QJsonParseError parseError;
        const auto document = QJsonDocument::fromJson(bytes, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
            return fail(errorMessage, QStringLiteral("动作种子必须是 JSON 数组：%1").arg(parseError.errorString()));
        }

        for (const auto &value : document.array()) {
            if (!value.isObject()) {
                return fail(errorMessage, QStringLiteral("动作种子数组只能包含对象"));
            }
            const auto object = value.toObject();
            const QString id = object.value(QStringLiteral("id")).toString().trimmed();
            const QString name = object.value(QStringLiteral("nameZh")).toString().trimmed();
            const QString bodyPart = object.value(QStringLiteral("bodyPart")).toString().trimmed();
            const QString movement = object.value(QStringLiteral("movement")).toString().trimmed();
            const QString loadMode = object.value(QStringLiteral("loadMode")).toString().trimmed();

            if (id.isEmpty() || name.isEmpty() || bodyPart.isEmpty() || movement.isEmpty() || loadMode.isEmpty()) {
                return fail(errorMessage, QStringLiteral("动作缺少必填字段：%1").arg(id.isEmpty() ? name : id));
            }
            if (exerciseIds.contains(id)) {
                return fail(errorMessage, QStringLiteral("动作 ID 重复：%1").arg(id));
            }
            exerciseIds.insert(id);
            exercises.append(object);
        }
    }

    for (const auto &exercise : exercises) {
        for (const auto &alternative : exercise.value(QStringLiteral("alternatives")).toArray()) {
            const QString alternativeId = alternative.toString();
            if (!exerciseIds.contains(alternativeId)) {
                return fail(errorMessage, QStringLiteral("动作 %1 引用了不存在的替代动作 %2")
                                              .arg(exercise.value(QStringLiteral("id")).toString(), alternativeId));
            }
        }
    }

    QSqlDatabase db = database;
    if (!db.transaction()) {
        return fail(errorMessage, db.lastError().text());
    }

    auto rollback = [&db, errorMessage](const QString &message) {
        db.rollback();
        return fail(errorMessage, message);
    };

    for (const auto &exercise : exercises) {
        const QString id = exercise.value(QStringLiteral("id")).toString();

        QSqlQuery exerciseQuery(db);
        exerciseQuery.prepare(QStringLiteral(
            "INSERT INTO exercise(id,name_zh,name_en,aliases_json,body_part,movement,equipment_json,load_mode,introduction,steps_json,cautions_json,difficulty,technique_points_json,common_mistakes_json,collections_json,recommended_sets,recommended_reps,rest_seconds,is_system,is_enabled,source_json) "
            "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,1,1,?) "
            "ON CONFLICT(id) DO UPDATE SET name_zh=excluded.name_zh,name_en=excluded.name_en,aliases_json=excluded.aliases_json,body_part=excluded.body_part,movement=excluded.movement,equipment_json=excluded.equipment_json,load_mode=excluded.load_mode,introduction=excluded.introduction,steps_json=excluded.steps_json,cautions_json=excluded.cautions_json,difficulty=excluded.difficulty,technique_points_json=excluded.technique_points_json,common_mistakes_json=excluded.common_mistakes_json,collections_json=excluded.collections_json,recommended_sets=excluded.recommended_sets,recommended_reps=excluded.recommended_reps,rest_seconds=excluded.rest_seconds,is_system=1,is_enabled=1,source_json=excluded.source_json"));
        exerciseQuery.addBindValue(id);
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("nameZh")).toString());
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("nameEn")).toString());
        exerciseQuery.addBindValue(compactJson(exercise.value(QStringLiteral("aliases"))));
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("bodyPart")).toString());
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("movement")).toString());
        exerciseQuery.addBindValue(compactJson(exercise.value(QStringLiteral("equipment"))));
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("loadMode")).toString());
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("introduction")).toString());
        exerciseQuery.addBindValue(compactJson(exercise.value(QStringLiteral("steps"))));
        exerciseQuery.addBindValue(compactJson(exercise.value(QStringLiteral("cautions"))));
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("difficulty"))
                                       .toString(QStringLiteral("")));
        exerciseQuery.addBindValue(compactJson(exercise.value(QStringLiteral("techniquePoints"))));
        exerciseQuery.addBindValue(compactJson(exercise.value(QStringLiteral("commonMistakes"))));
        exerciseQuery.addBindValue(compactJson(exercise.value(QStringLiteral("collections"))));
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("recommendedSets")).toInt());
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("recommendedReps")).toString());
        exerciseQuery.addBindValue(exercise.value(QStringLiteral("restSeconds")).toInt());
        exerciseQuery.addBindValue(compactJson(exercise.value(QStringLiteral("sources"))));
        if (!execute(exerciseQuery, errorMessage)) {
            db.rollback();
            return false;
        }

        QSqlQuery clearMuscles(db);
        clearMuscles.prepare(QStringLiteral("DELETE FROM exercise_muscle WHERE exercise_id=?"));
        clearMuscles.addBindValue(id);
        if (!execute(clearMuscles, errorMessage)) {
            db.rollback();
            return false;
        }

        const auto addMuscles = [&](const QJsonArray &muscles, const QString &role) -> bool {
            for (const auto &muscleValue : muscles) {
                const QString muscle = muscleValue.toString().trimmed();
                if (muscle.isEmpty()) {
                    continue;
                }

                QSqlQuery muscleQuery(db);
                muscleQuery.prepare(QStringLiteral("INSERT OR IGNORE INTO muscle(id,name_zh,body_part) VALUES(?,?,?)"));
                muscleQuery.addBindValue(muscle);
                muscleQuery.addBindValue(muscle);
                muscleQuery.addBindValue(exercise.value(QStringLiteral("bodyPart")).toString());
                if (!execute(muscleQuery, errorMessage)) {
                    return false;
                }

                QSqlQuery relationQuery(db);
                relationQuery.prepare(QStringLiteral("INSERT INTO exercise_muscle(exercise_id,muscle_id,role) VALUES(?,?,?)"));
                relationQuery.addBindValue(id);
                relationQuery.addBindValue(muscle);
                relationQuery.addBindValue(role);
                if (!execute(relationQuery, errorMessage)) {
                    return false;
                }
            }
            return true;
        };

        if (!addMuscles(exercise.value(QStringLiteral("primaryMuscles")).toArray(), QStringLiteral("primary"))
            || !addMuscles(exercise.value(QStringLiteral("secondaryMuscles")).toArray(), QStringLiteral("secondary"))) {
            db.rollback();
            return false;
        }

        QSqlQuery clearMedia(db);
        clearMedia.prepare(QStringLiteral("DELETE FROM exercise_media WHERE exercise_id=?"));
        clearMedia.addBindValue(id);
        if (!execute(clearMedia, errorMessage)) {
            db.rollback();
            return false;
        }

        for (const auto &mediaValue : exercise.value(QStringLiteral("media")).toArray()) {
            const auto media = mediaValue.toObject();
            QSqlQuery mediaQuery(db);
            mediaQuery.prepare(QStringLiteral("INSERT INTO exercise_media(exercise_id,media_type,local_path,external_url,title,source,license) VALUES(?,?,?,?,?,?,?)"));
            mediaQuery.addBindValue(id);
            mediaQuery.addBindValue(media.value(QStringLiteral("type")).toString());
            mediaQuery.addBindValue(media.value(QStringLiteral("localPath")).toString());
            mediaQuery.addBindValue(media.value(QStringLiteral("url")).toString());
            mediaQuery.addBindValue(media.value(QStringLiteral("title")).toString());
            mediaQuery.addBindValue(media.value(QStringLiteral("source")).toString());
            mediaQuery.addBindValue(media.value(QStringLiteral("license")).toString());
            if (!execute(mediaQuery, errorMessage)) {
                db.rollback();
                return false;
            }
        }
    }

    for (const auto &exercise : exercises) {
        const QString id = exercise.value(QStringLiteral("id")).toString();
        QSqlQuery clearAlternatives(db);
        clearAlternatives.prepare(QStringLiteral("DELETE FROM exercise_alternative WHERE exercise_id=?"));
        clearAlternatives.addBindValue(id);
        if (!execute(clearAlternatives, errorMessage)) {
            db.rollback();
            return false;
        }

        for (const auto &alternative : exercise.value(QStringLiteral("alternatives")).toArray()) {
            QSqlQuery relationQuery(db);
            relationQuery.prepare(QStringLiteral("INSERT INTO exercise_alternative(exercise_id,alternative_id) VALUES(?,?)"));
            relationQuery.addBindValue(id);
            relationQuery.addBindValue(alternative.toString());
            if (!execute(relationQuery, errorMessage)) {
                db.rollback();
                return false;
            }
        }
    }

    if (!db.commit()) {
        return rollback(db.lastError().text());
    }
    return true;
}

} // namespace fittrack
