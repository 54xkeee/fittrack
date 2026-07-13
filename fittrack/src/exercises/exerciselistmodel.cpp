#include "exercises/exerciselistmodel.h"

#include "storage/exerciseseedimporter.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QSqlQuery>
#include <QUuid>

namespace fittrack {

ExerciseListModel::ExerciseListModel(const QSqlDatabase &database,
                                     const QList<QByteArray> &seedDocuments, QObject *parent)
    : QAbstractListModel(parent)
    , m_database(database)
    , m_seedDocuments(seedDocuments)
{
    reload();
}

int ExerciseListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant ExerciseListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }
    const auto &item = m_items.at(index.row());
    switch (role) {
    case ExerciseIdRole: return item.id;
    case NameRole: return item.name;
    case BodyPartRole: return item.bodyPart;
    case MovementRole: return item.movement;
    case LoadModeRole: return item.loadMode;
    case RecommendedSetsRole: return item.recommendedSets;
    case RecommendedRepsRole: return item.recommendedReps;
    case RestSecondsRole: return item.restSeconds;
    case IntroductionRole: return item.introduction;
    case StepsRole: return item.steps;
    case CautionsRole: return item.cautions;
    case DifficultyRole: return item.difficulty;
    case TechniquePointsRole: return item.techniquePoints;
    case CommonMistakesRole: return item.commonMistakes;
    case CollectionsRole: return item.collections;
    case PrimaryMusclesRole: return item.primaryMuscles;
    case SecondaryMusclesRole: return item.secondaryMuscles;
    case MediaUrlRole: return item.mediaUrl;
    case MediaTitleRole: return item.mediaTitle;
    case MediaSourceRole: return item.mediaSource;
    case MediaLicenseRole: return item.mediaLicense;
    case MediaSourceUrlRole: return item.mediaSourceUrl;
    case EquipmentTextRole: return item.equipmentText;
    case IsSystemRole: return item.isSystem;
    case IsFavoriteRole: return item.isFavorite;
    case SourcesRole: return item.sources;
    case MediaItemsRole: return item.mediaItems;
    default: return {};
    }
}

QHash<int, QByteArray> ExerciseListModel::roleNames() const
{
    return {
        {ExerciseIdRole, "exerciseId"},
        {NameRole, "name"},
        {BodyPartRole, "bodyPart"},
        {MovementRole, "movement"},
        {LoadModeRole, "loadMode"},
        {RecommendedSetsRole, "recommendedSets"},
        {RecommendedRepsRole, "recommendedReps"},
        {RestSecondsRole, "restSeconds"},
        {IntroductionRole, "introduction"},
        {StepsRole, "steps"},
        {CautionsRole, "cautions"},
        {DifficultyRole, "difficulty"},
        {TechniquePointsRole, "techniquePoints"},
        {CommonMistakesRole, "commonMistakes"},
        {CollectionsRole, "collections"},
        {PrimaryMusclesRole, "primaryMuscles"},
        {SecondaryMusclesRole, "secondaryMuscles"},
        {MediaUrlRole, "mediaUrl"},
        {MediaTitleRole, "mediaTitle"},
        {MediaSourceRole, "mediaSource"},
        {MediaLicenseRole, "mediaLicense"},
        {MediaSourceUrlRole, "mediaSourceUrl"},
        {EquipmentTextRole, "equipmentText"},
        {IsSystemRole, "isSystem"},
        {IsFavoriteRole, "isFavorite"},
        {SourcesRole, "sources"},
        {MediaItemsRole, "mediaItems"},
    };
}

QString ExerciseListModel::searchText() const
{
    return m_searchText;
}

void ExerciseListModel::setSearchText(const QString &searchText)
{
    if (m_searchText == searchText) {
        return;
    }
    m_searchText = searchText;
    emit searchTextChanged();
    reload();
}

QString ExerciseListModel::bodyPart() const
{
    return m_bodyPart;
}

