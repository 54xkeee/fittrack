#include "timer/resttimercontroller.h"
#include "timer/androidresttimerbridge.h"

#include <QDateTime>

#include <algorithm>

namespace fittrack {

RestTimerController::RestTimerController(QObject *parent)
    : QObject(parent)
{
    m_tickTimer.setInterval(200);
    m_tickTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_tickTimer, &QTimer::timeout, this, &RestTimerController::updateRemaining);
}

RestTimerController::State RestTimerController::state() const
{
    return m_state;
}

int RestTimerController::remainingSeconds() const
{
    return m_remainingSeconds;
}

int RestTimerController::durationSeconds() const
{
    return m_durationSeconds;
}

void RestTimerController::start(int seconds)
{
    if (seconds <= 0) {
        reset();
        return;
    }

    m_durationSeconds = seconds;
    m_remainingSeconds = seconds;
    m_pausedRemainingMs = 0;
    m_deadlineMs = QDateTime::currentMSecsSinceEpoch() + static_cast<qint64>(seconds) * 1000;
    emit durationSecondsChanged();
    emit remainingSecondsChanged();
    setState(State::Running);
    m_tickTimer.start();
    androidtimer::start(seconds);
}

void RestTimerController::pause()
{
    if (m_state != State::Running) {
        return;
    }
    m_pausedRemainingMs = std::max<qint64>(0, m_deadlineMs - QDateTime::currentMSecsSinceEpoch());
    m_tickTimer.stop();
    updateRemaining();
    setState(State::Paused);
    androidtimer::pause(m_pausedRemainingMs);
}

void RestTimerController::resume()
{
    if (m_state != State::Paused || m_pausedRemainingMs <= 0) {
        return;
    }
    m_deadlineMs = QDateTime::currentMSecsSinceEpoch() + m_pausedRemainingMs;
    setState(State::Running);
    m_tickTimer.start();
    androidtimer::resume(m_pausedRemainingMs);
}

void RestTimerController::reset()
{
    m_tickTimer.stop();
    androidtimer::stop();
    const bool durationChanged = m_durationSeconds != 0;
    const bool remainingChanged = m_remainingSeconds != 0;
    m_durationSeconds = 0;
    m_remainingSeconds = 0;
    m_deadlineMs = 0;
    m_pausedRemainingMs = 0;
    if (durationChanged) {
        emit durationSecondsChanged();
    }
    if (remainingChanged) {
        emit remainingSecondsChanged();
    }
    setState(State::Idle);
}

void RestTimerController::finishEarly()
{
    if (m_state == State::Idle || m_state == State::Finished) {
        return;
    }
    androidtimer::stop();
    complete();
}

void RestTimerController::synchronize()
{
    updateRemaining();
}

void RestTimerController::updateRemaining()
{
    if (m_state != State::Running) {
        return;
    }

    const qint64 milliseconds = std::max<qint64>(0, m_deadlineMs - QDateTime::currentMSecsSinceEpoch());
    const int seconds = static_cast<int>((milliseconds + 999) / 1000);
    if (seconds != m_remainingSeconds) {
        m_remainingSeconds = seconds;
        emit remainingSecondsChanged();
    }
    if (milliseconds == 0) {
        complete();
    }
}

void RestTimerController::setState(State state)
{
    if (m_state == state) {
        return;
    }
    m_state = state;
    emit stateChanged();
}

void RestTimerController::complete()
{
    m_tickTimer.stop();
    if (m_remainingSeconds != 0) {
        m_remainingSeconds = 0;
        emit remainingSecondsChanged();
    }
    setState(State::Finished);
    emit finished();
}

} // namespace fittrack
