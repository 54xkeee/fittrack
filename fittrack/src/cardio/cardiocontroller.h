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
    Q_PROPERTY(QString pendingSessionId READ pendingSessionId NOTIFY pendingSessionChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit CardioController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList records() const;
    QString pendingSessionId() const;
    QString errorMessage() const;

    Q_INVOKABLE void reload();
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
    void pendingSessionChanged();
    void errorMessageChanged();
    void recordSaved();

private:
    bool insertRecord(const QString &type, int durationMinutes, double incline,
                      double speedKmh, double distanceKm, double machineLevel,
                      int floors, int steps, int averageHeartRate, const QString &notes);
    bool fail(const QString &message);
    void clearError();

    QSqlDatabase m_database;
    QVariantList m_records;
    QString m_pendingSessionId;
    QString m_errorMessage;
};

} // namespace fittrack
