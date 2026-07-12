#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>

namespace fittrack {

class AnalyticsDashboardController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int periodDays READ periodDays NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap sevenDayOverview READ sevenDayOverview NOTIFY dataChanged)
    Q_PROPERTY(QVariantMap overview READ overview NOTIFY dataChanged)
    Q_PROPERTY(QVariantList exercises READ exercises NOTIFY dataChanged)
    Q_PROPERTY(QVariantList gyms READ gyms NOTIFY dataChanged)
    Q_PROPERTY(QVariantList equipment READ equipment NOTIFY dataChanged)
    Q_PROPERTY(QVariantList trend READ trend NOTIFY dataChanged)
    Q_PROPERTY(QVariantList primaryMuscles READ primaryMuscles NOTIFY dataChanged)
    Q_PROPERTY(QVariantList secondaryMuscles READ secondaryMuscles NOTIFY dataChanged)
    Q_PROPERTY(QString selectedExerciseId READ selectedExerciseId NOTIFY dataChanged)
    Q_PROPERTY(QString gymFilterId READ gymFilterId NOTIFY dataChanged)
    Q_PROPERTY(QString equipmentFilterId READ equipmentFilterId NOTIFY dataChanged)

public:
    explicit AnalyticsDashboardController(const QSqlDatabase &database, QObject *parent = nullptr);

    int periodDays() const;
    QVariantMap sevenDayOverview() const;
    QVariantMap overview() const;
    QVariantList exercises() const;
    QVariantList gyms() const;
    QVariantList equipment() const;
    QVariantList trend() const;
    QVariantList primaryMuscles() const;
    QVariantList secondaryMuscles() const;
    QString selectedExerciseId() const;
    QString gymFilterId() const;
    QString equipmentFilterId() const;

    Q_INVOKABLE void setPeriodDays(int days);
    Q_INVOKABLE void selectExercise(const QString &exerciseId);
    Q_INVOKABLE void setGymFilter(const QString &gymId);
    Q_INVOKABLE void setEquipmentFilter(const QString &equipmentId);
    Q_INVOKABLE void reload();

signals:
    void dataChanged();

private:
    QVariantMap buildOverview(int days) const;
    QVariantList buildMuscles(int days, const QString &role) const;
    void loadOptions();
    void loadTrend();
    QString cutoff(int days) const;

    QSqlDatabase m_database;
    int m_periodDays = 7;
    QVariantMap m_sevenDayOverview;
    QVariantMap m_overview;
    QVariantList m_exercises;
    QVariantList m_gyms;
    QVariantList m_equipment;
    QVariantList m_trend;
    QVariantList m_primaryMuscles;
    QVariantList m_secondaryMuscles;
    QString m_selectedExerciseId;
    QString m_gymFilterId;
    QString m_equipmentFilterId;
};

} // namespace fittrack
