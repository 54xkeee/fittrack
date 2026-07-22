#pragma once

#include <QObject>

namespace fittrack {

class HapticFeedback final : public QObject
{
    Q_OBJECT

public:
    explicit HapticFeedback(QObject *parent = nullptr);

    Q_INVOKABLE void confirm();
    Q_INVOKABLE void strongConfirm();

private:
    void vibrate(int durationMs, int amplitude);
};

} // namespace fittrack
