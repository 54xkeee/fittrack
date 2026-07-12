#pragma once

#include <QVector>

namespace fittrack {

enum class LoadMode {
    Standard,
    DumbbellPair,
    Unilateral,
    Bodyweight
};

enum class BodyweightLoadType {
    Bodyweight,
    Added,
    Assisted
};

struct AppendSetRecord {
    double weightKg = 0.0;
    int reps = 0;
    int restSeconds = 0;
    bool completed = false;
};

struct SetRecord {
    double weightKg = 0.0;
    int reps = 0;
    bool completed = false;
    bool bothSides = true;
    QVector<AppendSetRecord> appendSets;
    BodyweightLoadType bodyweightLoadType = BodyweightLoadType::Bodyweight;
};

} // namespace fittrack
