# FitTrack 第三方组件说明

更新时间：2026-07-14

本文记录 FitTrack 可侧载分享版本涉及的第三方组件。当前目标包含直接分享 APK，不包含应用商店上架；每次分发前仍需以实际 APK 和所用 Qt 版本重新核对依赖与媒体清单。

## Qt 6.9.1

FitTrack Android 包实际包含 Qt `qtbase`、`qtdeclarative`、`qtsvg` 6.9.1：Core、Gui、Network、OpenGL、SQL、QML、Quick、Quick Controls 2、Layouts、Dialogs、Effects、Shapes 和 SVG 等运行库及插件。Qt 以共享库形式部署，项目没有修改 Qt 源码；桌面调试会使用的 Multimedia 没有进入当前 Android APK。

开发环境中的 Qt 6.9.1 SBOM 将这些 Qt 模块声明为商业许可或 LGPL/GPL 许可组合。当前项目按 Qt 开源许可的 LGPL 3.0 路径分发，正式分发时必须保留 Qt 版权与许可通知、提供 LGPL 3.0 全文，并为接收者提供获取对应 Qt 6.9.1 源码和替换/重新链接 Qt 共享库所需的信息。

- [Qt 6.9 开源许可说明](https://doc.qt.io/qt-6.9/licensing.html)
- [Qt 6.9.1 源码归档](https://download.qt.io/archive/qt/6.9/6.9.1/submodules/)
- [GNU LGPL 3.0](https://www.gnu.org/licenses/lgpl-3.0.html)

Qt 自身还包含 PCRE2 10.45、libpng 1.6.48、libjpeg-turbo 3.1.0、FreeType 2.13.3、HarfBuzz 11.2.1、SQLite 3.49.2、QML MASM、Material shadow 等第三方代码。准确组件、版权和许可证表达式以随侧载包提供的 `qtbase`、`qtdeclarative`、`qtsvg` 三份 Qt 6.9.1 SPDX SBOM 为准；许可正文位于同包 `licenses/texts/`，不能只依赖本摘要。

## AndroidX 与 Kotlin 运行时

Qt Android 打包当前解析到 AndroidX Core 1.13.1、VersionedParcelable 1.1.1、Lifecycle 2.6.2、Arch Core 2.2.0、Profile Installer 1.3.0、Startup 1.1.1、Tracing 1.0.0、Annotation 1.6.0/Experimental 1.4.0，以及 Kotlin 1.8.22、kotlinx.coroutines 1.6.4、ListenableFuture 1.0 和 JetBrains Annotations 13.0。这些 Gradle 运行时依赖按 Apache License 2.0 提供；侧载包包含该许可全文。

- [AndroidX 源码与许可](https://source.android.com/docs/setup/about/licenses)
- [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)

## Android NDK 运行时

APK 包含 Android NDK r27c（27.2.12479018）构建的 `libc++_shared.so`，对应 LLVM/Clang 18.0.3，许可为 Apache License 2.0 with LLVM exception，并包含历史组件声明。侧载包原样附带该 NDK 工具链的 `NOTICE`，其内容和 SHA-256 会进入分发清单。

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

## 分发许可包

`fittrack/scripts/package-side-load.ps1` 会从当前 APK 生成干净的 Debug 侧载目录，校验包名、版本、Debug 证书、v2 签名和 APK 哈希，并附带：

- 本说明、逐项媒体署名与 `exercise-media-shareable.json`；
- LGPL 3.0、GPL 3.0、Apache 2.0、五种 Creative Commons 及 Qt 内嵌第三方代码所需正文；
- Qt 对应源码与重新链接说明；
- 三份实际 Qt 模块 SBOM 和 Android NDK LLVM NOTICE；
- 对目录内全部文件生成的 SHA-256 清单。

这些材料用于保留通知和复核证据，不构成法律意见。扩大公开分发范围前仍应按最终构建及分发地区复核。

## 分发前检查

- 使用发布产物实际解析依赖，不从开发机的全部 Qt 安装内容推断最终包内容。
- 运行 `scripts/package-side-load.ps1`，确认许可正文、SBOM、NDK NOTICE 和 SHA-256 清单完整生成。
- 保留 Qt 对应版本源码获取方式和动态链接说明。
- 任何新增动作图片都必须带作者、原始页面、许可证和本地资源路径。
- 确认 APK 只包含 `resources/images/exercises/shareable/` 对应的 58 张图，不包含 MuscleDB、旧动作图片或自定义字体资源。
