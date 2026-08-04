# FitTrack React UI

This directory contains the React presentation layer used by the optional
Qt WebEngine workout page.

```powershell
cd fittrack/frontend
npm install
npm run build
```

After the bundle exists in `frontend/dist`, configure FitTrack with:

```powershell
cmake -S fittrack -B BUILD_DIR `
  -DFITTRACK_ENABLE_REACT_WEBENGINE=ON `
  -DCMAKE_PREFIX_PATH=QT_PREFIX
```

The native QML workout remains the default. The React page is selected only
when the WebEngine feature is compiled in, so the current application stays
buildable while the WebEngine and WebChannel Qt modules are being installed.

Qt WebEngine is used only by the Windows prototype. The Android APK requires
the system Android WebView integration rather than Qt WebEngine; that bridge is
the next migration stage.
