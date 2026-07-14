[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ArtifactPath,
    [string]$ToolchainRoot = "D:\FitTrackToolchains",
    [string]$BuildToolsVersion = "",
    [string]$NdkVersion = "",
    [string]$BundletoolPath = "",
    [string]$ExpectedPackageName = "com.xuke.fittrack",
    [int]$ExpectedMinSdk = 29,
    [int]$ExpectedTargetSdk = 36,
    [int]$ExpectedCompileSdk = 36,
    [ValidateSet("arm64-v8a", "x86_64")]
    [string[]]$ExpectedAbis = @("arm64-v8a")
)

$ErrorActionPreference = "Stop"

function Get-LatestVersionDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Parent -PathType Container)) {
        throw "$Label directory not found: $Parent"
    }
    $directories = @(Get-ChildItem -LiteralPath $Parent -Directory | Sort-Object {
        try { [version]$_.Name } catch { [version]"0.0" }
    } -Descending)
    if ($directories.Count -eq 0) {
        throw "No $Label installation found under $Parent"
    }
    return $directories[0].FullName
}

function Get-JavaTool {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        $candidate = Join-Path $env:JAVA_HOME "bin\$Name.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    $command = Get-Command "$Name.exe" -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    throw "$Name.exe was not found; set JAVA_HOME to the Android build JDK"
}

function Invoke-NativeCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Tool,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$FailureMessage
    )

    $output = @(& $Tool @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

function Get-ZipEntries {
    param([Parameter(Mandatory = $true)][string]$Path)

    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        return @($archive.Entries | ForEach-Object { $_.FullName })
    } finally {
        $archive.Dispose()
    }
}

function Copy-ZipEntry {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$EntryName,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $entry = $archive.GetEntry($EntryName)
        if (-not $entry) {
            throw "Archive entry not found: $EntryName"
        }
        $parent = Split-Path -Parent $Destination
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent | Out-Null
        }
        $input = $entry.Open()
        $output = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew)
        try {
            $input.CopyTo($output)
        } finally {
            $output.Dispose()
            $input.Dispose()
        }
    } finally {
        $archive.Dispose()
    }
}

function Test-ApkMetadata {
    param(
        [Parameter(Mandatory = $true)][string]$Apk,
        [Parameter(Mandatory = $true)][string]$Aapt
    )

    $badging = Invoke-NativeCheck $Aapt @("dump", "badging", $Apk) "APK metadata check failed"
    $packageLine = [string]($badging | Select-Object -First 1)
    $packageMatch = [regex]::Match($packageLine, "package: name='([^']+)'.*compileSdkVersion='([^']+)'")
    if (-not $packageMatch.Success) {
        throw "APK package or compileSdkVersion was not found in aapt output"
    }
    if ($packageMatch.Groups[1].Value -ne $ExpectedPackageName) {
        throw "Expected package $ExpectedPackageName, got $($packageMatch.Groups[1].Value)"
    }
    if ([int]$packageMatch.Groups[2].Value -ne $ExpectedCompileSdk) {
        throw "Expected compileSdk $ExpectedCompileSdk, got $($packageMatch.Groups[2].Value)"
    }

    $minLine = [string]($badging | Where-Object { $_ -like "minSdkVersion:*" } | Select-Object -First 1)
    $targetLine = [string]($badging | Where-Object { $_ -like "targetSdkVersion:*" } | Select-Object -First 1)
    if ($minLine -ne "minSdkVersion:'$ExpectedMinSdk'") {
        throw "Expected minSdk $ExpectedMinSdk, got $minLine"
    }
    if ($targetLine -ne "targetSdkVersion:'$ExpectedTargetSdk'") {
        throw "Expected targetSdk $ExpectedTargetSdk, got $targetLine"
    }

    $nativeLine = [string]($badging | Where-Object { $_ -like "native-code:*" } | Select-Object -First 1)
    $actualAbis = @([regex]::Matches($nativeLine, "'([^']+)'") | ForEach-Object {
        $_.Groups[1].Value
    } | Sort-Object -Unique)
    $expectedSorted = @($ExpectedAbis | Sort-Object -Unique)
    if (@(Compare-Object $expectedSorted $actualAbis).Count -ne 0) {
        throw "Expected ABI(s) $($expectedSorted -join ', '), got $($actualAbis -join ', ')"
    }

    Write-Host "Metadata passed: $ExpectedPackageName; API $ExpectedMinSdk/$ExpectedTargetSdk/$ExpectedCompileSdk; ABI $($actualAbis -join ', ')"
}

