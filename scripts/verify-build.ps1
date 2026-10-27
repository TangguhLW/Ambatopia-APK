$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $unit = & ./tools/godot.ps1 --headless --path . --script tests/run.gd -- all
    $unitExit=$LASTEXITCODE
    $unit | Set-Content evidence/verified-unit-tests.log
    if($unitExit -ne 0 -or ($unit -join "`n") -match '(SCRIPT ERROR|ERROR:|FAIL:)') { throw 'Godot behavior checks failed' }
    & node --test tests/*.test.mjs > evidence/verified-asset-tests.log
    if($LASTEXITCODE -ne 0) { throw 'Asset importer checks failed' }
    foreach($path in @('build/windows/GrowtopiaReconstruction.exe','build/android/GrowtopiaReconstruction.apk')) {
        if(!(Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -lt 1000000) { throw "Missing build: $path" }
    }
    $javaInfo=Get-Content tools/android.json -Raw | ConvertFrom-Json
    $env:JAVA_HOME=$javaInfo.java
    & ./tools/android-sdk/build-tools/35.0.1/apksigner.bat verify --verbose build/android/GrowtopiaReconstruction.apk > evidence/apk-signature.log
    if($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
    $hashes=Get-FileHash -Algorithm SHA256 build/windows/GrowtopiaReconstruction.exe,build/android/GrowtopiaReconstruction.apk
    $hashes | Select-Object Path,Hash | ConvertTo-Json | Set-Content evidence/build-hashes.json
    Write-Output ($unit | Select-Object -Last 3)
    Write-Output 'Asset tests, exported artifacts and APK signature verified.'
} finally { Pop-Location }
