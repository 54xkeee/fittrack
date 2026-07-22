# FitTrack 平台 UI 验证记录

本文件记录必须由运行环境证明的字体、密度、主题与辅助技术结果；推测值不计为通过。

## Windows 11 / Qt 6.11.1

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 系统 UI 字体 | `Microsoft YaHei UI`，Regular，9 pt | 2026-07-22 在当前构建机读取 `System.Drawing.SystemFonts.MessageBoxFont`。应用未调用 `setFont()` 或打包字体，因此正常 Windows QPA 继承该系统字体。 |
| 应用文字尺寸来源 | `Typography.qml` 语义角色，经 `fontScale` 统一缩放 | `Main.qml` 同时绑定 `Theme.fontScale` 与 `Typography.fontScale`。 |
| 主题 | System；Light/Dark 由系统色彩方案驱动 | `Theme.isDark` 绑定 `Qt.styleHints.colorScheme`。 |
| 构建 | 通过 | `D:\FitTrackBuild\windows-qt6.11.1`，单线程全量构建。 |
| 正常 Windows QPA 启动 | 通过 | 2026-07-22 启动 `fittrack.exe`，6 秒后进程仍存活且标准错误只有 Qt Multimedia/FFmpeg 后端信息，随后由冒烟脚本主动结束。 |
| QML lint | 退出码 0 | 仍有既有 unqualified-access 静态警告，未作为“无警告”记录。 |
| 非视觉自动测试 | 14/14 通过 | CTest 排除独立的 `qmlnavigation` 视觉/交互测试。 |

## Android

Android 继续继承平台系统字体及 `Configuration.fontScale`。以下项目需真机记录后才能勾选：

- [ ] 记录实际解析字体家族、字号与 400/500/600 字重回退。
- [ ] 在 1.0、1.3、1.5、2.0 字体缩放下检查标题、Sheet 和固定操作栏。
- [ ] Light、Dark、System 三种模式切换。
- [ ] TalkBack 焦点顺序、状态播报和 Overlay 退出后焦点恢复。
- [ ] 完成组与完成训练的两级触感强度。

## 已知验证隔离

`tst_qmlnavigation.exe` 在当前 Windows headless 环境中进入测试输出前持续驻留，120 秒超时。它保留为独立视觉/交互验证目标；业务、存储和控制器测试不再被该环境问题阻塞。
