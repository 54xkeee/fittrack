#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>

namespace fittrack {

class WorkoutSessionController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList planDays READ planDays NOTIFY planDaysChanged)
    Q_PROPERTY(QVariantMap suggestedDay READ suggestedDay NOTIFY suggestedDayChanged)
    Q_PROPERTY(QVariantList gyms READ gyms NOTIFY gymsChanged)
    Q_PROPERTY(QVariantList equipment READ equipment NOTIFY equipmentChanged)
    Q_PROPERTY(QVariantList exercises READ exercises NOTIFY exercisesChanged)
    Q_PROPERTY(QString selectedGymId READ selectedGymId NOTIFY selectedGymChanged)
    Q_PROPERTY(QString sessionName READ sessionName NOTIFY sessionChanged)
    Q_PROPERTY(QString sessionNotes READ sessionNotes NOTIFY sessionChanged)
    Q_PROPERTY(bool active READ active NOTIFY sessionChanged)
    Q_PROPERTY(bool hasUnfinished READ hasUnfinished NOTIFY unfinishedChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit WorkoutSessionController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList planDays() const;
    QVariantMap suggestedDay() const;
    QVariantList gyms() const;
    QVariantList equipment() const;
    QVariantList exercises() const;
    QString selectedGymId() const;
    QString sessionName() const;
    QString sessionNotes() const;
    bool active() const;
    bool hasUnfinished() const;
    QString errorMessage() const;

    Q_INVOKABLE bool startPlanDay(const QString &dayId);
    Q_INVOKABLE bool startSuggestedDay();
    Q_INVOKABLE bool startFreeWorkout(const QString &name = {});
    Q_INVOKABLE bool addGym(const QString &name);
    Q_INVOKABLE bool selectGym(const QString &gymId);
    Q_INVOKABLE bool addEquipment(const QString &name, const QString &code = {}, const QString &notes = {});
    Q_INVOKABLE bool setExerciseEquipment(int exerciseIndex, const QString &equipmentId);
    Q_INVOKABLE bool setSessionNotes(const QString &notes);
    Q_INVOKABLE bool setExerciseNotes(int exerciseIndex, const QString &notes);
    Q_INVOKABLE bool setSetNotes(int exerciseIndex, int setIndex, const QString &notes);
    Q_INVOKABLE bool saveCurrentAsPlan(
        const QString &planName, const QString &dayName, const QString &sectionName = {});
    Q_INVOKABLE bool addExercise(const QString &exerciseId, int setCount = 0, const QString &targetReps = {});
    Q_INVOKABLE bool replaceExercise(int exerciseIndex, const QString &exerciseId);
    Q_INVOKABLE bool moveExercise(int fromIndex, int toIndex);
    Q_INVOKABLE bool removeExercise(int exerciseIndex);
    Q_INVOKABLE bool configureExercise(int exerciseIndex, double weightKg, int targetReps, int setCount);
    Q_INVOKABLE bool completeSet(int exerciseIndex, int setIndex, double weightKg, int actualReps,
                                 bool toFailure = false, const QString &bodyweightLoadType = QStringLiteral("Bodyweight"));
    Q_INVOKABLE bool updateCompletedSet(
        int exerciseIndex, int setIndex, double weightKg, int actualReps,
        bool toFailure = false, const QString &bodyweightLoadType = QStringLiteral("Bodyweight"));
    Q_INVOKABLE bool addAppendSet(
        int exerciseIndex, int setIndex, double weightKg, int reps, int restSeconds, bool toFailure = false);
    Q_INVOKABLE bool resumeUnfinished();
    Q_INVOKABLE bool finishUnfinished();
    Q_INVOKABLE bool discardUnfinished();
    Q_INVOKABLE bool finishWorkout();
    Q_INVOKABLE bool discardWorkout();
    Q_INVOKABLE void reloadReferenceData();
    void reloadAfterRestore();

signals:
    void exercisesChanged();
    void planDaysChanged();
    void suggestedDayChanged();
    void gymsChanged();
    void equipmentChanged();
    void selectedGymChanged();
    void sessionChanged();
    void unfinishedChanged();
    void errorMessageChanged();
    void setCompleted(int restSeconds);
    void workoutFinished(const QString &sessionId);

private:
    void loadPlanDays();
    void loadSuggestedDay();
    void loadGyms();
    void loadEquipment();
    void refreshUnfinished();
    bool loadSession(const QString &sessionId);
    bool fail(const QString &message);
    void clearError();

    QSqlDatabase m_database;
    QVariantList m_planDays;
    QVariantMap m_suggestedDay;
    QVariantList m_gyms;
    QVariantList m_equipment;
    QVariantList m_exercises;
    QString m_selectedGymId;
    QString m_sessionId;
    QString m_sessionName;
    QString m_sessionNotes;
    QString m_errorMessage;
    bool m_hasUnfinished = false;
};

} // namespace fittrack