function Test-ApkSignature {
    param(
        [Parameter(Mandatory = $true)][string]$Apk,
        [Parameter(Mandatory = $true)][string]$ApkSigner
    )

    $result = Invoke-NativeCheck $ApkSigner @("verify", "--verbose", "--print-certs", $Apk) "APK signature verification failed"
    $text = $result -join [Environment]::NewLine
    if ($text -notmatch "Verified using v(2|3|3\.1) scheme .*: true") {
        throw "APK must verify with Signature Scheme v2 or newer"
    }
    Write-Host "APK signature passed"
}

function Test-ApkPageAlignment {
    param(
        [Parameter(Mandatory = $true)][string]$Apk,
        [Parameter(Mandatory = $true)][string]$ZipAlign,
        [Parameter(Mandatory = $true)][string]$ReadElf,
        [Parameter(Mandatory = $true)][string]$WorkDirectory
    )

    Invoke-NativeCheck $ZipAlign @("-c", "-P", "16", "4", $Apk) "APK ZIP 16 KB alignment failed" | Out-Null

    $entries = @(Get-ZipEntries $Apk | Where-Object { $_ -like "lib/*.so" })
    if ($entries.Count -eq 0) {
        throw "APK contains no native .so libraries"
    }

    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($entryName in $entries) {
        if ($entryName.Contains("..")) {
            throw "Unsafe APK entry path: $entryName"
        }
        $relativeName = $entryName.Replace("/", [IO.Path]::DirectorySeparatorChar)
        $libraryPath = [IO.Path]::GetFullPath((Join-Path $WorkDirectory $relativeName))
        $workPrefix = [IO.Path]::GetFullPath($WorkDirectory).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
        if (-not $libraryPath.StartsWith($workPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe APK entry destination: $entryName"
        }
        Copy-ZipEntry $Apk $entryName $libraryPath

        $headers = Invoke-NativeCheck $ReadElf @("--program-headers", "--wide", $libraryPath) "ELF inspection failed for $entryName"
        $alignments = New-Object System.Collections.Generic.List[long]
        foreach ($line in $headers) {
            $match = [regex]::Match([string]$line, "^\s*LOAD\s+.*\s+(0x[0-9a-fA-F]+)\s*$")
            if ($match.Success) {
                $alignments.Add([Convert]::ToInt64($match.Groups[1].Value.Substring(2), 16))
            }
        }
        if ($alignments.Count -eq 0) {
            $failures.Add("$entryName (no LOAD segments found)")
        } elseif (@($alignments | Where-Object { $_ -lt 16384 }).Count -gt 0) {
            $hex = @($alignments | ForEach-Object { "0x{0:x}" -f $_ }) -join ","
            $failures.Add("$entryName (p_align=$hex)")
        }
    }

    if ($failures.Count -gt 0) {
        throw "ELF 16 KB alignment failed for $($failures.Count)/$($entries.Count) libraries:`n$($failures -join [Environment]::NewLine)"
    }
    Write-Host "16 KB alignment passed: ZIP and $($entries.Count) ELF libraries"
}

function Test-ApkMediaBundle {
    param(
        [Parameter(Mandatory = $true)][string]$Apk,
        [Parameter(Mandatory = $true)][string]$WorkDirectory
    )

    $manifestPath = Join-Path $PSScriptRoot "..\resources\data\exercise-media-shareable.json"
    $manifest = @(Get-Content -Raw -Encoding utf8 -LiteralPath $manifestPath |
        ConvertFrom-Json)
    $expectedNames = @($manifest | ForEach-Object {
        foreach ($media in @($_.media)) {
            $localPath = [string]$media.localPath
            if ($localPath -notmatch '^qrc:/images/exercises/shareable/([^/]+\.jpg)$') {
                throw "Unexpected shareable media path: $localPath"
            }
            $Matches[1]
        }
    } | Sort-Object -Unique)
    if ($expectedNames.Count -ne 58) {
        throw "Expected 58 unique shareable JPEG entries, got $($expectedNames.Count)"
    }

    $applicationLibraries = @(Get-ZipEntries $Apk | Where-Object {
        $_ -match '^lib/[^/]+/libfittrack_[^/]+\.so$'
    })
    if ($applicationLibraries.Count -eq 0) {
        throw "APK contains no FitTrack application library"
    }

    foreach ($entryName in $applicationLibraries) {
        $libraryPath = Join-Path $WorkDirectory ([IO.Path]::GetFileName($entryName))
        Copy-ZipEntry $Apk $entryName $libraryPath
        $bytes = [IO.File]::ReadAllBytes($libraryPath)
        $evenStrings = [Text.Encoding]::Unicode.GetString($bytes)
        $oddStrings = if ($bytes.Length -gt 1) {
            [Text.Encoding]::Unicode.GetString($bytes, 1, $bytes.Length - 1)
        } else {
            ""
        }

        $missingNames = @($expectedNames | Where-Object {
            -not $evenStrings.Contains($_) -and -not $oddStrings.Contains($_)
        })
        if ($missingNames.Count -gt 0) {
            throw "APK media bundle is missing $($missingNames.Count) shareable image(s): $($missingNames -join ', ')"
        }
        if ($evenStrings.Contains("muscledb") -or $oddStrings.Contains("muscledb")) {
            throw "APK media bundle contains a forbidden MuscleDB resource directory"
        }

        $candidateNames = @(
            [regex]::Matches($evenStrings, '[A-Za-z0-9][A-Za-z0-9-]*\.jpg') |
                ForEach-Object { $_.Value }
            [regex]::Matches($oddStrings, '[A-Za-z0-9][A-Za-z0-9-]*\.jpg') |
                ForEach-Object { $_.Value }
        ) | Sort-Object -Unique
        $unexpectedNames = @($candidateNames | Where-Object {
            $candidate = $_
            -not @($expectedNames | Where-Object { $candidate.EndsWith($_) }).Count
        })
        if ($unexpectedNames.Count -gt 0) {
            throw "APK media bundle contains unexpected JPEG resource(s): $($unexpectedNames -join ', ')"
        }
    }

    Write-Host "Media bundle passed: 58 shareable JPEG resources only"
}

function Test-Apk {
    param(
        [Parameter(Mandatory = $true)][string]$Apk,
        [Parameter(Mandatory = $true)][string]$WorkDirectory,
        [Parameter(Mandatory = $true)][string]$Aapt,
        [Parameter(Mandatory = $true)][string]$ApkSigner,
        [Parameter(Mandatory = $true)][string]$ZipAlign,
        [Parameter(Mandatory = $true)][string]$ReadElf
    )

    Test-ApkMetadata $Apk $Aapt
    Test-ApkSignature $Apk $ApkSigner
    Test-ApkPageAlignment $Apk $ZipAlign $ReadElf $WorkDirectory
    Test-ApkMediaBundle $Apk (Join-Path $WorkDirectory "media")
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$resolvedArtifact = (Resolve-Path -LiteralPath $ArtifactPath -ErrorAction Stop).Path
$extension = [IO.Path]::GetExtension($resolvedArtifact).ToLowerInvariant()
if ($extension -notin @(".apk", ".aab")) {
    throw "Artifact must be an APK or AAB: $resolvedArtifact"
}

$buildToolsParent = Join-Path $ToolchainRoot "AndroidSdk\build-tools"
if ([string]::IsNullOrWhiteSpace($BuildToolsVersion)) {
    $buildToolsDirectory = Get-LatestVersionDirectory $buildToolsParent "Android build-tools"
} else {
    $buildToolsDirectory = Join-Path $buildToolsParent $BuildToolsVersion
}
$aapt = Join-Path $buildToolsDirectory "aapt2.exe"
if (-not (Test-Path -LiteralPath $aapt -PathType Leaf)) {
    $aapt = Join-Path $buildToolsDirectory "aapt.exe"
}
$apkSigner = Join-Path $buildToolsDirectory "apksigner.bat"
$zipAlign = Join-Path $buildToolsDirectory "zipalign.exe"
foreach ($tool in @($aapt, $apkSigner, $zipAlign)) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) {
        throw "Required Android build tool not found: $tool"
    }
}

