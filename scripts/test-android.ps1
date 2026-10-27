param([switch]$Network,[switch]$Authenticated,[switch]$SkipInstall,[string]$Package='org.thaney.growtopiareconstruction',[string]$ApkPath='build/android/GrowtopiaReconstruction.apk',[string]$EvidenceDirectory='evidence/android',[int]$TimeoutSeconds=420)
$ErrorActionPreference='Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$adb = Join-Path $projectRoot 'tools/android-sdk/platform-tools/adb.exe'
$package = $Package
$apk = Join-Path $projectRoot $ApkPath
$evidence = Join-Path $projectRoot $EvidenceDirectory
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
function Adb-Run([string[]]$Arguments) {
    & $adb @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB command failed: $($Arguments[0])" }
}
function Save-AppFile([string]$Name,[string]$Destination) {
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$adb
    $info.UseShellExecute=$false
    $info.RedirectStandardOutput=$true
    $info.RedirectStandardError=$true
    foreach($value in @('exec-out','run-as',$package,'cat',"files/$Name")) { $info.ArgumentList.Add($value) }
    $process=[System.Diagnostics.Process]::Start($info)
    $errors=$process.StandardError.ReadToEndAsync()
    $output=[System.IO.File]::Create($Destination)
    try { $process.StandardOutput.BaseStream.CopyTo($output) } finally { $output.Dispose() }
    $process.WaitForExit()
    if($process.ExitCode -ne 0) { throw "App file unavailable: $Name $($errors.GetAwaiter().GetResult())" }
}
function Save-OwnLog([string]$Destination) {
    $appPid = (& $adb shell pidof -s $package).Trim()
    if(!$appPid) { $appPid = (& $adb shell pidof -s "$package`:GodotApp").Trim() }
    if($appPid -match '^\d+$') { & $adb logcat --pid=$appPid -d -s 'godot:*' 'AndroidRuntime:E' > $Destination }
    else { 'No running process for this package; no device-wide log collected.' | Set-Content $Destination }
}
if(!$SkipInstall) { Adb-Run @('install','-r',$apk) }
Adb-Run @('shell','am','force-stop',$package)
Adb-Run @('shell','run-as',$package,'mkdir','-p','files')
Adb-Run @('shell','run-as',$package,'touch','files/qa-request.json')
if($Authenticated) {
    if(!(Get-Content (Join-Path $projectRoot 'data/network.json') -Raw | ConvertFrom-Json).enabled) {
        Adb-Run @('reverse','tcp:4192','tcp:4192')
        Adb-Run @('reverse','tcp:4193','tcp:4193')
    }
    Adb-Run @('push',(Join-Path $projectRoot 'server/private/qa-android.json'),'/data/local/tmp/ambatopia-qa-auth.json')
    Adb-Run @('shell','run-as',$package,'cp','/data/local/tmp/ambatopia-qa-auth.json','files/qa-auth.json')
    Adb-Run @('shell','rm','-f','/data/local/tmp/ambatopia-qa-auth.json')
}
if($Network) {
    Adb-Run @('reverse','tcp:4192','tcp:4192')
    Adb-Run @('push',(Join-Path $PSScriptRoot 'qa-network.json'),'/data/local/tmp/gtreference-qa-network.json')
    Adb-Run @('shell','run-as',$package,'cp','/data/local/tmp/gtreference-qa-network.json','files/qa-request.json')
    Adb-Run @('shell','rm','-f','/data/local/tmp/gtreference-qa-network.json')
}
Adb-Run @('shell','run-as',$package,'rm','-f','files/qa-report.json')
$activity = & $adb shell cmd package resolve-activity --brief $package
if($LASTEXITCODE -ne 0) { throw 'Cannot resolve exported launcher activity' }
$component = ($activity | Where-Object { $_ -match ('^'+[regex]::Escape($package)+'/') } | Select-Object -Last 1).Trim()
if(!$component) { throw 'Exported launcher component missing' }
Adb-Run @('shell','am','start','-n',$component)
$ready=$false
$deadline=(Get-Date).AddSeconds($TimeoutSeconds)
while((Get-Date) -lt $deadline) {
    & $adb shell run-as $package test -f files/qa-report.json
    if($LASTEXITCODE -eq 0) { $ready=$true;break }
    Start-Sleep -Seconds 3
}
if(!$ready) {
    Save-OwnLog (Join-Path $evidence 'startup-log.txt')
    try { Save-AppFile 'logs/godot.log' (Join-Path $evidence 'runtime-log.txt') } catch {}
    try { Save-AppFile 'qa-progress.json' (Join-Path $evidence 'progress.json') } catch {}
    throw 'Android QA timed out; inspect startup-log.txt'
}
Save-AppFile 'qa-report.json' (Join-Path $evidence 'qa-report.json')
foreach($name in @('menu','worlds','world','punch','inventory','wardrobe-slots','items','special-machine','special-wardrobe','automation-xenonite','automation-magplant','automation-gaia')) { Save-AppFile "qa-$name.png" (Join-Path $evidence "$name.png") }
foreach($name in @('legendbot','native_costume_particles','costume_and_iceage','costume_and_rlm','advanced_wardrobe_rlm')) { Save-AppFile "qa-effects-$name.png" (Join-Path $evidence "effects-$name.png") }
if($Network) { Save-AppFile 'qa-network.png' (Join-Path $evidence 'network.png') }
$report=Get-Content (Join-Path $evidence 'qa-report.json') -Raw | ConvertFrom-Json
try { Save-AppFile 'logs/godot.log' (Join-Path $evidence 'runtime-log.txt') } catch { Save-OwnLog (Join-Path $evidence 'runtime-log.txt') }
Write-Output ($report | ConvertTo-Json -Depth 6)
if($report.failures.Count -gt 0) { throw 'Android behavioral checks failed' }
