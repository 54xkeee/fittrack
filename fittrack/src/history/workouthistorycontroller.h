#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>
#include <QVariantMap>

namespace fittrack {

class WorkoutHistoryController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY sessionsChanged)
    Q_PROPERTY(QVariantMap selectedSession READ selectedSession NOTIFY selectedSessionChanged)

public:
    explicit WorkoutHistoryController(const QSqlDatabase &database, QObject *parent = nullptr);

    QVariantList sessions() const;
    QVariantMap selectedSession() const;

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool selectSession(const QString &sessionId);

signals:
    void sessionsChanged();
    void selectedSessionChanged();

private:
    QSqlDatabase m_database;
    QVariantList m_sessions;
    QVariantMap m_selectedSession;
};

} // namespace fittrack
