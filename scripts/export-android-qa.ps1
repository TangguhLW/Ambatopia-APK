param([string]$Output='build/android/Ambatopia-QA.apk')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
$original=[IO.File]::ReadAllText((Join-Path $root 'export_presets.cfg'))
try {
 $qa=$original.Substring($original.IndexOf('[preset.1]')).Replace('[preset.1]','[preset.2]').Replace('[preset.1.options]','[preset.2.options]').Replace('name="Android"','name="Android QA"').Replace('org.thaney.growtopiareconstruction','org.thaney.ambatopia.qa').Replace('package/name="Ambatopia"','package/name="Ambatopia QA"')
 [IO.File]::WriteAllText((Join-Path $root 'export_presets.cfg'),$original+"`n"+$qa)
 & ./tools/godot.ps1 --headless --path . --export-debug 'Android QA' $Output
 if ($LASTEXITCODE -ne 0) {throw 'Isolated Android export failed'}
} finally {
 [IO.File]::WriteAllText((Join-Path $root 'export_presets.cfg'),$original)
 Pop-Location
}
