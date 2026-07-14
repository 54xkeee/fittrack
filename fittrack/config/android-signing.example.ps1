# Copy this file to android-signing.local.ps1, then update only paths if needed.
# The local file and keystores are ignored by Git. Passwords are prompted for
# each PowerShell session and are never written to this file.

$FitTrackAndroidSigning = @{
    Direct = @{
        KeystorePath = "D:\FitTrackSecrets\fittrack-direct-release.p12"
        Alias = "fittrack-direct-release"
    }
    PlayUpload = @{
        KeystorePath = "D:\FitTrackSecrets\fittrack-play-upload.p12"
        Alias = "fittrack-play-upload"
    }
}

function ConvertFrom-FitTrackSecureString {
    param([Parameter(Mandatory = $true)][Security.SecureString]$SecureString)

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Use-FitTrackAndroidSigning {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Direct", "PlayUpload")]
        [string]$Profile
    )

    $settings = $FitTrackAndroidSigning[$Profile]
    if (-not (Test-Path -LiteralPath $settings.KeystorePath -PathType Leaf)) {
        throw "Keystore not found: $($settings.KeystorePath)"
    }

    $password = ConvertFrom-FitTrackSecureString (
        Read-Host "$Profile keystore password" -AsSecureString)
    $env:QT_ANDROID_KEYSTORE_PATH = $settings.KeystorePath
    $env:QT_ANDROID_KEYSTORE_ALIAS = $settings.Alias
    $env:QT_ANDROID_KEYSTORE_STORE_PASS = $password
    $env:QT_ANDROID_KEYSTORE_KEY_PASS = $password
    $env:FITTRACK_ANDROID_SIGNING_PROFILE = $Profile

    Write-Host "$Profile Android signing is active for this PowerShell process."
}

# Examples:
#   . .\config\android-signing.local.ps1
#   Use-FitTrackAndroidSigning Direct
#   .\scripts\build-android.ps1 -Configuration Release -Sign
#
#   Use-FitTrackAndroidSigning PlayUpload
#   .\scripts\build-android.ps1 -Configuration Release -Bundle -Sign
