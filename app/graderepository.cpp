#include "graderepository.h"

#include <QFile>
#include <QSet>
#include <QTextStream>

namespace {
void setError(QString *target, const QString &message)
{
    if (target)
        *target = message;
}
}

bool GradeRepository::validate(const StudentData &student, QString *error)
{
    if (student.id().trimmed().isEmpty() || student.name().trimmed().isEmpty()) {
        setError(error, QStringLiteral("学号和姓名不能为空"));
        return false;
    }
    if (student.sex() != QStringLiteral("男") && student.sex() != QStringLiteral("女")) {
        setError(error, QStringLiteral("性别必须为男或女"));
        return false;
    }
    if (student.english() < 0 || student.english() > 100
        || student.chinese() < 0 || student.chinese() > 100
        || student.math() < 0 || student.math() > 100) {
        setError(error, QStringLiteral("成绩必须在 0 至 100 之间"));
        return false;
    }
    return true;
}

bool GradeRepository::load(const QString &path, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setError(error, QStringLiteral("无法打开文件：%1").arg(file.errorString()));
        return false;
    }

    QVector<StudentData> loaded;
    QSet<QString> ids;
    QTextStream stream(&file);
    int lineNumber = 0;
    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();
        ++lineNumber;
        if (line.isEmpty())
            continue;
        const QStringList fields = line.split(',');
        if (fields.size() != 8) {
            setError(error, QStringLiteral("第 %1 行必须包含 8 列").arg(lineNumber));
            return false;
        }

        bool englishOk = false;
        bool chineseOk = false;
        bool mathOk = false;
        bool totalOk = false;
        bool rankOk = false;
        const double english = fields[3].trimmed().toDouble(&englishOk);
        const double chinese = fields[4].trimmed().toDouble(&chineseOk);
        const double math = fields[5].trimmed().toDouble(&mathOk);
        fields[6].trimmed().toDouble(&totalOk);
        fields[7].trimmed().toInt(&rankOk);
        if (!englishOk || !chineseOk || !mathOk || !totalOk || !rankOk) {
            setError(error, QStringLiteral("第 %1 行包含无效数字").arg(lineNumber));
            return false;
        }

        StudentData student(fields[0].trimmed(), fields[1].trimmed(), fields[2].trimmed(),
                            english, chinese, math);
        QString validationError;
        if (!validate(student, &validationError)) {
            setError(error, QStringLiteral("第 %1 行：%2").arg(lineNumber).arg(validationError));
            return false;
        }
        if (ids.contains(student.id())) {
            setError(error, QStringLiteral("第 %1 行：学号重复").arg(lineNumber));
            return false;
        }
        ids.insert(student.id());
        loaded.append(student);
    }

    sortAndRank(loaded);
    m_students = std::move(loaded);
    return true;
}

bool GradeRepository::save(const QString &path, QString *error) const
{
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        setError(error, QStringLiteral("无法保存文件：%1").arg(file.errorString()));
        return false;
    }

    QTextStream stream(&file);
    for (const StudentData &student : m_students) {
        stream << student.id() << ',' << student.name() << ',' << student.sex() << ','
               << QString::number(student.english(), 'f', 1) << ','
               << QString::number(student.chinese(), 'f', 1) << ','
               << QString::number(student.math(), 'f', 1) << ','
               << QString::number(student.total(), 'f', 1) << ',' << student.rank() << '\n';
    }
    return true;
}

bool GradeRepository::add(const StudentData &student, QString *error)
{
    if (!validate(student, error))
        return false;
    if (findById(student.id())) {
        setError(error, QStringLiteral("学号已存在"));
        return false;
    }
    m_students.append(student);
    sortAndRank(m_students);
    return true;
}

bool GradeRepository::removeAt(int row, QString *error)
{
    if (row < 0 || row >= m_students.size()) {
        setError(error, QStringLiteral("请先选中要删除的学生"));
        return false;
    }
    m_students.removeAt(row);
    sortAndRank(m_students);
    return true;
}

const StudentData *GradeRepository::findById(const QString &id) const
{
    for (const StudentData &student : m_students) {
        if (student.id() == id)
            return &student;
    }
    return nullptr;
}

void GradeRepository::sortByTotal()
{
    sortAndRank(m_students);
}

