#pragma once

#include <QObject>
#include <QTimer>

namespace fittrack {

class RestTimerController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(int remainingSeconds READ remainingSeconds NOTIFY remainingSecondsChanged)
    Q_PROPERTY(int durationSeconds READ durationSeconds NOTIFY durationSecondsChanged)

public:
    enum class State {
        Idle,
        Running,
        Paused,
        Finished
    };
    Q_ENUM(State)

    explicit RestTimerController(QObject *parent = nullptr);

    State state() const;
    int remainingSeconds() const;
    int durationSeconds() const;

    Q_INVOKABLE void start(int seconds);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void reset();
    Q_INVOKABLE void finishEarly();
    Q_INVOKABLE void synchronize();

signals:
    void stateChanged();
    void remainingSecondsChanged();
    void durationSecondsChanged();
    void finished();

private:
    void updateRemaining();
    void setState(State state);
    void complete();

    QTimer m_tickTimer;
    State m_state = State::Idle;
    int m_durationSeconds = 0;
    int m_remainingSeconds = 0;
    qint64 m_deadlineMs = 0;
    qint64 m_pausedRemainingMs = 0;
};

} // namespace fittrack
