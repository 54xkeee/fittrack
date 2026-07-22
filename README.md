<div align="center">

# 训迹 FitTrack

**面向力量训练的离线健身记录应用**

从训练计划、逐组记录到历史趋势，把每一次训练沉淀成清晰、可回顾的成长轨迹。

[![Release](https://img.shields.io/github/v/release/54xkeee/fittrack?display_name=tag&sort=semver)](https://github.com/54xkeee/fittrack/releases/latest)
![Android](https://img.shields.io/badge/Android-10%2B-3DDC84?logo=android&logoColor=white)
![Qt](https://img.shields.io/badge/Qt-6.11-41CD52?logo=qt&logoColor=white)
![Material 3](https://img.shields.io/badge/Material-3-6750A4?logo=materialdesign&logoColor=white)

[下载最新版 APK](https://github.com/54xkeee/fittrack/releases/latest)

</div>

## 简介 📋

训迹是一款专注于力量训练记录与进步追踪的 Android 应用。它把训练前的计划编排、训练中的逐组记录以及训练后的历史分析连接在同一套流程中，让训练数据不再只是零散数字。

- 使用系统计划、个人计划或自由训练快速开始
- 记录每组重量、次数、完成状态、器械和训练备注
- 通过休息计时与下一动作预告维持训练节奏
- 从日历、历史、容量和趋势中观察长期变化
- 无需注册账号，核心功能离线可用
- 数据保存在本地，并支持备份与恢复

## 功能 ⚡

### 训练计划与准备

- 管理系统计划和个人训练计划
- 根据当天状态添加、替换、删除或调整动作顺序
- 在正式开始前确认本次训练内容，计划变化不会打乱历史记录
- 支持自由训练，不需要预先创建完整计划

### 专业训练记录

- 以动作和组为层级记录重量、次数、力竭状态与完成进度
- 当前动作、当前组和下一动作清晰分层，训练中可以快速找到操作重点
- 自动衔接组间休息计时，并支持后台计时提醒
- 支持临时追加训练组、修改动作参数和补充训练备注
- 意外退出后可恢复未完成训练，减少记录丢失

### 历史与进步分析

- 使用训练日历和历史列表回看每一次训练
- 查看训练时长、组数、总容量等训练摘要
- 通过动作趋势和容量变化观察长期进步
- 独立记录有氧训练，让力量与有氧数据集中管理

### 动作与训练环境

- 内置动作目录，支持搜索、筛选、收藏和详情查看
- 支持创建自定义动作，补充个人训练体系
- 管理健身房、器械和动作参数，适应不同训练环境
- 训练计划、动作记录和历史数据统一存储，避免多处重复维护

### 使用体验

- 基于 Material 3 构建的 Android 界面
- 完整适配浅色与深色主题
- 当前训练、当前组和主要操作拥有明确视觉层级
- 提供底部操作区、弹窗、提示条和状态反馈

## 隐私与数据 🔒

训迹采用本地优先的数据方式：

- 不要求创建账号
- 当前版本不提供云同步或社交功能
- 训练数据存储在设备本地的 SQLite 数据库中
- 可通过应用内备份与恢复功能迁移或保留数据

卸载应用前，建议先导出备份。覆盖安装新版本通常会保留现有本地数据。

## 截图 👀

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/home.png" width="260" alt="训迹首页"><br><b>训练首页</b></td>
    <td align="center"><img src="docs/screenshots/training.png" width="260" alt="记录训练"><br><b>逐组记录</b></td>
    <td align="center"><img src="docs/screenshots/training-dark.png" width="260" alt="深色主题"><br><b>深色主题</b></td>
  </tr>
</table>

## 安装 🚀

1. 打开 [GitHub Releases](https://github.com/54xkeee/fittrack/releases/latest)。
2. 下载 `FitTrack-0.1.0-debug-arm64-v8a.apk`。
3. 在 Android 10 或更高版本的 ARM64 手机上安装。

首次侧载时，Android 可能要求允许当前应用“安装未知应用”。

> GitHub Releases 当前提供开发版本，可能仍存在问题且不会自动更新。准备长期分发时，需要改用固定的 Release 签名密钥。

## 技术栈 🛠️

- Qt 6 Quick / QML
- C++17
- SQLite
- CMake + Ninja
- Material 3
- Android SDK / NDK

## 构建

准备 Qt 6.11、CMake、Ninja、JDK 21，以及 Android SDK 36 和 NDK r27c。在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\fittrack\scripts\build-android.ps1
```

生成的 APK 位于：

```text
fittrack/build-android-arm64-debug/android-build/fittrack.apk
```

更完整的环境配置和发布说明见 [Android 构建文档](docs/fittrack-android-build.md)。

## 项目结构

```text
fittrack/qml/        页面、主题与界面组件
fittrack/src/        训练、计划、历史和数据业务
fittrack/resources/  内置动作、计划与图片资源
fittrack/android/    Android 平台适配
fittrack/tests/      项目测试
docs/                构建、架构与发布文档
```

## 问题与建议 🤔

如果你遇到问题或有功能建议，可以在 [Issues](https://github.com/54xkeee/fittrack/issues) 中提交。请尽量附上 Android 版本、设备型号、复现步骤和相关截图。

## 第三方内容

第三方组件和图片的来源与许可见：

- [第三方说明](docs/fittrack-third-party-notices.md)
- [媒体署名](docs/fittrack-media-credits.md)
