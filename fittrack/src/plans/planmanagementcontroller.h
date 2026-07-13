#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>

namespace fittrack {

class PlanManagementController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList plans READ plans NOTIFY plansChanged)
    Q_PROPERTY(QVariantMap selectedPlan READ selectedPlan NOTIFY selectedPlanChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit PlanManagementController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList plans() const;
    QVariantMap selectedPlan() const;
    QString errorMessage() const;

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool selectPlan(const QString &planId);
    Q_INVOKABLE bool createPlan(const QString &name);
    Q_INVOKABLE bool copyPlan(const QString &planId, const QString &newName = QString());
    Q_INVOKABLE bool renamePlan(const QString &planId, const QString &name);
    Q_INVOKABLE bool deletePlan(const QString &planId);
    Q_INVOKABLE bool addDay(const QString &planId, const QString &name);
    Q_INVOKABLE bool renameDay(const QString &dayId, const QString &name);
    Q_INVOKABLE bool deleteDay(const QString &dayId);
    Q_INVOKABLE bool addExercise(const QString &dayId, const QString &exerciseId);
    Q_INVOKABLE bool updateExercise(const QString &planExerciseId, int sets,
                                    const QString &reps, int restSeconds);
    Q_INVOKABLE bool removeExercise(const QString &planExerciseId);
    Q_INVOKABLE bool moveExercise(const QString &dayId, int fromIndex, int toIndex);

signals:
    void plansChanged();
    void selectedPlanChanged();
    void errorMessageChanged();

private:
    bool editablePlan(const QString &planId) const;
    QString editableDayPlanId(const QString &dayId) const;
    QString editableExercisePlanId(const QString &planExerciseId) const;
    bool fail(const QString &message);
    void clearError();

    QSqlDatabase m_database;
    QVariantList m_plans;
    QVariantMap m_selectedPlan;
    QString m_errorMessage;
};

} // namespace fittrack
