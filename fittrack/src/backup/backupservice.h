#pragma once

#include <QObject>
#include <QSqlDatabase>

namespace fittrack {

class BackupService final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit BackupService(const QSqlDatabase &database, QObject *parent = nullptr);

    QString errorMessage() const;
    Q_INVOKABLE bool exportDatabase(const QString &filePath);
    Q_INVOKABLE bool exportJson(const QString &filePath);
    Q_INVOKABLE bool restoreJson(const QString &filePath);

signals:
    void errorMessageChanged();
    void restored();

private:
    bool fail(const QString &message);
    void clearError();

    QSqlDatabase m_database;
    QString m_errorMessage;
};

} // namespace fittrack
