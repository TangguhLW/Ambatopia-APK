$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$adb=Join-Path $projectRoot 'tools/android-sdk/platform-tools/adb.exe'
& $adb install -r (Join-Path $projectRoot 'build/android/GrowtopiaReconstruction.apk')
if($LASTEXITCODE -ne 0) { throw 'Install Android build before synchronizing clients' }
$shell=(Get-Process -Id $PID).Path
$windows=Start-Process -FilePath $shell -ArgumentList @('-NoProfile','-File',(Join-Path $PSScriptRoot 'test-windows.ps1'),'-Network') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $projectRoot 'evidence/windows/network-test.log') -RedirectStandardError (Join-Path $projectRoot 'evidence/windows/network-test-error.log')
& (Join-Path $PSScriptRoot 'test-android.ps1') -Network -SkipInstall
$androidExit=$LASTEXITCODE
$windows.WaitForExit()
if($windows.ExitCode -ne 0 -or $androidExit -ne 0) { throw 'Cross-platform test failed; inspect per-platform reports' }
