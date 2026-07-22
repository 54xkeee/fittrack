<div align="center">

# 训迹 FitTrack

一款离线优先的 Android 健身记录应用。

[![Release](https://img.shields.io/github/v/release/54xkeee/fittrack?display_name=tag&sort=semver)](https://github.com/54xkeee/fittrack/releases/latest)
![Android](https://img.shields.io/badge/Android-10%2B-3DDC84?logo=android&logoColor=white)
![Qt](https://img.shields.io/badge/Qt-6.11-41CD52?logo=qt&logoColor=white)

[下载最新版 APK](https://github.com/54xkeee/fittrack/releases/latest)

</div>

## 界面

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/home.png" width="260" alt="首页"><br>首页</td>
    <td align="center"><img src="docs/screenshots/training.png" width="260" alt="记录训练"><br>记录训练</td>
    <td align="center"><img src="docs/screenshots/training-dark.png" width="260" alt="深色主题"><br>深色主题</td>
  </tr>
</table>

## 功能

- 训练计划与自由训练
- 逐组记录重量、次数与休息时间
- 训练历史、容量与趋势分析
- 本地备份与恢复
- 浅色、深色主题

## 安装

1. 打开 [Releases](https://github.com/54xkeee/fittrack/releases/latest)。
2. 下载 `FitTrack-0.1.0-debug-arm64-v8a.apk`。
3. 在 Android 10 或更高版本的 ARM64 手机上安装。

首次侧载时，系统可能要求允许“安装未知应用”。覆盖安装会保留本地数据；卸载前建议先在应用内导出备份。

## 技术栈

- Qt 6 Quick / QML
- C++17
- SQLite
- CMake + Ninja
- Material 3

## 构建

```powershell
powershell -ExecutionPolicy Bypass -File .\fittrack\scripts\build-android.ps1
```

APK 输出到 `fittrack/build-android-arm64-debug/android-build/fittrack.apk`。

## 目录

```text
fittrack/qml/        界面与组件
fittrack/src/        业务与数据层
fittrack/resources/  内置数据与图片
fittrack/tests/      自动化测试
docs/                项目文档
```

第三方组件和图片许可见 [第三方说明](docs/fittrack-third-party-notices.md) 与 [媒体署名](docs/fittrack-media-credits.md)。
