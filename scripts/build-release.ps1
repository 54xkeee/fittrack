$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$qtBin = 'C:\msys64\mingw64\bin'
$qmake = Join-Path $qtBin 'qmake6.exe'
$make = Join-Path $qtBin 'mingw32-make.exe'
$deploy = Join-Path $qtBin 'windeployqt6.exe'

foreach ($tool in @($qmake, $make, $deploy)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Qt tool not found: $tool"
    }
}

$env:PATH = "$qtBin;$env:PATH"
$tempRoot = 'C:\msys64\tmp\qt-grade-build'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$env:TEMP = $tempRoot
$env:TMP = $tempRoot
$env:TMPDIR = $tempRoot

$buildDir = Join-Path $projectRoot 'build-release'
$distDir = Join-Path $projectRoot 'dist\StudentGradeSystem'
New-Item -ItemType Directory -Force -Path $buildDir, $distDir | Out-Null

Push-Location $buildDir
try {
    & $qmake '..\app\app.pro' 'CONFIG+=release'
    if ($LASTEXITCODE -ne 0) { throw "qmake failed: $LASTEXITCODE" }
    & $make -j2
    if ($LASTEXITCODE -ne 0) { throw "build failed: $LASTEXITCODE" }
} finally {
    Pop-Location
}

Copy-Item -LiteralPath (Join-Path $buildDir 'release\StudentGradeSystem.exe') -Destination $distDir -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'grade.csv') -Destination $distDir -Force
& $deploy --release --compiler-runtime --no-translations (Join-Path $distDir 'StudentGradeSystem.exe')
if ($LASTEXITCODE -ne 0) { throw "windeployqt failed: $LASTEXITCODE" }
foreach ($runtime in @('libgcc_s_seh-1.dll', 'libstdc++-6.dll', 'libwinpthread-1.dll')) {
    Copy-Item -LiteralPath (Join-Path $qtBin $runtime) -Destination $distDir -Force
}

Write-Host "Release package: $distDir"
