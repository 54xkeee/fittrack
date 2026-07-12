#include "analytics/traininganalytics.h"

#include <algorithm>
#include <cmath>

namespace fittrack {

double TrainingAnalytics::loadMultiplier(const SetRecord &record, LoadMode mode)
{
    switch (mode) {
    case LoadMode::DumbbellPair:
        return 2.0;
    case LoadMode::Unilateral:
        return record.bothSides ? 2.0 : 1.0;
    case LoadMode::Standard:
    case LoadMode::Bodyweight:
        return 1.0;
    }
    return 1.0;
}

double TrainingAnalytics::setVolume(const SetRecord &record, LoadMode mode)
{
    const double multiplier = loadMultiplier(record, mode);
    double volume = 0.0;

    const bool countMainLoad = mode != LoadMode::Bodyweight
        || record.bodyweightLoadType == BodyweightLoadType::Added;
    if (countMainLoad && record.completed && record.weightKg > 0.0 && record.reps > 0) {
        volume += record.weightKg * record.reps * multiplier;
    }

    for (const auto &append : record.appendSets) {
        if (countMainLoad && append.completed && append.weightKg > 0.0 && append.reps > 0) {
            volume += append.weightKg * append.reps * multiplier;
        }
    }

    return volume;
}

double TrainingAnalytics::totalVolume(const QVector<SetRecord> &records, LoadMode mode)
{
    double total = 0.0;
    for (const auto &record : records) {
        total += setVolume(record, mode);
    }
    return total;
}

std::optional<HighestWeightPerformance> TrainingAnalytics::highestWeight(
    const QVector<SetRecord> &records)
{
    std::optional<HighestWeightPerformance> result;

    for (const auto &record : records) {
        if (!record.completed || record.weightKg <= 0.0 || record.reps <= 0) {
            continue;
        }

        if (!result || record.weightKg > result->weightKg) {
            result = HighestWeightPerformance{record.weightKg, record.reps, 1};
        } else if (std::abs(record.weightKg - result->weightKg) < 0.0001) {
            result->bestReps = std::max(result->bestReps, record.reps);
            ++result->setCount;
        }
    }

    return result;
}

std::optional<double> TrainingAnalytics::estimatedOneRepMax(
    const QVector<SetRecord> &records,
    LoadMode mode)
{
    if (mode == LoadMode::Bodyweight) {
        return std::nullopt;
    }

    std::optional<double> best;
    for (const auto &record : records) {
        if (!record.completed || record.weightKg <= 0.0 || record.reps <= 0) {
            continue;
        }

        const double estimate = record.weightKg * (1.0 + record.reps / 30.0);
        if (!best || estimate > *best) {
            best = estimate;
        }
    }
    return best;
}

} // namespace fittrack
