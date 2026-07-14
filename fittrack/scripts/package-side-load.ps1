param(
    [string]$ApkPath = "",
    [string]$ToolchainRoot = "D:\FitTrackToolchains",
    [string]$BuildToolsVersion = "35.0.0",
    [string]$QtVersion = "6.9.1",
    [string]$NdkVersion = "27.2.12479018"
)

$ErrorActionPreference = "Stop"

$projectDirectory = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$repositoryDirectory = (Resolve-Path (Join-Path $projectDirectory "..")).Path
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectDirectory "build-android-arm64\android-build\build\outputs\apk\debug\android-build-debug.apk"
}

$resolvedApk = (Resolve-Path -LiteralPath $ApkPath -ErrorAction Stop).Path
if ([System.IO.Path]::GetExtension($resolvedApk) -ne ".apk") {
    throw "Side-load package input must be an APK: $resolvedApk"
}

$buildToolsDirectory = Join-Path $ToolchainRoot "AndroidSdk\build-tools\$BuildToolsVersion"
if (-not (Test-Path -LiteralPath $buildToolsDirectory -PathType Container)) {
    throw "Android build-tools $BuildToolsVersion were not found: $buildToolsDirectory"
}

$aapt = Join-Path $buildToolsDirectory "aapt2.exe"
if (-not (Test-Path -LiteralPath $aapt)) {
    $aapt = Join-Path $buildToolsDirectory "aapt.exe"
}
if (-not (Test-Path -LiteralPath $aapt)) {
    throw "aapt2.exe or aapt.exe was not found in $buildToolsDirectory"
}
$badging = @(& $aapt dump badging $resolvedApk 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "APK metadata verification failed: $($badging -join [Environment]::NewLine)"
}
$packageLine = $badging | Select-Object -First 1
if ($packageLine -notmatch "package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'") {
    throw "APK metadata did not contain package and version information"
}
$packageName = $Matches[1]
$versionCode = $Matches[2]
$versionName = $Matches[3]
if ($packageName -ne "com.fittrack.app") {
    throw "Unexpected APK package name: $packageName"
}
$minSdkLine = $badging | Where-Object { $_ -like "minSdkVersion:*" } | Select-Object -First 1
$targetSdkLine = $badging | Where-Object { $_ -like "targetSdkVersion:*" } | Select-Object -First 1
if ($minSdkLine -ne "minSdkVersion:'28'" -or $targetSdkLine -ne "targetSdkVersion:'35'") {
    throw "Expected min SDK 28 and target SDK 35, got: $minSdkLine; $targetSdkLine"
}
$nativeCodeLine = $badging | Where-Object { $_ -like "native-code:*" } | Select-Object -First 1
if ($nativeCodeLine -ne "native-code: 'arm64-v8a'") {
    throw "Expected only arm64-v8a native code, got: $nativeCodeLine"
}
$badgingText = $badging -join [Environment]::NewLine
if ($badgingText -match "android\.permission\.(INTERNET|ACCESS_NETWORK_STATE)") {
    throw "The offline APK must not request INTERNET or ACCESS_NETWORK_STATE"
}
$metadataVerification = "Passed with $([System.IO.Path]::GetFileName($aapt)); API 28/35; arm64-v8a only; no network permission"

$apksigner = Join-Path $buildToolsDirectory "apksigner.bat"
$signingOutput = @(& $apksigner verify --verbose --print-certs $resolvedApk 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "APK signature verification failed: $($signingOutput -join [Environment]::NewLine)"
}
$signingText = $signingOutput -join [Environment]::NewLine
if ($signingText -notmatch 'Verified using v2 scheme \(APK Signature Scheme v2\): true') {
    throw "APK Signature Scheme v2 verification did not pass"
}
if ($signingText -notmatch 'certificate DN: .*CN=Android Debug') {
    throw "The APK is not signed with an Android Debug certificate"
}
$signatureVerification = "Android Debug certificate; APK Signature Scheme v2 passed"

$gitSha = @(& git -C $repositoryDirectory rev-parse HEAD 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Could not read the Git commit: $($gitSha -join [Environment]::NewLine)"
}
$gitSha = ($gitSha | Select-Object -First 1).Trim()
$trackedChanges = @(& git -C $repositoryDirectory status --porcelain --untracked-files=no 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Could not read the Git worktree state: $($trackedChanges -join [Environment]::NewLine)"
}
$gitTreeState = if ($trackedChanges.Count -eq 0) { "clean" } else { "dirty (tracked changes present)" }

