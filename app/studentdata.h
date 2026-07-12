#pragma once

#include <QString>
#include <QVector>

class StudentData
{
public:
    StudentData() = default;
    StudentData(QString id, QString name, QString sex,
                double english, double chinese, double math);

    const QString &id() const { return m_id; }
    const QString &name() const { return m_name; }
    const QString &sex() const { return m_sex; }
    double english() const { return m_english; }
    double chinese() const { return m_chinese; }
    double math() const { return m_math; }
    double total() const;
    double average() const;
    int rank() const { return m_rank; }
    void setRank(int rank) { m_rank = rank; }

private:
    QString m_id;
    QString m_name;
    QString m_sex;
    double m_english = 0;
    double m_chinese = 0;
    double m_math = 0;
    int m_rank = 0;
};

void sortAndRank(QVector<StudentData> &students);

