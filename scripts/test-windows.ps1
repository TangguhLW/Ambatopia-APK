param([switch]$Network,[switch]$Authenticated,[string]$Executable='build/windows/GrowtopiaReconstruction.exe')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$evidence=Join-Path $projectRoot 'evidence/windows'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
if($Authenticated) {
    Copy-Item -LiteralPath (Join-Path $projectRoot 'server/private/qa-windows.json') -Destination (Join-Path $projectRoot 'tools/profile-export/GTRef/qa-auth.json') -Force
}
$info=[System.Diagnostics.ProcessStartInfo]::new()
$info.FileName=Join-Path $projectRoot $Executable
$info.UseShellExecute=$false
$info.RedirectStandardOutput=$true
$info.RedirectStandardError=$true
$info.Environment['APPDATA']=Join-Path $projectRoot 'tools/profile-export'
$info.ArgumentList.Add('--qa-run')
$info.ArgumentList.Add('--qa-exit')
if($Network) { $info.ArgumentList.Add('--qa-network') }
$process=[System.Diagnostics.Process]::Start($info)
$stdout=$process.StandardOutput.ReadToEndAsync()
$stderr=$process.StandardError.ReadToEndAsync()
$process.WaitForExit()
$output=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
$output | Set-Content (Join-Path $evidence 'runtime-log.txt')
if($process.ExitCode -ne 0 -or $output -match '(SCRIPT ERROR|ERROR:)') { throw 'Exported Windows QA failed; see runtime-log.txt' }
$reportFile=Get-Item -LiteralPath (Join-Path $projectRoot 'tools/profile-export/GTRef/qa-report.json') -ErrorAction SilentlyContinue
if(!$reportFile) { throw 'Exported Windows QA report missing' }
Copy-Item -LiteralPath $reportFile.FullName -Destination (Join-Path $evidence 'qa-report.json') -Force
$report=Get-Content (Join-Path $evidence 'qa-report.json') -Raw | ConvertFrom-Json
foreach($name in @('menu','worlds','world','inventory','wardrobe-slots','items','special-machine','special-wardrobe','automation-xenonite','automation-magplant','automation-gaia')) { Copy-Item -LiteralPath (Join-Path $reportFile.DirectoryName "qa-$name.png") -Destination (Join-Path $evidence "$name.png") -Force }
if($Network) { Copy-Item -LiteralPath (Join-Path $reportFile.DirectoryName 'qa-network.png') -Destination (Join-Path $evidence 'network.png') -Force }
$report | ConvertTo-Json -Depth 6
if($report.failures.Count -ne 0) { throw 'Windows behavioral QA failed' }
