#include "app/androidreactbridge.h"

#ifdef FITTRACK_REACT_ANDROID_WEBVIEW

#include "timer/resttimercontroller.h"
#include "training/workoutsessioncontroller.h"

#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJniObject>
#include <QMetaObject>
#include <QtCore/qcoreapplication_platform.h>
#include <QThread>
#include <QTimer>
#include <jni.h>
#include <utility>

namespace {

fittrack::AndroidReactBridge *g_bridge = nullptr;

QJsonObject setJson(const QVariantMap &set, int setIndex, int activeSetIndex)
{
    const bool completed = set.value(QStringLiteral("completed")).toBool();
    const int reps = completed
        ? set.value(QStringLiteral("actualReps")).toInt()
        : set.value(QStringLiteral("targetReps")).toInt();
    return {
        {QStringLiteral("id"), set.value(QStringLiteral("id")).toString()},
        {QStringLiteral("number"), set.value(QStringLiteral("number"), setIndex + 1).toInt()},
        {QStringLiteral("weightKg"), set.value(QStringLiteral("weightKg")).toDouble()},
        {QStringLiteral("reps"), reps},
        {QStringLiteral("state"), completed ? QStringLiteral("completed")
            : setIndex == activeSetIndex ? QStringLiteral("active")
                                         : QStringLiteral("pending")},
    };
}

template <typename Function>
auto invokeOnBridgeThread(Function &&function) -> decltype(function())
{
    using Result = decltype(function());
    if (!g_bridge)
        return Result{};
    if (QThread::currentThread() == g_bridge->thread())
        return function();
    Result result{};
    QMetaObject::invokeMethod(g_bridge, [&] { result = function(); },
                              Qt::BlockingQueuedConnection);
    return result;
}

template <typename Function>
void invokeVoidOnBridgeThread(Function &&function)
{
    if (!g_bridge)
        return;
    if (QThread::currentThread() == g_bridge->thread()) {
        function();
        return;
    }
    QMetaObject::invokeMethod(g_bridge, std::forward<Function>(function),
                              Qt::BlockingQueuedConnection);
}

QString fromJString(JNIEnv *, jstring value)
{
    return value ? QJniObject(value).toString() : QString{};
}

jstring toJString(JNIEnv *env, const QString &value)
{
    return env->NewString(reinterpret_cast<const jchar *>(value.constData()), value.size());
}

} // namespace

