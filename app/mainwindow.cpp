#include "mainwindow.h"

#include "adminwindow.h"
#include "authentication.h"
#include "studentwindow.h"
#include "ui_mainwindow.h"

#include <QCoreApplication>
#include <QMessageBox>
#include <QTimer>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent), ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    connect(ui->pushButton_admin, &QPushButton::clicked, this, &MainWindow::loginAdmin);
    connect(ui->pushButton_student, &QPushButton::clicked, this, &MainWindow::loginStudent);
    connect(ui->pushButton_exit, &QPushButton::clicked, qApp, &QApplication::quit);
    connect(ui->lineEdit_password, &QLineEdit::returnPressed, this, &MainWindow::loginStudent);

    QString error;
    const QString path = QCoreApplication::applicationDirPath() + "/grade.csv";
    if (!m_repository.load(path, &error)) {
        QTimer::singleShot(0, this, [this, error] {
            QMessageBox::warning(this, tr("数据加载失败"),
                                 tr("未能自动加载成绩文件。\n%1\n管理员可登录后手动导入。").arg(error));
        });
    }
}

MainWindow::~MainWindow() { delete ui; }

void MainWindow::loginAdmin()
{
    if (!isAdminCredentials(ui->lineEdit_account->text(), ui->lineEdit_password->text())) {
        QMessageBox::critical(this, tr("登录失败"), tr("管理员账号或密码错误。"));
        return;
    }
    auto *window = new AdminWindow(&m_repository);
    window->setAttribute(Qt::WA_DeleteOnClose);
    connect(window, &AdminWindow::returnRequested, this, [this, window] { window->close(); restoreLogin(); });
    connect(window, &QObject::destroyed, this, [this] { if (!isVisible()) restoreLogin(); });
    hide();
    window->show();
}

void MainWindow::loginStudent()
{
    const QString account = ui->lineEdit_account->text();
    if (!isStudentCredentials(account, ui->lineEdit_password->text())) {
        QMessageBox::critical(this, tr("登录失败"), tr("学生账号或密码错误。"));
        return;
    }
    const StudentData *student = m_repository.findById(account);
    if (!student) {
        QMessageBox::warning(this, tr("无成绩数据"), tr("未找到该学生的成绩，请联系管理员导入数据。"));
        return;
    }
    auto *window = new StudentWindow(*student);
    window->setAttribute(Qt::WA_DeleteOnClose);
    connect(window, &StudentWindow::returnRequested, this, [this, window] { window->close(); restoreLogin(); });
    connect(window, &QObject::destroyed, this, [this] { if (!isVisible()) restoreLogin(); });
    hide();
    window->show();
}

void MainWindow::restoreLogin()
{
    ui->lineEdit_password->clear();
    show();
    raise();
    activateWindow();
}