void ExerciseListModel::setBodyPart(const QString &bodyPart)
{
    if (m_bodyPart == bodyPart) {
        return;
    }
    m_bodyPart = bodyPart;
    emit bodyPartChanged();
    reload();
}

QString ExerciseListModel::movementFilter() const { return m_movementFilter; }
void ExerciseListModel::setMovementFilter(const QString &movement)
{
    if (m_movementFilter == movement) return;
    m_movementFilter = movement;
    emit movementFilterChanged();
    reload();
}

QString ExerciseListModel::equipmentFilter() const { return m_equipmentFilter; }
void ExerciseListModel::setEquipmentFilter(const QString &equipment)
{
    if (m_equipmentFilter == equipment) return;
    m_equipmentFilter = equipment;
    emit equipmentFilterChanged();
    reload();
}

QString ExerciseListModel::collectionFilter() const { return m_collectionFilter; }
void ExerciseListModel::setCollectionFilter(const QString &collection)
{
    if (m_collectionFilter == collection) return;
    m_collectionFilter = collection;
    emit collectionFilterChanged();
    reload();
}

bool ExerciseListModel::favoritesOnly() const { return m_favoritesOnly; }
void ExerciseListModel::setFavoritesOnly(bool enabled)
{
    if (m_favoritesOnly == enabled) return;
    m_favoritesOnly = enabled;
    emit favoritesOnlyChanged();
    reload();
}

