param([ValidateSet('Windows','Android','All')][string]$Target='All',[string]$WindowsOutput='build/windows/GrowtopiaReconstruction.exe',[string]$AndroidOutput='build/android/GrowtopiaReconstruction.apk')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    node scripts/build-item-assets.mjs
    if($LASTEXITCODE -ne 0) { throw 'Item asset composition failed' }
    $iconPython=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if(-not (Test-Path -LiteralPath $iconPython)) { $iconPython=(Get-Command python -ErrorAction Stop).Source }
    & $iconPython scripts/build-inventory-icons.py
    if($LASTEXITCODE -ne 0) { throw 'Inventory icon composition failed; previous verified pack retained' }
    node scripts/build-placeable-blocks.mjs
    if($LASTEXITCODE -ne 0) { throw 'Block registry build failed' }
    node scripts/write-build-info.mjs
    if($LASTEXITCODE -ne 0) { throw 'Build provenance failed' }
    $catalogGeneration=(Get-Content data/catalog-index.json -Raw | ConvertFrom-Json).generation
    if($catalogGeneration -notmatch '^[a-f0-9]{16}$') { throw 'Invalid catalog generation' }
    $catalogFiles=@(Get-ChildItem data -File -Filter '*.json' | ForEach-Object { 'data/' + $_.Name })
    $catalogInclude='assets/reference/manifest.json,assets/web-wardrobe/*.bin,assets/inventory/*.bin,' + ($catalogFiles -join ',') + ',data/catalog/' + $catalogGeneration + '/*.json,data/simulator/*.json'
    $presets=Get-Content export_presets.cfg -Raw
    $presets=[regex]::Replace($presets,'(?m)^include_filter=.*$',('include_filter="' + $catalogInclude + '"'))
    $catalogExclude=@(Get-ChildItem data/catalog -Directory | Where-Object { $_.Name -ne $catalogGeneration } | ForEach-Object { 'data/catalog/' + $_.Name + '/*' })
    $exclude='tools/*,evidence/*,research/*,tests/*,scripts/*,build/*,web-client/*,server/private/*,supabase/*,README.md'
    if($catalogExclude.Count -gt 0) { $exclude += ',' + ($catalogExclude -join ',') }
    $presets=[regex]::Replace($presets,'(?m)^exclude_filter=.*$',('exclude_filter="' + $exclude + '"'))
    Set-Content -LiteralPath export_presets.cfg -Value $presets -NoNewline
    New-Item -ItemType Directory -Force -Path build/windows,build/android | Out-Null
    New-Item -ItemType File -Force -Path build/.gdignore | Out-Null
    & ./tools/godot.ps1 --headless --path . --check-only --script src/diagnostics/qa_runner.gd
    if ($LASTEXITCODE -ne 0) { throw 'Exported QA harness does not compile' }
    if ($Target -in @('Windows','All')) {
        & ./tools/godot.ps1 --headless --path . --export-release 'Windows Desktop' $WindowsOutput
        if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
    }
    if ($Target -in @('Android','All')) {
        $android = Get-Content tools/android.json -Raw | ConvertFrom-Json
        $settingsPath = Join-Path $projectRoot 'tools/profile/Godot/editor_settings-4.7.tres'
        $settingsText = Get-Content -LiteralPath $settingsPath -Raw
        $sdkPath = $android.sdk.Replace('\','/')
        $javaPath = $android.java.Replace('\','/')
        $settingsText = [regex]::Replace($settingsText,'(?m)^export/android/android_sdk_path = .*$',('export/android/android_sdk_path = "' + $sdkPath + '"'))
        $settingsText = [regex]::Replace($settingsText,'(?m)^export/android/java_sdk_path = .*$',('export/android/java_sdk_path = "' + $javaPath + '"'))
        Set-Content -LiteralPath $settingsPath -Value $settingsText -Encoding utf8
        & ./tools/godot.ps1 --headless --path . --export-debug Android $AndroidOutput
        if ($LASTEXITCODE -ne 0) { throw 'Android export failed' }
    }
} finally { Pop-Location }