$licenseSourceDirectory = Join-Path $projectDirectory "licenses"
$licenseTextDirectory = Join-Path $licenseSourceDirectory "texts"
$requiredLicenseTexts = @(
    "Apache-2.0.txt",
    "BSD-2-Clause.txt",
    "BSD-3-Clause.txt",
    "CC0-1.0.txt",
    "CC-BY-2.0.txt",
    "CC-BY-SA-2.0.txt",
    "CC-BY-SA-3.0.txt",
    "CC-BY-SA-4.0.txt",
    "FTL.txt",
    "GPL-3.0-only.txt",
    "HPND.txt",
    "HPND-sell-variant.txt",
    "IJG.txt",
    "Imlib2.txt",
    "LGPL-3.0-only.txt",
    "Libpng.txt",
    "libpng-2.0.txt",
    "LicenseRef-BSD-3-Clause-with-PCRE2-Binary-Like-Packages-Exception.txt",
    "LicenseRef-ICC-License.txt",
    "MIT.txt",
    "MIT-open-group.txt",
    "MPL-2.0.txt",
    "Unicode-3.0.txt",
    "X11.txt",
    "Zlib.txt",
    "blessing.txt"
)
$licenseDocuments = @(
    (Join-Path $licenseSourceDirectory "README.md"),
    (Join-Path $licenseSourceDirectory "SOURCE-AND-RELINK.md"),
    (Join-Path $repositoryDirectory "docs\fittrack-third-party-notices.md"),
    (Join-Path $repositoryDirectory "docs\fittrack-media-credits.md"),
    (Join-Path $repositoryDirectory "docs\media\original\README.md"),
    (Join-Path $projectDirectory "resources\data\exercise-media-shareable.json")
)
foreach ($path in $licenseDocuments) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required distribution notice is missing: $path"
    }
}
foreach ($name in $requiredLicenseTexts) {
    $path = Join-Path $licenseTextDirectory $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required license text is missing: $path"
    }
}

$qtSbomDirectory = Join-Path $ToolchainRoot "Qt\$QtVersion\android_arm64_v8a\sbom"
$qtSbomNames = @(
    "qtbase-$QtVersion.spdx.json",
    "qtdeclarative-$QtVersion.spdx.json",
    "qtsvg-$QtVersion.spdx.json"
)
foreach ($name in $qtSbomNames) {
    $path = Join-Path $qtSbomDirectory $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Qt SBOM is missing: $path"
    }
}
$ndkNotice = Join-Path $ToolchainRoot "AndroidSdk\ndk\$NdkVersion\toolchains\llvm\prebuilt\windows-x86_64\NOTICE"
if (-not (Test-Path -LiteralPath $ndkNotice -PathType Leaf)) {
    throw "Android NDK LLVM NOTICE is missing: $ndkNotice"
}
$androidDependencyEvidence = Join-Path $projectDirectory "build-android-arm64\android-build\build\intermediates\incremental\lintAnalyzeDebug\debug-artifact-dependencies.xml"
if (-not (Test-Path -LiteralPath $androidDependencyEvidence -PathType Leaf)) {
    throw "Android runtime dependency evidence is missing; run lintDebug first: $androidDependencyEvidence"
}
if ((Get-Item -LiteralPath $androidDependencyEvidence).LastWriteTimeUtc `
    -lt (Get-Item -LiteralPath $resolvedApk).LastWriteTimeUtc) {
    throw "Android runtime dependency evidence is older than the APK; run lintDebug again"
}

$distributionDirectory = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryDirectory "dist\FitTrack-sideload"))
$repositoryPrefix = [System.IO.Path]::GetFullPath(
    $repositoryDirectory + [System.IO.Path]::DirectorySeparatorChar)
if (-not $distributionDirectory.StartsWith(
        $repositoryPrefix,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean outside the repository: $distributionDirectory"
}
if (Test-Path -LiteralPath $distributionDirectory) {
    Remove-Item -LiteralPath $distributionDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $distributionDirectory | Out-Null

$safeVersion = $versionName -replace '[^0-9A-Za-z._-]', '_'
$apkName = "FitTrack-$safeVersion-debug-arm64-v8a.apk"
$packagedApk = Join-Path $distributionDirectory $apkName
$sourceHash = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash
Copy-Item -LiteralPath $resolvedApk -Destination $packagedApk
$packagedHash = (Get-FileHash -LiteralPath $packagedApk -Algorithm SHA256).Hash
if ($packagedHash -ne $sourceHash) {
    throw "Packaged APK hash does not match the source APK"
}

$distributionLicenseDirectory = Join-Path $distributionDirectory "licenses"
New-Item -ItemType Directory -Path $distributionLicenseDirectory | Out-Null
Copy-Item -LiteralPath $licenseTextDirectory -Destination $distributionLicenseDirectory -Recurse
Copy-Item -LiteralPath (Join-Path $licenseSourceDirectory "README.md") `
    -Destination (Join-Path $distributionLicenseDirectory "LICENSE-BUNDLE-README.md")
Copy-Item -LiteralPath (Join-Path $licenseSourceDirectory "SOURCE-AND-RELINK.md") `
    -Destination $distributionLicenseDirectory
Copy-Item -LiteralPath (Join-Path $repositoryDirectory "docs\fittrack-third-party-notices.md") `
    -Destination (Join-Path $distributionLicenseDirectory "THIRD-PARTY-NOTICES.md")
Copy-Item -LiteralPath (Join-Path $repositoryDirectory "docs\fittrack-media-credits.md") `
    -Destination (Join-Path $distributionLicenseDirectory "MEDIA-CREDITS.md")
Copy-Item -LiteralPath (Join-Path $repositoryDirectory "docs\media\original\README.md") `
    -Destination (Join-Path $distributionLicenseDirectory "FITTRACK-ORIGINAL-MEDIA-CC0.md")
Copy-Item -LiteralPath (Join-Path $projectDirectory "resources\data\exercise-media-shareable.json") `
    -Destination $distributionLicenseDirectory
Copy-Item -LiteralPath $ndkNotice `
    -Destination (Join-Path $distributionLicenseDirectory "ANDROID-NDK-LLVM-NOTICE.txt")
Copy-Item -LiteralPath $androidDependencyEvidence `
    -Destination (Join-Path $distributionLicenseDirectory "android-runtime-dependencies.xml")

$distributionSbomDirectory = Join-Path $distributionLicenseDirectory "sbom"
New-Item -ItemType Directory -Path $distributionSbomDirectory | Out-Null
foreach ($name in $qtSbomNames) {
    Copy-Item -LiteralPath (Join-Path $qtSbomDirectory $name) `
        -Destination $distributionSbomDirectory
}

