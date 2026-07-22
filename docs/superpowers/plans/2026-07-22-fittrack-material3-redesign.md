# FitTrack 原生 Material 3 与交互架构重构计划

**状态：** 执行中。按轮次提交，每轮仅改动本轮目标所需文件。

**目标：** 将 FitTrack 变成 Android 优先、完整且有任务感的 Material 3 健身应用。重构重点不是给页面换颜色，而是先统一训练渲染、导航、任务流、反馈与组件边界，再完成全局视觉与页面迁移。

**范围基础：** Qt 6 Quick/QML、Qt Quick Controls Material、现有 C++ Controller、SQLite、可选 React 原型。

**执行记录（2026-07-22）：**
- Round 1：已冻结 Android React/WebView 默认接管；QML 是唯一正式训练渲染路径；交互契约已落在 `docs/superpowers/specs/2026-07-22-fittrack-interaction-contract.md`。
- Round 2（进行中）：已移除重复 `Spacing` 单例，文字尺寸统一由 `Typography` 计算，`WorkoutTheme` 改为训练领域适配层；已让 Qt Material 和语义色 Token 跟随系统明暗模式。Windows Qt 6.11.1 构建通过。
- Round 3（进行中）：已建立 `AppScaffold`、Top App Bar、Navigation Bar、Bottom Sheet、Snackbar、OverlayHost 与 TaskFeedbackHost；主底部导航和训练准备顶栏已迁移到组件层，动作详情、动作选择、参数、排序、训练/动作操作菜单、休息计时、训练组配置、已完成组修正、目标次数、追加组、器械选择、训练/动作备注和保存个人计划已迁移为 Bottom Sheet；保存成功已通过全局 Snackbar 反馈，训练页也不再覆盖系统明暗主题，保留原 `objectName`、焦点和无障碍页签语义。Windows Qt 6.11.1 构建通过。
- 待后续轮次：真机记录实际解析字体与字号；将现有页面迁移到文字角色；把具体编辑/选择流程迁移到 Sheet 与全局反馈宿主。

---

## 1. 当前判断

### 1.1 根因

当前的“网页感、层次弱、交互薄”主要由交互架构造成，不是单独的字体或卡片问题：

- 同一训练流程同时存在 QML 训练页、桌面 WebEngine React 页、Android 全屏 WebView 覆层。
- 主导航使用底栏 index，训练准备、详情、完成总结等依赖局部 Boolean、Overlay 或嵌套页签，缺少稳定返回栈。
- 大量名为 Sheet 的界面实际是居中 Dialog，移动端编辑、选择、排序都像桌面弹窗。
- 训练页同时承担工作流、视图、弹层、焦点、滚动和事件编排，导致任何新互动都只能继续堆进大页面。
- Theme、Typography、Spacing、WorkoutTheme 和 React CSS 并存，基础组件虽命名统一，却经常被页面绕过或被重复自绘。

### 1.2 这次重构真正要补齐的能力

| 能力 | 当前问题 | 重构目标 |
|---|---|---|
| 生产渲染 | 同一训练有三套宿主 | 一个正式训练渲染器。 |
| 任务流 | 入口、返回、完成后的去向不稳定 | 明确的训练状态机与来源返回。 |
| Overlay | 居中 Dialog 泛用 | Dialog、Sheet、详情、Menu 各司其职。 |
| 瞬态反馈 | 页面内提示会被滚动隐藏 | 全局 Snackbar、Undo、加载、提交反馈。 |
| 组件系统 | 多 Token、多套样式、页面绕过组件 | 单一基础层和少量稳定变体。 |
| 视觉层级 | 同质卡片、随意字重与颜色 | Material 3 语义色、文字角色与表面层级。 |
| 原生反馈 | 动效零散，缺少触感与状态交接 | 可预测的动效、触感和辅助技术播报。 |

---

## 2. 架构目标

### 2.1 建议的正式架构

```text
C++ Controller / RestTimer
    训练事实、事务、持久化、后台计时
                ↓
QML App Shell
    一级目的地、Back、安全区、主题
                ↓
Workout Flow
    准备、训练中、休息、完成、总结、有氧
                ↓
Overlay Host + Feedback Host
    Bottom Sheet、Dialog、全屏详情、Snackbar、Undo
                ↓
Material 3 Foundation
    Token、文字、状态层、基础控件、模式组件
                ↓
页面与训练领域组件
```

这不是引入 Redux、万能 Router 或重写 Controller。它只是把现在散落在页面、Dialog、WebView 和局部状态中的职责收束为五个明确边界。

### 2.2 训练渲染器决策

**建议：QML 是唯一正式训练前端。**

