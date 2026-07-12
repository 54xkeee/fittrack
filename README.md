# 学生成绩管理系统

Qt 6 Widgets 大作业，使用 Qt Designer `.ui` 文件、qmake、MinGW 和 C++17 实现。界面根据 Stitch 生成的现代校园蓝方案使用 QSS 复刻。

后续开发建议见 [`docs/大作业开发流程与注意事项.md`](docs/大作业开发流程与注意事项.md)。

## 账号

- 管理员：`xmu123` / `123456`
- 学生：`231202501` ~ `231202560`
- 学生密码：`password01` ~ `password60`

## 功能

- 启动时自动加载 `grade.csv`
- 管理员导入、添加、删除、按总分排序、导出
- 学生查看英语、语文、数学、总分、平均分和排名
- 并列总分使用竞赛排名，例如 `1、2、2、4`

## 数据格式

CSV/TXT 使用 UTF-8、无表头、8 列：

```text
学号,姓名,性别,英语,语文,数学,总分,排名
```

程序会重新计算总分、平均分和排名。

## 环境

Qt 已通过 MSYS2 配置：

- Qt 6.9.1 Widgets/Test
- qmake 3.1
- MinGW-w64 GCC

如需重新安装：

```powershell
C:\msys64\usr\bin\pacman.exe -S --needed mingw-w64-x86_64-qt6-base
```

## 测试

```powershell
$env:PATH = "C:\msys64\mingw64\bin;$env:PATH"
New-Item -ItemType Directory -Force build-tests | Out-Null
Push-Location build-tests
qmake6 ..\tests\tests.pro
mingw32-make -j2
.\release\test_core.exe -o test-results.txt,txt
Get-Content test-results.txt
Pop-Location
```

## Release 打包

```powershell
.\scripts\build-release.ps1
```

输出位于 `dist\StudentGradeSystem\`，可直接运行 `StudentGradeSystem.exe`。

Stitch 设计项目：<https://stitch.withgoogle.com/projects/2823835893686043597?pli=1>
