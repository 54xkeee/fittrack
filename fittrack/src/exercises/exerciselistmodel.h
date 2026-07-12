#pragma once

#include <QAbstractListModel>
#include <QSqlDatabase>
#include <QString>
#include <QVector>

namespace fittrack {

class ExerciseListModel final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)
    Q_PROPERTY(QString bodyPart READ bodyPart WRITE setBodyPart NOTIFY bodyPartChanged)

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
        MediaSourceUrlRole
    };

    explicit ExerciseListModel(const QSqlDatabase &database, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString searchText() const;
    void setSearchText(const QString &searchText);
    QString bodyPart() const;
    void setBodyPart(const QString &bodyPart);

    Q_INVOKABLE void reload();

signals:
    void searchTextChanged();
    void bodyPartChanged();

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
    };

    QSqlDatabase m_database;
    QString m_searchText;
    QString m_bodyPart;
    QVector<Item> m_items;
};

} // namespace fittrack
