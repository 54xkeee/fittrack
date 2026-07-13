# 训迹 FitTrack

FitTrack 是一个面向 Android 的个人健身训练记录与分析应用。当前桌面开发版已完成训练记录闭环、谭成义三分化与自由训练、个人计划管理、训练历史、容量与 e1RM 分析、有氧记录、健身房/器械区分、备份恢复，以及 52 个动作的离线资料库。

## 当前可用能力

- 首页根据按时间倒序的最新已完成谭成义训练日显示下一训练日，并可直接开始或继续训练。
- 计划页展示只读的谭成义三分化，支持一键复制为可编辑个人版；个人计划和训练日可以创建、重命名、删除，训练日支持添加动作、调整顺序和参数后直接开始训练。
- 正式组支持重量、次数、力竭、备注和短休追加组；完成后立即写入 SQLite。
- 自重动作明确区分纯自重、附加负重和辅助重量；只有附加负重计入外加负重容量，三者均不计算 e1RM。
- 训练中的已完成组和历史详情中的组都可以修正重量、次数、力竭与自重负荷类型；历史训练支持二次确认后整次删除，统计会立即刷新。
- 休息倒计时支持 2/3/5 分钟、自定义、暂停、继续、重置和提前结束；窗口最小化或切换后台后按绝对截止时间校准，结束播放一次程序生成的提示音。
- 首页和分析页显示 7 天、30 天、全部历史的训练次数、正式组、容量、最高重量、对应次数与组数、e1RM 和肌群分布。
- 有氧页支持跑步机爬坡与爬楼机记录；跑步机默认模板为坡度 9、速度 5 km/h、30 分钟。有氧可单独记录，也可附加到刚完成的力量训练。
- 场馆管理支持健身房与具体器械的新增、重命名和删除；被历史记录引用的条目会归档而不是破坏历史数据。
- 数据管理支持 JSON 完整备份/事务恢复和 SQLite 快照导出；JSON 恢复会进行外键完整性检查。
- 动作库提供 52 个动作的简介、主要/次要肌群、4 步动作说明、3 条核心注意点和训练参数；其中 26 个动作内置许可明确的离线图片，其他动作不使用许可不明或动作形式不准确的替代素材。内置动作可收藏和恢复默认，用户可创建、编辑及删除自定义动作，并按部位、动作模式、器械和收藏状态组合筛选。
- 底部导航固定为首页、计划、训练、动作和分析五个入口；历史、有氧和管理合并在分析入口内。
- Graphite & Lime 设计系统已经提取为语义主题与通用组件，底部导航、首页、训练、计划、动作库、趋势、历史、有氧和管理页面均已纳入移动单列体系；可操作控件保持至少 48 logical px 触控区并提供完整空状态。
- 应用内置 SIL Open Font License 的 Inter 可变字体，统一英文、数字和单位显示；中文继续使用系统字体回退。

当前自动化测试共 14 项，覆盖统计规则、SQLite、种子导入、训练会话、历史、分析、计划管理、动作库管理、有氧、健身房/器械、备份恢复、倒计时状态和真实 QML 页面加载。

当前代码结构见 [`ARCHITECTURE.md`](ARCHITECTURE.md)，完整里程碑见 [`../docs/fittrack-development-plan.md`](../docs/fittrack-development-plan.md)。

## 当前桌面构建环境

- Qt 6.9.1（MSYS2 MinGW 64-bit）
- Qt Multimedia（倒计时提示音）
- CMake 4.1
- Ninja 1.13
- C++17

MSYS2 Qt 的 QML 扫描器无法正确处理当前工作区的中文路径。开发机使用目录联接 `C:\FitTrackDev` 指向仓库根目录，从英文路径构建；源文件仍只保存在本仓库。

```powershell
cmake -S C:\FitTrackDev\fittrack -B C:\FitTrackDev\fittrack\build -G Ninja `
  -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON
cmake --build C:\FitTrackDev\fittrack\build
ctest --test-dir C:\FitTrackDev\fittrack\build --output-on-failure
```

QML 导航测试会把五个主页面、训练进行中、历史详情、有氧、管理和带真实训练数据的分析页分别按 360×800、420×920、480×1056 写入 `C:\FitTrackDev\fittrack\build\visual`。默认使用 `offscreen` 与软件渲染，可直接在无交互窗口的测试环境运行；如需检查本机图形后端可使用：

```powershell
$env:QT_QPA_PLATFORM = "windows"
$env:QSG_RHI_BACKEND = "d3d11"
ctest --test-dir C:\FitTrackDev\fittrack\build -R qmlnavigation --output-on-failure
```

## Android 状态

项目结构采用 Qt Quick/QML + CMake，能够继续配置 Qt for Android。当前机器尚未安装 Qt Android ABI、Android SDK/NDK/JDK，因此尚未生成 APK。Android 目标固定为 `arm64-v8a`；正式包名、版本号和签名身份将在 Android 落地阶段冻结，`com.fittrack.app` 仅为早期占位值。

## 数据与媒体

- 内置动作 JSON 位于 `resources/data/exercises-*.json`。
- 谭成义三分化模板位于 `resources/data/tan-three-day-split.json`。
- 内置动作会在应用启动时事务化导入 SQLite。
- 动作图片位于 `resources/images/exercises/`，每张图片的原始链接和许可记录在对应动作 JSON 的 `media` 字段中。
- Inter 字体与 SIL OFL 许可位于 `resources/fonts/`。
- 当前内置 26 张开放许可或公共领域图片；找不到动作准确且许可明确素材的条目保持无图。
- 未授权的抖音、B站、知乎视频或截图不得打包进 APK；只允许外链。自制、明确授权或开放许可素材才可内置。

## 已知平台边界

当前“后台计时”指桌面窗口最小化或应用失去焦点后继续按绝对截止时间运行并在恢复时校准。Android 系统级前台服务、锁屏通知和后台播放将在 Android 工具链阶段实现，当前不宣称已经完成。