$size = (Get-Item -LiteralPath $packagedApk).Length
$generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
$readme = @"
# FitTrack Debug 侧载包

- APK：$apkName
- 版本：$versionName（versionCode $versionCode）
- 包名：$packageName
- Git SHA：$gitSha
- Git 工作树：$gitTreeState
- SHA-256：$packagedHash
- 大小：$size 字节
- 生成时间：$generatedAt
- 元数据校验：$metadataVerification
- 签名校验：$signatureVerification

## 安装

连接已启用 USB 调试的 Android 设备后执行：

    adb install -r ".\$apkName"

也可以把 APK 复制到手机后直接打开安装。校验文件完整性：

    (Get-FileHash ".\$apkName" -Algorithm SHA256).Hash

`licenses/` 包含第三方组件通知、动作媒体署名、完整许可正文、Qt SBOM、Android NDK
NOTICE、Qt 对应源码与重新链接说明。`SHA256SUMS.txt` 可校验除清单自身外的全部文件。

## 限制

这是使用 Android Debug 证书签名的非正式测试包，仅用于直接侧载，不可作为应用商店发布包。不同构建机的 Debug 证书可能不同，届时无法覆盖安装；卸载旧版会清除本地应用数据，请先在应用内导出备份。长期分发和稳定覆盖升级需要固定保管的 Release 密钥与正式签名 APK。
"@
Set-Content -LiteralPath (Join-Path $distributionDirectory "README.md") -Value $readme -Encoding utf8

if (Get-ChildItem -LiteralPath $distributionDirectory -Filter "*.aab" -File -Recurse) {
    throw "Unsigned AAB must not be included in the side-load package"
}
$packagedApks = @(Get-ChildItem -LiteralPath $distributionDirectory -Filter "*.apk" -File -Recurse)
if ($packagedApks.Count -ne 1) {
    throw "The side-load package must contain exactly one APK"
}
$copiedLicenseTexts = @(Get-ChildItem -LiteralPath (Join-Path $distributionLicenseDirectory "texts") -File)
if ($copiedLicenseTexts.Count -ne $requiredLicenseTexts.Count) {
    throw "The copied license text count does not match the required manifest"
}
$copiedSboms = @(Get-ChildItem -LiteralPath $distributionSbomDirectory -Filter "*.spdx.json" -File)
if ($copiedSboms.Count -ne $qtSbomNames.Count) {
    throw "The copied Qt SBOM count does not match the required manifest"
}

$hashManifestPath = Join-Path $distributionDirectory "SHA256SUMS.txt"
$hashLines = Get-ChildItem -LiteralPath $distributionDirectory -File -Recurse |
    Where-Object { $_.FullName -ne $hashManifestPath } |
    Sort-Object FullName |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($distributionDirectory.Length).TrimStart("\", "/").Replace("\", "/")
        "$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)  $relativePath"
    }
Set-Content -LiteralPath $hashManifestPath -Value $hashLines -Encoding utf8

$archivePath = Join-Path (Split-Path $distributionDirectory -Parent) `
    "FitTrack-$safeVersion-debug-arm64-v8a.zip"
$archiveHashPath = "$archivePath.sha256"
foreach ($path in @($archivePath, $archiveHashPath)) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}
Compress-Archive -Path (Join-Path $distributionDirectory "*") `
    -DestinationPath $archivePath -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
Set-Content -LiteralPath $archiveHashPath `
    -Value "$archiveHash  $([System.IO.Path]::GetFileName($archivePath))" -Encoding utf8

Write-Host "FitTrack side-load package: $distributionDirectory"
Write-Host "FitTrack side-load archive: $archivePath"
Write-Host "APK SHA-256: $packagedHash"
Write-Host "Archive SHA-256: $archiveHash"

exit 0
