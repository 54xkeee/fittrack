[CmdletBinding()]
param(
    [string]$OutputDirectory = "D:\FitTrackSecrets",
    [int]$ValidityDays = 10000
)

$ErrorActionPreference = "Stop"

if ($ValidityDays -lt 1) {
    throw "ValidityDays must be greater than zero"
}

$repositoryDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$repositoryPrefix = $repositoryDirectory.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
if ($outputPath.Equals($repositoryDirectory, [StringComparison]::OrdinalIgnoreCase) -or
    $outputPath.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Signing keys must be created outside the Git repository: $outputPath"
}

$keytool = $null
if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
    $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $keytool = $candidate
    }
}
if (-not $keytool) {
    $command = Get-Command keytool.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        $keytool = $command.Source
    }
}
if (-not $keytool) {
    throw "keytool.exe was not found; set JAVA_HOME to the Android build JDK"
}

if (-not (Test-Path -LiteralPath $outputPath -PathType Container)) {
    New-Item -ItemType Directory -Path $outputPath | Out-Null
}

function ConvertFrom-SecureStringForKeytool {
    param([Parameter(Mandatory = $true)][Security.SecureString]$SecureString)

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Read-ConfirmedPassword {
    param([Parameter(Mandatory = $true)][string]$Label)

    $first = ConvertFrom-SecureStringForKeytool (Read-Host "$Label password" -AsSecureString)
    $second = ConvertFrom-SecureStringForKeytool (Read-Host "Confirm $Label password" -AsSecureString)
    if ([string]::IsNullOrWhiteSpace($first)) {
        throw "$Label password must not be empty"
    }
    if ($first -cne $second) {
        throw "$Label passwords do not match"
    }
    return $first
}

function New-SigningKey {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Alias,
        [Parameter(Mandatory = $true)][string]$DistinguishedName,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (Test-Path -LiteralPath $Path) {
        throw "Refusing to overwrite an existing keystore: $Path"
    }

    $password = Read-ConfirmedPassword $Label
    $passwordVariable = "FITTRACK_KEYTOOL_PASSWORD"
    [Environment]::SetEnvironmentVariable($passwordVariable, $password, "Process")
    try {
        $output = @(& $keytool -genkeypair -v `
            -keystore $Path `
            -storetype PKCS12 `
            -alias $Alias `
            -keyalg RSA `
            -keysize 4096 `
            -sigalg SHA256withRSA `
            -validity $ValidityDays `
            -dname $DistinguishedName `
            "-storepass:env" $passwordVariable `
            "-keypass:env" $passwordVariable 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "keytool failed for $Label`: $($output -join [Environment]::NewLine)"
        }
    } finally {
        [Environment]::SetEnvironmentVariable($passwordVariable, $null, "Process")
        $password = $null
    }

    Write-Host "$Label keystore created: $Path"
}

$directPath = Join-Path $outputPath "fittrack-direct-release.p12"
$uploadPath = Join-Path $outputPath "fittrack-play-upload.p12"

Write-Host "Two independent keys will be created outside the repository."
Write-Host "Back up both files securely; losing the Direct key prevents APK upgrades."

New-SigningKey `
    -Path $directPath `
    -Alias "fittrack-direct-release" `
    -DistinguishedName "CN=FitTrack Direct APK,OU=FitTrack,O=Xuke,C=CN" `
    -Label "Direct APK"

New-SigningKey `
    -Path $uploadPath `
    -Alias "fittrack-play-upload" `
    -DistinguishedName "CN=FitTrack Play Upload,OU=FitTrack,O=Xuke,C=CN" `
    -Label "Play upload"

Write-Host "Copy config\android-signing.example.ps1 to config\android-signing.local.ps1."
Write-Host "The local config prompts for passwords and maps the chosen profile to Qt variables."