void ExerciseListModel::reload()
{
    QString sql = QStringLiteral(
        "SELECT id,name_zh,body_part,movement,load_mode,recommended_sets,recommended_reps,rest_seconds,"
        "introduction,steps_json,cautions_json,difficulty,technique_points_json,common_mistakes_json,"
        "collections_json,equipment_json,is_system,"
        "EXISTS(SELECT 1 FROM favorite_exercise f WHERE f.exercise_id=exercise.id),source_json "
        "FROM exercise WHERE is_enabled=1");
    if (!m_searchText.trimmed().isEmpty()) {
        sql += QStringLiteral(" AND (name_zh LIKE ? OR name_en LIKE ? OR aliases_json LIKE ?)");
    }
    if (!m_bodyPart.trimmed().isEmpty()) {
        sql += QStringLiteral(" AND body_part=?");
    }
    if (!m_movementFilter.trimmed().isEmpty()) sql += QStringLiteral(" AND movement LIKE ?");
    if (!m_equipmentFilter.trimmed().isEmpty()) sql += QStringLiteral(" AND equipment_json LIKE ?");
    if (!m_collectionFilter.trimmed().isEmpty()) sql += QStringLiteral(" AND collections_json LIKE ?");
    if (m_favoritesOnly) sql += QStringLiteral(
        " AND EXISTS(SELECT 1 FROM favorite_exercise f WHERE f.exercise_id=exercise.id)");
    sql += QStringLiteral(" ORDER BY body_part,name_zh");

    QSqlQuery query(m_database);
    query.prepare(sql);
    if (!m_searchText.trimmed().isEmpty()) {
        const QString pattern = QStringLiteral("%%1%").arg(m_searchText.trimmed());
        query.addBindValue(pattern);
        query.addBindValue(pattern);
        query.addBindValue(pattern);
    }
    if (!m_bodyPart.trimmed().isEmpty()) {
        query.addBindValue(m_bodyPart.trimmed());
    }
    if (!m_movementFilter.trimmed().isEmpty())
        query.addBindValue(QStringLiteral("%%1%").arg(m_movementFilter.trimmed()));
    if (!m_equipmentFilter.trimmed().isEmpty())
        query.addBindValue(QStringLiteral("%%1%").arg(m_equipmentFilter.trimmed()));
    if (!m_collectionFilter.trimmed().isEmpty())
        query.addBindValue(QStringLiteral("%\"%1\"%").arg(m_collectionFilter.trimmed()));

    QVector<Item> items;
    if (query.exec()) {
        while (query.next()) {
            Item item{
                query.value(0).toString(),
                query.value(1).toString(),
                query.value(2).toString(),
                query.value(3).toString(),
                query.value(4).toString(),
                query.value(5).toInt(),
                query.value(6).toString(),
                query.value(7).toInt(),
                query.value(8).toString(),
            };
            const auto steps = QJsonDocument::fromJson(query.value(9).toByteArray()).array();
            for (const auto &step : steps) item.steps.append(step.toString());
            const auto cautions = QJsonDocument::fromJson(query.value(10).toByteArray()).array();
            for (const auto &caution : cautions) item.cautions.append(caution.toString());
            item.difficulty = query.value(11).toString();
            item.techniquePoints = QJsonDocument::fromJson(query.value(12).toByteArray())
                                       .array().toVariantList();
            item.commonMistakes = QJsonDocument::fromJson(query.value(13).toByteArray())
                                      .array().toVariantList();
            item.collections = QJsonDocument::fromJson(query.value(14).toByteArray())
                                   .array().toVariantList();
            const auto equipment = QJsonDocument::fromJson(query.value(15).toByteArray()).array();
            QStringList equipmentNames;
            for (const auto &value : equipment) equipmentNames.append(value.toString());
            item.equipmentText = equipmentNames.join(QStringLiteral("、"));
            item.isSystem = query.value(16).toBool();
            item.isFavorite = query.value(17).toBool();
            item.sources = QJsonDocument::fromJson(query.value(18).toByteArray())
                               .array().toVariantList();

            QSqlQuery muscles(m_database);
            muscles.prepare(QStringLiteral(
                "SELECT m.name_zh,em.role FROM exercise_muscle em JOIN muscle m ON m.id=em.muscle_id "
                "WHERE em.exercise_id=? ORDER BY em.role,m.name_zh"));
            muscles.addBindValue(item.id);
            if (muscles.exec()) {
                while (muscles.next()) {
                    (muscles.value(1).toString() == QStringLiteral("primary")
                         ? item.primaryMuscles : item.secondaryMuscles).append(muscles.value(0).toString());
                }
            }
            QSqlQuery media(m_database);
            media.prepare(QStringLiteral(
                "SELECT local_path,external_url,title,source,license FROM exercise_media "
                "WHERE exercise_id=? ORDER BY id"));
            media.addBindValue(item.id);
            if (media.exec()) {
                while (media.next()) {
                    const QVariantMap mediaItem{
                        {QStringLiteral("url"), media.value(0).toString()},
                        {QStringLiteral("sourceUrl"), media.value(1).toString()},
                        {QStringLiteral("title"), media.value(2).toString()},
                        {QStringLiteral("source"), media.value(3).toString()},
                        {QStringLiteral("license"), media.value(4).toString()},
                    };
                    item.mediaItems.append(mediaItem);
                    if (item.mediaUrl.isEmpty()) {
                        item.mediaUrl = mediaItem.value(QStringLiteral("url")).toString();
                        item.mediaSourceUrl = mediaItem.value(QStringLiteral("sourceUrl")).toString();
                        item.mediaTitle = mediaItem.value(QStringLiteral("title")).toString();
                        item.mediaSource = mediaItem.value(QStringLiteral("source")).toString();
                        item.mediaLicense = mediaItem.value(QStringLiteral("license")).toString();
                    }
                }
            }
            items.append(item);
        }
    }

    beginResetModel();
    m_items = std::move(items);
    endResetModel();
}

