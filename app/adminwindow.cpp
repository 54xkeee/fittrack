#include "adminwindow.h"
#include "ui_adminwindow.h"

#include <QFileDialog>
#include <QHeaderView>
#include <QMessageBox>

AdminWindow::AdminWindow(GradeRepository *repository, QWidget *parent)
    : QMainWindow(parent), ui(new Ui::AdminWindow), m_repository(repository)
{
    ui->setupUi(this);
    connect(ui->pushButton_import, &QPushButton::clicked, this, &AdminWindow::importFile);
    connect(ui->pushButton_export, &QPushButton::clicked, this, &AdminWindow::exportFile);
    connect(ui->pushButton_add, &QPushButton::clicked, this, &AdminWindow::addStudent);
    connect(ui->pushButton_delete, &QPushButton::clicked, this, &AdminWindow::deleteStudent);
    connect(ui->pushButton_sort, &QPushButton::clicked, this, &AdminWindow::sortStudents);
    connect(ui->pushButton_return, &QPushButton::clicked, this, &AdminWindow::returnRequested);
    ui->tableWidget->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    refreshTable();
}

AdminWindow::~AdminWindow() { delete ui; }

void AdminWindow::refreshTable()
{
    const auto &students = m_repository->students();
    ui->tableWidget->setRowCount(students.size());
    for (int row = 0; row < students.size(); ++row) {
        const StudentData &s = students[row];
        const QStringList values{s.id(), s.name(), s.sex(), QString::number(s.english(), 'f', 1),
            QString::number(s.chinese(), 'f', 1), QString::number(s.math(), 'f', 1),
            QString::number(s.total(), 'f', 1), QString::number(s.average(), 'f', 2), QString::number(s.rank())};
        for (int column = 0; column < values.size(); ++column)
            ui->tableWidget->setItem(row, column, new QTableWidgetItem(values[column]));
    }
    ui->label_table->setText(tr("学生成绩列表（%1 人）").arg(students.size()));
}

void AdminWindow::importFile()
{
    const QString path = QFileDialog::getOpenFileName(this, tr("导入成绩"), {}, tr("成绩文件 (*.csv *.txt)"));
    if (path.isEmpty()) return;
    QString error;
    if (!m_repository->load(path, &error)) { QMessageBox::critical(this, tr("导入失败"), error); return; }
    refreshTable();
    QMessageBox::information(this, tr("导入完成"), tr("已导入 %1 条成绩。").arg(m_repository->students().size()));
}

void AdminWindow::exportFile()
{
    const QString path = QFileDialog::getSaveFileName(this, tr("导出成绩"), "grades.csv", tr("CSV 文件 (*.csv);;TXT 文件 (*.txt)"));
    if (path.isEmpty()) return;
    QString error;
    if (!m_repository->save(path, &error)) { QMessageBox::critical(this, tr("导出失败"), error); return; }
    QMessageBox::information(this, tr("导出完成"), tr("成绩已保存。"));
}

void AdminWindow::addStudent()
{
    StudentData student(ui->lineEdit_id->text().trimmed(), ui->lineEdit_name->text().trimmed(),
                        ui->lineEdit_sex->text().trimmed(), ui->doubleSpinBox_english->value(),
                        ui->doubleSpinBox_chinese->value(), ui->doubleSpinBox_math->value());
    QString error;
    if (!m_repository->add(student, &error)) { QMessageBox::warning(this, tr("无法添加"), error); return; }
    clearForm();
    refreshTable();
}

void AdminWindow::deleteStudent()
{
    const int row = ui->tableWidget->currentRow();
    if (row < 0) { QMessageBox::warning(this, tr("未选中"), tr("请先选中要删除的学生。")); return; }
    if (QMessageBox::question(this, tr("确认删除"), tr("确定删除选中学生吗？")) != QMessageBox::Yes) return;
    QString error;
    if (!m_repository->removeAt(row, &error)) { QMessageBox::warning(this, tr("删除失败"), error); return; }
    refreshTable();
}

void AdminWindow::sortStudents() { m_repository->sortByTotal(); refreshTable(); }

void AdminWindow::clearForm()
{
    ui->lineEdit_id->clear(); ui->lineEdit_name->clear(); ui->lineEdit_sex->clear();
    ui->doubleSpinBox_english->setValue(0); ui->doubleSpinBox_chinese->setValue(0); ui->doubleSpinBox_math->setValue(0);
}

