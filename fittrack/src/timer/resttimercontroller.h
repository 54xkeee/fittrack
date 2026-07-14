#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

namespace fittrack {

class RestTimerController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY remainingSecondsChanged)
    Q_PROPERTY(int durationSeconds READ durationSeconds NOTIFY durationSecondsChanged)
    Q_PROPERTY(BackgroundAlertState backgroundAlertState READ backgroundAlertState
               NOTIFY backgroundAlertStateChanged)

public:
    enum class State {
        Idle,
        Running,
        Paused,
        Finished
    };
    Q_ENUM(State)

    enum class BackgroundAlertState {
        Unsupported,
        Available,
        Requestable,
        Disabled,
        Unavailable
    };
    Q_ENUM(BackgroundAlertState)

    explicit RestTimerController(QObject *parent = nullptr);

    State state() const;
    int remainingSeconds() const;
    int durationSeconds() const;
    BackgroundAlertState backgroundAlertState() const;

    Q_INVOKABLE void start(int seconds);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void reset();
    Q_INVOKABLE void finishEarly();
    Q_INVOKABLE void synchronize();
    Q_INVOKABLE void refreshBackgroundAlertState();
    Q_INVOKABLE void requestBackgroundAlertPermission();
    Q_INVOKABLE void openBackgroundAlertSettings();

signals:
    void stateChanged();
    void remainingSecondsChanged();
    void durationSecondsChanged();
    void backgroundAlertStateChanged();
    void finished();

private:
    void updateRemaining();
    void setState(State state);
    void complete();

    QTimer m_tickTimer;
    QElapsedTimer m_clock;
    State m_state = State::Idle;
    int m_durationSeconds = 0;
    int m_remainingSeconds = 0;
    BackgroundAlertState m_backgroundAlertState = BackgroundAlertState::Unsupported;
    bool m_backgroundServiceStartFailed = false;
    qint64 m_deadlineMs = 0;
    qint64 m_pausedRemainingMs = 0;
};

} // namespace fittrack
