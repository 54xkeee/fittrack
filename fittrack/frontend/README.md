# FitTrack React UI

This directory contains a frozen React workout prototype for visual experiments.
It is not part of the production training flow.

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

The native QML workout is the production renderer. The React page can only be
selected explicitly for desktop prototype work with the WebEngine option.

The Android WebView bridge is intentionally disabled by default. Do not enable
it for production builds while the Material 3 interaction architecture is being
consolidated around the native QML workout flow.
