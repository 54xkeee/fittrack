#include "gyms/gymmanagementcontroller.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

namespace fittrack {
namespace {
QString newId() { return QUuid::createUuid().toString(QUuid::WithoutBraces); }
}

GymManagementController::GymManagementController(const QSqlDatabase &database, QObject *parent)
    : QObject(parent), m_database(database)
{
    reload();
}

QVariantList GymManagementController::gyms() const { return m_gyms; }
QVariantList GymManagementController::equipment() const { return m_equipment; }
QString GymManagementController::selectedGymId() const { return m_selectedGymId; }
QString GymManagementController::errorMessage() const { return m_errorMessage; }

void GymManagementController::reload()
{
    QVariantList gyms;
    QSqlQuery query(m_database);
    if (query.exec(QStringLiteral(
            "SELECT g.id,g.name,(SELECT COUNT(*) FROM equipment_instance e "
            "WHERE e.gym_id=g.id AND e.is_enabled=1) FROM gym g WHERE g.is_enabled=1 ORDER BY g.name"))) {
        while (query.next()) {
            gyms.append(QVariantMap{{QStringLiteral("id"), query.value(0)},
                                     {QStringLiteral("name"), query.value(1)},
                                     {QStringLiteral("equipmentCount"), query.value(2)}});
        }
    }
    m_gyms = gyms;
    bool selectedStillExists = false;
    for (const auto &item : m_gyms) {
        if (item.toMap().value(QStringLiteral("id")) == m_selectedGymId) {
            selectedStillExists = true;
            break;
        }
    }
    if (!selectedStillExists) {
        m_selectedGymId = m_gyms.isEmpty()
            ? QString{} : m_gyms.first().toMap().value(QStringLiteral("id")).toString();
    }
    loadEquipment();
    emit dataChanged();
}

void GymManagementController::loadEquipment()
{
    QVariantList result;
    if (!m_selectedGymId.isEmpty()) {
        QSqlQuery query(m_database);
        query.prepare(QStringLiteral(
            "SELECT id,name,COALESCE(code,''),COALESCE(notes,'') FROM equipment_instance "
            "WHERE gym_id=? AND is_enabled=1 ORDER BY name,code"));
        query.addBindValue(m_selectedGymId);
        if (query.exec()) {
            while (query.next()) {
                result.append(QVariantMap{{QStringLiteral("id"), query.value(0)},
                                          {QStringLiteral("name"), query.value(1)},
                                          {QStringLiteral("code"), query.value(2)},
                                          {QStringLiteral("notes"), query.value(3)}});
            }
        }
    }
    m_equipment = result;
}

bool GymManagementController::selectGym(const QString &gymId)
{
    if (!exists(QStringLiteral("gym"), gymId)) return false;
    m_selectedGymId = gymId;
    loadEquipment();
    emit dataChanged();
    return true;
}

bool GymManagementController::createGym(const QString &name)
{
    clearError();
    if (name.trimmed().isEmpty()) return fail(QStringLiteral("健身房名称不能为空"));
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO gym(id,name,is_enabled) VALUES(?,?,1) "
        "ON CONFLICT(name) DO UPDATE SET is_enabled=1"));
    const QString id = newId();
    query.addBindValue(id);
    query.addBindValue(name.trimmed());
    if (!query.exec()) return fail(query.lastError().text());
    QSqlQuery selected(m_database);
    selected.prepare(QStringLiteral("SELECT id FROM gym WHERE name=? AND is_enabled=1"));
    selected.addBindValue(name.trimmed());
    if (!selected.exec() || !selected.next()) return fail(selected.lastError().text());
    m_selectedGymId = selected.value(0).toString();
    reload();
    return true;
}

bool GymManagementController::renameGym(const QString &gymId, const QString &name)
{
    clearError();
    if (name.trimmed().isEmpty()) return fail(QStringLiteral("健身房名称不能为空"));
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("UPDATE gym SET name=? WHERE id=? AND is_enabled=1"));
    query.addBindValue(name.trimmed());
    query.addBindValue(gymId);
    if (!query.exec()) return fail(query.lastError().text());
    reload();
    return query.numRowsAffected() > 0;
}

