# FitTrack 当前架构

> 本文件用于快速了解运行结构；完整分层、状态机、函数调用链和发布边界见 [`../docs/fittrack-global-architecture.md`](../docs/fittrack-global-architecture.md)。

本文描述截至 2026-07-15 已在代码中存在的桌面与 Android 共用实现，不把尚未完成的真机验收写成已完成事实。

## 运行结构

```text
QML 页面与组件
        ↓ context properties / signals
C++ Controller 与 Model
        ↓ QSqlDatabase
SQLite v8
```

`src/app/main.cpp` 负责初始化数据库、导入系统动作和计划种子，并把各控制器注入 QML。当前控制器直接使用同一个 SQLite 连接，没有额外 Repository 抽象；在现阶段这能保持实现简单。

主要模块：

- `training/`：活动训练快照、正式组、短休追加组、未完成训练恢复。
- `plans/`：系统计划和个人计划管理，包括训练日、动作分组、动作替换、排序和单段有氧目标。
- `exercises/`：动作查询、组合筛选、收藏和自定义动作。
- `analytics/`：容量、最高重量、e1RM、肌群和有氧汇总。
- `history/`：已完成力量训练详情、已完成组修正和整次训练删除。
- `cardio/`：跑步机爬坡、爬楼机和有氧历史。
- `gyms/`：健身房和具体器械实例；被历史引用时归档。
- `timer/`：单调时钟截止时间倒计时、桌面提示音，以及 Android 前台服务和完成通知桥接。
- `backup/`：JSON 事务恢复、SQLite 快照导出和 Android `content://` 文档 URI 访问。
- `storage/`：数据库版本守卫、完整性检查、损坏恢复、结构升级和种子导入。

## 关键数据流

### 力量训练

```text
系统/个人计划或自由训练
  → 创建 WorkoutSession 快照
  → 计划有氧同时复制为可选 WorkoutCardioTarget
  → 调整动作、器械和顺序
  → 完成 SetRecord 并立即写库
  → 可选 AppendSetRecord
  → 完成训练
  → 展示训练完成总结
  → 完成，或用快照预填并附加 CardioRecord
  → 历史与分析读取已完成记录
```

训练重量由用户填写。系统只计算和展示数据，不输出下一组或下一次训练的重量建议。

### 系统数据与用户数据

- `resources/data/exercises-*.json` 和 `tan-three-day-split.json` 是版本化系统种子；动作媒体的独立审核清单位于 `resources/data/exercise-media-shareable.json`。
- 系统动作和系统计划只读，可恢复默认。
- 用户动作、个人计划、历史训练、有氧和场馆器械保存在 SQLite，不因恢复系统种子而删除。

### 备份恢复

- JSON 导出包含受支持业务表的完整数据，包括计划有氧与训练快照；恢复在单个事务中替换本地数据并执行外键检查。旧版 JSON 缺少新表时按空表恢复，并在事务内把结构版本归一到 v8。
- SQLite 导出通过 `VACUUM INTO` 生成一致快照。
- 本地路径使用 `QSaveFile` 原子写入；Android `content://` URI 通过 Qt 文件接口直接读写。SQLite 导出先生成临时一致快照，再流式复制到文档 URI。
- JSON 恢复拒绝超过 64MB 的输入，恢复成功后会清空旧的活动训练内存状态，并重新加载动作、计划、历史、分析、有氧和场馆数据。

### 数据库启动与损坏恢复

- 打开数据库后先读取 `schema_version`。高于 v8 的数据库立即拒绝，且不会进入完整性扫描、迁移或损坏恢复，避免未来版本被当前应用静默降级。
- 当前及旧版本随后执行 `PRAGMA quick_check(1)`；这里的参数只限制返回的错误条数，检查仍会扫描数据库页，真机冷启动耗时仍需在一加 Ace 5 Pro 上记录。
- 确认损坏后，主库与现存的 `-journal`、`-wal`、`-shm` 会先复制并核对大小到唯一 `.corrupt-*` 前缀。空白 v8 在同目录临时创建并校验，通过 `QSaveFile` 写入 recovery-pending 标记后才替换 canonical 主库。
- 若进程在替换期间终止，下次启动会优先读取 pending 标记：继续安装已校验的临时库，或在新库已提交时只完成校验与标记清理。成功后 QML 提示保留路径；原备份不会自动上传或删除。

### Android 计时与生命周期

