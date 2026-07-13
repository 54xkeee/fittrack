#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>

namespace fittrack {

class CardioController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList records READ records NOTIFY recordsChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY hasMoreChanged)
    Q_PROPERTY(QString pendingSessionId READ pendingSessionId NOTIFY pendingSessionChanged)
    Q_PROPERTY(QVariantMap pendingTarget READ pendingTarget NOTIFY pendingSessionChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit CardioController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList records() const;
    bool hasMore() const;
    QString pendingSessionId() const;
    QVariantMap pendingTarget() const;
    QString errorMessage() const;

    Q_INVOKABLE void ensureLoaded();
    Q_INVOKABLE void reload();
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE QVariantMap overview(int days) const;
    Q_INVOKABLE bool addTreadmill(int durationMinutes, double incline = 9.0,
                                  double speedKmh = 5.0, double distanceKm = -1.0,
                                  int averageHeartRate = 0, const QString &notes = {});
    Q_INVOKABLE bool addStairClimber(int durationMinutes, double machineLevel = -1.0,
                                    int floors = -1, int steps = -1,
                                    int averageHeartRate = 0, const QString &notes = {});
    Q_INVOKABLE bool removeRecord(const QString &recordId);
    Q_INVOKABLE void clearPendingSession();

public slots:
    void setPendingSession(const QString &sessionId);

signals:
    void recordsChanged();
    void hasMoreChanged();
    void pendingSessionChanged();
    void errorMessageChanged();
    void recordSaved();

private:
    bool insertRecord(const QString &type, int durationMinutes, double incline,
                      double speedKmh, double distanceKm, double machineLevel,
                      int floors, int steps, int averageHeartRate, const QString &notes);
    bool fail(const QString &message);
    void clearError();
    void loadPage(bool reset, int limit);

    QSqlDatabase m_database;
    QVariantList m_records;
    bool m_hasMore = false;
    bool m_loaded = false;
    QString m_pendingSessionId;
    QVariantMap m_pendingTarget;
    QString m_errorMessage;
};

} // namespace fittrack
