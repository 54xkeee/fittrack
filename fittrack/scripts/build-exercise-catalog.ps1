param(
    [Parameter(Mandatory = $true)]
    [string]$MuscleDbRoot,

    [Parameter(Mandatory = $true)]
    [string]$TanNotesPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$dataRoot = Join-Path $projectRoot 'resources\data'
$mappingPath = Join-Path $dataRoot 'muscledb-mapping.json'
$mediaManifestPath = Join-Path $dataRoot 'exercise-media-shareable.json'
$muscleDbPath = Join-Path $MuscleDbRoot 'exercises.json'

foreach ($path in @($mappingPath, $mediaManifestPath, $muscleDbPath, $TanNotesPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "缺少输入文件：$path"
    }
}

function Read-Json([string]$Path) {
    Get-Content -Encoding utf8 -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Copy-JsonObject($Value) {
    $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json
}

function Add-UniqueAlias($Exercise, [string]$Alias) {
    if ([string]::IsNullOrWhiteSpace($Alias) -or $Alias -eq $Exercise.nameZh) {
        return
    }
    $aliases = @($Exercise.aliases)
    if ($aliases -notcontains $Alias) {
        $Exercise.aliases = @($aliases + $Alias)
    }
}

function Set-JsonProperty($Object, [string]$Name, $Value) {
    $Object | Add-Member -Force -NotePropertyName $Name -NotePropertyValue $Value
}

function Set-JsonArrayProperty {
    param(
        $Object,
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]]$Value
    )
    $Object | Add-Member -Force -NotePropertyName $Name -NotePropertyValue @($Value)
}

function Parse-TanNotes([string]$Path) {
    $result = @{}
    $current = $null
    $section = ''
    foreach ($line in Get-Content -Encoding utf8 -LiteralPath $Path) {
        if ($line -match '^####\s+\d+\.\s+(.+)$') {
            $name = $Matches[1].Trim()
            $current = [ordered]@{
                name = $name
                techniquePoints = @()
                cautions = @()
                commonMistakes = @()
            }
            $result[$name] = $current
            $section = ''
            continue
        }
        if ($null -eq $current) { continue }
        if ($line -eq '**发力要点：**') { $section = 'techniquePoints'; continue }
        if ($line -eq '**注意事项：**') { $section = 'cautions'; continue }
        if ($line -eq '**常见错误：**') { $section = 'commonMistakes'; continue }
        if ($line -match '^##+\s+' -or $line -eq '---') { $section = ''; continue }
        if ($section.Length -gt 0 -and $line -match '^-\s+(.+)$') {
            $current[$section] = @($current[$section] + $Matches[1].Trim())
        }
    }
    return $result
}

function StandardEquipment([string]$Equipment, $Fallback) {
    switch ($Equipment) {
        '绳索' { return @('钢线') }
        '器械' { return @('固定器械') }
        '徒手' { return @('自重') }
        '其他' { return @($Fallback) }
        default { return @($Equipment) }
    }
}

$mapping = Get-Content -Encoding utf8 -Raw -LiteralPath $mappingPath | ConvertFrom-Json
$mediaManifest = Get-Content -Encoding utf8 -Raw -LiteralPath $mediaManifestPath | ConvertFrom-Json
$muscleDb = Get-Content -Encoding utf8 -Raw -LiteralPath $muscleDbPath | ConvertFrom-Json
$notes = Parse-TanNotes $TanNotesPath
$dbById = @{}
foreach ($item in $muscleDb) { $dbById[[int]$item.id] = $item }
$mediaById = @{}
foreach ($item in $mediaManifest) { $mediaById[[string]$item.id] = @($item.media) }

$seedPaths = @(
    Join-Path $dataRoot 'exercises-push.json'
    Join-Path $dataRoot 'exercises-pull.json'
    Join-Path $dataRoot 'exercises-legs.json'
)
$documents = @()
$exerciseById = @{}
$documentById = @{}
for ($documentIndex = 0; $documentIndex -lt $seedPaths.Count; ++$documentIndex) {
    $parsedItems = Get-Content -Encoding utf8 -Raw -LiteralPath $seedPaths[$documentIndex] | ConvertFrom-Json
    $items = [System.Collections.ArrayList]::new()
    foreach ($parsedItem in $parsedItems) { [void]$items.Add($parsedItem) }
    $documents += ,$items
    foreach ($exercise in $items) {
        $exerciseById[$exercise.id] = $exercise
        $documentById[$exercise.id] = $documentIndex
    }
}

