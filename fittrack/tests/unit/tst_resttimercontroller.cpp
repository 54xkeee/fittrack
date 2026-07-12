#include "timer/resttimercontroller.h"

#include <QSignalSpy>
#include <QTest>

using namespace fittrack;

class RestTimerControllerTest : public QObject
{
    Q_OBJECT

private slots:
    void startsPausesAndResumes();
    void emitsFinishedExactlyOnce();
    void resetReturnsToIdle();
};

void RestTimerControllerTest::startsPausesAndResumes()
{
    RestTimerController timer;
    timer.start(2);
    QCOMPARE(timer.state(), RestTimerController::State::Running);
    QCOMPARE(timer.remainingSeconds(), 2);

    timer.pause();
    QCOMPARE(timer.state(), RestTimerController::State::Paused);
    const int pausedSeconds = timer.remainingSeconds();
    QTest::qWait(250);
    QCOMPARE(timer.remainingSeconds(), pausedSeconds);

    timer.resume();
    QCOMPARE(timer.state(), RestTimerController::State::Running);
}

void RestTimerControllerTest::emitsFinishedExactlyOnce()
{
    RestTimerController timer;
    QSignalSpy finishedSpy(&timer, &RestTimerController::finished);
    timer.start(1);
    QTRY_COMPARE_WITH_TIMEOUT(timer.state(), RestTimerController::State::Finished, 1600);
    QCOMPARE(timer.remainingSeconds(), 0);
    QCOMPARE(finishedSpy.count(), 1);
    timer.finishEarly();
    QCOMPARE(finishedSpy.count(), 1);
}

void RestTimerControllerTest::resetReturnsToIdle()
{
    RestTimerController timer;
    timer.start(120);
    timer.reset();
    QCOMPARE(timer.state(), RestTimerController::State::Idle);
    QCOMPARE(timer.remainingSeconds(), 0);
    QCOMPARE(timer.durationSeconds(), 0);
}

QTEST_GUILESS_MAIN(RestTimerControllerTest)

#include "tst_resttimercontroller.moc"
