# FitTrack 项目协作约定

## 项目定位

- Android 个人健身训练记录与分析应用，技术栈为 Qt 6 Quick/QML、C++17、SQLite 和 CMake/Ninja。
- 以 [`README.md`](README.md) 说明当前能力，以 [`ARCHITECTURE.md`](ARCHITECTURE.md) 说明代码结构；不要在本文件重复维护易过期的版本、测试数量和完成状态。
- 不主动扩展登录、云同步、饮食、社交、自动重量建议、RIR/RPE 或复杂周期算法。

## 修改原则

- 只处理当前任务需要的内容，沿用现有实现和风格；不顺手重构、不增加预留抽象。
- 不确定需求会影响数据、兼容性或用户体验时先说明假设；不影响结果的小细节可直接采用最简单方案。
- 不把未经构建、测试或真机验证的结果描述为已完成。
- 中文工作区可能影响 Qt 的 QML 工具；需要构建时使用 `C:\FitTrackDev\fittrack` 英文路径。

## 必须保持的边界

- 数据库迁移、恢复和备份不得静默丢失或覆盖用户数据；不接受未来版本数据库的降级写入。
- 内置系统计划保持只读；临时调整只作用于本次训练或另存为个人计划。
- 训练页不自动建议下一组重量。
- APK、源码和媒体包只使用自制、公共领域或明确允许再分发的素材，并保留来源与许可证信息。
- 不提交构建目录、临时日志、数据库、用户数据、SDK/NDK/JDK、密钥或签名密码。
- UI 改动复用 `qml/theme/Theme.qml` 和现有组件，并保证基本的移动端触控与无障碍体验。

## 验证

- 按变更范围运行最小但足够的验证，不要求每个小改动都执行全量构建和所有平台测试。
- C++、QML、数据库或构建脚本改动应运行对应的构建、测试或 lint；纯文档和已人工检查的媒体调整无需全量测试。
- 发布 APK/AAB、数据库迁移、备份恢复和签名相关改动仍需执行完整发布校验。
- Windows 常用验证：

```powershell
cmake --build D:\FitTrackBuild\windows-qt6.11.1 -j 6
cmake --build D:\FitTrackBuild\windows-qt6.11.1 --target all_qmllint -j 6
ctest --test-dir D:\FitTrackBuild\windows-qt6.11.1 -j 4 --output-on-failure
```

- Android 构建与发布流程见 [`../docs/fittrack-android-build.md`](../docs/fittrack-android-build.md)。