bool GymManagementController::removeGym(const QString &gymId)
{
    clearError();
    QSqlQuery usage(m_database);
    usage.prepare(QStringLiteral("SELECT COUNT(*) FROM workout_session WHERE gym_id=?"));
    usage.addBindValue(gymId);
    if (!usage.exec() || !usage.next()) return fail(usage.lastError().text());
    QSqlQuery query(m_database);
    if (usage.value(0).toInt() > 0) {
        query.prepare(QStringLiteral("UPDATE gym SET is_enabled=0 WHERE id=?"));
        query.addBindValue(gymId);
        if (!query.exec()) return fail(query.lastError().text());
        QSqlQuery equipment(m_database);
        equipment.prepare(QStringLiteral("UPDATE equipment_instance SET is_enabled=0 WHERE gym_id=?"));
        equipment.addBindValue(gymId);
        if (!equipment.exec()) return fail(equipment.lastError().text());
    } else {
        query.prepare(QStringLiteral("DELETE FROM gym WHERE id=?"));
        query.addBindValue(gymId);
        if (!query.exec()) return fail(query.lastError().text());
    }
    reload();
    return query.numRowsAffected() > 0;
}

bool GymManagementController::createEquipment(const QString &name, const QString &code,
                                               const QString &notes)
{
    clearError();
    if (m_selectedGymId.isEmpty()) return fail(QStringLiteral("请先选择健身房"));
    if (name.trimmed().isEmpty()) return fail(QStringLiteral("器械名称不能为空"));
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "INSERT INTO equipment_instance(id,gym_id,name,code,notes,is_enabled) VALUES(?,?,?,?,?,1)"));
    query.addBindValue(newId());
    query.addBindValue(m_selectedGymId);
    query.addBindValue(name.trimmed());
    query.addBindValue(code.trimmed());
    query.addBindValue(notes.trimmed());
    if (!query.exec()) return fail(query.lastError().text());
    reload();
    return true;
}

bool GymManagementController::updateEquipment(const QString &equipmentId, const QString &name,
                                               const QString &code, const QString &notes)
{
    clearError();
    if (name.trimmed().isEmpty()) return fail(QStringLiteral("器械名称不能为空"));
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral(
        "UPDATE equipment_instance SET name=?,code=?,notes=? WHERE id=? AND is_enabled=1"));
    query.addBindValue(name.trimmed());
    query.addBindValue(code.trimmed());
    query.addBindValue(notes.trimmed());
    query.addBindValue(equipmentId);
    if (!query.exec()) return fail(query.lastError().text());
    reload();
    return query.numRowsAffected() > 0;
}

bool GymManagementController::removeEquipment(const QString &equipmentId)
{
    clearError();
    QSqlQuery usage(m_database);
    usage.prepare(QStringLiteral("SELECT COUNT(*) FROM workout_exercise WHERE equipment_instance_id=?"));
    usage.addBindValue(equipmentId);
    if (!usage.exec() || !usage.next()) return fail(usage.lastError().text());
    QSqlQuery query(m_database);
    query.prepare(usage.value(0).toInt() > 0
        ? QStringLiteral("UPDATE equipment_instance SET is_enabled=0 WHERE id=?")
        : QStringLiteral("DELETE FROM equipment_instance WHERE id=?"));
    query.addBindValue(equipmentId);
    if (!query.exec()) return fail(query.lastError().text());
    reload();
    return query.numRowsAffected() > 0;
}

bool GymManagementController::exists(const QString &table, const QString &id) const
{
    if (table != QStringLiteral("gym")) return false;
    QSqlQuery query(m_database);
    query.prepare(QStringLiteral("SELECT 1 FROM gym WHERE id=? AND is_enabled=1"));
    query.addBindValue(id);
    return query.exec() && query.next();
}

bool GymManagementController::fail(const QString &message)
{
    m_errorMessage = message;
    emit errorMessageChanged();
    return false;
}

void GymManagementController::clearError()
{
    if (m_errorMessage.isEmpty()) return;
    m_errorMessage.clear();
    emit errorMessageChanged();
}

} // namespace fittrack
