# FitTrack 项目协作约定

## 产品目标

- 目标是可上架、可长期使用的 Android 个人健身训练应用，不是只供答辩的界面原型。
- 当前实现是 Windows 桌面开发版；Android APK/AAB、真机后台能力和商店交付尚未完成。
- 核心边界保持不变：不做登录、云同步、饮食、社交、自动重量建议、RIR/RPE 或复杂周期算法。

## 开发方式

- 技术栈：Qt 6 Quick/QML + C++17 + SQLite + CMake/Ninja。
- 中文路径会影响 MSYS2 Qt 的 QML 扫描，统一从 `C:\FitTrackDev\fittrack` 配置和构建。
- 每个大轮开始前先核对目标、已完成能力、缺口、本轮范围和验收标准；完成后必须构建、全量测试、手机尺寸截图验收，再提交 Git。
- 前端遵循 Stitch 的 Graphite & Lime 方向：`#0F0F0F`/`#1A1A1A` 背景、`#C5FF4A` 主色、`#FFB74D` 辅色，优先保证 360–480px 竖屏触控体验。

## 红线

- 系统只记录和可视化训练数据，不在训练页自行建议下一组重量。
- 内置系统计划只读；个人改动必须保存为个人计划或仅作用于本次训练。
- 不把抖音、B站、知乎等未授权截图或视频帧打包进应用。媒体必须可追溯到自制、授权或开放许可来源。
- 不提交构建目录、临时测试日志、数据库或用户数据。

## 验证命令

```powershell
cmake --build C:\FitTrackDev\fittrack\build -j 6
ctest --test-dir C:\FitTrackDev\fittrack\build -j 4 --output-on-failure
```

当前测试基线为 14 项。视觉验收使用 `tst_qmlnavigation` 在 Windows/OpenGL 后端生成 `build/visual/*.png`，并额外检查训练进行中页面。

项目状态和下一阶段缺口以 [`README.md`](README.md) 与 [`../docs/fittrack-development-plan.md`](../docs/fittrack-development-plan.md) 为准。