- 现有业务控制器、计时器、无障碍和动作数据本来就以 QML 为主路径。
- React 训练页冻结为视觉原型或未来独立 Web 客户端，不再自动覆盖 Android 训练流程。
- 未来若要正式采用 React，必须作为完整独立客户端开发，而不是 WebView 覆层。

本项是 Round 1 的决策门。未确认前，不删除 React，也不继续扩展其业务功能。

### 2.3 Material 3 实施方式

- Qt Quick Controls Material 是基础控件和行为底座。
- 项目只封装全局必须统一的 M3 外观和模式，不继续逐控件手绘 `Rectangle` 外观。
- 使用 Material 3 的语义色、排版、形状、状态和表面层级；不把 Qt 默认样式直接当作完整产品设计。
- Android 使用正常密度与至少 48dp 触控目标；Windows 可在不破坏组件语义的前提下使用更紧凑布局。

---

## 3. 必要约束与明确非目标

### 3.1 必要约束

- 保持 C++ Controller、SQLite、训练规则、数据迁移和现有业务事务语义。
- 保持用户可达的一级信息架构，除非 Round 1 的任务流审查证明某个入口不成立。
- 保留测试依赖的 ObjectName、业务信号、可访问名称和数据绑定；视觉组件可重写。
- 一个生产训练流程只允许一个渲染器和一套交互语义。
- 所有可操作目标至少 48dp，所有弹层无焦点陷阱，所有状态不只依赖颜色。
- 所有文字、颜色、圆角、动效和间距必须来自单一 Token 或组件角色。
- 每轮限定改动范围，提交可单独回滚，并在进入下一轮前完成审查。

### 3.2 第一阶段不做的事

- 不重写 C++ 业务层，不迁移 Jetpack Compose、Flutter 或 Web-only 架构。
- 不因为旧组件丑而重做已有训练算法或数据库。
- 不做 Android 动态壁纸取色，第一期使用固定 M3 Blue Seed。
- 不引入大量持续动画、玻璃效果、营销页渐变、装饰性发光或多套品牌色。
- 不用 ImageGen 生成按钮、图标、输入框、导航、文字 UI 或动作教学替代图。
- 不为一次性页面制造抽象层或“万能组件”。

这些限制的目的不是保守，而是让重构集中在真正影响 App 感的架构和高频任务流上。

---

## 4. 组件与开发体验策略

### 4.1 处理旧组件的原则

现有组件不是视觉遗产，也不是必须保留的结构。保留业务行为和测试契约，重新决定其视觉与交互实现。

| 处理 | 组件或能力 | 原因 |
|---|---|---|
| 保留行为 | `AppPage` 安全区、`NumberField` 校验与滑动调重、组状态语义、拖动排序与上下移动后备操作 | 已有高价值交互或无障碍行为。 |
| 重建外观与合同 | Button、IconButton、TextField、NumberField、CheckBox、Switch、ComboBox、Card、Dialog、导航、训练顶栏 | 当前各自绘制状态，不能形成统一 M3 体验。 |
| 新建必要模式 | Top App Bar、Navigation Bar、Bottom Sheet、Snackbar、Empty State、List Item、State Layer | 当前缺失，页面重复实现。 |
| 收敛或淘汰 | `WorkoutTheme`、重复 Typography/Spacing、ActionPill、重复组行、三套休息计时呈现 | 减少视觉系统分叉。 |

### 4.2 最小组件层级

```text
Foundation
  Color / Type / Shape / Spacing / Motion / State
Primitives
  Button / IconButton / TextField / NumberField / Selection Control
Patterns
  AppScaffold / TopAppBar / NavigationBar / ListItem / Card
  BottomSheet / Dialog / Snackbar / EmptyState
Features
  WorkoutSetRow / CurrentSetPanel / RestTimerBar / WorkoutSummary
Pages
  只编排内容和业务状态，不定义视觉细节
```

只有跨三个以上场景复用，或必须全局一致的能力才进入组件层。页面局部结构留在页面内，避免组件爆炸。

---

## 5. 交互合同

### 5.1 导航与返回

- 底部导航只用于稳定、同等重要的一级目的地。
- 训练准备、训练中、完成总结、动作详情和编辑不伪装成一级 Tab。
- Back 优先级固定为：关闭 Overlay → 回详情来源 → 回工作流来源 → 回一级目的地 → 退出。
- 开始训练时保存来源入口；取消准备、完成总结和附加有氧均返回合理来源，而不是一律回首页或跳入分析页。

### 5.2 表面使用矩阵

| 场景 | 表面 |
|---|---|
| 添加、替换动作、参数、器械、排序、已完成组编辑 | Modal Bottom Sheet。 |
| 动作详情 | 全高 Sheet 或详情页面。 |
| 删除、放弃训练、提前结束、不可逆恢复 | Confirm Dialog。 |
| 保存成功、删除后撤销、临时后台状态 | Snackbar。 |
| 输入校验 | 控件下方 Inline Error。 |
| 空、加载、失败 | 页面级状态。 |

