#include "app/hapticfeedback.h"

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QNativeInterface>
#endif

namespace fittrack {

HapticFeedback::HapticFeedback(QObject *parent)
    : QObject(parent)
{
}

void HapticFeedback::confirm()
{
    vibrate(28, 96);
}

void HapticFeedback::strongConfirm()
{
    vibrate(55, 160);
}

void HapticFeedback::vibrate(int durationMs, int amplitude)
{
#ifdef Q_OS_ANDROID
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return;

    const QJniObject serviceName = QJniObject::fromString(QStringLiteral("vibrator"));
    const QJniObject vibrator = context.callObjectMethod(
        "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;",
        serviceName.object<jstring>());
    if (!vibrator.isValid())
        return;

    const QJniObject effect = QJniObject::callStaticObjectMethod(
        "android/os/VibrationEffect", "createOneShot",
        "(JI)Landroid/os/VibrationEffect;",
        static_cast<jlong>(durationMs), static_cast<jint>(amplitude));
    if (effect.isValid()) {
        vibrator.callMethod<void>(
            "vibrate", "(Landroid/os/VibrationEffect;)V",
            effect.object<jobject>());
    }
#else
    Q_UNUSED(durationMs)
    Q_UNUSED(amplitude)
#endif
}

} // namespace fittrack
