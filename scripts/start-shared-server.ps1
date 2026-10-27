param([switch]$QA)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$serverExecutable=Join-Path $projectRoot 'build/windows/GrowtopiaReconstruction.exe'
if(!(Test-Path -LiteralPath $serverExecutable)) { throw 'Build the Windows executable first.' }
$evidence=Join-Path $projectRoot 'evidence/ambatopia-2026-10-23'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$arguments=@('--headless','--server')
$serverEnvironment=@{}
if($QA) { $arguments+='--qa-server' }
else {
 foreach($line in Get-Content (Join-Path $projectRoot 'server/private/.env')) {
  if($line -match '^GAME_INTERNAL_TOKEN=(.+)$') { $serverEnvironment['GAME_INTERNAL_TOKEN']=$Matches[1] }
 }
 if(!$serverEnvironment['GAME_INTERNAL_TOKEN']) { throw 'Private account service configuration missing.' }
}
$process=Start-Process -FilePath $serverExecutable -ArgumentList $arguments -WorkingDirectory $projectRoot -Environment $serverEnvironment -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $evidence 'server.log') -RedirectStandardError (Join-Path $evidence 'server-error.log')
$process.Id | Set-Content (Join-Path $evidence 'server.pid')
Write-Output "Game server started on loopback port 4192; anonymous QA mode: $QA"
