# FitTrack Android 构建与真机验收

本文记录 2026-07-14 已验证的 Android 构建基线，以及尚需在一加 Ace 5 Pro 上完成的检查。当前交付目标是自用并可把 APK 直接分享给其他用户侧载安装；长期 Release 密钥与同签名覆盖升级属于 R6，AAB、应用商店签名及商店材料不属于当前范围。

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

2026-07-14 15:11 从当前源码构建并通过门禁的产物为：

```text
C:\FitTrackDev\fittrack\build-android-arm64\android-build\build\outputs\apk\debug\android-build-debug.apk
```

- 文件大小：64,480,320 字节；
- SHA-256：`0DA757DC586153004EEB01D9ABFFB5C37B3CF2AC5EA62CC05AE4D3F90CF91315`；
- Android Lint：0 issue；
- 签名：Android Debug 证书，APK Signature Scheme v2 校验通过；
- 包内 ABI：仅 `arm64-v8a`；
- 媒体：58/58 张 shareable JPEG 已嵌入，116 张 MuscleDB 图片、旧图片目录和 Inter 字体均未进入 APK。

旧 `dist\FitTrack` 目录不代表当前提交，不得继续手工复制其中 APK 或 unsigned AAB。正式分享只使用下节脚本从待发布提交重新生成的 `FitTrack-sideload` 目录或 ZIP。

Debug 证书适合直接侧载测试，但不能作为应用商店发布签名。若不同构建机使用不同 Debug 证书，后续包不能覆盖安装，需先卸载旧版。

## 生成 Debug 侧载包

完成 Debug 构建和 Android Lint 后运行：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\package-side-load.ps1
```

脚本不会把 unsigned AAB 混入分发物，并会硬性检查包名、版本、仅 `arm64-v8a`、Android Debug 证书、APK Signature Scheme v2、复制前后 APK SHA-256，以及 Lint 生成的实际 Android 运行时依赖证据。任一工具或证据缺失都会失败，不会降级为未验签包。输出为：

```text
C:\FitTrackDev\dist\FitTrack-sideload\
C:\FitTrackDev\dist\FitTrack-0.1.0-debug-arm64-v8a.zip
C:\FitTrackDev\dist\FitTrack-0.1.0-debug-arm64-v8a.zip.sha256
```

目录内恰好包含 1 个 APK，并附安装说明、26 份实际所需许可正文、第三方通知、媒体逐项署名、Qt 对应源码与重新链接说明、`qtbase`/`qtdeclarative`/`qtsvg` 三份 Qt 6.9.1 SBOM、Android NDK LLVM NOTICE 和 `SHA256SUMS.txt`。当前 `dist/` 被 Git 忽略；提交并推送待发布源码后必须再运行一次脚本，使包内 Git SHA 指向最终提交。

## 构建 Release 包

构建无签名 Release APK：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Configuration Release
```

输出到：

```text
C:\FitTrackDev\fittrack\build-android-arm64-release\android-build\build\outputs\apk\release\android-build-release-unsigned.apk
```

构建无签名 Release AAB：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Configuration Release -Bundle
```

输出到：

```text
C:\FitTrackDev\fittrack\build-android-arm64-release\android-build\build\outputs\bundle\release\android-build-release.aab
```

无签名产物只用于构建和结构检查，不能作为正式分发包。`dist\FitTrack` 中的 `FitTrack-0.1.0-release-unsigned-arm64-v8a.aab` 同样明确是未签名检查产物。

## 使用发布密钥签名

正式 keystore 必须保存在仓库外并至少备份两份。直接分享 APK 后，后续版本必须继续使用同一个包名和同一把密钥，否则用户无法覆盖升级。

脚本从当前进程的四个环境变量读取签名参数，不把密码写入仓库：

```powershell
$env:QT_ANDROID_KEYSTORE_PATH = "D:\FitTrackSecrets\fittrack-release.p12"
$env:QT_ANDROID_KEYSTORE_ALIAS = "fittrack-release"
$env:QT_ANDROID_KEYSTORE_STORE_PASS = Read-Host "Keystore password"
$env:QT_ANDROID_KEYSTORE_KEY_PASS = $env:QT_ANDROID_KEYSTORE_STORE_PASS

powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Configuration Release -Sign
```

如以后需要发布 AAB，将最后一条命令增加 `-Bundle`。脚本会在清理构建目录前检查四个环境变量是否齐全，并显式关闭未选择的签名模式，避免 CMake 缓存沿用旧的签名状态。

当前已用一次性测试密钥验证 Release APK 的 V3 签名链路；测试 keystore 已删除，测试签名 APK 未进入交付目录。当前侧载测试使用 Debug APK；R6 要完成稳定覆盖升级，必须由用户创建并保管长期 Release 密钥，并使用同一包名和密钥验证覆盖安装。

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

当前最终打包权限只有通知、前台服务和 AndroidX 动态广播接收器权限；`WRITE_EXTERNAL_STORAGE` 仅声明到 API 27，而应用最低 API 为 28。应用不执行内置网络请求，最终 APK/AAB 不包含 `INTERNET` 或 `ACCESS_NETWORK_STATE` 权限。动作资料不提供教学视频或媒体外链入口。

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
10. 分别放入可追溯的真实 v1–v7 数据库副本和损坏测试副本：旧库升级后关键记录仍在；损坏库启动后显示 `.corrupt-*` 保留路径，主库及现存 sidecar 字节不变，恢复替换期间强制结束进程后再次启动可以续完。

出现崩溃时收集：

```powershell
& "D:\FitTrackToolchains\AndroidSdk\platform-tools\adb.exe" logcat -c
& "D:\FitTrackToolchains\AndroidSdk\platform-tools\adb.exe" logcat | Select-String -Pattern "fittrack|AndroidRuntime|Qt"
```

## 直接侧载分享前仍需完成

- 在一加 Ace 5 Pro 上完成首次安装、完整训练、后台计时、通知允许/拒绝、备份恢复、返回键、真实 TalkBack、系统大字体和数字键盘验收。
- 使用真实历史数据库和损坏副本完成升级、原文件保留、启动提示及中断续跑验收；桌面合成夹具不能替代这一步。
- 从待发布提交运行 `package-side-load.ps1`，分享其 ZIP 与 `.sha256`，并明确这是 Debug 签名测试版。
- R6 冻结包名，在仓库外创建并备份长期 Release keystore，再用同签名 Release APK 验证覆盖升级。

如以后决定进入应用商店，再补签名 AAB、公开隐私政策 URL、Health Apps 声明、商店截图、Feature Graphic 和商店版本说明；这些不阻塞当前自用与直接分享目标。