bool ExerciseListModel::toggleFavorite(const QString &exerciseId)
{
    QSqlQuery existing(m_database);
    existing.prepare(QStringLiteral("SELECT 1 FROM favorite_exercise WHERE exercise_id=?"));
    existing.addBindValue(exerciseId);
    const bool favorite = existing.exec() && existing.next();
    QSqlQuery update(m_database);
    if (favorite) {
        update.prepare(QStringLiteral("DELETE FROM favorite_exercise WHERE exercise_id=?"));
        update.addBindValue(exerciseId);
    } else {
        update.prepare(QStringLiteral(
            "INSERT INTO favorite_exercise(exercise_id,created_at) VALUES(?,datetime('now'))"));
        update.addBindValue(exerciseId);
    }
    const bool ok = update.exec();
    if (ok) reload();
    return ok;
}

bool ExerciseListModel::createCustomExercise(const QString &name, const QString &bodyPart,
    const QString &movement, const QString &equipment, const QString &introduction,
    int recommendedSets, const QString &recommendedReps, int restSeconds)
{
    if (name.trimmed().isEmpty() || bodyPart.trimmed().isEmpty() || movement.trimmed().isEmpty())
        return false;
    const QJsonArray equipmentArray = equipment.trimmed().isEmpty()
        ? QJsonArray{} : QJsonArray{equipment.trimmed()};
    if (!m_database.transaction()) return false;
    const QString exerciseId = QStringLiteral("custom-%1").arg(
        QUuid::createUuid().toString(QUuid::WithoutBraces));
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO exercise(id,name_zh,body_part,movement,equipment_json,load_mode,introduction,"
        "recommended_sets,recommended_reps,rest_seconds,is_system,is_enabled) "
        "VALUES(?,?,?,?,?,'Standard',?,?,?,?,0,1)"));
    query.addBindValue(exerciseId);
    query.addBindValue(name.trimmed());
    query.addBindValue(bodyPart.trimmed());
    query.addBindValue(movement.trimmed());
    query.addBindValue(QString::fromUtf8(QJsonDocument(equipmentArray).toJson(QJsonDocument::Compact)));
    query.addBindValue(introduction.trimmed());
    query.addBindValue(qMax(1, recommendedSets));
    query.addBindValue(recommendedReps.trimmed());
    query.addBindValue(qMax(0, restSeconds));
    if (!query.exec()) {
        m_database.rollback();
        return false;
    }
    QString muscleId;
    QSqlQuery findMuscle(m_database);
    findMuscle.prepare(QStringLiteral("SELECT id FROM muscle WHERE name_zh=?"));
    findMuscle.addBindValue(bodyPart.trimmed());
    if (findMuscle.exec() && findMuscle.next()) {
        muscleId = findMuscle.value(0).toString();
    } else {
        muscleId = QStringLiteral("custom-muscle-%1").arg(
            QUuid::createUuid().toString(QUuid::WithoutBraces));
        QSqlQuery muscle(m_database);
        muscle.prepare(QStringLiteral("INSERT INTO muscle(id,name_zh,body_part) VALUES(?,?,?)"));
        muscle.addBindValue(muscleId);
        muscle.addBindValue(bodyPart.trimmed());
        muscle.addBindValue(bodyPart.trimmed());
        if (!muscle.exec()) {
            m_database.rollback();
            return false;
        }
    }
    QSqlQuery mapping(m_database);
    mapping.prepare(QStringLiteral(
        "INSERT INTO exercise_muscle(exercise_id,muscle_id,role) VALUES(?,?,'primary')"));
    mapping.addBindValue(exerciseId);
    mapping.addBindValue(muscleId);
    if (!mapping.exec() || !m_database.commit()) {
        m_database.rollback();
        return false;
    }
    const bool ok = true;
    if (ok) reload();
    return ok;
}