namespace fittrack {

AndroidReactBridge::AndroidReactBridge(WorkoutSessionController *workoutController,
                                       RestTimerController *restTimer,
                                       QObject *parent)
    : QObject(parent)
    , m_workoutController(workoutController)
    , m_restTimer(restTimer)
{
    g_bridge = this;
    connect(m_workoutController, &WorkoutSessionController::sessionChanged,
            this, &AndroidReactBridge::handleSessionChanged);
    connect(m_workoutController, &WorkoutSessionController::exercisesChanged,
            this, [this] {
                if (m_workoutController->exercises().isEmpty())
                    hide();
                else
                    show();
            });
    connect(m_workoutController, &WorkoutSessionController::workoutFinished,
            this, [this] { hide(); });
    QTimer::singleShot(0, this, &AndroidReactBridge::handleSessionChanged);
}

AndroidReactBridge::~AndroidReactBridge()
{
    hide();
    if (g_bridge == this)
        g_bridge = nullptr;
}

int AndroidReactBridge::firstIncompleteExerciseIndex() const
{
    const QVariantList exercises = m_workoutController->exercises();
    for (int exerciseIndex = 0; exerciseIndex < exercises.size(); ++exerciseIndex) {
        const QVariantList sets = exercises.at(exerciseIndex).toMap()
                                      .value(QStringLiteral("sets")).toList();
        for (const QVariant &set : sets) {
            if (!set.toMap().value(QStringLiteral("completed")).toBool())
                return exerciseIndex;
        }
    }
    return exercises.isEmpty() ? -1 : 0;
}

int AndroidReactBridge::nextIncompleteExerciseIndex(int afterIndex) const
{
    const QVariantList exercises = m_workoutController->exercises();
    for (int exerciseIndex = afterIndex + 1; exerciseIndex < exercises.size(); ++exerciseIndex) {
        const QVariantList sets = exercises.at(exerciseIndex).toMap()
                                      .value(QStringLiteral("sets")).toList();
        for (const QVariant &set : sets) {
            if (!set.toMap().value(QStringLiteral("completed")).toBool())
                return exerciseIndex;
        }
    }
    return -1;
}

AndroidReactBridge::SetPosition AndroidReactBridge::findSet(const QString &setId) const
{
    const QVariantList exercises = m_workoutController->exercises();
    for (int exerciseIndex = 0; exerciseIndex < exercises.size(); ++exerciseIndex) {
        const QVariantList sets = exercises.at(exerciseIndex).toMap()
                                      .value(QStringLiteral("sets")).toList();
        for (int setIndex = 0; setIndex < sets.size(); ++setIndex) {
            if (sets.at(setIndex).toMap().value(QStringLiteral("id")).toString() == setId)
                return {exerciseIndex, setIndex};
        }
    }
    return {};
}

QString AndroidReactBridge::snapshotJson()
{
    const QVariantList exercises = m_workoutController->exercises();
    if (exercises.isEmpty())
        return QStringLiteral("{}");
    if (m_currentExerciseIndex < 0 || m_currentExerciseIndex >= exercises.size())
        m_currentExerciseIndex = firstIncompleteExerciseIndex();

    auto exerciseJson = [&](int exerciseIndex) {
        const QVariantMap exercise = exercises.at(exerciseIndex).toMap();
        const QVariantList sets = exercise.value(QStringLiteral("sets")).toList();
        int activeSetIndex = -1;
        for (int setIndex = 0; setIndex < sets.size(); ++setIndex) {
            if (!sets.at(setIndex).toMap().value(QStringLiteral("completed")).toBool()) {
                activeSetIndex = setIndex;
                break;
            }
        }
        QJsonArray setArray;
        for (int setIndex = 0; setIndex < sets.size(); ++setIndex)
            setArray.append(setJson(sets.at(setIndex).toMap(), setIndex, activeSetIndex));
        const QString reps = exercise.value(QStringLiteral("recommendedReps")).toString();
        return QJsonObject{
            {QStringLiteral("id"), exercise.value(QStringLiteral("id")).toString()},
            {QStringLiteral("name"), exercise.value(QStringLiteral("name")).toString()},
            {QStringLiteral("image"), exerciseIndex == m_currentExerciseIndex
                ? QStringLiteral("./images/incline-dumbbell-bench-press.jpg")
                : QStringLiteral("./images/barbell-bench-press.jpg")},
            {QStringLiteral("meta"), QStringLiteral("%1组 · %2 · 休息%3秒")
                .arg(sets.size())
                .arg(reps.isEmpty() ? QStringLiteral("自定次数") : reps)
                .arg(exercise.value(QStringLiteral("restSeconds")).toInt())},
            {QStringLiteral("notes"), exercise.value(QStringLiteral("notes")).toString()},
            {QStringLiteral("sets"), setArray},
        };
    };

    int completedSetCount = 0;
    double totalVolume = 0.0;
    for (const QVariant &exerciseValue : exercises) {
        const QVariantMap exercise = exerciseValue.toMap();
        const QVariantList sets = exercise.value(QStringLiteral("sets")).toList();
        for (const QVariant &setValue : sets) {
            const QVariantMap set = setValue.toMap();
            if (!set.value(QStringLiteral("completed")).toBool())
                continue;
            ++completedSetCount;
            const int sideFactor = set.value(QStringLiteral("bothSides")).toBool() ? 2 : 1;
            totalVolume += set.value(QStringLiteral("weightKg")).toDouble()
                         * set.value(QStringLiteral("actualReps")).toInt()
                         * sideFactor;
        }
    }

    const int nextIndex = nextIncompleteExerciseIndex(m_currentExerciseIndex);
    const QJsonValue nextExercise = nextIndex >= 0 ? QJsonValue(exerciseJson(nextIndex))
                                                   : QJsonValue(QJsonValue::Null);
    const QJsonObject snapshot{
        {QStringLiteral("title"), QStringLiteral("记录训练")},
        {QStringLiteral("progress"), QStringLiteral("%1 · 第%2/%3个动作")
            .arg(m_workoutController->sessionName())
            .arg(m_currentExerciseIndex + 1)
            .arg(exercises.size())},
        {QStringLiteral("elapsed"), QStringLiteral("进行中")},
        {QStringLiteral("totalVolume"), QStringLiteral("%1 kg").arg(qRound(totalVolume))},
        {QStringLiteral("completedSets"), completedSetCount},
        {QStringLiteral("restSeconds"), m_restTimer->remainingSeconds()},
        {QStringLiteral("restRunning"), m_restTimer->state() == RestTimerController::State::Running},
        {QStringLiteral("current"), exerciseJson(m_currentExerciseIndex)},
        {QStringLiteral("next"), nextExercise},
    };
    return QString::fromUtf8(QJsonDocument(snapshot).toJson(QJsonDocument::Compact));
}

bool AndroidReactBridge::updateSet(const QString &setId, double weightKg, int reps)
{
    const SetPosition position = findSet(setId);
    return position.exerciseIndex >= 0
        && m_workoutController->setSetWeight(position.exerciseIndex, position.setIndex, weightKg)
        && m_workoutController->setTargetReps(position.exerciseIndex, position.setIndex, reps);
}

bool AndroidReactBridge::completeSet(const QString &setId)
{
    const SetPosition position = findSet(setId);
    if (position.exerciseIndex < 0)
        return false;
    const QVariantMap exercise = m_workoutController->exercises()
                                     .at(position.exerciseIndex).toMap();
    const QVariantMap set = exercise.value(QStringLiteral("sets")).toList()
                                .at(position.setIndex).toMap();
    const bool ok = m_workoutController->completeSet(
        position.exerciseIndex, position.setIndex,
        set.value(QStringLiteral("weightKg")).toDouble(),
        set.value(QStringLiteral("targetReps")).toInt(), false,
        set.value(QStringLiteral("bodyweightLoadType"), QStringLiteral("Bodyweight")).toString());
    return ok;
}

bool AndroidReactBridge::addSet()
{
    const QVariantMap exercise = m_workoutController->exercises()
                                     .value(m_currentExerciseIndex).toMap();
    const QVariantList sets = exercise.value(QStringLiteral("sets")).toList();
    if (sets.isEmpty())
        return m_workoutController->addSetFromFirstSet(m_currentExerciseIndex);
    const QVariantMap first = sets.constFirst().toMap();
    const QVariant reps = first.value(QStringLiteral("completed")).toBool()
        ? first.value(QStringLiteral("actualReps"))
        : first.value(QStringLiteral("targetReps"));
    return m_workoutController->addSetFromFirstSet(
        m_currentExerciseIndex, first.value(QStringLiteral("weightKg")), reps);
}

bool AndroidReactBridge::openNextExercise()
{
    const int nextIndex = nextIncompleteExerciseIndex(m_currentExerciseIndex);
    if (nextIndex < 0)
        return false;
    m_currentExerciseIndex = nextIndex;
    return true;
}

void AndroidReactBridge::pauseOrResumeRest()
{
    if (m_restTimer->state() == RestTimerController::State::Paused)
        m_restTimer->resume();
    else
        m_restTimer->pause();
}

void AndroidReactBridge::skipRest()
{
    m_restTimer->reset();
}

bool AndroidReactBridge::finishWorkout()
{
    return m_workoutController->finishWorkout();
}

void AndroidReactBridge::show()
{
    if (m_suppressedForSession || !m_workoutController->active()
        || m_workoutController->exercises().isEmpty())
        return;
    const QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()
        || !QNativeInterface::QAndroidApplication::isActivityContext())
        return;
    QJniObject::callStaticMethod<void>(
        "com/xuke/fittrack/ReactWebViewBridge", "show",
        "(Landroid/app/Activity;)V", activity.object<jobject>());
}