- QML/C++ 计时器仍负责前台显示和状态机；每次开始、暂停、继续、重置或提前结束都会通过 JNI 同步 `RestTimerService`。
- Android 服务使用单调时钟保存截止时间，并以前台通知显示倒计时；自然结束时发送一次系统提示音通知，提前结束不会误报完成。
- Android 13 及以上开始倒计时时不会自动请求通知权限；只有用户点击“开启后台提醒”才请求一次，拒绝后改为提供系统通知设置入口。服务不使用精确闹钟，也不申请传感器或健康数据权限。
- 系统返回键先关闭历史详情或分析子页，再返回首页；只有首页再次返回才交给系统退出。

### Android 打包

- `android/` 提供 Manifest、Java 服务、Adaptive Icon、主题图标、启动页和备份排除规则。
- CMake 在 Android 上默认关闭测试和 Qt Multimedia，并按构建参数部署单一 ABI；手机包使用 `arm64-v8a`，模拟器调试包使用 `x86_64`。桌面端继续使用 Qt Multimedia 播放程序生成的提示音。
- `scripts/build-android.ps1` 将 Debug 与 Release、`arm64-v8a` 与 `x86_64` 构建目录分离，可生成 APK 或 AAB。正式签名分为 Direct APK 和 PlayUpload AAB 两个 profile；本地配置只负责把仓库外的 keystore 信息加载到进程环境，构建脚本再从环境变量读取路径、别名和密码，并显式重置未选择的签名模式，避免复用旧 CMake 缓存。
- `scripts/package-side-load.ps1` 只接受已通过包名、单 ABI、Debug 证书和 v2 签名校验的 APK；输出一个可分享 ZIP，并附带许可正文、实际 Qt SBOM、NDK NOTICE、媒体署名和逐文件 SHA-256。分发产物位于忽略提交的 `dist/`，不会污染源码历史。
- 当前应用名为“训迹”，包名 `com.xuke.fittrack`，版本 `0.1.0`/1，min API 29，target/compile API 36，Qt 6.11.1，JDK 21，Build Tools 36.0.0，NDK 27.2.12479018。最终包不含 `INTERNET` 或 `ACCESS_NETWORK_STATE` 权限；正式分发必须使用仓库外长期保管的 Direct 或 PlayUpload 密钥。

## SQLite v8

数据库表按领域分组：

- 系统：`app_meta`。
- 动作：`muscle`、`exercise`、`exercise_muscle`、`exercise_media`、`exercise_alternative`、`favorite_exercise`。
- 计划：`training_plan`、`plan_day`、`plan_section`、`plan_exercise`、`plan_cardio`。
- 场馆：`gym`、`equipment_instance`。
- 力量训练：`workout_session`、`workout_cardio_target`、`workout_exercise`、`set_record`、`append_set_record`。
- 有氧：`cardio_record`。

`plan_cardio` 每个训练日最多保存一个跑步机或爬楼机目标。`startPlanDay()` 在同一事务中把它复制到 `workout_cardio_target`，因此之后修改个人计划不会改变已经开始的训练；目标只用于训练后预填，真实完成值仍写入 `cardio_record`。

外键在连接初始化时开启。`gym` 和 `equipment_instance` 通过 `is_enabled` 归档；`cardio_record.performed_at` 保存有氧发生时间。

`exercise` 在 v5 增加专业资料字段，v6 增加单 active 触发器，v7 为 `workout_exercise` 增加 `rest_seconds` 快照。v8 补齐常用排序、关联删除和筛选索引。当前版本只有在版本守卫、`quick_check` 和关键约束检查通过后才走快路径；旧版本按“建表、补列或重建不一致表、建触发器与索引、写入版本”的顺序事务升级。早期可空的 `cardio_record.performed_at` 会重建为当前 `TEXT NOT NULL` 定义，避免同为 v8 却存在两种约束。

动作与计划种子保存 SHA-256 内容摘要，内容未变时各只执行一次摘要查询。动作目录、计划详情、训练恢复、历史详情和分析聚合均使用固定数量的批量 SQL；动作模型与一级页面按首次使用加载，历史和有氧列表分页，避免启动成本与历史数据量线性增长。

## QML 导航

一级导航为首页、计划、训练、动作、分析。分析页内部包含趋势、历史、有氧和管理四个页签。训练完成后会保留会话编号并打开训练总结，用户明确选择后返回首页或继续附加有氧；系统不会强制进入有氧表单。

