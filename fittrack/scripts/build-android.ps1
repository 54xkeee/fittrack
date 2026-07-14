param(
    [string]$ToolchainRoot = "D:\FitTrackToolchains",
    [string]$SourceDirectory = "",
    [string]$BuildDirectory = "",
    [string]$QtVersion = "6.11.1",
    [string]$NdkVersion = "27.2.12479018",
    [string]$BuildToolsVersion = "36.0.0",
    [ValidateSet("arm64-v8a", "x86_64")]
    [string]$Abi = "arm64-v8a",
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",
    [ValidateRange(1, 2100000000)]
    [int]$VersionCode = 1,
    [switch]$Bundle,
    [switch]$Sign,
    [string]$SigningProfile = "",
    [string]$SigningConfig = ""
)

$ErrorActionPreference = "Stop"

if ($Sign -and $Configuration -ne "Release") {
    throw "Formal signing is only supported for Release builds"
}
if ($Bundle -and $Configuration -ne "Release") {
    throw "AAB output is only supported for Release builds"
}

$projectDirectory = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
    $sourceDirectory = $projectDirectory
} else {
    $sourceDirectory = (Resolve-Path -LiteralPath $SourceDirectory).Path
}
$abiDirectory = if ($Abi -eq "arm64-v8a") { "arm64" } else { "x86_64" }
if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $directoryName = "build-android-$abiDirectory-$($Configuration.ToLowerInvariant())"
    $BuildDirectory = Join-Path $sourceDirectory $directoryName
}

$qtArchitecture = if ($Abi -eq "arm64-v8a") { "android_arm64_v8a" } else { "android_x86_64" }
$qtRoot = Join-Path $ToolchainRoot "Qt\$QtVersion\$qtArchitecture"
$hostQtRoot = Join-Path $ToolchainRoot "Qt\$QtVersion\mingw_64"
$sdkRoot = Join-Path $ToolchainRoot "AndroidSdk"
$ndkRoot = Join-Path $sdkRoot "ndk\$NdkVersion"
$jdkRoot = Get-ChildItem (Join-Path $ToolchainRoot "jdk21") -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1 -ExpandProperty FullName
$qtCmake = Join-Path $qtRoot "bin\qt-cmake.bat"
$ninja = (Get-Command ninja.exe -ErrorAction Stop).Source

foreach ($requiredPath in @($qtCmake, $hostQtRoot, $sdkRoot, $ndkRoot, $jdkRoot, $ninja)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Missing Android build dependency: $requiredPath"
    }
}

if ($Sign) {
    if ([string]::IsNullOrWhiteSpace($SigningProfile)) {
        $SigningProfile = if ($Bundle) { "PlayUpload" } else { "Direct" }
    }
    if ($SigningProfile -notin @("Direct", "PlayUpload")) {
        throw "SigningProfile must be Direct or PlayUpload"
    }
    if ($Bundle -and $SigningProfile -ne "PlayUpload") {
        throw "AAB releases must use the PlayUpload signing profile"
    }
    if (-not $Bundle -and $SigningProfile -ne "Direct") {
        throw "Direct APK releases must use the Direct signing profile"
    }

    if ([string]::IsNullOrWhiteSpace($SigningConfig)) {
        $SigningConfig = Join-Path $sourceDirectory "config\android-signing.local.ps1"
    }
    $activeProfile = $env:FITTRACK_ANDROID_SIGNING_PROFILE
    if ((Test-Path -LiteralPath $SigningConfig -PathType Leaf) -and
            ([string]::IsNullOrWhiteSpace($env:QT_ANDROID_KEYSTORE_PATH) -or
             $activeProfile -ne $SigningProfile)) {
        . $SigningConfig
        if (-not (Get-Command Use-FitTrackAndroidSigning -ErrorAction SilentlyContinue)) {
            throw "Signing config must define Use-FitTrackAndroidSigning"
        }
        Use-FitTrackAndroidSigning $SigningProfile
    }

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
    if (-not (Test-Path -LiteralPath $env:QT_ANDROID_KEYSTORE_PATH -PathType Leaf)) {
        throw "Signing keystore not found: $env:QT_ANDROID_KEYSTORE_PATH"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:FITTRACK_ANDROID_SIGNING_PROFILE) -and
            $env:FITTRACK_ANDROID_SIGNING_PROFILE -ne $SigningProfile) {
        throw "Active signing profile is $env:FITTRACK_ANDROID_SIGNING_PROFILE, expected $SigningProfile"
    }
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
    $longPackagePath = "\\?\$resolvedPackage"
    try {
        [System.IO.Directory]::Delete($longPackagePath, $true)
    } catch [System.IO.IOException] {
        $gradleWrapper = Join-Path $resolvedPackage "gradlew.bat"
        if (-not (Test-Path -LiteralPath $gradleWrapper)) {
            throw
        }
        Push-Location $resolvedPackage
        try {
            & $gradleWrapper --stop | Out-Host
        } finally {
            Pop-Location
        }
        [System.IO.Directory]::Delete($longPackagePath, $true)
    }
}

