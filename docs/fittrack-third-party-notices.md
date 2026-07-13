# FitTrack 第三方组件说明

更新时间：2026-07-14

本文记录 FitTrack 可侧载分享版本涉及的第三方组件。当前目标包含直接分享 APK，不包含应用商店上架；每次分发前仍需以实际 APK 和所用 Qt 版本重新核对依赖与媒体清单。

## Qt 6.9.1

FitTrack 使用 Qt Core、Gui、QML、Quick、Quick Controls 2、SQL、SVG，以及桌面调试版中的 Multimedia。Android 包以共享库形式部署 Qt，项目没有修改 Qt 源码。

开发环境中的 Qt 6.9.1 SBOM 将这些 Qt 模块声明为商业许可或 LGPL/GPL 许可组合。当前项目按 Qt 开源许可的 LGPL 3.0 路径分发，正式分发时必须保留 Qt 版权与许可通知、提供 LGPL 3.0 全文，并为接收者提供获取对应 Qt 6.9.1 源码和替换/重新链接 Qt 共享库所需的信息。

- [Qt 6.9 开源许可说明](https://doc.qt.io/qt-6.9/licensing.html)
- [Qt 6.9.1 源码归档](https://download.qt.io/archive/qt/6.9/6.9.1/submodules/)
- [GNU LGPL 3.0](https://www.gnu.org/licenses/lgpl-3.0.html)

Qt 自身还包含多种第三方组件。准确组件与许可证以所用 Qt 6.9.1 安装目录 `sbom/*.spdx.json` 为准；制作正式分发包时应从该 SBOM 生成完整通知，不应仅依赖本摘要。

## AndroidX 与 Kotlin 运行时

Qt Android 打包当前解析到 AndroidX Core 1.13.1 及其传递依赖，包括 AndroidX Annotation、Lifecycle、Profile Installer、Startup、Tracing、Kotlin 标准库和 kotlinx-coroutines。这些组件由 Android Gradle 构建链引入，主要按 Apache License 2.0 提供；正式分发包应包含相应通知和 Apache License 2.0 全文。

- [AndroidX 源码与许可](https://source.android.com/docs/setup/about/licenses)
- [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)

## 系统字体

生产应用不打包 Inter 或其他第三方字体，直接使用 Android/Windows 系统字体。测试进程在 Windows 离屏渲染时可加载开发机已有的微软雅黑，但该文件不会复制到源码或 APK，因此分发清单不包含 SIL OFL 字体项。

## 动作图片

应用当前 58 个动作各使用 1 张已审核图片，共 58 张：42 张开放许可/公共领域素材，16 张 FitTrack 原创 CC0 图。第三方素材涉及 CC BY 2.0、CC BY-SA 2.0、CC BY-SA 3.0、CC BY-SA 4.0 和美国联邦政府公共领域作品。逐项标题、作者/来源、原始页面、许可证和本地路径见 [`fittrack-media-credits.md`](fittrack-media-credits.md) 与 `fittrack/resources/data/exercise-media-shareable.json`。

- [Creative Commons Attribution 2.0](https://creativecommons.org/licenses/by/2.0/)
- [Creative Commons Attribution-ShareAlike 2.0](https://creativecommons.org/licenses/by-sa/2.0/)
- [Creative Commons Attribution-ShareAlike 3.0](https://creativecommons.org/licenses/by-sa/3.0/)
- [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)

所有内置图片均被统一缩放、裁切或补边并重新编码为 JPEG；原许可证与署名继续保留。MuscleDB 的 116 张本地图片、旧图片目录和国内视频平台素材不进入分发 APK。

## 分发前检查

- 使用发布产物实际解析依赖，不从开发机的全部 Qt 安装内容推断最终包内容。
- 将 LGPL 3.0、Apache 2.0 和图片所需的 Creative Commons 许可证全文放入分发包或配套许可目录。
- 保留 Qt 对应版本源码获取方式和动态链接说明。
- 任何新增动作图片都必须带作者、原始页面、许可证和本地资源路径。
- 确认 APK 只包含 `resources/images/exercises/shareable/` 对应的 58 张图，不包含 MuscleDB、旧动作图片或自定义字体资源。
