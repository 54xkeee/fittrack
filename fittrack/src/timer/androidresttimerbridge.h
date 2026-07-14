#pragma once

#include <QtGlobal>

namespace fittrack::androidtimer {

bool start(int durationSeconds);
void pause(qint64 remainingMilliseconds);
void resume(qint64 remainingMilliseconds);
void stop();
int backgroundAlertState();
bool requestBackgroundAlertPermission();
bool openBackgroundAlertSettings();

} // namespace fittrack::androidtimer
