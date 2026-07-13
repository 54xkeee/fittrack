param(
    [string]$ToolchainRoot = "D:\FitTrackToolchains",
    [string]$BuildDirectory = "",
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",
    [switch]$Bundle,
    [switch]$Sign
)

$ErrorActionPreference = "Stop"

$sourceDirectory = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $directoryName = if ($Configuration -eq "Release") {
        "build-android-arm64-release"
    } else {
        "build-android-arm64"
    }
    $BuildDirectory = Join-Path $sourceDirectory $directoryName
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
        throw "Missing Android build dependency: $requiredPath"
    }
}

$signVariable = $null
if ($Sign) {
    $requiredSigningVariables = @(
        "QT_ANDROID_KEYSTORE_PATH",
        "QT_ANDROID_KEYSTORE_ALIAS",
        "QT_ANDROID_KEYSTORE_STORE_PASS",
        "QT_ANDROID_KEYSTORE_KEY_PASS"
    )
    foreach ($variableName in $requiredSigningVariables) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($variableName))) {
            throw "Signing requires environment variable: $variableName"
        }
    }
    $signVariable = if ($Bundle) { "QT_ANDROID_SIGN_AAB" } else { "QT_ANDROID_SIGN_APK" }
}

$env:JAVA_HOME = $jdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_NDK_ROOT = $ndkRoot
$env:PATH = "$(Join-Path $jdkRoot 'bin');$(Join-Path $sdkRoot 'platform-tools');$env:PATH"

$packageDirectory = Join-Path $BuildDirectory "android-build"
if (Test-Path -LiteralPath $packageDirectory) {
    $resolvedBuild = [System.IO.Path]::GetFullPath($BuildDirectory)
    $resolvedPackage = (Resolve-Path -LiteralPath $packageDirectory).Path
    if (-not $resolvedPackage.StartsWith(
            $resolvedBuild + [System.IO.Path]::DirectorySeparatorChar,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean outside build directory: $resolvedPackage"
    }
    $gradleWrapper = Join-Path $resolvedPackage "gradlew.bat"
    if (Test-Path -LiteralPath $gradleWrapper) {
        Push-Location $resolvedPackage
        try {
            & $gradleWrapper --stop | Out-Host
        } finally {
            Pop-Location
        }
    }
    Remove-Item -LiteralPath $resolvedPackage -Recurse -Force
}

$cmakeArguments = @(
    "-S", $sourceDirectory,
    "-B", $BuildDirectory,
    "-G", "Ninja",
    "-DCMAKE_MAKE_PROGRAM=$ninja",
    "-DANDROID_SDK_ROOT=$sdkRoot",
    "-DANDROID_NDK_ROOT=$ndkRoot",
    "-DQT_HOST_PATH=$hostQtRoot",
    "-DANDROID_PLATFORM=android-28",
    "-DCMAKE_BUILD_TYPE=$Configuration",
    "-DQT_ANDROID_SIGN_AAB=OFF",
    "-DQT_ANDROID_SIGN_APK=OFF",
    "-DBUILD_TESTING=OFF"
)

if ($signVariable) {
    $cmakeArguments += "-D$signVariable=ON"
}

& $qtCmake @cmakeArguments
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

$variant = $Configuration.ToLowerInvariant()
if ($Bundle) {
    $artifact = Join-Path $packageDirectory "build\outputs\bundle\$variant\android-build-$variant.aab"
} else {
    $apkDirectory = Join-Path $packageDirectory "build\outputs\apk\$variant"
    $artifact = Get-ChildItem -LiteralPath $apkDirectory -Filter "*.apk" -File |
        Sort-Object Name |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $artifact -or -not (Test-Path -LiteralPath $artifact)) {
    throw "Build succeeded but no $Configuration artifact was found"
}

Write-Host "FitTrack $Configuration artifact: $artifact"

exit 0