$reportRows = @()
foreach ($entry in $mapping) {
    $dbItem = $dbById[[int]$entry.muscleDbId]
    if ($null -eq $dbItem) { throw "MuscleDB ID 不存在：$($entry.muscleDbId)" }
    if (-not $mediaById.ContainsKey([string]$entry.fittrackId)) {
        throw "可分发媒体清单缺少动作：$($entry.fittrackId)"
    }

    $isNew = -not $exerciseById.ContainsKey($entry.fittrackId)
    if ($isNew) {
        if ([string]::IsNullOrWhiteSpace($entry.templateId) -or -not $exerciseById.ContainsKey($entry.templateId)) {
            throw "新增动作缺少有效模板：$($entry.fittrackId)"
        }
        $exercise = Copy-JsonObject $exerciseById[$entry.templateId]
        $exercise.id = $entry.fittrackId
        $documentIndex = $documentById[$entry.templateId]
        [void]$documents[$documentIndex].Add($exercise)
        $exerciseById[$entry.fittrackId] = $exercise
        $documentById[$entry.fittrackId] = $documentIndex
    } else {
        $exercise = $exerciseById[$entry.fittrackId]
    }

    $oldName = [string]$exercise.nameZh
    $approximate = [string]$entry.match -eq 'approximate'
    $entryCollections = @($entry.collections | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_)
    })
    if (-not [string]::IsNullOrWhiteSpace($entry.tanName)) {
        $note = $notes[[string]$entry.tanName]
        if ($null -eq $note) { throw "谭成义原文中找不到动作：$($entry.tanName)" }
        $exercise.nameZh = [string]$entry.tanName
        Set-JsonArrayProperty -Object $exercise -Name 'techniquePoints' -Value @($note.techniquePoints)
        $exercise.cautions = @($note.cautions)
        Set-JsonArrayProperty -Object $exercise -Name 'commonMistakes' -Value @($note.commonMistakes)
        Set-JsonArrayProperty -Object $exercise -Name 'collections' -Value $entryCollections
        if ($isNew) { $exercise.steps = @($dbItem.steps) }
    } else {
        Set-JsonArrayProperty -Object $exercise -Name 'collections' -Value $entryCollections
        Set-JsonArrayProperty -Object $exercise -Name 'techniquePoints' -Value @()
        Set-JsonArrayProperty -Object $exercise -Name 'commonMistakes' -Value @()
        if (-not $approximate) {
            $exercise.nameZh = [string]$dbItem.name_zh
            $exercise.nameEn = [string]$dbItem.name_en
            $exercise.steps = @($dbItem.steps)
            Set-JsonArrayProperty -Object $exercise -Name 'equipment' -Value @(StandardEquipment ([string]$dbItem.equipment) $exercise.equipment)
        }
    }
    Set-JsonArrayProperty -Object $exercise -Name 'equipment' -Value @($exercise.equipment)
    Set-JsonProperty $exercise 'difficulty' ([string]$dbItem.difficulty)
    Add-UniqueAlias $exercise $oldName
    Add-UniqueAlias $exercise ([string]$dbItem.name_zh)

    $sources = @($exercise.sources | Where-Object {
        [string]$_.type -ne 'muscleDbLocalExport'
    })
    $exercise.sources = @($sources + [ordered]@{
        title = "MuscleDB：$($dbItem.name_zh)"
        url = [string]$dbItem.url
        type = 'muscleDbLocalExport'
        muscleDbId = [int]$dbItem.id
    })

    $media = @($mediaById[[string]$entry.fittrackId])
    foreach ($mediaItem in $media) {
        $relativePath = [string]$mediaItem.localPath -replace '^qrc:/', ''
        $sourceImage = Join-Path (Join-Path $projectRoot 'resources') $relativePath
        if (-not (Test-Path -LiteralPath $sourceImage -PathType Leaf)) {
            throw "可分发媒体文件不存在：$sourceImage"
        }
    }
    $exercise.media = @(Copy-JsonObject $media)

    $reportRows += [pscustomobject]@{
        FitTrackId = $entry.fittrackId
        Action = $exercise.nameZh
        MuscleDbId = $entry.muscleDbId
        MuscleDbAction = $dbItem.name_zh
        Match = if ($approximate) { '近似，已保留原文字段' } else { '确认' }
        Source = if ($entry.tanName) { '用户原文' } else { 'MuscleDB' }
        Collections = @($entry.collections) -join '、'
    }
}

for ($documentIndex = 0; $documentIndex -lt $seedPaths.Count; ++$documentIndex) {
    $json = @($documents[$documentIndex]) | ConvertTo-Json -Depth 100
    Set-Content -Encoding utf8 -LiteralPath $seedPaths[$documentIndex] -Value $json
}

$reportPath = Join-Path (Split-Path -Parent $projectRoot) 'docs\fittrack-exercise-mapping.md'
$report = @(
    '# FitTrack 动作与 MuscleDB 映射',
    '',
    '> 本文件由 `fittrack/scripts/build-exercise-catalog.ps1` 生成。近似匹配不覆盖原动作文字；动作图片独立取自可再分发媒体清单。',
    '',
    '| FitTrack ID | 动作 | MuscleDB | 匹配 | 文字来源 | 动作集合 |',
    '| --- | --- | --- | --- | --- | --- |'
)
foreach ($row in $reportRows) {
    $report += "| ``$($row.FitTrackId)`` | $($row.Action) | $($row.MuscleDbId) · $($row.MuscleDbAction) | $($row.Match) | $($row.Source) | $($row.Collections) |"
}
Set-Content -Encoding utf8 -LiteralPath $reportPath -Value $report

Write-Output "已生成 $($mapping.Count) 个动作映射：$reportPath"









