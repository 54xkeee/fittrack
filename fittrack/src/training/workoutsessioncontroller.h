#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QStringList>
#include <QVariantMap>
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
    Q_PROPERTY(QVariantList activeSessions READ activeSessions NOTIFY activeSessionsChanged)
    Q_PROPERTY(QVariantMap preparation READ preparation NOTIFY preparationChanged)
    Q_PROPERTY(bool preparing READ preparing NOTIFY preparationChanged)
    Q_PROPERTY(QString selectedGymId READ selectedGymId NOTIFY selectedGymChanged)
    Q_PROPERTY(QString sessionId READ sessionId NOTIFY sessionChanged)
    Q_PROPERTY(QString sessionName READ sessionName NOTIFY sessionChanged)
    Q_PROPERTY(QString sessionNotes READ sessionNotes NOTIFY sessionChanged)
    Q_PROPERTY(bool active READ active NOTIFY sessionChanged)
    Q_PROPERTY(bool hasUnfinished READ hasUnfinished NOTIFY unfinishedChanged)
    Q_PROPERTY(QString sessionState READ sessionState NOTIFY sessionStateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit WorkoutSessionController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList planDays() const;
    QVariantMap suggestedDay() const;
    QVariantList gyms() const;
    QVariantList equipment() const;
    QVariantList exercises() const;
    QVariantList activeSessions() const;
    QVariantMap preparation() const;
    bool preparing() const;
    QString selectedGymId() const;
    QString sessionId() const;
    QString sessionName() const;
    QString sessionNotes() const;
    bool active() const;
    bool hasUnfinished() const;
    QString sessionState() const;
    QString errorMessage() const;

    Q_INVOKABLE QVariantMap requestStartPlanDay(const QString &dayId);
    Q_INVOKABLE QVariantMap requestStartSuggestedDay();
    Q_INVOKABLE QVariantMap requestStartFreeWorkout(const QString &name = {});
    Q_INVOKABLE QVariantMap requestPreparePlanDay(const QString &dayId);
    Q_INVOKABLE QVariantMap requestPrepareSuggestedDay();
    Q_INVOKABLE QVariantMap requestPrepareFreeWorkout(const QString &name = {});
    Q_INVOKABLE bool updatePreparedExercise(const QString &draftExerciseId, int sets,
                                            const QString &reps, int restSeconds);
    Q_INVOKABLE bool restorePreparedExerciseDefaults(const QString &draftExerciseId);
    Q_INVOKABLE bool addPreparedExercise(const QString &exerciseId);
    Q_INVOKABLE bool replacePreparedExercise(const QString &draftExerciseId,
                                             const QString &exerciseId);
    Q_INVOKABLE bool movePreparedExercise(const QString &draftExerciseId, int toIndex);
    Q_INVOKABLE bool reorderPreparedExercises(const QStringList &orderedDraftExerciseIds);
    Q_INVOKABLE bool removePreparedExercise(const QString &draftExerciseId);
    Q_INVOKABLE bool savePreparationAsPlan(const QString &planName, const QString &dayName);
    Q_INVOKABLE bool commitPreparation();
    Q_INVOKABLE void cancelPreparation();
    Q_INVOKABLE bool continueExistingWorkout();
    Q_INVOKABLE bool resolveCurrentWorkout(bool discardCurrent);
    Q_INVOKABLE bool recoverActiveSessions(const QString &keepSessionId, bool discardOthers);
    Q_INVOKABLE bool switchToPlanDay(const QString &dayId, bool discardCurrent);
    Q_INVOKABLE bool switchToFreeWorkout(const QString &name, bool discardCurrent);
    Q_INVOKABLE void dismissError();
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
    Q_INVOKABLE bool setTargetReps(int exerciseIndex, int setIndex, int targetReps);
    Q_INVOKABLE bool saveCurrentAsPlan(
        const QString &planName, const QString &dayName, const QString &sectionName = {});
    Q_INVOKABLE bool addExercise(const QString &exerciseId, int setCount = 0, const QString &targetReps = {});
    Q_INVOKABLE bool replaceExercise(int exerciseIndex, const QString &exerciseId);
    Q_INVOKABLE bool moveExercise(int fromIndex, int toIndex);
    Q_INVOKABLE bool reorderExercises(const QStringList &orderedWorkoutExerciseIds);
    Q_INVOKABLE bool removeExercise(int exerciseIndex);
    Q_INVOKABLE bool addSetFromFirstSet(int exerciseIndex,
                                        const QVariant &firstWeightKg = {},
                                        const QVariant &firstReps = {});
    Q_INVOKABLE bool setSetWeight(int exerciseIndex, int setIndex, double weightKg);
    Q_INVOKABLE bool configureExercise(int exerciseIndex, double weightKg, int targetReps, int setCount);
    Q_INVOKABLE bool configureExerciseParameters(int exerciseIndex, double weightKg,
                                                 const QString &targetReps, int setCount,
                                                 int restSeconds);
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
    void reloadGymData();
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
    void activeSessionsChanged();
    void preparationChanged();
    void sessionStateChanged();
    void errorMessageChanged();
    void setCompleted(int restSeconds);
    void workoutFinished(const QString &sessionId);

private:
    void loadStartupState();
    void applyActiveSessions(const QVariantList &activeSessions);
    void loadPlanDays();
    void loadSuggestedDay();
    void loadGyms();
    void loadEquipment();
    void refreshUnfinished();
    QVariantMap requestStart(const QString &kind, const QString &targetId,
                             const QString &displayName);
    QVariantMap requestPrepare(const QString &kind, const QString &targetId,
                               const QString &displayName);
    bool preparePlanDay(const QString &dayId);
    bool prepareFreeWorkout(const QString &name);
    QVariantMap exerciseDefaults(const QString &exerciseId) const;
    int preparedExerciseIndex(const QString &draftExerciseId) const;
    QVariantMap activeSessionSummary() const;
    int activeSessionCount() const;
    bool insertPlanDaySession(const QString &dayId, QString *sessionId);
    bool insertFreeWorkout(const QString &name, QString *sessionId);
    bool switchWorkout(const QString &kind, const QString &targetId,
                       const QString &displayName, bool discardCurrent);
    bool loadSession(const QString &sessionId);
    bool fail(const QString &message);
    void clearError();

    QSqlDatabase m_database;
    QVariantList m_planDays;
    QVariantMap m_suggestedDay;
    QVariantList m_gyms;
    QVariantList m_equipment;
    QVariantList m_exercises;
    QVariantList m_activeSessions;
    QVariantMap m_preparation;
    QString m_selectedGymId;
    QString m_sessionId;
    QString m_sessionName;
    QString m_sessionNotes;
    QString m_errorMessage;
    bool m_hasUnfinished = false;
    int m_activeSessionCount = 0;
};

} // namespace fittrack
