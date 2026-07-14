# FitTrack 分发许可包

本目录保存 FitTrack Android 侧载包所需的许可正文。`scripts/package-side-load.ps1`
会把这些文件与实际构建所用 Qt 6.9.1 SBOM、Android NDK NOTICE、组件通知和媒体
署名一起复制到分发目录，并生成逐文件 SHA-256 清单。

本清单按当前 APK 中实际存在的组件收口，不包含未打包的 Qt Multimedia、OpenSSL、
Inter 字体、MuscleDB 图片或纯构建工具。

## 正文与用途

- `LGPL-3.0-only.txt`、`GPL-3.0-only.txt`：Qt 6.9.1 开源分发路径。
- `Apache-2.0.txt`：AndroidX、Kotlin、kotlinx.coroutines，以及 Android NDK LLVM 组件。
- `BSD-*`、`MIT*`、`FTL.txt`、`Libpng.txt`、`libpng-2.0.txt`、`IJG.txt`、
  `Zlib.txt`、`MPL-2.0.txt`、`Imlib2.txt`、`X11.txt`、`HPND*.txt`、
  `Unicode-3.0.txt`、`LicenseRef-*`、`blessing.txt`：Qt 内嵌第三方代码；准确组件、
  版本和版权声明以分发包中的三个 Qt SBOM 为准。
- `CC-BY-2.0.txt`、`CC-BY-SA-2.0.txt`、`CC-BY-SA-3.0.txt`、
  `CC-BY-SA-4.0.txt`、`CC0-1.0.txt`：内置动作图片。

## 来源

Qt/SPDX 正文来自本项目构建所用 Qt 6.9.1 安装的许可证目录；Creative Commons
与 `HPND-sell-variant` 正文取自 SPDX License List Data，并保留对应许可证的原始
英文法律文本。Creative Commons 的规范页面为：

- https://creativecommons.org/licenses/by/2.0/legalcode
- https://creativecommons.org/licenses/by-sa/2.0/legalcode
- https://creativecommons.org/licenses/by-sa/3.0/legalcode
- https://creativecommons.org/licenses/by-sa/4.0/legalcode
- https://creativecommons.org/publicdomain/zero/1.0/legalcode

这些文件用于保留原始许可与署名，不构成法律意见。扩大公开分发范围前仍应由发布者
依据最终 APK、签名方式和分发地区进行合规复核。
