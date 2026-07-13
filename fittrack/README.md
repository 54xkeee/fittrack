# 训迹 FitTrack

FitTrack 是一个面向 Android 的个人健身训练记录与分析应用，当前交付目标是供用户本人长期使用，并可把 APK 直接分享给其他用户侧载安装。源码已完成训练记录闭环、谭成义三分化与自由训练、个人计划管理、训练历史、容量与 e1RM 分析、有氧记录、健身房/器械区分、备份恢复，以及 58 个动作的离线资料库，并能构建 Windows 调试版和 Android `arm64-v8a` Debug/Release 包。

## 当前可用能力

- 首页根据按时间倒序的最新已完成谭成义训练日显示下一训练日，并可直接开始或继续训练。
- 首页、计划页和训练空态统一先进入不落库的训练准备页；可预览动作、调整组数/逐组次数/间歇、添加/替换/排序动作、恢复进入准备时的默认值，并选择仅开始本次训练或保存为个人计划。
- 计划页展示只读的谭成义三分化，支持一键复制为可编辑个人版；个人计划和训练日可以创建、重命名、删除，训练日支持动作分组、添加、替换、参数编辑、单段有氧目标，以及在独立排序弹层中拖动或上移/下移后直接开始训练。
- 正式组支持逐组目标次数、重量、实际次数、力竭、备注和短休追加组；完成后立即写入 SQLite。目标次数只由用户修改，不触发重量或次数建议。
- 自重动作明确区分纯自重、附加负重和辅助重量；只有附加负重计入外加负重容量，三者均不计算 e1RM。
- 训练中的已完成组和历史详情中的组都可以修正重量、次数、力竭与自重负荷类型；历史训练支持二次确认后整次删除，统计会立即刷新。
- 完成力量训练后先展示正式组、容量、最高重量、e1RM 和肌群总结，再由用户选择完成或继续添加有氧，不强制跳转。
- 休息倒计时支持 2/3/5 分钟、自定义、暂停、继续、重置和提前结束；桌面端按绝对截止时间校准并播放一次程序生成的提示音，Android 端使用前台服务显示后台倒计时并在自然结束时发送一次系统提示音通知。
- 首页和分析页显示 7 天、30 天、全部历史的训练次数、正式组、容量、最高重量、对应次数与组数、e1RM 和肌群分布。
- 有氧页支持跑步机爬坡与爬楼机记录；首页只读取最新记录，进入有氧页首批加载 50 条并可继续分页，趋势固定展示最近 30 次。跑步机默认模板为坡度 9、速度 5 km/h、30 分钟。有氧可单独记录，也可附加到刚完成的力量训练。
- 场馆管理支持健身房与具体器械的新增、重命名和删除；被历史记录引用的条目会归档而不是破坏历史数据。
- 数据管理支持 JSON 完整备份/事务恢复和 SQLite 快照导出；Android 支持通过系统文档选择器的 `content://` URI 导入导出。JSON 包含计划有氧与训练快照，仍兼容缺少这两张表的旧版备份；恢复会限制 64MB 输入、进行外键完整性检查，并刷新所有内存状态。
- 动作库提供 58 个目标动作的简介、主要/次要肌群、步骤、注意事项和训练参数；其中 29 个核心动作额外提供发力要点和常见错误，其余为标准资料。每项展示 1 张经过动作对应性审核的本地图片，并在详情中显示素材标题、来源和许可证；42 张来自开放许可或公共领域，16 张为 FitTrack 原创 CC0。内置动作可收藏和恢复默认，用户可创建、编辑及删除自定义动作；应用不提供教学视频或媒体外链入口。
- 底部导航固定为首页、计划、训练、动作和分析五个入口；历史、有氧和管理合并在分析入口内。
- Graphite & Lime 设计系统已经提取为语义主题与通用组件，统一线性图标由 `AppIcon` 使用 `PathSvg` 绘制，不再依赖 Unicode 字符图标。底部导航、首页、训练、计划、动作库、趋势、历史、有氧和管理页面均已纳入移动单列体系；准备页与训练页长标题可响应换行，计划/训练动作预览保持至少 48 logical px，训练动作卡提供可见键盘焦点。
- 应用不再内置字体，直接继承 Android、Windows 等平台的系统字体；Android 字体缩放会统一映射到设计令牌，训练主流程和弹层已自动化验证 1.0、1.3、1.5 和 2.0 倍字体。

