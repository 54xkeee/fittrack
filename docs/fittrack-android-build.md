# FitTrack Android 构建、发布门禁与设备验收

本文记录 2026-07-14 的 Android 构建基线。FitTrack 当前支持直接侧载 APK，以及为将来商店上传生成 AAB；正式可升级的 APK/AAB 必须由发布者在仓库外创建并长期保管签名密钥。商店图文材料不属于当前开发范围。

## 当前基线

- 应用 ID：`com.xuke.fittrack`
- 应用名：训迹
- 版本：`0.1.0`，默认 versionCode 1
- min/target/compile API：29/36/36
- ABI：`arm64-v8a`、`x86_64`，每个 APK 只包含所选单一 ABI
- Qt：6.11.1
- JDK：21.0.11
- Android SDK / Build Tools：36 / 36.0.0
- Android NDK：27.2.12479018（r27c）
- AGP / Gradle：9.0.0 / 9.3.1

本机工具链默认位于 `D:\FitTrackToolchains`，源码通过英文联接路径 `C:\FitTrackDev\fittrack` 构建。工具链、构建目录、签名配置和 keystore 均不得提交到 Git。

## Debug APK

构建 arm64 调试包：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Abi arm64-v8a -Configuration Debug
```

构建模拟器用 x86_64 调试包：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Abi x86_64 -Configuration Debug
```

默认输出分别为：

```text
C:\FitTrackDev\fittrack\build-android-arm64-debug\android-build\fittrack.apk
C:\FitTrackDev\fittrack\build-android-x86_64-debug\android-build\fittrack.apk
```

可通过 `-SourceDirectory` 和 `-BuildDirectory` 使用独立源码或构建目录。脚本只清理目标构建目录中的 `android-build`，不会清理仓库外的其他目录。

2026-07-14 的无设备验证产物：

| ABI | SHA-256 |
| --- | --- |
| arm64-v8a | `286307D2C74399077567CD94BFCEB1C36443B5E683B6AC28C55E85E882912FB7` |
| x86_64 | `6EEF0CC89B35B8A7615293C6A9F38A49D0E76E31DC4A2B03106CAC5877D7EC6B` |

两者均通过包名、API、精确单 ABI、APK V2 Debug 签名、ZIP 16 KB 和 81/81 ELF LOAD `p_align` 检查。arm64 Android Lint 为 0 error、2 warning：API 29 以上已无效的存储权限声明，以及 API 29–32 会忽略的预测返回属性；二者不阻塞运行。

## Release APK 和 AAB

无签名 Release APK：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Abi arm64-v8a -Configuration Release
```

无签名 Release AAB：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Abi arm64-v8a -Configuration Release -Bundle
```

APK 位于 `build-android-arm64-release\android-build\fittrack.apk`，AAB 位于同一 `android-build\build\outputs\bundle\release` 下。无签名产物只能用于结构检查，不能安装、上传或分发。

2026-07-14 的无签名基准：

| 产物 | SHA-256 |
| --- | --- |
| arm64 Release APK | `F988B72B4A5EA7D90DADFC5EDE59B90D056DD248486DB1690BC3115344C7A87A` |
| arm64 Release AAB | `FEF12127E886A87743C0B1E4337067D2EE5E0933352A6DED740107359F8FCF7E` |

原始产物按设计无法通过签名校验。审计过程只在系统临时目录创建一次性签名副本；APK 和 AAB 经 bundletool 生成的 universal APK 均通过包名/API/ABI、ZIP 16 KB 和 81/81 ELF 对齐检查，临时副本随后删除，原始哈希未改变。

## 正式签名

直接分发 APK 使用 `Direct` 密钥；上传商店的 AAB 使用独立的 `PlayUpload` 密钥。不要混用两种 profile。

首次创建密钥：

```powershell
$env:JAVA_HOME = "D:\FitTrackToolchains\jdk21\jdk-21.0.11+10"
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\new-android-signing-keys.ps1 `
  -OutputDirectory D:\FitTrackSecrets

