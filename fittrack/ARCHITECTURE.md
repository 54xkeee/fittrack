# FitTrack 当前架构

本文描述 2026-07-13 已在代码中存在的桌面与 Android 共用实现，不把尚未完成的真机和正式分发验收写成已完成事实。

## 运行结构

```text
QML 页面与组件
        ↓ context properties / signals
C++ Controller 与 Model
        ↓ QSqlDatabase
SQLite v3
```

`src/app/main.cpp` 负责初始化数据库、导入系统动作和计划种子，并把各控制器注入 QML。当前控制器直接使用同一个 SQLite 连接，没有额外 Repository 抽象；在现阶段这能保持实现简单。

主要模块：

- `training/`：活动训练快照、正式组、短休追加组、未完成训练恢复。
- `plans/`：系统计划和个人计划管理，包括训练日、动作分组、动作替换和排序。
- `exercises/`：动作查询、组合筛选、收藏和自定义动作。
- `analytics/`：容量、最高重量、e1RM、肌群和有氧汇总。
- `history/`：已完成力量训练详情、已完成组修正和整次训练删除。
- `cardio/`：跑步机爬坡、爬楼机和有氧历史。
- `gyms/`：健身房和具体器械实例；被历史引用时归档。
- `timer/`：绝对截止时间倒计时、桌面提示音，以及 Android 前台服务和完成通知桥接。
- `backup/`：JSON 事务恢复、SQLite 快照导出和 Android `content://` 文档 URI 访问。
- `storage/`：数据库初始化、结构升级和种子导入。

## 关键数据流

### 力量训练

```text
系统/个人计划或自由训练
  → 创建 WorkoutSession 快照
  → 调整动作、器械和顺序
  → 完成 SetRecord 并立即写库
  → 可选 AppendSetRecord
  → 完成训练
  → 展示训练完成总结
  → 完成，或可选附加 CardioRecord
  → 历史与分析读取已完成记录
```

训练重量由用户填写。系统只计算和展示数据，不输出下一组或下一次训练的重量建议。

### 系统数据与用户数据

- `resources/data/exercises-*.json` 和 `tan-three-day-split.json` 是版本化系统种子。
- 系统动作和系统计划只读，可恢复默认。
- 用户动作、个人计划、历史训练、有氧和场馆器械保存在 SQLite，不因恢复系统种子而删除。

### 备份恢复

- JSON 导出包含受支持业务表的完整数据；恢复在单个事务中替换本地数据并执行外键检查。
- SQLite 导出通过 `VACUUM INTO` 生成一致快照。
- 本地路径使用 `QSaveFile` 原子写入；Android `content://` URI 通过 Qt 文件接口直接读写。SQLite 导出先生成临时一致快照，再流式复制到文档 URI。
- JSON 恢复拒绝超过 64MB 的输入，恢复成功后会清空旧的活动训练内存状态，并重新加载动作、计划、历史、分析、有氧和场馆数据。

### Android 计时与生命周期

- QML/C++ 计时器仍负责前台显示和状态机；每次开始、暂停、继续、重置或提前结束都会通过 JNI 同步 `RestTimerService`。
- Android 服务使用单调时钟保存截止时间，并以前台通知显示倒计时；自然结束时发送一次系统提示音通知，提前结束不会误报完成。
- Android 13 及以上首次开始倒计时时请求通知权限。服务不使用精确闹钟，也不申请传感器或健康数据权限。
- 系统返回键先关闭历史详情或分析子页，再返回首页；只有首页再次返回才交给系统退出。

### Android 打包

- `android/` 提供 Manifest、Java 服务、Adaptive Icon、主题图标、启动页和备份排除规则。
- CMake 在 Android 上默认关闭测试和 Qt Multimedia，只部署 `arm64-v8a` 所需库；桌面端继续使用 Qt Multimedia 播放程序生成的提示音。
- `scripts/build-android.ps1` 将 Debug 与 Release 构建目录分离，可生成 APK 或 AAB；签名时只从进程环境读取 keystore 路径、别名和密码，并显式重置未选择的签名模式，避免复用旧 CMake 缓存。
- 当前配置为包名 `com.fittrack.app`、版本 `0.1.0`/1、min API 28、target/compile API 35。最终包不含 `INTERNET` 或 `ACCESS_NETWORK_STATE` 权限。直接分享前必须冻结包名并改用长期发布签名。

## SQLite v3

数据库表按领域分组：

- 系统：`app_meta`。
- 动作：`muscle`、`exercise`、`exercise_muscle`、`exercise_media`、`exercise_alternative`、`favorite_exercise`。
- 计划：`training_plan`、`plan_day`、`plan_section`、`plan_exercise`。
- 场馆：`gym`、`equipment_instance`。
- 力量训练：`workout_session`、`workout_exercise`、`set_record`、`append_set_record`。
- 有氧：`cardio_record`。

外键在连接初始化时开启。`gym` 和 `equipment_instance` 通过 `is_enabled` 归档；`cardio_record.performed_at` 保存有氧发生时间。

当前升级逻辑采用“建表 + 检查缺失列 + 写入 schema 版本 3”的幂等方式。它适合尚未公开发布的开发数据库；首次公开版本冻结后，必须改为逐版本、可测试的迁移链。

## QML 导航

一级导航为首页、计划、训练、动作、分析。分析页内部包含趋势、历史、有氧和管理四个页签。训练完成后会保留会话编号并打开训练总结，用户明确选择后返回首页或继续附加有氧；系统不会强制进入有氧表单。

Graphite & Lime 视觉令牌集中在 `qml/theme/Theme.qml`，页面通过 `AppPage`、`AppButton`、`NumberField`、`ConfirmDialog`、`InlineFeedback`、`TrendChart`、`RestTimerBar` 等组件复用安全区、触控尺寸、颜色、间距和状态反馈。首页、训练、计划、动作库、趋势、历史、有氧和管理均已纳入移动单列体系。可操作控件使用至少 3:1 的边界对比度，纯信息卡片使用独立的弱轮廓令牌；趋势图同时提供触摸、键盘和辅助技术可读摘要。

`resources/fonts/InterVariable.ttf` 以 SIL OFL 许可内置。启动时通过 `QFontDatabase` 注册，英文、数字和单位使用 Inter，中文由系统字体回退，避免 Windows 离屏渲染选择到符号字体。

## 验证基线

```powershell
cmake --build C:\FitTrackDev\fittrack\build -j 6
ctest --test-dir C:\FitTrackDev\fittrack\build -j 4 --output-on-failure
```

当前 14 项测试覆盖计算、数据库、种子导入、动作、计划、训练、历史、分析、有氧、场馆、备份、倒计时和 QML 导航。计划测试覆盖动作替换时保留参数、分组增删改和跨训练日校验；QML 测试在 360×800、420×920、480×1056 三档生成主页面、可编辑计划、训练进行中、训练完成总结、带真实数据的历史详情与非空分析截图。

Android `arm64-v8a` Debug APK 与无签名 Release APK/AAB 已完成构建；Debug APK 通过零问题 Android Lint、API/ABI/包名/权限检查和 V2 调试签名校验，AAB 通过 bundletool 结构校验。一次性测试密钥验证了 Release APK 的 V3 签名链路，随后已恢复为无签名构建状态。Android 自动化尚未覆盖设备生命周期、系统通知策略、SAF 提供方差异和同签名覆盖升级，这些仍属于一加 Ace 5 Pro 真机验收范围。