当前自动化测试共 15 项，覆盖统计规则、SQLite、种子导入、训练会话、历史、分析、计划管理、动作库管理、有氧、健身房/器械、备份恢复、性能 SQL 门禁、倒计时状态和真实 QML 页面加载。QML 回归额外覆盖训练准备零写入、动作详情真实打开、参数保存/恢复、稳定 ID 排序、字符图标门禁、TalkBack 语义、计划/训练动作预览 48dp、训练动作卡焦点、长标题不截断、1.0/1.3/1.5/2.0 四档字体和真实触摸输入。

当前数据库结构版本为 SQLite v8。同版本启动使用版本快路径；旧库仍会幂等补列、建索引和触发器，既有用户数据会保留。

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

QML 导航测试会把五个主页面、可编辑个人计划、训练日有氧弹层、训练进行中、目标次数弹层、训练完成总结、历史详情、有氧、管理和带真实训练数据的分析页分别按 360×800、420×920、480×1056 写入 `C:\FitTrackDev\fittrack\build\visual`。默认使用 `offscreen` 与软件渲染，可直接在无交互窗口的测试环境运行；如需检查本机图形后端可使用：

```powershell
$env:QT_QPA_PLATFORM = "windows"
$env:QSG_RHI_BACKEND = "d3d11"
ctest --test-dir C:\FitTrackDev\fittrack\build -R qmlnavigation --output-on-failure
```

## Android 状态

本机已经配置 Qt 6.9.1 Android `arm64-v8a`、JDK 17、Android SDK 35、Build Tools 35.0.0 和 NDK r27c。统一构建入口：

```powershell
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 -Configuration Release
powershell -ExecutionPolicy Bypass -File C:\FitTrackDev\fittrack\scripts\build-android.ps1 -Configuration Release -Bundle
```

脚本分别输出 Debug APK、无签名 Release APK 或无签名 Release AAB。当前包名为 `com.fittrack.app`，min API 28，target/compile API 35，仅包含 `arm64-v8a`；当前源码的 Debug APK 已通过 Android Lint（0 issue）、清单/ABI/最小权限检查、V2 调试签名验证和包内媒体白名单检查。`dist` 中的旧产物不能代表当前提交，正式分享前必须从当前提交重新生成并核验哈希。Release APK/AAB 的外部环境变量签名流程已用一次性测试密钥验证；若要保证跨版本覆盖升级，仍需创建并长期保管发布密钥。

完整工具链、Lint、APK 检查和真机命令见 [`../docs/fittrack-android-build.md`](../docs/fittrack-android-build.md)。

## 数据与媒体

- 内置动作 JSON 位于 `resources/data/exercises-*.json`。
- 谭成义三分化模板位于 `resources/data/tan-three-day-split.json`。
- 内置动作会在应用启动时事务化导入 SQLite。
- 可分发动作图片位于 `resources/images/exercises/shareable/`，58 个动作各 1 张，统一为 900×600 JPEG。
- 机器可读的媒体标题、来源页面、作者/来源、许可证和应用内路径位于 `resources/data/exercise-media-shareable.json`，并同步进入对应动作 JSON 的 `media` 字段。
- MuscleDB 只保留为动作文字映射参考；其图片目录和旧动作图片不会被 CMake 打包进 APK。应用也不再打包 Inter 字体。
- 数据映射见 [`../docs/fittrack-exercise-mapping.md`](../docs/fittrack-exercise-mapping.md)，媒体用途限制见 [`../docs/fittrack-media-credits.md`](../docs/fittrack-media-credits.md)。
- Qt、AndroidX/Kotlin 和动作图片的分发说明见 [`../docs/fittrack-third-party-notices.md`](../docs/fittrack-third-party-notices.md)。
- 本地数据、权限、导出与医疗边界见 [`../docs/fittrack-privacy.md`](../docs/fittrack-privacy.md)。
- 未授权的抖音、B站、知乎视频或截图不得打包进 APK，也不提供媒体外链区域；只有自制、公共领域或明确允许再分发的开放许可素材可以内置。

## 已知平台边界

Android 前台服务、完成通知、系统返回层级、SAF 文档 URI、Adaptive Icon 和启动页已进入代码并通过离线构建检查。当前 Debug APK 可作为侧载测试版分享，但尚未在一加 Ace 5 Pro 上完成安装和运行回归；ColorOS 后台限制、通知允许/拒绝、锁屏完成提醒、SAF 导入导出、返回键、真实 TalkBack 和系统大字体仍不能写成真机已验收。无签名 Release 产物不能安装；长期分发与覆盖升级需要固定发布密钥。
