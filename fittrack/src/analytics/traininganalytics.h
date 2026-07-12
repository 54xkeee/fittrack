#pragma once

#include "training/setrecord.h"

#include <optional>

namespace fittrack {

struct HighestWeightPerformance {
    double weightKg = 0.0;
    int bestReps = 0;
    int setCount = 0;
};

class TrainingAnalytics final
{
public:
    static double setVolume(const SetRecord &record, LoadMode mode);
    static double totalVolume(const QVector<SetRecord> &records, LoadMode mode);
    static std::optional<HighestWeightPerformance> highestWeight(
        const QVector<SetRecord> &records);
    static std::optional<double> estimatedOneRepMax(
        const QVector<SetRecord> &records,
        LoadMode mode);

private:
    static double loadMultiplier(const SetRecord &record, LoadMode mode);
};

} // namespace fittrack
