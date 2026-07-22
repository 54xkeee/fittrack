# 训迹 FitTrack

FitTrack 是一个面向 Android 的个人健身训练记录与分析应用，当前交付目标是供用户本人长期使用，并可把 APK 直接分享给其他用户侧载安装。源码已完成训练记录闭环、谭成义三分化与自由训练、个人计划管理、训练历史、容量与 e1RM 分析、有氧记录、健身房/器械区分、备份恢复，以及 58 个动作的离线资料库，并能构建 Windows 调试版、Android `arm64-v8a` Debug/Release 包和 `x86_64` 模拟器调试包。

## 当前可用能力

- 首页根据按时间倒序的最新已完成谭成义训练日显示下一训练日，并可直接开始或继续训练。
- 首页、计划页和训练空态统一先进入不落库的训练准备页；可预览动作、调整组数/逐组次数/间歇、添加/替换/排序动作、恢复进入准备时的默认值，并选择仅开始本次训练或保存为个人计划。
- 计划页展示只读的谭成义三分化，支持一键复制为可编辑个人版；个人计划和训练日可以创建、重命名、删除，训练日支持动作分组、添加、替换、参数编辑、单段有氧目标，以及在独立排序弹层中拖动或上移/下移后直接开始训练。
- 正式组支持逐组目标次数、重量、实际次数、力竭、备注和短休追加组；完成后立即写入 SQLite。目标次数只由用户修改，不触发重量或次数建议。
- 自重动作明确区分纯自重、附加负重和辅助重量；只有附加负重计入外加负重容量，三者均不计算 e1RM。
- 训练中的已完成组和历史详情中的组都可以修正重量、次数、力竭与自重负荷类型；历史训练支持二次确认后整次删除，统计会立即刷新。
- 完成力量训练后先展示正式组、容量、最高重量、e1RM 和肌群总结，再由用户选择完成或继续添加有氧，不强制跳转。
- 休息倒计时支持 2/3/5 分钟、自定义、暂停、继续、重置和提前结束；桌面端按单调时钟截止时间校准并播放一次程序生成的提示音，Android 端使用前台服务显示后台倒计时并在自然结束时发送一次系统提示音通知。
- 首页和分析页显示 7 天、30 天、全部历史的训练次数、正式组、容量、最高重量、对应次数与组数、e1RM 和肌群分布。
- 有氧页支持跑步机爬坡与爬楼机记录；首页只读取最新记录，进入有氧页首批加载 50 条并可继续分页，趋势固定展示最近 30 次。跑步机默认模板为坡度 9、速度 5 km/h、30 分钟。有氧可单独记录，也可附加到刚完成的力量训练。
- 场馆管理支持健身房与具体器械的新增、重命名和删除；被历史记录引用的条目会归档而不是破坏历史数据。
- 数据管理支持 JSON 完整备份/事务恢复和 SQLite 快照导出；Android 支持通过系统文档选择器的 `content://` URI 导入导出。JSON 包含计划有氧与训练快照，仍兼容缺少这两张表的旧版备份；恢复会限制 64MB 输入、进行外键完整性检查，并刷新所有内存状态。
- 启动时会先拒绝高于当前版本的数据库，再执行 SQLite 快速完整性检查。检测到损坏时，主库及 `-journal`/`-wal`/`-shm` 会先复制到唯一的 `.corrupt-*` 备份，再创建空白数据库；恢复中途被系统终止时，下次启动会从 pending 标记继续，成功后提示备份路径和 JSON 恢复入口。
- 动作库提供 58 个目标动作的简介、主要/次要肌群、步骤、注意事项和训练参数；其中 29 个核心动作额外提供发力要点和常见错误，其余为标准资料。每项展示 1 张经过动作要领与器械结构审核的本地图，并在详情中显示素材标题、来源和许可证；51 张项目制作图按 CC0 1.0 提供，7 张 Free Exercise DB 实拍按 Unlicense 分发。内置动作可收藏和恢复默认，用户可创建、编辑及删除自定义动作；应用不提供教学视频或媒体外链入口。
- 底部导航固定为首页、计划、训练、动作和分析五个入口；历史、有氧和管理合并在分析入口内。
- UI 使用 Material 3 语义令牌与原生交互组件。QML 是唯一正式训练渲染路径；React/WebView 仅为显式开启的实验原型。底部导航、训练准备顶栏、动作详情、选择、排序、参数、休息计时与训练编辑均使用 `AppNavigationBar`、`AppTopAppBar`、`AppBottomSheet`、`AppDialog`、`ConfirmDialog` 和全局 Snackbar 的明确表面语义；破坏性操作仍要求确认。统一线性图标由 `AppIcon` 使用 `PathSvg` 绘制，不依赖 Unicode 字符图标。
- 应用不再内置字体，直接继承 Android、Windows 等平台的系统字体；Android 字体缩放统一映射到设计令牌。当前 Windows 系统 UI 字体记录为 `Microsoft YaHei UI`；Android 的真实字体回退和四档字体缩放仍需真机复核，详见 [`../docs/fittrack-platform-ui-audit.md`](../docs/fittrack-platform-ui-audit.md)。

