# FitTrack 项目协作约定

## 产品目标

- 目标是可长期自用并可直接分享 APK 给其他用户安装的 Android 个人健身训练应用，不是只供答辩的界面原型。应用商店上架保留为后续能力，不是当前交付门槛。
- 当前实现可构建 Windows 桌面调试版和 Android `arm64-v8a` Debug/Release APK、AAB；Android 真机验收和长期发布密钥仍未完成。
- 当前数据库为 SQLite v4；个人训练日单段有氧通过 `plan_cardio` 保存，开始训练时复制到 `workout_cardio_target`，训练后只预填实际有氧记录。
- 核心边界保持不变：不做登录、云同步、饮食、社交、自动重量建议、RIR/RPE 或复杂周期算法。

## 开发方式

- 技术栈：Qt 6 Quick/QML + C++17 + SQLite + CMake/Ninja。
- 中文路径会影响 MSYS2 Qt 的 QML 扫描，统一从 `C:\FitTrackDev\fittrack` 配置和构建。
- Android 工具链安装在 `D:\FitTrackToolchains`，统一通过 `scripts/build-android.ps1` 构建，不把本机 SDK、NDK、JDK 或签名材料提交到仓库。
- 每个大轮开始前先核对目标、已完成能力、缺口、本轮范围和验收标准；完成后必须构建、全量测试、手机尺寸截图验收，再提交 Git。
- 前端遵循 Stitch 的 Graphite & Lime 方向，颜色、间距、字号和动效只能引用 `qml/theme/Theme.qml`，优先保证 360–480px 竖屏触控体验。

## 红线

- 系统只记录和可视化训练数据，不在训练页自行建议下一组重量。
- 内置系统计划只读；个人改动必须保存为个人计划或仅作用于本次训练。
- 不把抖音、B站、知乎等未授权截图或视频帧打包进应用。媒体必须可追溯到自制、授权或开放许可来源。
- 不提交构建目录、临时测试日志、数据库或用户数据。

## 验证命令

```powershell
cmake --build C:\FitTrackDev\fittrack\build -j 6
cmake --build C:\FitTrackDev\fittrack\build --target all_qmllint -j 6
ctest --test-dir C:\FitTrackDev\fittrack\build -j 4 --output-on-failure
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 -Configuration Release
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 -Configuration Release -Bundle
```

当前测试基线为 14 项。视觉验收使用 `tst_qmlnavigation` 在 360×800、420×920、480×1056 生成 `build/visual/*.png`，并额外检查可编辑个人计划、训练日有氧弹层、训练进行中、目标次数弹层、训练完成总结、带真实数据的历史详情和非空分析页面。

Android 当前基线为包名 `com.fittrack.app`、min API 28、target/compile API 35、仅 `arm64-v8a`。Debug APK 必须通过 Android Lint、`aapt` 清单检查和 `apksigner` 校验；Release 签名只从四个 `QT_ANDROID_KEYSTORE_*` 环境变量读取，不提交密钥或密码。直接分享前必须冻结包名、使用长期密钥签名，并在一加 Ace 5 Pro 验收后台计时、通知拒绝、SAF、返回键、ColorOS 电池策略和同签名覆盖升级。构建与排障见 [`../docs/fittrack-android-build.md`](../docs/fittrack-android-build.md)。

项目状态和下一阶段缺口以 [`README.md`](README.md) 与 [`../docs/fittrack-development-plan.md`](../docs/fittrack-development-plan.md) 为准。
