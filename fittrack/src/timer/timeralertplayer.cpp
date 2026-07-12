#include "timer/timeralertplayer.h"

#include <QAudioFormat>
#include <QtMath>

namespace fittrack {

TimerAlertPlayer::TimerAlertPlayer(QObject *parent)
    : QObject(parent)
{
    constexpr int sampleRate = 44100;
    constexpr int durationMs = 240;
    constexpr double frequency = 880.0;
    QByteArray samples;
    samples.resize(sampleRate * durationMs / 1000 * static_cast<int>(sizeof(qint16)));
    auto *output = reinterpret_cast<qint16 *>(samples.data());
    const int sampleCount = samples.size() / static_cast<int>(sizeof(qint16));
    for (int index = 0; index < sampleCount; ++index) {
        const double fade = 1.0 - static_cast<double>(index) / sampleCount;
        output[index] = static_cast<qint16>(9000.0 * fade
            * qSin(2.0 * M_PI * frequency * index / sampleRate));
    }
    m_buffer.setData(samples);
    m_buffer.open(QIODevice::ReadOnly);

    QAudioFormat format;
    format.setSampleRate(sampleRate);
    format.setChannelCount(1);
    format.setSampleFormat(QAudioFormat::Int16);
    m_audioSink = std::make_unique<QAudioSink>(format, this);
    m_audioSink->setVolume(0.7);
}

void TimerAlertPlayer::play()
{
    m_audioSink->stop();
    m_buffer.seek(0);
    m_audioSink->start(&m_buffer);
}

} // namespace fittrack
