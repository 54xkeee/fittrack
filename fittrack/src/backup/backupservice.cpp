#include "backup/backupservice.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QUrl>

namespace fittrack {
namespace {

const QStringList &tables()
{
    static const QStringList value{
        QStringLiteral("app_meta"), QStringLiteral("muscle"), QStringLiteral("exercise"),
        QStringLiteral("exercise_muscle"), QStringLiteral("exercise_media"),
        QStringLiteral("exercise_alternative"), QStringLiteral("favorite_exercise"),
        QStringLiteral("training_plan"), QStringLiteral("plan_day"), QStringLiteral("plan_section"),
        QStringLiteral("plan_exercise"), QStringLiteral("gym"), QStringLiteral("equipment_instance"),
        QStringLiteral("workout_session"), QStringLiteral("workout_exercise"),
        QStringLiteral("set_record"), QStringLiteral("append_set_record"),
        QStringLiteral("cardio_record"),
    };
    return value;
}

QJsonValue jsonValue(const QVariant &value)
{
    return value.isNull() ? QJsonValue(QJsonValue::Null) : QJsonValue::fromVariant(value);
}

QString localPath(const QString &input)
{
    const QUrl url(input);
    return url.isLocalFile() ? url.toLocalFile() : input;
}

} // namespace

BackupService::BackupService(const QSqlDatabase &database, QObject *parent)
    : QObject(parent), m_database(database)
{
}

QString BackupService::errorMessage() const { return m_errorMessage; }

bool BackupService::exportDatabase(const QString &filePath)
{
    clearError();
    if (filePath.trimmed().isEmpty()) return fail(QStringLiteral("备份路径不能为空"));
    const QString absolutePath = QFileInfo(localPath(filePath)).absoluteFilePath();
    if (!QDir().mkpath(QFileInfo(absolutePath).absolutePath()))
        return fail(QStringLiteral("无法创建备份目录"));
    QFile::remove(absolutePath);
    QString escaped = absolutePath;
    escaped.replace(QLatin1Char('\''), QStringLiteral("''"));
    QSqlQuery query(m_database);
    if (!query.exec(QStringLiteral("VACUUM INTO '%1'").arg(escaped)))
        return fail(query.lastError().text());
    return QFileInfo(absolutePath).size() > 0;
}

bool BackupService::exportJson(const QString &filePath)
{
    clearError();
    QJsonObject tableData;
    for (const QString &table : tables()) {
        QSqlQuery query(m_database);
        if (!query.exec(QStringLiteral("SELECT * FROM %1").arg(table)))
            return fail(query.lastError().text());
        QJsonArray rows;
        const QSqlRecord record = query.record();
        while (query.next()) {
            QJsonObject row;
            for (int column = 0; column < record.count(); ++column)
                row.insert(record.fieldName(column), jsonValue(query.value(column)));
            rows.append(row);
        }
        tableData.insert(table, rows);
    }
    QJsonObject root{
        {QStringLiteral("format"), QStringLiteral("fittrack-json")},
        {QStringLiteral("version"), 1},
        {QStringLiteral("createdAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
        {QStringLiteral("tables"), tableData},
    };
    QSaveFile file(localPath(filePath));
    if (!file.open(QIODevice::WriteOnly)) return fail(file.errorString());
    if (file.write(QJsonDocument(root).toJson(QJsonDocument::Indented)) < 0)
        return fail(file.errorString());
    if (!file.commit()) return fail(file.errorString());
    return true;
}

bool BackupService::restoreJson(const QString &filePath)
{
    clearError();
    QFile file(localPath(filePath));
    if (!file.open(QIODevice::ReadOnly)) return fail(file.errorString());
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return fail(QStringLiteral("备份文件不是有效JSON"));
    const QJsonObject root = document.object();
    if (root.value(QStringLiteral("format")).toString() != QStringLiteral("fittrack-json")
        || root.value(QStringLiteral("version")).toInt() != 1
        || !root.value(QStringLiteral("tables")).isObject())
        return fail(QStringLiteral("不是受支持的FitTrack备份"));
    const QJsonObject tableData = root.value(QStringLiteral("tables")).toObject();
    for (const QString &table : tables()) {
        if (!tableData.value(table).isArray())
            return fail(QStringLiteral("备份缺少数据表：%1").arg(table));
    }

    if (!m_database.transaction()) return fail(m_database.lastError().text());
    auto rollback = [this](const QString &message) {
        m_database.rollback();
        return fail(message);
    };
    for (auto it = tables().crbegin(); it != tables().crend(); ++it) {
        QSqlQuery clear(m_database);
        if (!clear.exec(QStringLiteral("DELETE FROM %1").arg(*it)))
            return rollback(clear.lastError().text());
    }
    for (const QString &table : tables()) {
        const QJsonArray rows = tableData.value(table).toArray();
        for (const QJsonValue &value : rows) {
            if (!value.isObject()) return rollback(QStringLiteral("备份行格式错误"));
            const QJsonObject row = value.toObject();
            const QStringList columns = row.keys();
            if (columns.isEmpty()) continue;
            QStringList placeholders;
            placeholders.fill(QStringLiteral("?"), columns.size());
            QSqlQuery insert(m_database);
            insert.prepare(QStringLiteral("INSERT INTO %1(%2) VALUES(%3)")
                               .arg(table, columns.join(QLatin1Char(',')),
                                    placeholders.join(QLatin1Char(','))));
            for (const QString &column : columns) {
                const QJsonValue cell = row.value(column);
                insert.addBindValue(cell.isNull() ? QVariant{} : cell.toVariant());
            }
            if (!insert.exec()) return rollback(insert.lastError().text());
        }
    }
    QSqlQuery check(m_database);
    if (!check.exec(QStringLiteral("PRAGMA foreign_key_check")) || check.next())
        return rollback(QStringLiteral("备份包含无效的数据关联"));
    if (!m_database.commit()) return fail(m_database.lastError().text());
    emit restored();
    return true;
}

bool BackupService::fail(const QString &message)
{
    m_errorMessage = message;
    emit errorMessageChanged();
    return false;
}

void BackupService::clearError()
{
    if (m_errorMessage.isEmpty()) return;
    m_errorMessage.clear();
    emit errorMessageChanged();
}

} // namespace fittrack
