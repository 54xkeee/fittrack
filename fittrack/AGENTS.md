# FitTrack 项目协作约定

## 产品目标

- 目标是供用户本人长期使用、也可把 APK 直接分享给他人侧载安装的 Android 个人健身训练应用，不是只供答辩的界面原型；应用商店上架不属于当前目标。
- 当前实现可构建 Windows 桌面调试版和 Android `arm64-v8a` Debug/Release APK、AAB；当前交付物是通过包级审计的 Debug APK。长期发布密钥、商店签名和上架材料不属于当前验收。
- 当前数据库为 SQLite v7；v5 为动作增加难度、发力要点、常见错误和动作集合字段，v6 增加单一 active 训练约束，v7 增加训练动作间歇快照。个人训练日单段有氧通过 `plan_cardio` 保存，开始训练时复制到 `workout_cardio_target`，训练后只预填实际有氧记录。
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
- 分享产物只能内置自制、公共领域或许可证明确允许再分发的动作媒体；抖音、B站、知乎视频帧、MuscleDB 授权不明图片及其他用途不明素材不得进入 APK、源码或媒体包。
- 当前 58 个系统动作各使用 1 张已审核图片：42 张开放许可/公共领域素材和 16 张 FitTrack 原创 CC0 图。每项必须保留标题、来源、许可证和原始来源 URL；动作详情只显示本地图片与文本署名，不提供教学视频或媒体外链入口。
- 动作文字资料分为 29 个详细动作和 29 个标准动作；不得把只在详细层存在的“发力要点/常见错误”描述为 58 项全覆盖。
- 不提交构建目录、临时测试日志、数据库或用户数据。

## 验证命令

```powershell
cmake --build C:\FitTrackDev\fittrack\build -j 6
cmake --build C:\FitTrackDev\fittrack\build --target all_qmllint -j 6
ctest --test-dir C:\FitTrackDev\fittrack\build -j 4 --output-on-failure
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1
```

当前测试基线为 14 项。视觉验收使用 `tst_qmlnavigation` 在 360×800、420×920、480×1056 生成 `build/visual/*.png`，并额外检查可编辑个人计划、训练日有氧弹层、训练进行中、目标次数弹层、训练完成总结、带真实数据的历史详情和非空分析页面。

Android 当前基线为包名 `com.fittrack.app`、min API 28、target/compile API 35、仅 `arm64-v8a`。Debug APK 必须通过 Android Lint、`aapt` 清单检查、`apksigner` 校验和包内媒体白名单检查；自动化还要覆盖 360×640、1.5 倍字体、360×800、2.0 倍字体、TalkBack 语义、48dp 触控区和真实 `QTouchEvent`。一加 Ace 5 Pro 的后台计时、通知拒绝、SAF、返回键、ColorOS 电池策略、TalkBack、大字体和数字键盘仍需连接真机验收。Release 长期签名、AAB 和商店材料不属于当前验收范围。构建与排障见 [`../docs/fittrack-android-build.md`](../docs/fittrack-android-build.md)。

产品范围和媒体边界以本文件为准；代码状态和功能缺口参考 [`README.md`](README.md) 与 [`../docs/fittrack-development-plan.md`](../docs/fittrack-development-plan.md)。