$cmakeArguments = @(
    "-S", $sourceDirectory,
    "-B", $BuildDirectory,
    "-G", "Ninja",
    "-DCMAKE_MAKE_PROGRAM=$ninja",
    "-DANDROID_SDK_ROOT=$sdkRoot",
    "-DANDROID_NDK_ROOT=$ndkRoot",
    "-DQT_HOST_PATH=$hostQtRoot",
    "-DANDROID_ABI=$Abi",
    "-DANDROID_PLATFORM=android-29",
    "-DFITTRACK_ANDROID_VERSION_CODE=$VersionCode",
    "-DCMAKE_BUILD_TYPE=$Configuration",
    "-DQT_ANDROID_SIGN_AAB=OFF",
    "-DQT_ANDROID_SIGN_APK=OFF",
    "-DBUILD_TESTING=OFF"
)

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

if ($Bundle) {
    $variant = $Configuration.ToLowerInvariant()
    $aabDirectory = Join-Path $packageDirectory "build\outputs\bundle\$variant"
    $artifact = Get-ChildItem -LiteralPath $aabDirectory -Filter "*.aab" -File |
        Sort-Object Name |
        Select-Object -First 1 -ExpandProperty FullName
} else {
    $artifact = Join-Path $packageDirectory "fittrack.apk"
}
if (-not $artifact -or -not (Test-Path -LiteralPath $artifact)) {
    throw "Build succeeded but no $Configuration artifact was found"
}

if ($Sign) {
    $signedArtifact = Join-Path $packageDirectory (
        "fittrack-signed" + [IO.Path]::GetExtension($artifact))
    if ($Bundle) {
        $jarsigner = Join-Path $jdkRoot "bin\jarsigner.exe"
        $signingOutput = @(& $jarsigner `
            -sigalg SHA256withRSA `
            -digestalg SHA-256 `
            -keystore $env:QT_ANDROID_KEYSTORE_PATH `
            "-storepass:env" QT_ANDROID_KEYSTORE_STORE_PASS `
            "-keypass:env" QT_ANDROID_KEYSTORE_KEY_PASS `
            -signedjar $signedArtifact `
            $artifact `
            $env:QT_ANDROID_KEYSTORE_ALIAS 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "AAB signing failed: $($signingOutput -join [Environment]::NewLine)"
        }
    } else {
        $buildToolsDirectory = Join-Path $sdkRoot "build-tools\$BuildToolsVersion"
        $zipalign = Join-Path $buildToolsDirectory "zipalign.exe"
        $apksigner = Join-Path $buildToolsDirectory "apksigner.bat"
        foreach ($tool in @($zipalign, $apksigner)) {
            if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
                throw "Required APK signing tool not found: $tool"
            }
        }

        $alignedArtifact = Join-Path $packageDirectory "fittrack-aligned.apk"
        try {
            & $zipalign -f -P 16 4 $artifact $alignedArtifact
            if ($LASTEXITCODE -ne 0) { throw "APK zipalign failed" }
            & $apksigner sign `
                --ks $env:QT_ANDROID_KEYSTORE_PATH `
                --ks-pass "env:QT_ANDROID_KEYSTORE_STORE_PASS" `
                --key-pass "env:QT_ANDROID_KEYSTORE_KEY_PASS" `
                --ks-key-alias $env:QT_ANDROID_KEYSTORE_ALIAS `
                --out $signedArtifact `
                $alignedArtifact
            if ($LASTEXITCODE -ne 0) { throw "APK signing failed" }
        } finally {
            if (Test-Path -LiteralPath $alignedArtifact) {
                Remove-Item -LiteralPath $alignedArtifact -Force
            }
        }
    }
    $artifact = $signedArtifact
}

Write-Host "FitTrack $Configuration artifact: $artifact"

if ($Configuration -eq "Release" -and $Sign) {
    $verifyScript = Join-Path $sourceDirectory "scripts\verify-android-release.ps1"
    & $verifyScript `
        -ArtifactPath $artifact `
        -ToolchainRoot $ToolchainRoot `
        -NdkVersion $NdkVersion `
        -ExpectedAbis $Abi
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

exit 0
