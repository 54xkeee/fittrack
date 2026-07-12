#include "exercises/exerciselistmodel.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QSqlQuery>

namespace fittrack {

ExerciseListModel::ExerciseListModel(const QSqlDatabase &database, QObject *parent)
    : QAbstractListModel(parent)
    , m_database(database)
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
    case PrimaryMusclesRole: return item.primaryMuscles;
    case SecondaryMusclesRole: return item.secondaryMuscles;
    case MediaUrlRole: return item.mediaUrl;
    case MediaLicenseRole: return item.mediaLicense;
    case MediaSourceUrlRole: return item.mediaSourceUrl;
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
        {PrimaryMusclesRole, "primaryMuscles"},
        {SecondaryMusclesRole, "secondaryMuscles"},
        {MediaUrlRole, "mediaUrl"},
        {MediaLicenseRole, "mediaLicense"},
        {MediaSourceUrlRole, "mediaSourceUrl"},
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

void ExerciseListModel::reload()
{
    QString sql = QStringLiteral(
        "SELECT id,name_zh,body_part,movement,load_mode,recommended_sets,recommended_reps,rest_seconds,"
        "introduction,steps_json,cautions_json "
        "FROM exercise WHERE is_enabled=1");
    if (!m_searchText.trimmed().isEmpty()) {
        sql += QStringLiteral(" AND (name_zh LIKE ? OR name_en LIKE ? OR aliases_json LIKE ?)");
    }
    if (!m_bodyPart.trimmed().isEmpty()) {
        sql += QStringLiteral(" AND body_part=?");
    }
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
                "SELECT local_path,external_url,license FROM exercise_media "
                "WHERE exercise_id=? ORDER BY id LIMIT 1"));
            media.addBindValue(item.id);
            if (media.exec() && media.next()) {
                item.mediaUrl = media.value(0).toString();
                item.mediaSourceUrl = media.value(1).toString();
                item.mediaLicense = media.value(2).toString();
            }
            items.append(item);
        }
    }

    beginResetModel();
    m_items = std::move(items);
    endResetModel();
}

} // namespace fittrack