bool ExerciseListModel::updateCustomExercise(const QString &exerciseId, const QString &name,
    const QString &bodyPart, const QString &movement, const QString &equipment,
    const QString &introduction, int recommendedSets, const QString &recommendedReps,
    int restSeconds)
{
    if (name.trimmed().isEmpty() || bodyPart.trimmed().isEmpty() || movement.trimmed().isEmpty())
        return false;
    const QJsonArray equipmentArray = equipment.trimmed().isEmpty()
        ? QJsonArray{} : QJsonArray{equipment.trimmed()};
    if (!m_database.transaction()) return false;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "UPDATE exercise SET name_zh=?,body_part=?,movement=?,equipment_json=?,introduction=?,"
        "recommended_sets=?,recommended_reps=?,rest_seconds=? WHERE id=? AND is_system=0"));
    query.addBindValue(name.trimmed());
    query.addBindValue(bodyPart.trimmed());
    query.addBindValue(movement.trimmed());
    query.addBindValue(QString::fromUtf8(QJsonDocument(equipmentArray).toJson(QJsonDocument::Compact)));
    query.addBindValue(introduction.trimmed());
    query.addBindValue(qMax(1, recommendedSets));
    query.addBindValue(recommendedReps.trimmed());
    query.addBindValue(qMax(0, restSeconds));
    query.addBindValue(exerciseId);
    if (!query.exec() || query.numRowsAffected() != 1) {
        m_database.rollback();
        return false;
    }
    QString muscleId;
    QSqlQuery findMuscle(m_database);
    findMuscle.prepare(QStringLiteral("SELECT id FROM muscle WHERE name_zh=?"));
    findMuscle.addBindValue(bodyPart.trimmed());
    if (findMuscle.exec() && findMuscle.next()) {
        muscleId = findMuscle.value(0).toString();
    } else {
        muscleId = QStringLiteral("custom-muscle-%1").arg(
            QUuid::createUuid().toString(QUuid::WithoutBraces));
        QSqlQuery muscle(m_database);
        muscle.prepare(QStringLiteral("INSERT INTO muscle(id,name_zh,body_part) VALUES(?,?,?)"));
        muscle.addBindValue(muscleId);
        muscle.addBindValue(bodyPart.trimmed());
        muscle.addBindValue(bodyPart.trimmed());
        if (!muscle.exec()) {
            m_database.rollback();
            return false;
        }
    }
    QSqlQuery clear(m_database);
    clear.prepare(QStringLiteral("DELETE FROM exercise_muscle WHERE exercise_id=?"));
    clear.addBindValue(exerciseId);
    QSqlQuery mapping(m_database);
    mapping.prepare(QStringLiteral(
        "INSERT INTO exercise_muscle(exercise_id,muscle_id,role) VALUES(?,?,'primary')"));
    mapping.addBindValue(exerciseId);
    mapping.addBindValue(muscleId);
    if (!clear.exec() || !mapping.exec() || !m_database.commit()) {
        m_database.rollback();
        return false;
    }
    const bool ok = true;
    if (ok) reload();
    return ok;
}

bool ExerciseListModel::deleteCustomExercise(const QString &exerciseId)
{
    QSqlQuery references(m_database);
    references.prepare(QStringLiteral(
        "SELECT (SELECT COUNT(*) FROM workout_exercise WHERE exercise_id=?)+"
        "(SELECT COUNT(*) FROM plan_exercise WHERE exercise_id=?)"));
    references.addBindValue(exerciseId);
    references.addBindValue(exerciseId);
    if (!references.exec() || !references.next()) return false;
    QSqlQuery query(m_database);
    if (references.value(0).toInt() > 0)
        query.prepare(QStringLiteral("UPDATE exercise SET is_enabled=0 WHERE id=? AND is_system=0"));
    else
        query.prepare(QStringLiteral("DELETE FROM exercise WHERE id=? AND is_system=0"));
    query.addBindValue(exerciseId);
    const bool ok = query.exec() && query.numRowsAffected() == 1;
    if (ok) reload();
    return ok;
}

bool ExerciseListModel::restoreSystemExercises()
{
    if (m_seedDocuments.isEmpty()) return false;
    QString error;
    const bool ok = ExerciseSeedImporter::importDocuments(m_database, m_seedDocuments, &error);
    if (ok) reload();
    return ok;
}

} // namespace fittrack
