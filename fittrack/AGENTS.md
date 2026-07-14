# FitTrack 项目协作约定

## 产品目标

- 目标是供用户本人长期使用、也可把 APK 直接分享给他人侧载安装的 Android 个人健身训练应用，不是只供答辩的界面原型；当前交付同时包含正式 Direct APK 和 PlayUpload AAB 的可重复构建、签名与校验能力，商店文案和截图物料不在本轮范围。
- 当前实现可构建 Windows 桌面调试版、Android `arm64-v8a` 手机 Debug/Release APK/AAB 和 `x86_64` 模拟器调试包。迁移后的最终产物必须从当前提交重新构建并通过对应门禁；真实长期密钥、Direct 同签名覆盖升级、PlayUpload AAB 和真机结果没有证据前不得描述为已完成。
- 当前数据库为 SQLite v8；v5 为动作增加难度、发力要点、常见错误和动作集合字段，v6 增加单一 active 训练约束，v7 增加训练动作间歇快照，v8 增加常用索引、种子内容摘要和同版本启动快路径。启动必须先拒绝未来版本，再执行完整性检查；损坏恢复必须先保留主库及 sidecar，并通过 pending 标记保证替换中断后可继续，禁止用空库静默覆盖。个人训练日单段有氧通过 `plan_cardio` 保存，开始训练时复制到 `workout_cardio_target`，训练后只预填实际有氧记录。
- 核心边界保持不变：不做登录、云同步、饮食、社交、自动重量建议、RIR/RPE 或复杂周期算法。

## 开发方式

- 技术栈：Qt 6 Quick/QML + C++17 + SQLite + CMake/Ninja。
- 中文路径会影响 MSYS2 Qt 的 QML 扫描，统一从 `C:\FitTrackDev\fittrack` 配置和构建。
- Android 工具链安装在 `D:\FitTrackToolchains`，当前固定 Qt 6.11.1、JDK 21、SDK/Build Tools 36 和 NDK 27.2.12479018；统一通过 `scripts/build-android.ps1` 构建，不把本机 SDK、NDK、JDK 或签名材料提交到仓库。
- 每个大轮开始前先核对目标、已完成能力、缺口、本轮范围和验收标准；完成后必须构建、全量测试、手机尺寸截图验收，再提交 Git。
- 前端遵循 Stitch 的 Graphite & Lime 方向，颜色、间距、字号和动效只能引用 `qml/theme/Theme.qml`，优先保证 360–480px 竖屏触控体验。

## 红线

- 系统只记录和可视化训练数据，不在训练页自行建议下一组重量。
- 内置系统计划只读；个人改动必须保存为个人计划或仅作用于本次训练。
- 分享产物只能内置自制、公共领域或许可证明确允许再分发的动作媒体；抖音、B站、知乎视频帧、MuscleDB 授权不明图片及其他用途不明素材不得进入 APK、源码或媒体包。
- 当前 58 个系统动作各使用 1 张已审核图片：42 张开放许可/公共领域素材和 16 张 FitTrack 原创 CC0 图。每项必须保留标题、来源、许可证和原始来源 URL；动作详情只显示本地图片与文本署名，不提供教学视频或媒体外链入口。
- 动作文字资料分为 29 个详细动作和 29 个标准动作；不得把只在详细层存在的“发力要点/常见错误”描述为 58 项全覆盖。
- 不提交构建目录、临时测试日志、数据库或用户数据。

## 验证命令

```powershell
cmake --build D:\FitTrackBuild\windows-qt6.11.1 -j 6
cmake --build D:\FitTrackBuild\windows-qt6.11.1 --target all_qmllint -j 6
ctest --test-dir D:\FitTrackBuild\windows-qt6.11.1 -j 4 --output-on-failure
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1
$env:JAVA_HOME = "D:\FitTrackToolchains\jdk21\jdk-21.0.11+10"
$env:ANDROID_SDK_ROOT = "D:\FitTrackToolchains\AndroidSdk"
Push-Location C:\FitTrackDev\fittrack\build-android-arm64-debug\android-build
.\gradlew.bat lintDebug --no-daemon
Pop-Location
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\package-side-load.ps1
```

当前测试清单为 15 项。视觉验收使用 `tst_qmlnavigation` 在 360×800、420×920、480×1056 生成构建目录下的 `visual/*.png`，并额外检查 360×800 数据库恢复提示、1.0/1.3/1.5/2.0 四档字体、字符图标门禁、长标题完整换行、计划/训练动作预览 48dp 触控区、可见键盘焦点、可编辑个人计划、训练日有氧弹层、训练进行中、训练完成总结、带真实数据的历史详情和非空分析页面。Windows 固定 Qt 6.11.1/字体/离屏软件渲染环境会把 5 个静态关键状态与 `tests/visual/baselines/windows-qt6.11.1-offscreen-software-material-zh_CN-dpr1/` 比较；普通测试不得自动覆盖基准，界面有意变更时必须人工确认新图后再更新。2026-07-14 最新干净构建已通过 15/15，随后聚焦 `qmlnavigation` 再次通过。

Android 当前基线为应用名“训迹”、包名 `com.xuke.fittrack`、min API 29、target/compile API 36；手机包为 `arm64-v8a`，模拟器包为 `x86_64`，均保持单 ABI。Manifest 使用 Qt 默认 `org.qtproject.qt.android.bindings.QtActivity`，不得重新引入未经验证的自定义 Insets Activity。Debug APK 必须通过 Android Lint、`aapt` 清单检查、`apksigner` 校验和包内媒体白名单检查；正式 APK/AAB 还必须通过 `verify-android-release.ps1` 的元数据、签名、ZIP 对齐和 ELF LOAD 段检查。侧载包由 `package-side-load.ps1` 生成，且只有一个 APK，并附完整许可正文、Qt SBOM、NDK NOTICE、媒体署名和 SHA-256 清单。自动化还要覆盖 360×640、1.5 倍字体、360×800、2.0 倍字体、TalkBack 语义、48dp 触控区和真实 `QTouchEvent`。一加 Ace 5 Pro 的后台计时、通知拒绝、SAF、返回键、ColorOS 电池策略、TalkBack、大字体、数字键盘和同签名覆盖升级仍需真机验收；16 KB 与正式签名只能按对应最终产物的校验结果记录。构建与排障见 [`../docs/fittrack-android-build.md`](../docs/fittrack-android-build.md)。

产品范围和媒体边界以本文件为准；代码状态和功能缺口参考 [`README.md`](README.md) 与 [`../docs/fittrack-development-plan.md`](../docs/fittrack-development-plan.md)。
