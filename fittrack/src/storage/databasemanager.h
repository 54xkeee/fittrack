#pragma once

#include <QSqlDatabase>
#include <QString>

namespace fittrack {

class DatabaseManager final
{
public:
    DatabaseManager();
    ~DatabaseManager();

    DatabaseManager(const DatabaseManager &) = delete;
    DatabaseManager &operator=(const DatabaseManager &) = delete;

    bool initialize(const QString &databasePath, QString *errorMessage = nullptr);
    bool recoverCorruptDatabase(const QString &databasePath, QString *backupPath,
                                QString *errorMessage = nullptr);
    bool corruptionDetected() const;
    QSqlDatabase database() const;

private:
    bool createSchema(QString *errorMessage);
    bool execute(const QString &statement, QString *errorMessage);

    QString m_connectionName;
    QString m_databasePath;
    bool m_corruptionDetected = false;
};

} // namespace fittrack
