#pragma once

#include <QAudioSink>
#include <QBuffer>
#include <QObject>

#include <memory>

namespace fittrack {

class TimerAlertPlayer final : public QObject
{
    Q_OBJECT

public:
    explicit TimerAlertPlayer(QObject *parent = nullptr);
    void play();

private:
    QBuffer m_buffer;
    std::unique_ptr<QAudioSink> m_audioSink;
};

} // namespace fittrack