void AndroidReactBridge::hide(bool suppressForSession)
{
    m_suppressedForSession = m_suppressedForSession || suppressForSession;
    QJniObject::callStaticMethod<void>(
        "com/xuke/fittrack/ReactWebViewBridge", "hide", "()V");
}

void AndroidReactBridge::handleSessionChanged()
{
    if (!m_workoutController->active()) {
        m_suppressedForSession = false;
        hide();
        return;
    }
    m_currentExerciseIndex = firstIncompleteExerciseIndex();
    show();
}

} // namespace fittrack

extern "C" JNIEXPORT jstring JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativeGetSnapshot(JNIEnv *env, jclass)
{
    const QString json = invokeOnBridgeThread([] { return g_bridge->snapshotJson(); });
    return toJString(env, json);
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativeUpdateSet(
    JNIEnv *env, jclass, jstring setId, jdouble weightKg, jint reps)
{
    const QString id = fromJString(env, setId);
    return invokeOnBridgeThread([&] { return g_bridge->updateSet(id, weightKg, reps); });
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativeCompleteSet(
    JNIEnv *env, jclass, jstring setId)
{
    const QString id = fromJString(env, setId);
    return invokeOnBridgeThread([&] { return g_bridge->completeSet(id); });
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativeAddSet(JNIEnv *, jclass)
{
    return invokeOnBridgeThread([] { return g_bridge->addSet(); });
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativeOpenNextExercise(JNIEnv *, jclass)
{
    return invokeOnBridgeThread([] { return g_bridge->openNextExercise(); });
}

extern "C" JNIEXPORT void JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativePauseRest(JNIEnv *, jclass)
{
    invokeVoidOnBridgeThread([] { g_bridge->pauseOrResumeRest(); });
}

extern "C" JNIEXPORT void JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativeSkipRest(JNIEnv *, jclass)
{
    invokeVoidOnBridgeThread([] { g_bridge->skipRest(); });
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativeFinishWorkout(JNIEnv *, jclass)
{
    return invokeOnBridgeThread([] { return g_bridge->finishWorkout(); });
}

extern "C" JNIEXPORT void JNICALL
Java_com_xuke_fittrack_ReactWebViewBridge_nativeSuppressForSession(JNIEnv *, jclass)
{
    invokeVoidOnBridgeThread([] { g_bridge->hide(true); });
}

#endif
