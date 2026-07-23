<div align="center">

# 训迹 FitTrack

**离线优先的力量训练记录应用**

用于编辑训练计划、逐组记录训练，并在历史和分析页面查看结果。

[![Release](https://img.shields.io/github/v/release/54xkeee/fittrack?display_name=tag&sort=semver)](https://github.com/54xkeee/fittrack/releases/latest)
![Android](https://img.shields.io/badge/Android-10%2B-3DDC84?logo=android&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-Desktop-0078D4?logo=windows&logoColor=white)
![Qt](https://img.shields.io/badge/Qt-6.11-41CD52?logo=qt&logoColor=white)
![Material 3](https://img.shields.io/badge/Material-3-6750A4?logo=materialdesign&logoColor=white)

[Android 下载](https://github.com/54xkeee/fittrack/releases/latest) · [Windows 下载](https://github.com/54xkeee/fittrack/releases/latest) · [问题反馈](https://github.com/54xkeee/fittrack/issues)

</div>

## 概览

训迹提供计划编辑、逐组训练记录、动作资料查询、场馆器械管理、历史分析和有氧记录。训练数据保存在本地，可通过备份与恢复迁移。

- 系统计划、个人计划与自由训练
- 重量、次数、力竭、备注、器械与逐组进度记录
- 训练日历、历史详情、容量与动作趋势
- 有氧记录、场馆与器械管理
- 本地 SQLite 存储、备份与恢复；不要求账号

## 项目能力

### 动作资料库

动作资料包含中文名、英文名、别名、肌群、器械、动作步骤、注意事项、发力要点、常见错误、图片和来源信息。动作详情显示媒体署名与许可信息；个人动作可用于计划和训练记录。

### 面向训练业务的关系数据

SQLite Schema v8 保存动作与肌群、图片与替代动作、计划与训练日、场馆与器械、训练会话与动作、正式组与追加组、有氧记录等关系。训练准备内容先保存在草稿中；开始训练时，应用使用事务创建训练会话和本次动作快照。之后编辑计划不会改写已经开始的训练。

### 训练记录

准备页支持增删、替换和排序。训练页提供当前动作和当前组操作、休息计时、备注、追加组与未完成训练恢复。力量训练和有氧记录可在历史与分析页面查询。

### Android 与桌面交付

界面使用 Qt Quick / QML，训练、计划、历史、备份与数据访问逻辑使用 C++。本次 Release 提供 Android APK 和 Windows 桌面包。界面采用 Material 3，支持浅色、深色主题和系统字体缩放。

## 截图

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/home-with-history.png" width="220" alt="有训练记录的首页"><br><b>训练首页</b></td>
    <td align="center"><img src="docs/screenshots/preparation.png" width="220" alt="训练准备"><br><b>训练准备</b></td>
    <td align="center"><img src="docs/screenshots/training.png" width="220" alt="逐组训练记录"><br><b>逐组记录</b></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/library.png" width="220" alt="动作资料库"><br><b>动作资料库</b></td>
    <td align="center"><img src="docs/screenshots/training-dark.png" width="220" alt="深色主题训练记录"><br><b>深色主题</b></td>
  </tr>
</table>

## 下载与安装

前往 [GitHub Releases](https://github.com/54xkeee/fittrack/releases/latest)：

- **Android**：下载 `FitTrack-*-arm64-v8a.apk`，适用于 Android 10+ 的 ARM64 设备。
- **Windows**：下载 `FitTrack-*-windows-x64.zip`，解压后运行 `fittrack.exe`。

APK 为可侧载开发包；首次安装时，Android 可能要求允许当前应用安装未知来源应用。

## 技术栈

`Qt 6 Quick / QML` · `C++17` · `SQLite` · `CMake + Ninja` · `Material 3` · `Android SDK / NDK`

## 本地构建

准备 Qt 6.11、CMake、Ninja、JDK 21，以及 Android SDK 36 与 NDK r27c 后，在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\fittrack\scripts\build-android.ps1
```

更多构建与架构资料见 [docs](docs)。

## 许可与致谢

- [第三方说明](docs/fittrack-third-party-notices.md)
- [动作媒体署名](docs/fittrack-media-credits.md)