### 5.3 训练流程状态机

```text
入口
  → 训练准备
  → 训练中：当前组草稿 → 提交中 → 已完成
  → 休息运行 / 暂停 / 跳过
  → 下一组或下一动作
  → 完成确认
  → 训练总结
  → 可选附加有氧或返回来源

恢复 / 放弃 是任意活动训练状态的明确分支。
```

训练中的休息计时必须有固定可见的 Bottom Action Bar，不放在可滚出视区的动作卡中。

### 5.4 反馈、动效与触感

- 每个交互组件定义 Press、Focus、Disabled、Selected、Loading、Success、Error 状态。
- 完成本组：轻触感确认、行状态完成、TalkBack 播报、休息栏进入、下一任务清晰可见。
- 训练完成：较明显确认触感和总结进入。
- Snackbar 仅用于短暂且可撤销的反馈；不把长期错误放进 Snackbar。
- `reducedMotion` 时所有非必要动效直接变为即时状态变化。
- 不给普通滚动、每秒倒计时和日常导航添加触感。

---

## 6. 视觉、字体与资产策略

### 6.1 主题与表面

- 第一阶段固定 M3 Blue Seed，提供 Light、Dark、System 三套完整 Token。
- 只使用语义色，如 `primary`、`primaryContainer`、`surface`、`surfaceContainer`、`onSurface`、`outline`、`error`。
- Filled、Outlined、Elevated、Tonal 是有明确层级含义的容器变体，不能每块内容都同时描边和加阴影。
- 每屏仅一个 Filled 主操作；其他操作按 Tonal、Outlined、Text 逐级降级。

### 6.2 排版

- 合并 `Theme.qml`、`Typography.qml`、`Spacing.qml` 的重复职责，排版只保留一个来源。
- 使用 M3 基础角色：Display、Headline、PageTitle、SectionTitle、Body、BodyCompact、Label、Meta、TableLabel。
- 增加训练数据角色：MetricValue、TimerValue、SetValue，数字启用 `tnum`。
- 中文默认仅使用 400、500、600 字重；700 只用于极强结果状态。
- 生产应用继续继承系统字体和系统字体缩放；不打包新字体。
- Android 与 Windows 记录实际解析到的字体、字号和字重，避免设计请求与实际回退字形不一致。

### 6.3 ImageGen 的正确位置

在交互骨架确认后，ImageGen 只用于非功能视觉资产：

1. 首页、计划和训练准备的空态插画。
2. 训练完成和连续训练里程碑视觉。
3. 恢复、同步或数据管理的低干扰辅助视觉。
4. 设计评审参考板。

每个资产要有屏幕用途、尺寸、暗色主题处理、生成提示词和人工筛选记录。现有经过审核的动作教学图片继续使用，不用生成图替代。

---

## 7. 七轮执行计划

### Round 1：交互架构冻结与基线审查

**解决的问题：** 先判断谁负责训练、Back 去哪里、哪些表面该出现，避免先美化错误架构。

- [ ] 对比 `e943351` 与当前 Material 分支，列出未批准视觉提交的保留或回退决定。
- [ ] 确认正式训练渲染器，推荐 QML 唯一生产路径并冻结 React/WebView 自动覆盖。
- [ ] 输出一级导航图、Back 规则、训练状态机、Overlay 使用矩阵和反馈状态矩阵。
- [ ] 识别现有 ObjectName、辅助技术和视觉测试锚点，形成迁移保护清单。
- [ ] 使用低保真 QML 或交互图走查核心路径，不做最终视觉。

**验收门：** 用户确认 QML/React 处置、训练流程和表面矩阵。

### Round 2：M3 Foundation 与字体基线

**解决的问题：** 让所有后续页面从同一套主题、文字和状态规则开始。

- [ ] 建立唯一的 Color、Type、Shape、Spacing、Motion、State Token。
- [ ] 完成 Light、Dark、System 主题策略与 Android/Windows 密度策略。
- [ ] 完成文字角色、数字角色、系统字体解析检查和 React CSS Token 镜像。
- [ ] 移除或过渡重复的 Theme、Typography、Spacing、WorkoutTheme 定义。

**验收门：** 主题和字体缩放可运行；不存在新的页面原始 Hex、任意字号或任意圆角。

### Round 3：原生组件、App Shell 与反馈宿主

**解决的问题：** 不再让页面依赖丑旧组件或自行拼 UI。

