#pragma once

#ifdef FITTRACK_REACT_ANDROID_WEBVIEW

#include <QObject>

namespace fittrack {

class RestTimerController;
class WorkoutSessionController;

class AndroidReactBridge final : public QObject
{
    Q_OBJECT

public:
    AndroidReactBridge(WorkoutSessionController *workoutController,
                       RestTimerController *restTimer,
                       QObject *parent = nullptr);
    ~AndroidReactBridge() override;

    QString snapshotJson();
    bool updateSet(const QString &setId, double weightKg, int reps);
    bool completeSet(const QString &setId);
    bool addSet();
    bool openNextExercise();
    void pauseOrResumeRest();
    void skipRest();
    bool finishWorkout();

    void show();
    void hide(bool suppressForSession = false);

private:
    struct SetPosition {
        int exerciseIndex = -1;
        int setIndex = -1;
    };

    SetPosition findSet(const QString &setId) const;
    int firstIncompleteExerciseIndex() const;
    int nextIncompleteExerciseIndex(int afterIndex) const;
    void handleSessionChanged();

    WorkoutSessionController *m_workoutController = nullptr;
    RestTimerController *m_restTimer = nullptr;
    int m_currentExerciseIndex = 0;
    bool m_suppressedForSession = false;
};

} // namespace fittrack

#endif
