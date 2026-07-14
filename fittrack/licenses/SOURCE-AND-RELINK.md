# Qt 6.11.1 对应源码与重新链接说明

FitTrack 当前 Android APK 使用未修改的 Qt 6.11.1，并以独立共享库 `.so` 动态加载。
实际进入 APK 的 Qt 模块只有 `qtbase`、`qtdeclarative` 和 `qtsvg`；分发包附带这三个
模块的 SPDX SBOM，用于固定版本、源提交、第三方组件及许可证据。

对应源码可从 Qt 官方归档取得：

- https://download.qt.io/archive/qt/6.11/6.11.1/submodules/qtbase-everywhere-src-6.11.1.tar.xz
- https://download.qt.io/archive/qt/6.11/6.11.1/submodules/qtdeclarative-everywhere-src-6.11.1.tar.xz
- https://download.qt.io/archive/qt/6.11/6.11.1/submodules/qtsvg-everywhere-src-6.11.1.tar.xz

FitTrack 应用源码和可重复构建脚本位于：

- https://github.com/54xkeee/fittrack
- `fittrack/scripts/build-android.ps1`

接收者可以使用兼容的 Android NDK 与 Qt 6.11.1 源码重新构建上述共享库，解包 APK 后
替换 `lib/<abi>/libQt6*.so` 及对应的 `libplugins_*`、`libqml_*` Qt 插件，再重新打包、对齐并使用自己的密钥
签名。Android 要求修改后的 APK 重新签名；当前 Debug 签名不限制接收者执行替换或
运行自行签名的版本。`scripts/package-side-load.ps1` 生成的分发说明会记录应用 Git
提交、APK 哈希、Qt SBOM 和 Android NDK NOTICE 的哈希，便于确认所对应的构建。

Qt 许可正文见 `texts/LGPL-3.0-only.txt` 和 `texts/GPL-3.0-only.txt`。Qt 自身及其
第三方代码的准确版权与许可表达式以随包 SBOM、`THIRD-PARTY-NOTICES.md` 和
`texts/` 中的对应正文为准。
