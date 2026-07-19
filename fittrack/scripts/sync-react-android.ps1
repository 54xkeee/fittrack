param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$projectItem = Get-Item -LiteralPath $projectRoot
if ($projectItem.Target) {
    $projectRoot = [string]$projectItem.Target[0]
}
$frontend = Join-Path $projectRoot "frontend"
$dist = Join-Path $frontend "dist"
$target = Join-Path $projectRoot "android/assets/react"

if (-not $SkipBuild) {
    Push-Location $frontend
    try { npm run build } finally { Pop-Location }
}

if (-not (Test-Path (Join-Path $dist "index.html"))) {
    throw "React bundle missing: $dist"
}

if (Test-Path $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
}
New-Item -ItemType Directory -Path $target | Out-Null
Copy-Item -Path (Join-Path $dist "*") -Destination $target -Recurse -Force
Write-Host "React Android assets synced to $target"