Copy-Item C:\FitTrackDev\fittrack\config\android-signing.example.ps1 `
  C:\FitTrackDev\fittrack\config\android-signing.local.ps1
```

`android-signing.local.ps1` 只保存仓库外路径，密码在每个 PowerShell 进程中交互输入。至少离线备份两份 keystore；丢失 Direct 密钥后，已安装用户无法继续覆盖升级。

构建已签名 Direct APK：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Configuration Release -Abi arm64-v8a -Sign -SigningProfile Direct
```

构建已签名 PlayUpload AAB：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 `
  -Configuration Release -Abi arm64-v8a -Bundle -Sign -SigningProfile PlayUpload
```

Release 签名完成后，构建脚本会自动调用发布验证器。正式密钥目前尚未由发布者创建，因此当前不存在可安装的正式 Release 交付物。

## 发布验证器

对 APK 或已签名 AAB 运行：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\verify-android-release.ps1 `
  -ArtifactPath <APK或AAB绝对路径> `
  -ExpectedPackageName com.xuke.fittrack `
  -ExpectedMinSdk 29 -ExpectedTargetSdk 36 -ExpectedCompileSdk 36 `
  -ExpectedAbis arm64-v8a
```

验证器检查：

- APK/AAB 签名；AAB 还检查 bundletool 结构并生成 universal APK；
- 应用 ID、min/target/compile API 和精确 ABI；
- APK ZIP 16 KB 对齐；
- 包内每个 `.so` 的 ELF LOAD `p_align >= 16384`。

Android Lint：

```powershell
$env:JAVA_HOME = "D:\FitTrackToolchains\jdk21\jdk-21.0.11+10"
$env:ANDROID_SDK_ROOT = "D:\FitTrackToolchains\AndroidSdk"
Push-Location C:\FitTrackDev\fittrack\build-android-arm64-debug\android-build
.\gradlew.bat lintDebug --no-daemon
Pop-Location
```

## Debug 侧载包

`package-side-load.ps1` 只接收 arm64 Debug APK，并要求最新 Lint 依赖证据：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\package-side-load.ps1 `
  -ApkPath C:\FitTrackDev\fittrack\build-android-arm64-debug\android-build\fittrack.apk
```

输出 `dist\FitTrack-sideload`、ZIP 和 `.sha256`。目录中恰好有一个 Debug APK，并附 26 份许可正文、第三方通知、58 项媒体署名、Qt 6.11.1 的 `qtbase`/`qtdeclarative`/`qtsvg` SBOM、NDK NOTICE 和逐文件 SHA-256。正式分享前必须从已提交并推送的源码重新生成，确保清单中的 Git SHA 对应发布提交。

Debug 证书只适合测试；不同开发机的 Debug 密钥可能导致无法覆盖安装。

## 模拟器与真机边界

2026-07-14 的本轮发布审计没有调用 ADB，也没有连接用户手机。后续仅使用指定模拟器时，所有命令必须显式限定序列号：

```powershell
$adb = "D:\FitTrackToolchains\AndroidSdk\platform-tools\adb.exe"
& $adb -s emulator-5556 install -r <x86_64-debug-apk>
```

真机可用后再完成以下非阻塞验收：

1. 首次安装、Safe Area、深色状态栏、中文字体、系统大字体和数字键盘。
2. 完整训练流程、动作详情、参数恢复默认、添加预览、动作排序和训练冲突弹窗层级。
3. 后台/锁屏倒计时、通知允许与拒绝、ColorOS 电池策略。
4. JSON/SQLite 导出恢复、进程中断恢复、历史数据库迁移与损坏数据库保留。
5. TalkBack 语义、48dp 触控区、返回键层级。
6. 使用相同 Direct 签名的 Release APK 做覆盖升级，并先备份训练数据。

应用不申请网络权限；`WRITE_EXTERNAL_STORAGE` 仅保留到 API 27，而应用最低 API 为 29。动作媒体只打包 58 张可再分发图片，不包含 MuscleDB 图片、旧动作图片目录或自定义字体。
