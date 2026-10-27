param([string[]]$Scripts=@('src/ui/motion.gd','src/ui/motion_panel.gd','src/ui/text_button.gd','src/ui/hud.gd','src/ui/inventory.gd','src/game/terrain_renderer.gd','src/game/avatar_view.gd','src/game/world_view.gd','src/ui/dialog.gd'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $verified=& ./tools/godot.ps1 --headless --path . --script tests/run.gd all
    if($LASTEXITCODE -ne 0 -or ($verified -join "`n") -match 'SCRIPT ERROR|ERROR:|FAIL:') { throw 'Preview update refused: checks failed' }
    New-Item -ItemType Directory -Force build/live | Out-Null
    node scripts/write-build-info.mjs
    if($LASTEXITCODE -ne 0) { throw 'Live pack provenance failed' }
    & ./tools/godot.ps1 --headless --path . --export-pack 'Windows Desktop' build/live/staged.pck > evidence/live-pack-log.txt
    if($LASTEXITCODE -ne 0) { throw 'Preview pack export failed' }
    $digest=(Get-FileHash build/live/staged.pck -Algorithm SHA256).Hash.ToLowerInvariant()
    $name='update-'+$digest.Substring(0,16)+'.pck'
    Copy-Item -LiteralPath build/live/staged.pck -Destination (Join-Path build/live $name) -Force
    $paths=@($Scripts | ForEach-Object { if($_ -notmatch '^src/[A-Za-z0-9_/-]+\.gd$' -or $_ -match '\.\.') { throw 'Invalid preview script' }; 'res://'+$_ })
    @{pack=$name;sha256=$digest;scripts=$paths} | ConvertTo-Json -Depth 4 | Set-Content build/live/update.pending.json -Encoding utf8
    Move-Item -LiteralPath build/live/update.pending.json -Destination build/live/update.json -Force
    Write-Output 'Validated live update published locally; running EXE remains open.'
} finally { Pop-Location }
