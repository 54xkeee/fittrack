# FitTrack 第三方组件说明

更新时间：2026-07-13

本文是直接分享 FitTrack APK 时的第三方组件清单。正式分发压缩包应同时包含本文、动作图片署名清单和相应许可证全文。

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

## Inter Variable

应用内置 Inter Variable 字体，用于英文、数字和单位显示。字体按 SIL Open Font License 1.1 提供，许可证全文已保存在 `fittrack/resources/fonts/Inter-OFL.txt`。

- [Inter 项目](https://github.com/rsms/inter)
- [SIL Open Font License 1.1](https://openfontlicense.org/open-font-license-official-text/)

## 动作图片

应用当前内置 28 张来自 Wikimedia Commons 的开放许可或公共领域图片。逐项作者、来源 URL、许可证和修改说明见 [`fittrack-media-credits.md`](fittrack-media-credits.md)。

## 分发前检查

- 使用发布产物实际解析依赖，不从开发机的全部 Qt 安装内容推断最终包内容。
- 将 LGPL 3.0、Apache 2.0、SIL OFL 1.1 和图片所需的 Creative Commons 许可证全文放入分发压缩包。
- 保留 Qt 对应版本源码获取方式和动态链接说明。
- 任何新增动作图片都必须带作者、原始页面、许可证和本地资源路径。
- 不把抖音、B站、知乎等平台的未授权截图或视频帧加入分发包。
