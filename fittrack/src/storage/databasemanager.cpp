#include "storage/databasemanager.h"

#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <QUuid>

#include <utility>

namespace {

constexpr int kCurrentSchemaVersion = 8;

bool isCorruptionError(const QSqlError &error)
{
    bool codeOk = false;
    const int nativeCode = error.nativeErrorCode().toInt(&codeOk);
    if (codeOk) {
        const int primaryCode = nativeCode & 0xff;
        if (primaryCode == 11 || primaryCode == 26)
            return true;
    }
    const QString text = error.text().toLower();
    return text.contains(QStringLiteral("malformed"))
           || text.contains(QStringLiteral("not a database"))
           || text.contains(QStringLiteral("file is encrypted"));
}

} // namespace

namespace fittrack {

DatabaseManager::DatabaseManager()
    : m_connectionName(QStringLiteral("fittrack-%1").arg(
          QUuid::createUuid().toString(QUuid::WithoutBraces)))
{
}

DatabaseManager::~DatabaseManager()
{
    if (!QSqlDatabase::contains(m_connectionName)) {
        return;
    }

    {
        auto db = QSqlDatabase::database(m_connectionName, false);
        db.close();
    }
    QSqlDatabase::removeDatabase(m_connectionName);
}

bool DatabaseManager::initialize(const QString &databasePath, QString *errorMessage)
{
    m_corruptionDetected = false;
    m_databasePath = databasePath == QStringLiteral(":memory:")
        ? databasePath : QFileInfo(databasePath).absoluteFilePath();
    auto db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    db.setDatabaseName(databasePath);
    if (databasePath != QStringLiteral(":memory:")
        && QFileInfo::exists(m_databasePath + QStringLiteral(".recovery-pending"))) {
        m_corruptionDetected = true;
        if (errorMessage)
            *errorMessage = QStringLiteral("检测到上次未完成的数据库恢复");
        return false;
    }
    if (!db.open()) {
        m_corruptionDetected = isCorruptionError(db.lastError());
        if (errorMessage) {
            *errorMessage = db.lastError().text();
        }
        return false;
    }

    if (!execute(QStringLiteral("PRAGMA foreign_keys = ON"), errorMessage)) {
        return false;
    }
    int schemaVersion = 0;
    bool hasSchemaVersion = false;
    QSqlQuery version(db);
    if (version.exec(QStringLiteral(
            "SELECT value FROM app_meta WHERE key='schema_version'"))) {
        if (version.next()) {
            hasSchemaVersion = true;
            bool versionOk = false;
            schemaVersion = version.value(0).toString().toInt(&versionOk);
            if (!versionOk || schemaVersion < 1) {
                if (errorMessage)
                    *errorMessage = QStringLiteral("数据库版本信息无效");
                return false;
            }
            if (schemaVersion > kCurrentSchemaVersion) {
                if (errorMessage) {
                    *errorMessage = QStringLiteral("数据库版本 %1 高于当前应用支持的版本 %2")
                                        .arg(schemaVersion)
                                        .arg(kCurrentSchemaVersion);
                }
                return false;
            }
        }
    } else if (isCorruptionError(version.lastError())) {
        m_corruptionDetected = true;
        if (errorMessage)
            *errorMessage = version.lastError().text();
        return false;
    }
    version.finish();

    QSqlQuery integrity(db);
    if (!integrity.exec(QStringLiteral("PRAGMA quick_check(1)")) || !integrity.next()) {
        m_corruptionDetected = m_corruptionDetected || isCorruptionError(integrity.lastError());
        if (errorMessage)
            *errorMessage = integrity.lastError().text();
        return false;
    }
    const QString integrityResult = integrity.value(0).toString();
    integrity.finish();
    if (integrityResult != QStringLiteral("ok")) {
        m_corruptionDetected = true;
        if (errorMessage) {
            *errorMessage = QStringLiteral("数据库完整性检查失败：%1")
                                .arg(integrityResult);
        }
        return false;
    }

    if (hasSchemaVersion && schemaVersion == kCurrentSchemaVersion) {
        QSqlQuery columns(db);
        if (!columns.exec(QStringLiteral("PRAGMA table_info(cardio_record)"))) {
            m_corruptionDetected = m_corruptionDetected
                || isCorruptionError(columns.lastError());
            if (errorMessage)
                *errorMessage = columns.lastError().text();
            return false;
        }
        while (columns.next()) {
            if (columns.value(1).toString() == QStringLiteral("performed_at")
                && columns.value(3).toBool()) {
                return true;
            }
        }
        columns.finish();
    }
    return createSchema(errorMessage);
}

bool DatabaseManager::recoverCorruptDatabase(
    const QString &databasePath, QString *backupPath, QString *errorMessage)
{
    if (backupPath)
        backupPath->clear();
    const QString targetDatabasePath = QFileInfo(databasePath).absoluteFilePath();
    if (!m_corruptionDetected || databasePath.isEmpty()
        || databasePath == QStringLiteral(":memory:")
        || targetDatabasePath != m_databasePath) {
        if (errorMessage)
            *errorMessage = QStringLiteral("当前数据库不满足安全恢复条件");
        return false;
    }

    auto db = database();
    db.close();
    const QStringList sidecarSuffixes{QString{}, QStringLiteral("-journal"),
                                      QStringLiteral("-wal"), QStringLiteral("-shm")};
    const QString pendingPath = targetDatabasePath
        + QStringLiteral(".recovery-pending");
    const bool resumingPendingRecovery = QFileInfo::exists(pendingPath);
    QString backupDatabasePath;
    QString freshDatabasePath;
    QStringList backedUpSuffixes;

    const auto removeFileSet = [&](const QString &prefix) {
        QStringList failures;
        for (const QString &sidecarSuffix : sidecarSuffixes) {
            const QString path = prefix + sidecarSuffix;
            if (QFileInfo::exists(path) && !QFile::remove(path))
                failures.append(path);
        }
        return failures;
    };
    const auto restoreOriginal = [&] {
        db.close();
        QStringList failures = removeFileSet(targetDatabasePath);
        for (const QString &sidecarSuffix : std::as_const(backedUpSuffixes)) {
            const QString original = targetDatabasePath + sidecarSuffix;
            if (QFileInfo::exists(original))
                continue;
            if (!QFile::copy(backupDatabasePath + sidecarSuffix, original))
                failures.append(original);
        }
        db.setDatabaseName(targetDatabasePath);
        m_corruptionDetected = true;
        return failures;
    };
    const auto verifyCurrentDatabase = [&](const QString &path, bool leaveOpen,
                                           QString *verificationError) {
        db.close();
        db.setDatabaseName(path);
        if (!db.open()) {
            if (verificationError)
                *verificationError = db.lastError().text();
            return false;
        }
        QSqlQuery version(db);
        if (!version.exec(QStringLiteral(
                "SELECT value FROM app_meta WHERE key='schema_version'"))
            || !version.next()
            || version.value(0).toInt() != kCurrentSchemaVersion) {
            if (verificationError) {
                *verificationError = version.lastError().isValid()
                    ? version.lastError().text()
                    : QStringLiteral("恢复数据库版本无效");
            }
            db.close();
            return false;
        }
        version.finish();
        QSqlQuery integrity(db);
        if (!integrity.exec(QStringLiteral("PRAGMA quick_check(1)"))
            || !integrity.next()
            || integrity.value(0).toString() != QStringLiteral("ok")) {
            if (verificationError) {
                *verificationError = integrity.lastError().isValid()
                    ? integrity.lastError().text()
                    : integrity.value(0).toString();
            }
            db.close();
            return false;
        }
        integrity.finish();
        QSqlQuery foreignKeys(db);
        if (!foreignKeys.exec(QStringLiteral("PRAGMA foreign_keys = ON"))) {
            if (verificationError)
                *verificationError = foreignKeys.lastError().text();
            db.close();
            return false;
        }
        if (!leaveOpen)
            db.close();
        return true;
    };
    const auto createFreshDatabase = [&](QString *creationError) {
        db.close();
        db.setDatabaseName(freshDatabasePath);
        if (!db.open()) {
            if (creationError)
                *creationError = db.lastError().text();
            return false;
        }
        if (!execute(QStringLiteral("PRAGMA foreign_keys = ON"), creationError)
            || !createSchema(creationError)) {
            db.close();
            return false;
        }
        db.close();
        return verifyCurrentDatabase(freshDatabasePath, false, creationError);
    };

    if (resumingPendingRecovery) {
        QFile pendingFile(pendingPath);
        if (!pendingFile.open(QIODevice::ReadOnly)) {
            if (errorMessage)
                *errorMessage = QStringLiteral("无法读取数据库恢复标记：%1")
                                    .arg(pendingFile.errorString());
            return false;
        }
        const QList<QByteArray> markerLines = pendingFile.readAll().split('\n');
        pendingFile.close();
        if (markerLines.size() < 2) {
            if (errorMessage)
                *errorMessage = QStringLiteral("数据库恢复标记格式无效");
            return false;
        }
        backupDatabasePath = QFileInfo(
            QString::fromUtf8(markerLines.at(0))).absoluteFilePath();
        freshDatabasePath = QFileInfo(
            QString::fromUtf8(markerLines.at(1))).absoluteFilePath();
        const QFileInfo targetInfo(targetDatabasePath);
        const QFileInfo backupInfo(backupDatabasePath);
        const QFileInfo freshInfo(freshDatabasePath);
        const bool validBackupPath = backupInfo.absolutePath() == targetInfo.absolutePath()
            && backupInfo.fileName().startsWith(
                targetInfo.fileName() + QStringLiteral(".corrupt-"));
        const bool validFreshPath = freshInfo.absolutePath() == targetInfo.absolutePath()
            && freshInfo.fileName().startsWith(
                targetInfo.fileName() + QStringLiteral(".recovery-"))
            && freshInfo.fileName().endsWith(QStringLiteral(".tmp"));
        if (!validBackupPath || !validFreshPath
            || !QFileInfo::exists(backupDatabasePath)) {
            if (errorMessage)
                *errorMessage = QStringLiteral("数据库恢复标记引用的文件无效");
            return false;
        }
        for (const QString &sidecarSuffix : sidecarSuffixes) {
            if (QFileInfo::exists(backupDatabasePath + sidecarSuffix))
                backedUpSuffixes.append(sidecarSuffix);
        }
    } else {
        if (!QFileInfo::exists(targetDatabasePath)) {
            if (errorMessage)
                *errorMessage = QStringLiteral("找不到需要保留的损坏数据库");
            return false;
        }
        const QString stamp = QDateTime::currentDateTimeUtc().toString(
            QStringLiteral("yyyyMMdd-HHmmsszzz"));
        bool backupCollision = false;
        do {
            backupDatabasePath = targetDatabasePath
                + QStringLiteral(".corrupt-%1-%2")
                      .arg(stamp, QUuid::createUuid()
                                      .toString(QUuid::WithoutBraces));
            backupCollision = false;
            for (const QString &sidecarSuffix : sidecarSuffixes) {
                if (QFileInfo::exists(backupDatabasePath + sidecarSuffix)) {
                    backupCollision = true;
                    break;
                }
            }
        } while (backupCollision);

        QStringList createdBackupFiles;
        for (const QString &sidecarSuffix : sidecarSuffixes) {
            const QString source = targetDatabasePath + sidecarSuffix;
            if (!QFileInfo::exists(source))
                continue;
            const QString destination = backupDatabasePath + sidecarSuffix;
            const qint64 sourceSize = QFileInfo(source).size();
            const bool copied = QFile::copy(source, destination);
            if (QFileInfo::exists(destination))
                createdBackupFiles.append(destination);
            if (!copied || QFileInfo(destination).size() != sourceSize) {
                QStringList cleanupFailures;
                for (const QString &createdPath : std::as_const(createdBackupFiles)) {
                    if (QFileInfo::exists(createdPath) && !QFile::remove(createdPath))
                        cleanupFailures.append(createdPath);
                }
                if (!cleanupFailures.isEmpty() && backupPath)
                    *backupPath = backupDatabasePath;
                if (errorMessage) {
                    *errorMessage = QStringLiteral("无法完整备份损坏数据库文件：%1")
                                        .arg(source);
                    if (!cleanupFailures.isEmpty()) {
                        *errorMessage += QStringLiteral("；以下本次备份未能清理：%1")
                                             .arg(cleanupFailures.join(QStringLiteral("、")));
                    }
                }
                return false;
            }
            backedUpSuffixes.append(sidecarSuffix);
        }

        bool freshCollision = false;
        do {
            freshDatabasePath = targetDatabasePath
                + QStringLiteral(".recovery-%1.tmp")
                      .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
            freshCollision = false;
            for (const QString &sidecarSuffix : sidecarSuffixes) {
                if (QFileInfo::exists(freshDatabasePath + sidecarSuffix)) {
                    freshCollision = true;
                    break;
                }
            }
        } while (freshCollision);
    }

    if (backupPath)
        *backupPath = backupDatabasePath;

    QString recoveryError;
    if (resumingPendingRecovery && !QFileInfo::exists(freshDatabasePath)) {
        if (QFileInfo::exists(targetDatabasePath)
            && verifyCurrentDatabase(targetDatabasePath, true, &recoveryError)) {
            if (QFile::remove(pendingPath)) {
                m_corruptionDetected = false;
                return true;
            }
            db.close();
            m_corruptionDetected = true;
            if (errorMessage) {
                *errorMessage = QStringLiteral("恢复已完成，但无法清理恢复标记：%1")
                                    .arg(pendingPath);
            }
            return false;
        }
    }

    if (QFileInfo::exists(freshDatabasePath)
        && !verifyCurrentDatabase(freshDatabasePath, false, &recoveryError)) {
        const QStringList cleanupFailures = removeFileSet(freshDatabasePath);
        if (!cleanupFailures.isEmpty()) {
            if (errorMessage) {
                *errorMessage = QStringLiteral("无法清理无效的恢复数据库：%1")
                                    .arg(cleanupFailures.join(QStringLiteral("、")));
            }
            return false;
        }
    }
    if (!QFileInfo::exists(freshDatabasePath)
        && !createFreshDatabase(&recoveryError)) {
        const QStringList cleanupFailures = removeFileSet(freshDatabasePath);
        db.setDatabaseName(targetDatabasePath);
        m_corruptionDetected = true;
        if (errorMessage) {
            *errorMessage = QStringLiteral("无法创建恢复数据库：%1；原库备份位于：%2")
                                .arg(recoveryError, backupDatabasePath);
            if (!cleanupFailures.isEmpty()) {
                *errorMessage += QStringLiteral("；临时文件未能清理：%1")
                                     .arg(cleanupFailures.join(QStringLiteral("、")));
            }
        }
        return false;
    }

    if (!resumingPendingRecovery) {
        QSaveFile pendingFile(pendingPath);
        const QByteArray markerContents = backupDatabasePath.toUtf8() + '\n'
            + freshDatabasePath.toUtf8() + '\n';
        bool markerSaved = pendingFile.open(QIODevice::WriteOnly);
        if (markerSaved) {
            markerSaved = pendingFile.write(markerContents) == markerContents.size();
            if (markerSaved)
                markerSaved = pendingFile.commit();
            else
                pendingFile.cancelWriting();
        }
        if (!markerSaved) {
            const QString markerError = pendingFile.errorString();
            const QStringList cleanupFailures = removeFileSet(freshDatabasePath);
            db.setDatabaseName(targetDatabasePath);
            if (errorMessage) {
                *errorMessage = QStringLiteral("无法写入数据库恢复标记：%1；原库备份位于：%2")
                                    .arg(markerError, backupDatabasePath);
                if (!cleanupFailures.isEmpty()) {
                    *errorMessage += QStringLiteral("；临时文件未能清理：%1")
                                         .arg(cleanupFailures.join(QStringLiteral("、")));
                }
            }
            return false;
        }
    }

    for (const QString &sidecarSuffix : sidecarSuffixes) {
        const QString original = targetDatabasePath + sidecarSuffix;
        if (QFileInfo::exists(original) && !QFile::remove(original)) {
            const QStringList restoreFailures = restoreOriginal();
            if (errorMessage) {
                *errorMessage = QStringLiteral("无法替换损坏数据库文件：%1；原库备份位于：%2")
                                    .arg(original, backupDatabasePath);
                if (!restoreFailures.isEmpty()) {
                    *errorMessage += QStringLiteral("；回滚失败：%1")
                                         .arg(restoreFailures.join(QStringLiteral("、")));
                }
            }
            return false;
        }
    }

    if (!QFile::rename(freshDatabasePath, targetDatabasePath)) {
        const QStringList restoreFailures = restoreOriginal();
        if (errorMessage) {
            *errorMessage = QStringLiteral("无法启用恢复数据库；原库备份位于：%1")
                                .arg(backupDatabasePath);
            if (!restoreFailures.isEmpty()) {
                *errorMessage += QStringLiteral("；回滚失败：%1")
                                     .arg(restoreFailures.join(QStringLiteral("、")));
            }
        }
        return false;
    }

    if (!verifyCurrentDatabase(targetDatabasePath, true, &recoveryError)) {
        const QStringList restoreFailures = restoreOriginal();
        if (errorMessage) {
            *errorMessage = QStringLiteral("恢复数据库校验失败：%1；原库备份位于：%2")
                                .arg(recoveryError, backupDatabasePath);
            if (!restoreFailures.isEmpty()) {
                *errorMessage += QStringLiteral("；回滚失败：%1")
                                     .arg(restoreFailures.join(QStringLiteral("、")));
            }
        }
        return false;
    }
    if (!QFile::remove(pendingPath)) {
        db.close();
        m_corruptionDetected = true;
        if (errorMessage) {
            *errorMessage = QStringLiteral("恢复已完成，但无法清理恢复标记：%1")
                                .arg(pendingPath);
        }
        return false;
    }

    m_corruptionDetected = false;
    return true;
}

bool DatabaseManager::corruptionDetected() const
{
    return m_corruptionDetected;
}

QSqlDatabase DatabaseManager::database() const
{
    return QSqlDatabase::database(m_connectionName);
}

bool DatabaseManager::execute(const QString &statement, QString *errorMessage)
{
    QSqlQuery query(database());
    if (query.exec(statement)) {
        return true;
    }
    if (errorMessage) {
        *errorMessage = query.lastError().text();
    }
    m_corruptionDetected = m_corruptionDetected || isCorruptionError(query.lastError());
    return false;
}

bool DatabaseManager::createSchema(QString *errorMessage)
{
    const QStringList statements{
        QStringLiteral("CREATE TABLE IF NOT EXISTS app_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS muscle (id TEXT PRIMARY KEY, name_zh TEXT NOT NULL UNIQUE, body_part TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise (id TEXT PRIMARY KEY, name_zh TEXT NOT NULL, name_en TEXT, aliases_json TEXT NOT NULL DEFAULT '[]', body_part TEXT NOT NULL, movement TEXT NOT NULL, equipment_json TEXT NOT NULL DEFAULT '[]', load_mode TEXT NOT NULL, introduction TEXT NOT NULL DEFAULT '', steps_json TEXT NOT NULL DEFAULT '[]', cautions_json TEXT NOT NULL DEFAULT '[]', difficulty TEXT NOT NULL DEFAULT '', technique_points_json TEXT NOT NULL DEFAULT '[]', common_mistakes_json TEXT NOT NULL DEFAULT '[]', collections_json TEXT NOT NULL DEFAULT '[]', recommended_sets INTEGER NOT NULL DEFAULT 0, recommended_reps TEXT NOT NULL DEFAULT '', rest_seconds INTEGER NOT NULL DEFAULT 0, is_system INTEGER NOT NULL DEFAULT 1, is_enabled INTEGER NOT NULL DEFAULT 1, source_json TEXT NOT NULL DEFAULT '[]')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_muscle (exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, muscle_id TEXT NOT NULL REFERENCES muscle(id), role TEXT NOT NULL CHECK(role IN ('primary','secondary')), PRIMARY KEY(exercise_id, muscle_id, role))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_media (id INTEGER PRIMARY KEY AUTOINCREMENT, exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, media_type TEXT NOT NULL, local_path TEXT, external_url TEXT, title TEXT, source TEXT, license TEXT)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS exercise_alternative (exercise_id TEXT NOT NULL REFERENCES exercise(id) ON DELETE CASCADE, alternative_id TEXT NOT NULL REFERENCES exercise(id), PRIMARY KEY(exercise_id, alternative_id))"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS favorite_exercise (exercise_id TEXT PRIMARY KEY REFERENCES exercise(id) ON DELETE CASCADE, created_at TEXT NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS training_plan (id TEXT PRIMARY KEY, name TEXT NOT NULL, source_plan_id TEXT REFERENCES training_plan(id), is_system INTEGER NOT NULL DEFAULT 0, is_read_only INTEGER NOT NULL DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_day (id TEXT PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES training_plan(id) ON DELETE CASCADE, name TEXT NOT NULL, sort_order INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_section (id TEXT PRIMARY KEY, day_id TEXT NOT NULL REFERENCES plan_day(id) ON DELETE CASCADE, name TEXT NOT NULL, sort_order INTEGER NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_exercise (id TEXT PRIMARY KEY, day_id TEXT NOT NULL REFERENCES plan_day(id) ON DELETE CASCADE, section_id TEXT REFERENCES plan_section(id) ON DELETE SET NULL, exercise_id TEXT NOT NULL REFERENCES exercise(id), sort_order INTEGER NOT NULL, default_sets INTEGER NOT NULL, default_reps TEXT NOT NULL, rest_seconds INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS plan_cardio (day_id TEXT PRIMARY KEY REFERENCES plan_day(id) ON DELETE CASCADE, cardio_type TEXT NOT NULL CHECK(cardio_type IN ('TreadmillIncline','StairClimber')), duration_seconds INTEGER NOT NULL CHECK(duration_seconds > 0), incline REAL, speed_kmh REAL, machine_level REAL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS gym (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, is_enabled INTEGER NOT NULL DEFAULT 1)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS equipment_instance (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL REFERENCES gym(id) ON DELETE CASCADE, name TEXT NOT NULL, code TEXT, notes TEXT, is_enabled INTEGER NOT NULL DEFAULT 1)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS workout_session (id TEXT PRIMARY KEY, name TEXT NOT NULL, source_plan_id TEXT REFERENCES training_plan(id), gym_id TEXT REFERENCES gym(id), started_at TEXT NOT NULL, ended_at TEXT, status TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS workout_exercise (id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES workout_session(id) ON DELETE CASCADE, exercise_id TEXT NOT NULL REFERENCES exercise(id), equipment_instance_id TEXT REFERENCES equipment_instance(id), sort_order INTEGER NOT NULL, rest_seconds INTEGER, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS set_record (id TEXT PRIMARY KEY, workout_exercise_id TEXT NOT NULL REFERENCES workout_exercise(id) ON DELETE CASCADE, set_order INTEGER NOT NULL, weight_kg REAL, target_reps INTEGER, actual_reps INTEGER, completed INTEGER NOT NULL DEFAULT 0, to_failure INTEGER NOT NULL DEFAULT 0, both_sides INTEGER NOT NULL DEFAULT 1, bodyweight_load_type TEXT NOT NULL DEFAULT 'Bodyweight', completed_at TEXT, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS append_set_record (id TEXT PRIMARY KEY, parent_set_id TEXT NOT NULL REFERENCES set_record(id) ON DELETE CASCADE, weight_kg REAL, reps INTEGER NOT NULL, rest_seconds INTEGER NOT NULL, to_failure INTEGER NOT NULL DEFAULT 0)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS workout_cardio_target (session_id TEXT PRIMARY KEY REFERENCES workout_session(id) ON DELETE CASCADE, cardio_type TEXT NOT NULL CHECK(cardio_type IN ('TreadmillIncline','StairClimber')), duration_seconds INTEGER NOT NULL CHECK(duration_seconds > 0), incline REAL, speed_kmh REAL, machine_level REAL, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS cardio_record (id TEXT PRIMARY KEY, session_id TEXT REFERENCES workout_session(id) ON DELETE CASCADE, cardio_type TEXT NOT NULL, performed_at TEXT NOT NULL, duration_seconds INTEGER NOT NULL, incline REAL, speed_kmh REAL, distance_km REAL, machine_level REAL, floors INTEGER, steps INTEGER, average_heart_rate INTEGER, notes TEXT NOT NULL DEFAULT '')"),
        QStringLiteral("CREATE TRIGGER IF NOT EXISTS workout_session_single_active_insert "
                       "BEFORE INSERT ON workout_session WHEN NEW.status='active' "
                       "AND EXISTS(SELECT 1 FROM workout_session WHERE status='active') "
                       "BEGIN SELECT RAISE(ABORT, '已有进行中的训练'); END"),
        QStringLiteral("CREATE TRIGGER IF NOT EXISTS workout_session_single_active_update "
                       "BEFORE UPDATE OF status ON workout_session WHEN NEW.status='active' "
                       "AND OLD.status<>'active' AND EXISTS(SELECT 1 FROM workout_session "
                       "WHERE status='active' AND id<>NEW.id) "
                       "BEGIN SELECT RAISE(ABORT, '已有进行中的训练'); END"),
        QStringLiteral("INSERT OR IGNORE INTO app_meta(key, value) VALUES('schema_version', '8')"),
    };

    auto db = database();
    if (!db.transaction()) {
        m_corruptionDetected = m_corruptionDetected || isCorruptionError(db.lastError());
        if (errorMessage) {
            *errorMessage = db.lastError().text();
        }
        return false;
    }

    for (const auto &statement : statements) {
        if (!execute(statement, errorMessage)) {
            db.rollback();
            return false;
        }
    }

    const auto hasColumn = [&db](const QString &table, const QString &column) {
        QSqlQuery columns(db);
        if (!columns.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table))) {
            return false;
        }
        while (columns.next()) {
            if (columns.value(1).toString() == column) return true;
        }
        return false;
    };
    const auto columnIsNotNull = [&db](const QString &table, const QString &column) {
        QSqlQuery columns(db);
        if (!columns.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table)))
            return false;
        while (columns.next()) {
            if (columns.value(1).toString() == column)
                return columns.value(3).toBool();
        }
        return false;
    };
    if (!hasColumn(QStringLiteral("set_record"), QStringLiteral("bodyweight_load_type"))
        && !execute(QStringLiteral(
            "ALTER TABLE set_record ADD COLUMN bodyweight_load_type TEXT NOT NULL DEFAULT 'Bodyweight'"),
            errorMessage)) {
        db.rollback();
        return false;
    }
    const bool hasPerformedAt = hasColumn(
        QStringLiteral("cardio_record"), QStringLiteral("performed_at"));
    if (!hasPerformedAt
        || !columnIsNotNull(QStringLiteral("cardio_record"),
                            QStringLiteral("performed_at"))) {
        const QString performedAtSource = hasPerformedAt
            ? QStringLiteral(
                  "COALESCE(performed_at,(SELECT ended_at FROM workout_session "
                  "WHERE id=cardio_record_legacy_v8.session_id),"
                  "strftime('%Y-%m-%dT%H:%M:%SZ','now'))")
            : QStringLiteral(
                  "COALESCE((SELECT ended_at FROM workout_session "
                  "WHERE id=cardio_record_legacy_v8.session_id),"
                  "strftime('%Y-%m-%dT%H:%M:%SZ','now'))");
        if (!execute(QStringLiteral(
                "ALTER TABLE cardio_record RENAME TO cardio_record_legacy_v8"),
                errorMessage)
            || !execute(QStringLiteral(
                "CREATE TABLE cardio_record (id TEXT PRIMARY KEY, session_id TEXT "
                "REFERENCES workout_session(id) ON DELETE CASCADE, cardio_type TEXT NOT NULL, "
                "performed_at TEXT NOT NULL, duration_seconds INTEGER NOT NULL, incline REAL, "
                "speed_kmh REAL, distance_km REAL, machine_level REAL, floors INTEGER, "
                "steps INTEGER, average_heart_rate INTEGER, notes TEXT NOT NULL DEFAULT '')"),
                errorMessage)
            || !execute(QStringLiteral(
                "INSERT INTO cardio_record(id,session_id,cardio_type,performed_at,"
                "duration_seconds,incline,speed_kmh,distance_km,machine_level,floors,steps,"
                "average_heart_rate,notes) SELECT id,session_id,cardio_type,%1,"
                "duration_seconds,incline,speed_kmh,distance_km,machine_level,floors,steps,"
                "average_heart_rate,notes FROM cardio_record_legacy_v8")
                            .arg(performedAtSource),
                errorMessage)
            || !execute(QStringLiteral("DROP TABLE cardio_record_legacy_v8"),
                        errorMessage)) {
            db.rollback();
            return false;
        }
    }
    if (!hasColumn(QStringLiteral("gym"), QStringLiteral("is_enabled"))
        && !execute(QStringLiteral(
            "ALTER TABLE gym ADD COLUMN is_enabled INTEGER NOT NULL DEFAULT 1"), errorMessage)) {
        db.rollback();
        return false;
    }
    if (!hasColumn(QStringLiteral("equipment_instance"), QStringLiteral("is_enabled"))
        && !execute(QStringLiteral(
            "ALTER TABLE equipment_instance ADD COLUMN is_enabled INTEGER NOT NULL DEFAULT 1"), errorMessage)) {
        db.rollback();
        return false;
    }
    if (!hasColumn(QStringLiteral("workout_exercise"), QStringLiteral("rest_seconds"))) {
        if (!execute(QStringLiteral(
                "ALTER TABLE workout_exercise ADD COLUMN rest_seconds INTEGER"), errorMessage)
            || !execute(QStringLiteral(
                "UPDATE workout_exercise SET rest_seconds=(SELECT rest_seconds FROM exercise "
                "WHERE exercise.id=workout_exercise.exercise_id) WHERE rest_seconds IS NULL"),
                errorMessage)) {
            db.rollback();
            return false;
        }
    }
    const QList<QPair<QString, QString>> exerciseColumns{
        {QStringLiteral("difficulty"), QStringLiteral("TEXT NOT NULL DEFAULT ''")},
        {QStringLiteral("technique_points_json"), QStringLiteral("TEXT NOT NULL DEFAULT '[]'")},
        {QStringLiteral("common_mistakes_json"), QStringLiteral("TEXT NOT NULL DEFAULT '[]'")},
        {QStringLiteral("collections_json"), QStringLiteral("TEXT NOT NULL DEFAULT '[]'")},
    };
    for (const auto &[column, definition] : exerciseColumns) {
        if (!hasColumn(QStringLiteral("exercise"), column)
            && !execute(QStringLiteral("ALTER TABLE exercise ADD COLUMN %1 %2")
                            .arg(column, definition), errorMessage)) {
            db.rollback();
            return false;
        }
    }
    const QStringList indexStatements{
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_exercise_media_exercise ON exercise_media(exercise_id,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_plan_day_plan_order ON plan_day(plan_id,sort_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_plan_section_day_order ON plan_section(day_id,sort_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_plan_exercise_day_order ON plan_exercise(day_id,sort_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_equipment_gym_enabled ON equipment_instance(gym_id,is_enabled,name,code)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_workout_session_status_end ON workout_session(status,ended_at DESC,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_workout_exercise_session_order ON workout_exercise(session_id,sort_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_workout_exercise_previous ON workout_exercise(exercise_id,equipment_instance_id,session_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_set_exercise_order ON set_record(workout_exercise_id,set_order,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_append_parent ON append_set_record(parent_set_id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_cardio_performed ON cardio_record(performed_at DESC,id)"),
        QStringLiteral("CREATE INDEX IF NOT EXISTS idx_cardio_session ON cardio_record(session_id)"),
    };
    for (const QString &statement : indexStatements) {
        if (!execute(statement, errorMessage)) {
            db.rollback();
            return false;
        }
    }
    if (!execute(QStringLiteral(
        "INSERT INTO app_meta(key,value) VALUES('schema_version','8') "
        "ON CONFLICT(key) DO UPDATE SET value='8'"), errorMessage)) {
        db.rollback();
        return false;
    }

    if (!db.commit()) {
        m_corruptionDetected = m_corruptionDetected || isCorruptionError(db.lastError());
        if (errorMessage) {
            *errorMessage = db.lastError().text();
        }
        return false;
    }
    return true;
}

} // namespace fittrack