$ndkParent = Join-Path $ToolchainRoot "AndroidSdk\ndk"
if ([string]::IsNullOrWhiteSpace($NdkVersion)) {
    $ndkDirectory = Get-LatestVersionDirectory $ndkParent "Android NDK"
} else {
    $ndkDirectory = Join-Path $ndkParent $NdkVersion
}
$readElf = Join-Path $ndkDirectory "toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe"
if (-not (Test-Path -LiteralPath $readElf -PathType Leaf)) {
    throw "llvm-readelf.exe not found: $readElf"
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempDirectory = Join-Path $tempBase ("fittrack-release-verify-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDirectory | Out-Null

try {
    if ($extension -eq ".apk") {
        Test-Apk $resolvedArtifact (Join-Path $tempDirectory "apk") $aapt $apkSigner $zipAlign $readElf
    } else {
        $entries = Get-ZipEntries $resolvedArtifact
        $hasSignatureBlock = @($entries | Where-Object {
            $_ -match "^META-INF/[^/]+\.(RSA|DSA|EC)$"
        }).Count -gt 0
        if (-not $hasSignatureBlock) {
            throw "AAB is not JAR-signed (no META-INF signature block)"
        }

        $jarsigner = Get-JavaTool "jarsigner"
        Invoke-NativeCheck $jarsigner @("-verify", "-verbose", "-certs", $resolvedArtifact) "AAB signature verification failed" | Out-Null

        if ([string]::IsNullOrWhiteSpace($BundletoolPath)) {
            $bundletoolDirectory = Join-Path $ToolchainRoot "bundletool"
            $bundletool = Get-ChildItem -LiteralPath $bundletoolDirectory -Filter "bundletool*.jar" -File -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
        } else {
            $bundletool = (Resolve-Path -LiteralPath $BundletoolPath -ErrorAction Stop).Path
        }
        if (-not $bundletool -or -not (Test-Path -LiteralPath $bundletool -PathType Leaf)) {
            throw "bundletool JAR not found; pass -BundletoolPath"
        }
        $java = Get-JavaTool "java"
        Invoke-NativeCheck $java @("-jar", $bundletool, "validate", "--bundle=$resolvedArtifact") "bundletool validate failed" | Out-Null

        $apksPath = Join-Path $tempDirectory "universal.apks"
        Invoke-NativeCheck $java @(
            "-jar", $bundletool, "build-apks",
            "--bundle=$resolvedArtifact",
            "--output=$apksPath",
            "--mode=universal",
            "--overwrite"
        ) "bundletool failed to generate a universal APK" | Out-Null
        $generatedApk = Join-Path $tempDirectory "universal.apk"
        Copy-ZipEntry $apksPath "universal.apk" $generatedApk

        Write-Host "AAB signature and bundle structure passed; verifying generated universal APK"
        Test-Apk $generatedApk (Join-Path $tempDirectory "aab-apk") $aapt $apkSigner $zipAlign $readElf
    }

    Write-Host "Android release verification passed: $resolvedArtifact"
} finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempDirectory)
    $tempPrefix = $tempBase.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    if ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $resolvedTemp).StartsWith("fittrack-release-verify-")) {
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}