Graphite & Lime 视觉令牌集中在 `qml/theme/Theme.qml`，页面通过 `AppPage`、`AppButton`、`AppIcon`、`IconButton`、`NumberField`、`AppDialog`、`ConfirmDialog`、`InlineFeedback`、`TrendChart`、`RestTimerBar` 等组件复用安全区、触控尺寸、颜色、间距和状态反馈。`AppIcon` 统一用 `PathSvg` 绘制线性图标，QML 门禁禁止重新引入已淘汰的字符图标。训练页的 14 个操作弹层与 4 个危险确认框全部使用统一组件；大字体时按钮自动纵向排列，危险确认默认聚焦“取消”。首页、训练、计划、动作库、趋势、历史、有氧和管理均已纳入移动单列体系，准备页与训练页长标题可响应换行，计划/训练动作预览至少 48dp，训练动作卡提供可见键盘焦点。可操作控件使用至少 3:1 的边界对比度，纯信息卡片使用独立的弱轮廓令牌；趋势图同时提供触摸、键盘和辅助技术可读摘要。

生产应用不注册或打包自定义字体，直接继承 Android/Windows 系统字体。Android 启动和回到前台时读取系统 `fontScale`，并通过 `Theme.fontScale` 统一缩放字号；自动化覆盖 1.0、1.3、1.5 和 2.0 倍。QML 测试在 Windows 离屏渲染时仅在测试进程加载本机微软雅黑，以避免无窗口平台选择到不可读的通用别名，这不影响生产包。

训练准备草稿由 `WorkoutSessionController` 保存在内存中。预览、参数修改、恢复默认、添加、替换和排序都不创建训练记录；只有确认“开始本次训练”时，控制器才在一个事务中创建 session、动作、正式组和有氧目标快照，失败时完整回滚并保留草稿。

计划、训练准备和正式训练共享 `ExerciseOrderSheet`。弹层只复制稳定记录 ID 和显示数据作为本地草稿；取消不会调用控制器，保存才提交完整 ID 列表。计划与正式训练控制器在单个事务中校验 ID 集合、重写连续 `sort_order` 并在失败时回滚；删除动作也同步归一化剩余顺序。准备草稿只在内存中按 `draftId` 重排。QML 同时提供真实触摸拖动和 48dp 的上移/下移按钮，后者作为键盘、TalkBack 与拖动失败时的操作通道。

动作详情从模型获取专业字段和媒体署名。58 个动作都展示本地图片、素材标题、来源、许可证、步骤、注意事项和参考资料；其中 29 个核心动作额外展示发力要点和常见错误。详情弹层、动作图和来源卡均具有辅助技术语义。页面没有 `Qt.openUrlExternally`，不提供教学视频或媒体外链入口。

## 验证基线

```powershell
cmake --build D:\FitTrackBuild\windows-qt6.11.1 -j 6
ctest --test-dir D:\FitTrackBuild\windows-qt6.11.1 -j 4 --output-on-failure
```

当前 15 项测试覆盖计算、数据库、种子导入、动作、计划、训练、历史、分析、有氧、场馆、备份、性能 SQL 门禁、倒计时和 QML 导航。数据库用例以数据驱动夹具覆盖合成 v1–v7、旧 v8 约束修复、v9 拒绝、主库与三类 sidecar 原字节保留，以及替换前后两种中断续跑；真实历史安装包数据库仍需真机验收。计划和训练测试覆盖逐组目标次数、训练日有氧增删改、计划复制、准备草稿与训练快照，以及稳定 ID 排序、事务回滚、删除归一化和重新实例化持久化；备份测试覆盖旧版 JSON 兼容；QML 测试在 360×800、420×920、480×1056 三档生成主页面和关键流程截图，并额外检查 1.0/1.3/1.5/2.0 四档字体、字符图标门禁、准备与训练标题不截断、计划/训练动作预览 48dp、训练动作卡可见焦点、当前动作详情真实打开、TalkBack 角色/名称及真实 `QTouchEvent` 拖动输入。Windows 固定环境还对 5 个静态关键状态执行尺寸、坏点比例与 RGB 平均误差门禁，失败时保留 actual、expected 和 diff 证据；这不能替代 Android 真机视觉与 TalkBack 验收。

Android 构建脚本支持 `arm64-v8a` 手机包、`x86_64` 模拟器包、Debug/Release APK、Release AAB，以及 Direct/PlayUpload 两套正式签名。`verify-android-release.ps1` 会检查包名、API、ABI、签名、ZIP 对齐和 ELF LOAD 段，`package-side-load.ps1` 继续检查 Debug 侧载包及 58 张 shareable 图片白名单。2026-07-14 的 arm64/x86_64 Debug 和 arm64 unsigned Release APK/AAB 已完成对应离线门禁；真实长期密钥、同签名覆盖升级和一加 Ace 5 Pro 真机回归均不得写成已经通过。
