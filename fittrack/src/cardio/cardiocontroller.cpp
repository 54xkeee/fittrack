#include "cardio/cardiocontroller.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace fittrack {
namespace {

QVariant optionalDouble(double value)
{
    return value < 0.0 ? QVariant{} : QVariant(value);
}

QVariant optionalInt(int value)
{
    return value <= 0 ? QVariant{} : QVariant(value);
}

QString newId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

} // namespace

CardioController::CardioController(const QSqlDatabase &database, QObject *parent)
    : QObject(parent), m_database(database)
{
    reload();
}

QVariantList CardioController::records() const { return m_records; }
QString CardioController::pendingSessionId() const { return m_pendingSessionId; }
QString CardioController::errorMessage() const { return m_errorMessage; }

void CardioController::reload()
{
    QVariantList result;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT c.id,c.cardio_type,c.performed_at,c.duration_seconds,c.incline,c.speed_kmh,"
        "c.distance_km,c.machine_level,c.floors,c.steps,c.average_heart_rate,c.notes,"
        "COALESCE(ws.name,'') FROM cardio_record c "
        "LEFT JOIN workout_session ws ON ws.id=c.session_id ORDER BY c.performed_at DESC,c.rowid DESC"));
    if (query.exec()) {
        while (query.next()) {
            result.append(QVariantMap{
                {QStringLiteral("id"), query.value(0)},
                {QStringLiteral("type"), query.value(1)},
                {QStringLiteral("performedAt"), query.value(2)},
                {QStringLiteral("durationMinutes"), query.value(3).toInt() / 60},
                {QStringLiteral("incline"), query.value(4)},
                {QStringLiteral("speedKmh"), query.value(5)},
                {QStringLiteral("distanceKm"), query.value(6)},
                {QStringLiteral("machineLevel"), query.value(7)},
                {QStringLiteral("floors"), query.value(8)},
                {QStringLiteral("steps"), query.value(9)},
                {QStringLiteral("averageHeartRate"), query.value(10)},
                {QStringLiteral("notes"), query.value(11)},
                {QStringLiteral("sessionName"), query.value(12)},
            });
        }
    }
    m_records = result;
    emit recordsChanged();
}

QVariantMap CardioController::overview(int days) const
{
    QString condition;
    QString cutoff;
    if (days > 0) {
        condition = QStringLiteral(" WHERE performed_at>=?");
        cutoff = QDateTime::currentDateTimeUtc().addDays(-days).toString(Qt::ISODate);
    }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "SELECT COUNT(*),COALESCE(SUM(duration_seconds),0),"
        "SUM(CASE WHEN cardio_type='TreadmillIncline' THEN 1 ELSE 0 END),"
        "SUM(CASE WHEN cardio_type='StairClimber' THEN 1 ELSE 0 END) FROM cardio_record") + condition);
    if (!cutoff.isEmpty()) query.addBindValue(cutoff);
    if (!query.exec() || !query.next()) return {};
    return {
        {QStringLiteral("count"), query.value(0)},
        {QStringLiteral("durationMinutes"), query.value(1).toInt() / 60},
        {QStringLiteral("treadmillCount"), query.value(2)},
        {QStringLiteral("stairCount"), query.value(3)},
    };
}

bool CardioController::addTreadmill(int durationMinutes, double incline, double speedKmh,
                                    double distanceKm, int averageHeartRate, const QString &notes)
{
    return insertRecord(QStringLiteral("TreadmillIncline"), durationMinutes, incline,
                        speedKmh, distanceKm, -1.0, -1, -1, averageHeartRate, notes);
}

bool CardioController::addStairClimber(int durationMinutes, double machineLevel, int floors,
                                      int steps, int averageHeartRate, const QString &notes)
{
    return insertRecord(QStringLiteral("StairClimber"), durationMinutes, -1.0,
                        -1.0, -1.0, machineLevel, floors, steps, averageHeartRate, notes);
}

bool CardioController::insertRecord(const QString &type, int durationMinutes, double incline,
                                    double speedKmh, double distanceKm, double machineLevel,
                                    int floors, int steps, int averageHeartRate, const QString &notes)
{
    clearError();
    if (durationMinutes <= 0) return fail(QStringLiteral("有氧时长必须大于0分钟"));
    if (!m_pendingSessionId.isEmpty()) {
        QSqlQuery session(m_database);
        session.prepare(QStringLiteral("SELECT 1 FROM workout_session WHERE id=?"));
        session.addBindValue(m_pendingSessionId);
        if (!session.exec() || !session.next()) return fail(QStringLiteral("关联的力量训练不存在"));
    }
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO cardio_record(id,session_id,cardio_type,performed_at,duration_seconds,"
        "incline,speed_kmh,distance_km,machine_level,floors,steps,average_heart_rate,notes) "
        "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)"));
    query.addBindValue(newId());
    query.addBindValue(m_pendingSessionId.isEmpty() ? QVariant{} : QVariant(m_pendingSessionId));
    query.addBindValue(type);
    query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    query.addBindValue(durationMinutes * 60);
    query.addBindValue(optionalDouble(incline));
    query.addBindValue(optionalDouble(speedKmh));
    query.addBindValue(optionalDouble(distanceKm));
    query.addBindValue(optionalDouble(machineLevel));
    query.addBindValue(optionalInt(floors));
    query.addBindValue(optionalInt(steps));
    query.addBindValue(optionalInt(averageHeartRate));
    query.addBindValue(notes.trimmed().isNull() ? QStringLiteral("") : notes.trimmed());
    if (!query.exec()) return fail(query.lastError().text());
    m_pendingSessionId.clear();
    emit pendingSessionChanged();
    reload();
    emit recordSaved();
    return true;
}

bool CardioController::removeRecord(const QString &recordId)
{
    clearError();
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("DELETE FROM cardio_record WHERE id=?"));
    query.addBindValue(recordId);
    if (!query.exec()) return fail(query.lastError().text());
    reload();
    return query.numRowsAffected() > 0;
}

void CardioController::setPendingSession(const QString &sessionId)
{
    if (m_pendingSessionId == sessionId) return;
    m_pendingSessionId = sessionId;
    emit pendingSessionChanged();
}

void CardioController::clearPendingSession()
{
    setPendingSession({});
}

bool CardioController::fail(const QString &message)
{
    m_errorMessage = message;
    emit errorMessageChanged();
    return false;
}

void CardioController::clearError()
{
    if (m_errorMessage.isEmpty()) return;
    m_errorMessage.clear();
    emit errorMessageChanged();
}

} // namespace fittrack
