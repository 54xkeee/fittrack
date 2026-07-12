# 训迹 FitTrack

FitTrack 是一个面向 Android 的个人健身训练记录与分析应用。当前桌面开发版已完成训练记录闭环、谭成义三分化与自由训练、个人计划、训练历史、容量与 e1RM 分析、健身房/器械区分，以及 32 个动作的离线资料库。

## 当前可用能力

- 首页根据最近完成的谭成义训练日显示下一训练日，并可直接开始或继续训练。
- 正式组支持重量、次数、力竭、备注和短休追加组；完成后立即写入 SQLite。
- 自重动作明确区分纯自重、附加负重和辅助重量；只有附加负重计入外加负重容量，三者均不计算 e1RM。
- 休息倒计时支持 2/3/5 分钟、自定义、暂停、继续、重置和提前结束；窗口最小化或切换后台后按绝对截止时间校准，结束播放一次程序生成的提示音。
- 首页和分析页显示 7 天、30 天、全部历史的训练次数、正式组、容量、最高重量、对应次数与组数、e1RM 和肌群分布。
- 动作库提供 32 个动作的简介、主要/次要肌群、4 步动作说明、3 条核心注意点和训练参数；其中 20 个动作内置许可明确的离线图片，其他动作不使用许可不明的替代素材。

当前自动化测试共 9 项，覆盖统计规则、SQLite、种子导入、训练会话、历史、分析、动作详情数据和倒计时状态。

完整里程碑见 [`../docs/fittrack-development-plan.md`](../docs/fittrack-development-plan.md)。

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

## Android 状态

项目结构采用 Qt Quick/QML + CMake，能够继续配置 Qt for Android。当前机器尚未安装 Qt Android ABI、Android SDK/NDK/JDK，因此尚未生成 APK。Android 目标固定为 `arm64-v8a`，包名暂定 `com.fittrack.app`。

## 数据与媒体

- 内置动作 JSON 位于 `resources/data/exercises-*.json`。
- 谭成义三分化模板位于 `resources/data/tan-three-day-split.json`。
- 内置动作会在应用启动时事务化导入 SQLite。
- 动作图片位于 `resources/images/exercises/`，每张图片的原始链接和许可记录在对应动作 JSON 的 `media` 字段中。
- 当前内置 20 张开放许可或公共领域图片；找不到动作准确且许可明确素材的条目保持无图。
- 未授权的抖音、B站、知乎视频或截图不得打包进 APK；只允许外链。自制、明确授权或开放许可素材才可内置。

## 已知平台边界

当前“后台计时”指桌面窗口最小化或应用失去焦点后继续按绝对截止时间运行并在恢复时校准。Android 系统级前台服务、锁屏通知和后台播放将在 Android 工具链阶段实现，当前不宣称已经完成。
