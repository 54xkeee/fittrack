param(
    [string]$ToolchainRoot = "D:\FitTrackToolchains",
    [string]$BuildDirectory = "",
    [switch]$Bundle
)

$ErrorActionPreference = "Stop"

$sourceDirectory = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $BuildDirectory = Join-Path $sourceDirectory "build-android-arm64"
}

$qtRoot = Join-Path $ToolchainRoot "Qt\6.9.1\android_arm64_v8a"
$hostQtRoot = Join-Path $ToolchainRoot "Qt\6.9.1\mingw_64"
$sdkRoot = Join-Path $ToolchainRoot "AndroidSdk"
$ndkRoot = Join-Path $sdkRoot "ndk\27.2.12479018"
$jdkRoot = Get-ChildItem (Join-Path $ToolchainRoot "jdk17") -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1 -ExpandProperty FullName
$qtCmake = Join-Path $qtRoot "bin\qt-cmake.bat"
$ninja = (Get-Command ninja.exe -ErrorAction Stop).Source

foreach ($requiredPath in @($qtCmake, $hostQtRoot, $sdkRoot, $ndkRoot, $jdkRoot, $ninja)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "缺少 Android 构建依赖：$requiredPath"
    }
}

$packageDirectory = Join-Path $BuildDirectory "android-build"
if (Test-Path -LiteralPath $packageDirectory) {
    $resolvedBuild = [System.IO.Path]::GetFullPath($BuildDirectory)
    $resolvedPackage = (Resolve-Path -LiteralPath $packageDirectory).Path
    if (-not $resolvedPackage.StartsWith(
            $resolvedBuild + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "拒绝清理构建目录之外的路径：$resolvedPackage"
    }
    Remove-Item -LiteralPath $resolvedPackage -Recurse -Force
}

$env:JAVA_HOME = $jdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_NDK_ROOT = $ndkRoot
$env:PATH = "$(Join-Path $jdkRoot 'bin');$(Join-Path $sdkRoot 'platform-tools');$env:PATH"

& $qtCmake `
    -S $sourceDirectory `
    -B $BuildDirectory `
    -G Ninja `
    "-DCMAKE_MAKE_PROGRAM=$ninja" `
    "-DANDROID_SDK_ROOT=$sdkRoot" `
    "-DANDROID_NDK_ROOT=$ndkRoot" `
    "-DQT_HOST_PATH=$hostQtRoot" `
    -DANDROID_PLATFORM=android-28 `
    -DCMAKE_BUILD_TYPE=Debug `
    -DBUILD_TESTING=OFF
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$target = if ($Bundle) { "aab" } else { "apk" }
& cmake --build $BuildDirectory --target $target --parallel 6
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# androiddeployqt writes a valid Gradle path whose drive colon Android Lint still
# treats as an unescaped Java-properties separator. Normalize the generated file
# after packaging so the same directory can run lint without false errors.
$localProperties = Join-Path $packageDirectory "local.properties"
if (Test-Path -LiteralPath $localProperties) {
    $escapedSdkRoot = $sdkRoot.Replace("\", "/").Replace(":", "\:")
    Set-Content -LiteralPath $localProperties -Value "sdk.dir=$escapedSdkRoot" -Encoding ascii
}

exit 0