- [ ] 重建基础输入、选择、按钮和状态层，优先保留 Qt Material 控件行为。
- [ ] 建立 AppScaffold、Top App Bar、Navigation Bar、Bottom Sheet、Dialog、Snackbar、Empty State。
- [ ] 建立 OverlayHost 和 TaskFeedbackHost，页面不再自行管理居中 Dialog 和滚动提示。
- [ ] 保留旧组件的业务信号、ObjectName、无障碍语义和必要手势；只替换视觉/交互实现。

**验收门：** 一个试验页可只通过组件角色完成完整交互，没有局部手写视觉样式。

### Round 4：首页、计划与训练准备

**解决的问题：** 让日常入口与开始训练路径具备原生 App 的层级和任务感。

- [ ] 重构首页为今日训练、近期进度、最近活动三级结构。
- [ ] 重构计划和训练准备，使用详情、Sheet、菜单替代重复的卡内 CRUD 按钮。
- [ ] 实现来源返回，不再让取消准备一律回首页。
- [ ] 筛选并接入第一批空态视觉资产。

**验收门：** 每屏一个 Filled 主操作；用户能从首页或计划进入、取消并回到合理来源。

### Round 5：训练中、休息与完成总结

**解决的问题：** 完成最关键的高频训练任务流。

- [ ] 拆分训练页的流程编排、Overlay、反馈和呈现职责。
- [ ] 重构训练顶栏、当前动作、组表、输入草稿、完成组反馈与焦点策略。
- [ ] 实现固定休息 Bottom Action Bar、计时设置 Sheet、暂停和跳过。
- [ ] 实现结束确认、训练总结、可选有氧和来源返回。
- [ ] 加入必要触感、TalkBack 播报和 reduced-motion 路径。

**验收门：** 在不寻找隐藏操作的情况下，可完成一组、休息、进入下一组、结束训练和返回。

### Round 6：动作、分析、历史、有氧与管理

**解决的问题：** Material 3 不只覆盖训练页，也不让次要功能退回 Web/桌面式 CRUD。

- [ ] 重构动作库、动作详情、筛选和收藏。
- [ ] 重构分析、历史、有氧和管理的页面状态、详情流和可撤销反馈。
- [ ] 用 Bottom Sheet、详情页和 Snackbar 替换不合适的中心 Dialog 与页面内提示。
- [ ] 审核并接入第二批必要视觉资产。

**验收门：** 全部一级功能都遵循同一导航、表面、反馈和文字规则。

### Round 7：收束、验证与发布准备

**解决的问题：** 防止“局部好看、全局漂移”，并留下可维护的前端基线。

- [ ] 处理 React runtime、Android WebView bridge 与构建资源的冻结、隔离或删除决策。
- [ ] 完成 React 原型与 QML 正式端的职责说明，避免双实现再次出现。
- [ ] 更新视觉基准，修复或隔离 `qmlnavigation` 执行环境问题。
- [ ] 运行 QML lint、Windows 构建、自动测试、视觉回归和 Android 真机走查。
- [ ] 记录组件用法、主题规则、资产清单和已知平台差异。

**验收门：** 生产前端只有一套训练交互语义；关键路径、字体缩放、无障碍和主题切换均通过审查。

---

## 8. 全局验收标准

### 体验

- 用户始终知道自己在哪、Back 会去哪、当前任务是什么、下一步是什么。
- 训练中关键状态不因滚动而丢失。
- 编辑、详情、确认和瞬态反馈使用正确表面，不再把所有操作塞进中心 Dialog。
- 每页一个主要行动，辅助操作不会抢占任务焦点。

### 可访问性与输入

- 触控目标至少 48dp，焦点可见，Overlay 可退出并恢复焦点。
- TalkBack 只播报状态变化，不逐秒播报计时。
- 1.0、1.3、1.5、2.0 字体缩放下，无标题截断和主操作溢出。
- 拖动排序和滑动调重保留可发现说明与按钮/键盘后备操作。

### 工程

- C++ 业务层、事务和数据兼容性不因视觉重构回归。
- 新页面不直接定义颜色、圆角、字号或控件背景。
- 不保留没有明确职责的重复 Token、重复计时器或双渲染器。
- 每轮只修改完成该轮目标所需的文件，并通过对应的最小验证。

---

## 9. 当前确认门

1. 是否同意 QML 作为唯一正式训练前端，React/WebView 冻结为原型或未来独立客户端。
2. 是否同意先完成 Round 1 的交互架构与低保真走查，再进入 Material 3 视觉实现。
3. 是否同意固定 M3 Blue Seed、系统字体、Light/Dark/System 三主题作为第一期基础。
4. 是否同意 ImageGen 后置到交互骨架稳定后，仅用于非功能视觉资产。

确认上述四项后，才开始 Round 1。
