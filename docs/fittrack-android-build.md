# FitTrack Android 构建与真机验收

本文记录 2026-07-13 已验证的 Android 构建基线，以及尚需在一加 Ace 5 Pro 上完成的检查。正式发布前不得跳过真机与签名步骤。

## 工具链

开发机使用以下本地目录，不提交到 Git：

- Qt Android：`D:\FitTrackToolchains\Qt\6.9.1\android_arm64_v8a`
- Qt Host：`D:\FitTrackToolchains\Qt\6.9.1\mingw_64`
- JDK：`D:\FitTrackToolchains\jdk17\jdk-17.0.19+10`
- Android SDK：`D:\FitTrackToolchains\AndroidSdk`
- NDK：`D:\FitTrackToolchains\AndroidSdk\ndk\27.2.12479018`

源码从纯英文联接路径 `C:\FitTrackDev\fittrack` 构建，避免 Qt QML 工具处理中文路径时失败。

## 构建调试 APK

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1
```

脚本会清理且只清理 `build-android-arm64/android-build`，然后配置和构建 `arm64-v8a` 调试包。输出：

```text
C:\FitTrackDev\fittrack\build-android-arm64\android-build\build\outputs\apk\debug\android-build-debug.apk
```

当前配置：

- 包名：`com.fittrack.app`（发布前待冻结）
- 版本：`0.1.0`，versionCode 1
- min API：28
- target/compile API：35
- ABI：`arm64-v8a`

## 离线质量门禁

先设置环境：

```powershell
$env:JAVA_HOME = "D:\FitTrackToolchains\jdk17\jdk-17.0.19+10"
$env:ANDROID_SDK_ROOT = "D:\FitTrackToolchains\AndroidSdk"
```

运行 Android Lint：

```powershell
Push-Location C:\FitTrackDev\fittrack\build-android-arm64\android-build
.\gradlew.bat lintDebug --no-daemon
Pop-Location
```

检查包名、API、标签和 ABI：

```powershell
$apk = "C:\FitTrackDev\fittrack\build-android-arm64\android-build\build\outputs\apk\debug\android-build-debug.apk"
& "D:\FitTrackToolchains\AndroidSdk\build-tools\35.0.0\aapt.exe" dump badging $apk
& "D:\FitTrackToolchains\AndroidSdk\build-tools\35.0.0\apksigner.bat" verify --verbose --print-certs $apk
Get-FileHash $apk -Algorithm SHA256
```

调试包使用 Android Debug 证书，只用于开发安装，不得上传商店。

## 一加 Ace 5 Pro 真机回归

开启开发者选项和 USB 调试，连接后先确认设备：

```powershell
& "D:\FitTrackToolchains\AndroidSdk\platform-tools\adb.exe" devices -l
```

设备状态为 `device` 后安装：

```powershell
& "D:\FitTrackToolchains\AndroidSdk\platform-tools\adb.exe" install -r $apk
```

必须逐项验证：

1. 首次启动、中文字体、竖屏 Safe Area、底部导航和所有主要页面。
2. 开始 2 分钟倒计时，切后台和锁屏，通知剩余时间继续递减且只在结束时提醒一次。
3. 拒绝通知权限时应用不崩溃；重新允许后完成提示可用。
4. 暂停、继续、重置和提前结束不会留下错误的前台通知。
5. ColorOS 默认电池策略和允许后台活动两种设置下分别记录结果。
6. 通过系统文档选择器导出 JSON/SQLite，再从 JSON 恢复；恢复后动作、计划、历史、分析、有氧和场馆同步刷新。
7. 返回键依次关闭详情、返回分析主页、返回首页，首页再返回退出。
8. 活动训练中强制结束进程，重启后可恢复已完成组且不丢数据。
9. 使用 `adb install -r` 覆盖安装新包，数据库可以继续打开。

出现崩溃时收集：

```powershell
& "D:\FitTrackToolchains\AndroidSdk\platform-tools\adb.exe" logcat -c
& "D:\FitTrackToolchains\AndroidSdk\platform-tools\adb.exe" logcat | Select-String -Pattern "fittrack|AndroidRuntime|Qt"
```

## 发布前仍需完成

- 确认最终唯一包名；包名发布后不可随意更换。
- 在仓库外创建并备份发布 keystore，不提交密码、密钥或签名属性文件。
- 生成并验证 release AAB，以及同签名的可侧载 APK。
- 完成隐私政策、Health Apps 声明、医疗免责声明、第三方许可和媒体来源清单。
- 使用真机生成商店截图与 Feature Graphic，并核对页面内容和版本说明。
