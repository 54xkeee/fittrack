#include "timer/androidresttimerbridge.h"

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QJniObject>

namespace {

QJniObject androidContext()
{
    return QNativeInterface::QAndroidApplication::context();
}

} // namespace
#endif

namespace fittrack::androidtimer {

bool start(int durationSeconds)
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    return QJniObject::callStaticMethod<jboolean>(
        "com/xuke/fittrack/RestTimerBridge",
        "start",
        "(Landroid/content/Context;I)Z",
        context.object<jobject>(),
        static_cast<jint>(durationSeconds)) == JNI_TRUE;
#else
    Q_UNUSED(durationSeconds)
    return false;
#endif
}

void pause(qint64 remainingMilliseconds)
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    QJniObject::callStaticMethod<void>(
        "com/xuke/fittrack/RestTimerBridge",
        "pause",
        "(Landroid/content/Context;J)V",
        context.object<jobject>(),
        static_cast<jlong>(remainingMilliseconds));
#else
    Q_UNUSED(remainingMilliseconds)
#endif
}

void resume(qint64 remainingMilliseconds)
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    QJniObject::callStaticMethod<void>(
        "com/xuke/fittrack/RestTimerBridge",
        "resume",
        "(Landroid/content/Context;J)V",
        context.object<jobject>(),
        static_cast<jlong>(remainingMilliseconds));
#else
    Q_UNUSED(remainingMilliseconds)
#endif
}

void stop()
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    QJniObject::callStaticMethod<void>(
        "com/xuke/fittrack/RestTimerBridge",
        "stop",
        "(Landroid/content/Context;)V",
        context.object<jobject>());
#endif
}

int backgroundAlertState()
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    return static_cast<int>(QJniObject::callStaticMethod<jint>(
        "com/xuke/fittrack/RestTimerBridge",
        "backgroundAlertState",
        "(Landroid/content/Context;)I",
        context.object<jobject>()));
#else
    return 0;
#endif
}

bool requestBackgroundAlertPermission()
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    return QJniObject::callStaticMethod<jboolean>(
        "com/xuke/fittrack/RestTimerBridge",
        "requestNotificationPermission",
        "(Landroid/content/Context;)Z",
        context.object<jobject>()) == JNI_TRUE;
#else
    return false;
#endif
}

bool openBackgroundAlertSettings()
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    return QJniObject::callStaticMethod<jboolean>(
        "com/xuke/fittrack/RestTimerBridge",
        "openNotificationSettings",
        "(Landroid/content/Context;)Z",
        context.object<jobject>()) == JNI_TRUE;
#else
    return false;
#endif
}

} // namespace fittrack::androidtimer