默认 CTest 注册 14 项业务、存储、控制器与性能测试，已在 2026-07-22 全部通过。`tst_qmlnavigation` 仍会构建，但仅在配置 `-DFITTRACK_ENABLE_QML_VISUAL_TEST=ON` 时注册为 `qml;visual` 测试；当前 Windows headless 环境在进入测试输出前超时。数据库用例覆盖合成 v1–v7 迁移、旧 v8 约束修复、损坏原字节与 sidecar 保留、恢复中断续跑及损坏 v9 拒绝；QML 回归负责训练准备、详情、排序、TalkBack、字体缩放、触控目标和视觉基准，待执行环境修复后恢复为发布门禁。

当前数据库结构版本为 SQLite v8。版本判断与完整性检查通过后才进入同版本快路径；旧库会在单个事务中补列、重建不一致约束、建索引和触发器，既有用户数据会保留。v9 及以上数据库不会被当前版本降级或替换。

当前代码结构见 [`ARCHITECTURE.md`](ARCHITECTURE.md)，完整里程碑见 [`../docs/fittrack-development-plan.md`](../docs/fittrack-development-plan.md)。

## 当前桌面构建环境

- Qt 6.11.1（MinGW 64-bit）
- Qt Multimedia（倒计时提示音）
- CMake 4.1
- Ninja 1.13
- C++17

Qt 的 QML 工具处理当前工作区中文路径时仍可能失败。开发机使用目录联接 `C:\FitTrackDev` 指向仓库根目录，从英文路径构建；源文件仍只保存在本仓库。当前 Windows 构建目录与 Qt 运行库路径如下：

```powershell
$env:PATH = "D:\FitTrackToolchains\Qt\6.11.1\mingw_64\bin;D:\FitTrackToolchains\Qt\Tools\mingw1310_64\bin;$env:PATH"
& "D:\FitTrackToolchains\Qt\6.11.1\mingw_64\bin\qt-cmake.bat" `
  -S C:\FitTrackDev\fittrack -B D:\FitTrackBuild\windows-qt6.11.1 -G Ninja `
  -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON
cmake --build D:\FitTrackBuild\windows-qt6.11.1
ctest --test-dir D:\FitTrackBuild\windows-qt6.11.1 --output-on-failure
```

QML 导航测试会把五个主页面、可编辑个人计划、训练日有氧弹层、训练进行中、目标次数弹层、训练完成总结、历史详情、有氧、管理和带真实训练数据的分析页分别按 360×800、420×920、480×1056 写入构建目录下的 `visual/`。受控基准位于 `tests/visual/baselines/windows-qt6.11.1-offscreen-software-material-zh_CN-dpr1/`；Windows 门禁固定 Qt 6.11.1、`offscreen`、软件渲染、Material、`zh_CN`、DPR 1、96 DPI 和指定微软雅黑文件，视觉差异超限时写入 `visual/diff/`。如需人工检查本机图形后端，应直接运行应用；视觉基准测试不会接受外部后端覆盖。

