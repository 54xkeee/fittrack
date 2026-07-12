# FitTrack 当前架构

本文描述 2026-07-13 已在代码中存在的桌面开发版，不把尚未落地的 Android 能力写成已完成事实。

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
- `plans/`：系统计划和个人计划管理。
- `exercises/`：动作查询、组合筛选、收藏和自定义动作。
- `analytics/`：容量、最高重量、e1RM、肌群和有氧汇总。
- `history/`：已完成力量训练详情。
- `cardio/`：跑步机爬坡、爬楼机和有氧历史。
- `gyms/`：健身房和具体器械实例；被历史引用时归档。
- `timer/`：绝对截止时间倒计时和桌面提示音。
- `backup/`：JSON 事务恢复与 SQLite 快照导出。
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
  → 历史与分析读取已完成记录
  → 可选附加 CardioRecord
```

训练重量由用户填写。系统只计算和展示数据，不输出下一组或下一次训练的重量建议。

### 系统数据与用户数据

- `resources/data/exercises-*.json` 和 `tan-three-day-split.json` 是版本化系统种子。
- 系统动作和系统计划只读，可恢复默认。
- 用户动作、个人计划、历史训练、有氧和场馆器械保存在 SQLite，不因恢复系统种子而删除。

### 备份恢复

- JSON 导出包含受支持业务表的完整数据；恢复在单个事务中替换本地数据并执行外键检查。
- SQLite 导出通过 `VACUUM INTO` 生成一致快照。
- Android `content://` URI 尚未支持；当前文件操作只在桌面普通路径上验证。

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

一级导航为首页、计划、训练、动作、分析。分析页内部包含趋势、历史、有氧和管理四个页签。训练完成后会保留会话编号并跳转到有氧入口，用户可以附加有氧或取消。

Graphite & Lime 视觉令牌目前直接存在于通用组件中：深色背景 `#0F0F0F`/`#1A1A1A`、主色 `#C5FF4A`、辅助色 `#FFB74D`。下一视觉轮应把剩余旧页面统一到同一组件体系，再决定是否提取轻量主题单例。

## 验证基线

```powershell
cmake --build C:\FitTrackDev\fittrack\build -j 6
ctest --test-dir C:\FitTrackDev\fittrack\build -j 4 --output-on-failure
```

当前 14 项测试覆盖计算、数据库、种子导入、动作、计划、训练、历史、分析、有氧、场馆、备份、倒计时和 QML 导航。QML 测试还生成训练进行中等手机尺寸截图；Android APK、真机生命周期和后台通知不在当前验证范围内。
