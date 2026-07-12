# Student Grade System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and package the approved Qt Widgets student grade management system.

**Architecture:** Three Designer-based windows share a small in-memory repository. Core parsing, ranking, and authentication logic is independent from widgets and covered by Qt Test; QSS reproduces the approved Stitch campus-blue design.

**Tech Stack:** Qt 6.9 Widgets/Test, qmake, MinGW-w64, C++17, CSV/TXT, QSS

## Global Constraints

- Preserve the PDF-required object names and three `.ui` files.
- Use `xmu123 / 123456` for the administrator and `2312025XX / passwordXX` for students.
- Auto-load `grade.csv`; import/export headerless 8-column UTF-8 CSV/TXT.
- Use competition ranking (`1, 2, 2, 4`) and show averages with two decimals.
- Keep the implementation minimal: no database, WebEngine, network service, or speculative features.

---

### Task 1: Toolchain and build skeleton

**Files:**
- Create: `StudentGradeSystem.pro`, `app/app.pro`, `tests/tests.pro`
- Create: `app/main.cpp`, `tests/test_core.cpp`

- [ ] Install `mingw-w64-x86_64-qt6-base` through the existing MSYS2 pacman.
- [ ] Add `C:\msys64\mingw64\bin` to build commands and verify `qmake6`, `mingw32-make`, and `windeployqt6`.
- [ ] Create a qmake `subdirs` project with `tests` ordered before `app`; configure C++17 and Qt Widgets/Test modules.
- [ ] Build an intentionally minimal Qt Test smoke case and confirm it passes.
- [ ] Commit with `build: add Qt project skeleton`.

### Task 2: Student data, sorting, and ranking

**Files:**
- Create: `app/studentdata.h`, `app/studentdata.cpp`
- Modify: `tests/test_core.cpp`

**Interfaces:**
- `StudentData(QString id, QString name, QString sex, double english, double chinese, double math)`
- `double total() const`, `double average() const`, `int rank() const`, `void setRank(int)`
- `void sortAndRank(QVector<StudentData> &students)`

- [ ] Add failing tests for total, two-decimal display source value, descending sort, and ranks `1,2,2,4`.
- [ ] Run the test executable and confirm the new cases fail to link.
- [ ] Implement only the value object and `sortAndRank` needed by those tests.
- [ ] Rebuild and confirm all cases pass.
- [ ] Commit with `feat: add student score and ranking model`.

### Task 3: Repository and file format

**Files:**
- Create: `app/graderepository.h`, `app/graderepository.cpp`
- Modify: `tests/test_core.cpp`

**Interfaces:**
- `bool load(const QString &path, QString *error)` replaces data atomically on success.
- `bool save(const QString &path, QString *error) const` writes eight headerless UTF-8 fields.
- `bool add(StudentData student, QString *error)`, `bool removeAt(int row, QString *error)`.
- `const StudentData *findById(const QString &id) const`, `const QVector<StudentData> &students() const`.

- [ ] Add failing temporary-file tests for the provided 8-column format, malformed rows, score range, duplicate IDs, atomic replacement, add/delete, and save/reload equivalence.
- [ ] Run tests and confirm repository cases fail before implementation.
- [ ] Implement CSV parsing with `QTextStream`, exact 8-field validation, derived total recalculation, and ranking refresh after mutations.
- [ ] Rebuild and confirm all repository cases pass.
- [ ] Copy the supplied 60-row CSV to repository-root `grade.csv` and assert a load count of 60.
- [ ] Commit with `feat: add grade repository and csv persistence`.

### Task 4: Authentication

**Files:**
- Create: `app/authentication.h`, `app/authentication.cpp`
- Modify: `tests/test_core.cpp`

**Interfaces:**
- `bool isAdminCredentials(const QString &account, const QString &password)`.
- `bool isStudentCredentials(const QString &account, const QString &password)` validates exact suffix mapping; repository lookup remains in `MainWindow`.

- [ ] Add failing boundary tests for administrator credentials, students `01` and `60`, wrong suffixes, malformed IDs, and out-of-range accounts.
- [ ] Implement the two pure functions with exact string matching.
- [ ] Rebuild and confirm the complete core suite passes.
- [ ] Commit with `feat: add login credential validation`.

### Task 5: Designer forms and shared style

**Files:**
- Create: `app/mainwindow.ui`, `app/adminwindow.ui`, `app/studentwindow.ui`
- Create: `app/resources.qrc`, `app/styles/app.qss`

- [ ] Build the login form at 370x280 with `lineEdit_account`, password-mode `lineEdit_password`, `pushButton_admin`, `pushButton_student`, and `pushButton_exit`.
- [ ] Build the 860x620 administrator form with read-only, row-selecting nine-column `tableWidget`; the specified input widgets and six action buttons.
- [ ] Build the 420x480 student form with all nine required labels and `pushButton_return`.
- [ ] Add a restrained QSS using `#1890FF`, `#F5F7FA`, white panels, 4px radii, clear focus/hover states, and alternating table rows.
- [ ] Run `qmake6` and build to prove all UI headers and resources compile.
- [ ] Commit with `feat: add Stitch-inspired Qt forms`.

### Task 6: Window behavior and application integration

**Files:**
- Create: `app/mainwindow.h`, `app/mainwindow.cpp`
- Create: `app/adminwindow.h`, `app/adminwindow.cpp`
- Create: `app/studentwindow.h`, `app/studentwindow.cpp`
- Modify: `app/main.cpp`, `app/app.pro`

- [ ] Wire startup loading from `QCoreApplication::applicationDirPath() + "/grade.csv"` and show a recoverable warning on failure.
- [ ] Implement administrator/student login, error messages, window switching, and a single shared `GradeRepository` lifetime.
- [ ] Implement administrator table refresh, import replacement, validated add, confirmed delete, total sort, export, and return.
- [ ] Implement student label refresh with two-decimal average and return.
- [ ] Build Debug and manually verify the PDF login paths plus all buttons.
- [ ] Commit with `feat: implement grade management windows`.

### Task 7: Release verification and packaging

**Files:**
- Create: `README.md`
- Create: `scripts/build-release.ps1`
- Create: `dist/StudentGradeSystem/` (generated, not committed unless requested)

- [ ] Run the full Qt Test executable and record zero failures.
- [ ] Build Release with qmake and MinGW.
- [ ] Copy the EXE and `grade.csv`, run `windeployqt6 --release`, and verify the packaged EXE starts without build-directory DLLs.
- [ ] Visually inspect login, administrator, and student windows for clipping, overlap, Chinese text, and Stitch style consistency.
- [ ] Document credentials, build commands, data format, and packaged executable location in `README.md`.
- [ ] Commit with `docs: add build and usage guide`.