## Android 状态

本机已经配置 Qt 6.11.1 Android `arm64-v8a`/`x86_64`、JDK 21、Android SDK 36、Build Tools 36.0.0 和 NDK r27c。统一构建入口：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 -Abi x86_64
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 -Configuration Release
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 -Configuration Release -Bundle
```

脚本分别输出 Debug APK、Release APK 或 Release AAB，并可用 `Direct` 与 `PlayUpload` 两个签名 profile 生成正式签名产物。当前包名为 `com.xuke.fittrack`，min API 29，target/compile API 36；手机包使用 `arm64-v8a`，模拟器包使用 `x86_64`。完成 Debug 构建和 `lintDebug` 后运行 `scripts/package-side-load.ps1`，会硬性复核 APK 元数据与签名，并在 `dist/` 生成仅含一个 Debug APK 的 ZIP、安装说明、逐文件 SHA-256、实际 Qt SBOM、NDK NOTICE、媒体署名及完整许可正文。`dist` 不提交 Git，正式分享前必须从待发布提交重新生成。仓库只提供密钥生成、配置示例、签名和校验能力；真实 keystore 与密码必须在仓库外创建并长期保管。

完整工具链、Lint、APK 检查和真机命令见 [`../docs/fittrack-android-build.md`](../docs/fittrack-android-build.md)。

## 数据与媒体

- 内置动作 JSON 位于 `resources/data/exercises-*.json`。
- 谭成义三分化模板位于 `resources/data/tan-three-day-split.json`。
- 内置动作会在应用启动时事务化导入 SQLite。
- 可分发动作图片位于 `resources/images/exercises/shareable/`，58 个动作各 1 张，统一为 1200×800 JPEG。
- 机器可读的媒体标题、来源页面、作者/来源、许可证和应用内路径位于 `resources/data/exercise-media-shareable.json`，并同步进入对应动作 JSON 的 `media` 字段。
- MuscleDB 只保留为动作文字映射参考；其图片目录和旧动作图片不会被 CMake 打包进 APK。应用也不再打包 Inter 字体。
- 数据映射见 [`../docs/fittrack-exercise-mapping.md`](../docs/fittrack-exercise-mapping.md)，媒体用途限制见 [`../docs/fittrack-media-credits.md`](../docs/fittrack-media-credits.md)。
- Qt、AndroidX/Kotlin 和动作图片的分发说明见 [`../docs/fittrack-third-party-notices.md`](../docs/fittrack-third-party-notices.md)。
- 可随包复制的许可正文与 Qt 对应源码/重新链接说明位于 [`licenses/`](licenses/)。
- 本地数据、权限、导出与医疗边界见 [`../docs/fittrack-privacy.md`](../docs/fittrack-privacy.md)。
- 未授权的抖音、B站、知乎视频或截图不得打包进 APK，也不提供媒体外链区域；只有自制、公共领域或明确允许再分发的开放许可素材可以内置。

## 已知平台边界

Android 前台服务、完成通知、系统返回层级、SAF 文档 URI、Adaptive Icon 和启动页已进入代码。应用已迁移到 Qt 6.11.1、`com.xuke.fittrack` 和 API 29/36；升级后的最终包仍需完成一加 Ace 5 Pro 上的完整训练、ColorOS 后台限制、通知允许/拒绝、锁屏完成提醒、SAF 导入导出、返回键、真实 TalkBack、系统大字体及同签名覆盖升级回归。正式分发只能使用用户长期保管的 Direct Release 密钥；Play AAB 使用独立上传密钥。
