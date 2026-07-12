#include "studentwindow.h"
#include "ui_studentwindow.h"

StudentWindow::StudentWindow(const StudentData &student, QWidget *parent)
    : QMainWindow(parent), ui(new Ui::StudentWindow)
{
    ui->setupUi(this);
    ui->label_id->setText(tr("学号：%1").arg(student.id()));
    ui->label_name->setText(student.name());
    ui->label_sex->setText(tr("性别：%1").arg(student.sex()));
    ui->label_english->setText(QString::number(student.english(), 'f', 1));
    ui->label_chinese->setText(QString::number(student.chinese(), 'f', 1));
    ui->label_math->setText(QString::number(student.math(), 'f', 1));
    ui->label_total->setText(QString::number(student.total(), 'f', 1));
    ui->label_ave->setText(QString::number(student.average(), 'f', 2));
    ui->label_rankValue->setText(QString::number(student.rank()));
    connect(ui->pushButton_return, &QPushButton::clicked, this, &StudentWindow::returnRequested);
}

StudentWindow::~StudentWindow() { delete ui; }

