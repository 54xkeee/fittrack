#pragma once

#include <QtGlobal>

namespace fittrack::androidtimer {

void start(int durationSeconds);
void pause(qint64 remainingMilliseconds);
void resume(qint64 remainingMilliseconds);
void stop();

} // namespace fittrack::androidtimer
