#include "analytics/traininganalytics.h"

#include <QTest>

using namespace fittrack;

class TrainingAnalyticsTest : public QObject
{
    Q_OBJECT

private slots:
    void standardVolumeIgnoresIncompleteSets();
    void dumbbellPairUsesSingleDumbbellInput();
    void unilateralVolumeAccountsForBothSides();
    void appendSetContributesToVolume();
    void highestWeightIncludesBestRepsAndSetCount();
    void estimatedOneRepMaxUsesBestCompletedSet();
    void bodyweightDoesNotProduceOneRepMax();
    void distinguishesBodyweightLoadTypes();
};

void TrainingAnalyticsTest::standardVolumeIgnoresIncompleteSets()
{
    const QVector<SetRecord> sets{
        {80.0, 8, true, true, {}},
        {80.0, 8, false, true, {}},
    };

    QCOMPARE(TrainingAnalytics::totalVolume(sets, LoadMode::Standard), 640.0);
}

void TrainingAnalyticsTest::dumbbellPairUsesSingleDumbbellInput()
{
    const SetRecord record{30.0, 10, true, true, {}};
    QCOMPARE(TrainingAnalytics::setVolume(record, LoadMode::DumbbellPair), 600.0);
}

void TrainingAnalyticsTest::unilateralVolumeAccountsForBothSides()
{
    SetRecord bothSides{20.0, 12, true, true, {}};
    SetRecord oneSide{20.0, 12, true, false, {}};

    QCOMPARE(TrainingAnalytics::setVolume(bothSides, LoadMode::Unilateral), 480.0);
    QCOMPARE(TrainingAnalytics::setVolume(oneSide, LoadMode::Unilateral), 240.0);
}

void TrainingAnalyticsTest::appendSetContributesToVolume()
{
    SetRecord record{40.0, 10, true, true, {}};
    record.appendSets.append({40.0, 5, 5, true});

    QCOMPARE(TrainingAnalytics::setVolume(record, LoadMode::Standard), 600.0);
}

void TrainingAnalyticsTest::highestWeightIncludesBestRepsAndSetCount()
{
    const QVector<SetRecord> sets{
        {75.0, 10, true, true, {}},
        {80.0, 6, true, true, {}},
        {80.0, 8, true, true, {}},
        {85.0, 3, false, true, {}},
    };

    const auto result = TrainingAnalytics::highestWeight(sets);
    QVERIFY(result.has_value());
    QCOMPARE(result->weightKg, 80.0);
    QCOMPARE(result->bestReps, 8);
    QCOMPARE(result->setCount, 2);
}

void TrainingAnalyticsTest::estimatedOneRepMaxUsesBestCompletedSet()
{
    const QVector<SetRecord> sets{
        {80.0, 6, true, true, {}},
        {75.0, 10, true, true, {}},
        {100.0, 1, false, true, {}},
    };

    const auto result = TrainingAnalytics::estimatedOneRepMax(sets, LoadMode::Standard);
    QVERIFY(result.has_value());
    QCOMPARE(*result, 100.0);
}

void TrainingAnalyticsTest::bodyweightDoesNotProduceOneRepMax()
{
    const QVector<SetRecord> sets{{20.0, 8, true, true, {}}};
    QVERIFY(!TrainingAnalytics::estimatedOneRepMax(sets, LoadMode::Bodyweight).has_value());
}

void TrainingAnalyticsTest::distinguishesBodyweightLoadTypes()
{
    SetRecord bodyweight{20.0, 10, true, true, {}};
    bodyweight.bodyweightLoadType = BodyweightLoadType::Bodyweight;
    QCOMPARE(TrainingAnalytics::setVolume(bodyweight, LoadMode::Bodyweight), 0.0);

    SetRecord added{20.0, 10, true, true, {}};
    added.bodyweightLoadType = BodyweightLoadType::Added;
    QCOMPARE(TrainingAnalytics::setVolume(added, LoadMode::Bodyweight), 200.0);

    SetRecord assisted{35.0, 10, true, true, {}};
    assisted.bodyweightLoadType = BodyweightLoadType::Assisted;
    QCOMPARE(TrainingAnalytics::setVolume(assisted, LoadMode::Bodyweight), 0.0);
    QVERIFY(!TrainingAnalytics::estimatedOneRepMax({added}, LoadMode::Bodyweight).has_value());
}

QTEST_APPLESS_MAIN(TrainingAnalyticsTest)

#include "tst_traininganalytics.moc"
