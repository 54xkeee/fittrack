#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QList>
#include <QSqlDatabase>
#include <QString>
#include <QVector>

namespace fittrack {

class ExerciseListModel final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(QString bodyPart READ bodyPart WRITE setBodyPart NOTIFY bodyPartChanged)
    Q_PROPERTY(QString movementFilter READ movementFilter WRITE setMovementFilter NOTIFY movementFilterChanged)
    Q_PROPERTY(QString equipmentFilter READ equipmentFilter WRITE setEquipmentFilter NOTIFY equipmentFilterChanged)
    Q_PROPERTY(bool favoritesOnly READ favoritesOnly WRITE setFavoritesOnly NOTIFY favoritesOnlyChanged)

public:
    enum Role {
        ExerciseIdRole = Qt::UserRole + 1,
        NameRole,
        BodyPartRole,
        MovementRole,
        LoadModeRole,
        RecommendedSetsRole,
        RecommendedRepsRole,
        RestSecondsRole,
        IntroductionRole,
        StepsRole,
        CautionsRole,
        PrimaryMusclesRole,
        SecondaryMusclesRole,
        MediaUrlRole,
        MediaLicenseRole,
        MediaSourceUrlRole,
        EquipmentTextRole,
        IsSystemRole,
        IsFavoriteRole
    };

    explicit ExerciseListModel(const QSqlDatabase &database,
                               const QList<QByteArray> &seedDocuments = {}, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString searchText() const;
    void setSearchText(const QString &searchText);
    QString bodyPart() const;
    void setBodyPart(const QString &bodyPart);
    QString movementFilter() const;
    void setMovementFilter(const QString &movement);
    QString equipmentFilter() const;
    void setEquipmentFilter(const QString &equipment);
    bool favoritesOnly() const;
    void setFavoritesOnly(bool enabled);

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool toggleFavorite(const QString &exerciseId);
    Q_INVOKABLE bool createCustomExercise(const QString &name, const QString &bodyPart,
        const QString &movement, const QString &equipment, const QString &introduction,
        int recommendedSets, const QString &recommendedReps, int restSeconds);
    Q_INVOKABLE bool updateCustomExercise(const QString &exerciseId, const QString &name,
        const QString &bodyPart, const QString &movement, const QString &equipment,
        const QString &introduction, int recommendedSets, const QString &recommendedReps,
        int restSeconds);
    Q_INVOKABLE bool deleteCustomExercise(const QString &exerciseId);
    Q_INVOKABLE bool restoreSystemExercises();

signals:
    void searchTextChanged();
    void bodyPartChanged();
    void movementFilterChanged();
    void equipmentFilterChanged();
    void favoritesOnlyChanged();

private:
    struct Item {
        QString id;
        QString name;
        QString bodyPart;
        QString movement;
        QString loadMode;
        int recommendedSets = 0;
        QString recommendedReps;
        int restSeconds = 0;
        QString introduction;
        QVariantList steps;
        QVariantList cautions;
        QStringList primaryMuscles;
        QStringList secondaryMuscles;
        QString mediaUrl;
        QString mediaLicense;
        QString mediaSourceUrl;
        QString equipmentText;
        bool isSystem = true;
        bool isFavorite = false;
    };

    QSqlDatabase m_database;
    QString m_searchText;
    QString m_bodyPart;
    QString m_movementFilter;
    QString m_equipmentFilter;
    bool m_favoritesOnly = false;
    QList<QByteArray> m_seedDocuments;
    QVector<Item> m_items;
};

} // namespace fittrack
