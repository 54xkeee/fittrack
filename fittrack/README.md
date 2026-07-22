# FitTrack 应用源码

主项目说明、截图和下载入口见 [仓库首页](../README.md)。

## 构建 Android APK

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-android.ps1
```

默认生成 Android ARM64 Debug APK：

```text
build-android-arm64-debug/android-build/fittrack.apk
```

## 运行测试

```powershell
cmake --build D:\FitTrackBuild\windows-qt6.11.1 -j 1
ctest --test-dir D:\FitTrackBuild\windows-qt6.11.1 --output-on-failure
```

架构说明见 [ARCHITECTURE.md](ARCHITECTURE.md)，Android 工具链说明见 [fittrack-android-build.md](../docs/fittrack-android-build.md)。
