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

void start(int durationSeconds)
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    QJniObject::callStaticMethod<void>(
        "com/fittrack/app/RestTimerBridge",
        "start",
        "(Landroid/content/Context;I)V",
        context.object<jobject>(),
        static_cast<jint>(durationSeconds));
#else
    Q_UNUSED(durationSeconds)
#endif
}

void pause(qint64 remainingMilliseconds)
{
#ifdef Q_OS_ANDROID
    const QJniObject context = androidContext();
    QJniObject::callStaticMethod<void>(
        "com/fittrack/app/RestTimerBridge",
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
        "com/fittrack/app/RestTimerBridge",
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
        "com/fittrack/app/RestTimerBridge",
        "stop",
        "(Landroid/content/Context;)V",
        context.object<jobject>());
#endif
}

} // namespace fittrack::androidtimer
