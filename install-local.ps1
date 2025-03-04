Param(
  [string]$TargetDir
)

$ErrorActionPreference = "Stop"

if (-not $TargetDir)
{
    $TargetDir = [array]($env:PSModulePath -split ';') | Where-Object { $_.StartsWith($env:USERPROFILE) } | Select-Object -First 1
    if (-not $TargetDir)
    {
        throw "Unable to find a PSModulePath in your user profile (" + $env:UserProfile + "), PSModulePath: " + $env:PSModulePath
    }
}

if (-not (Test-Path $TargetDir))
{
    New-Item -Path $TargetDir -ItemType Container -Force | Out-Null
}
$ModuleName = "safeguard-ps"
$Module = (Join-Path $PSScriptRoot "src\$ModuleName.psd1")
$ModuleDef = (Invoke-Expression -Command (Get-Content $Module -Raw))

Write-Host "Installing '$ModuleName $($ModuleDef["ModuleVersion"])' to '$TargetDir'"
$ModuleDir = (Join-Path $TargetDir $ModuleName)
if (-not (Test-Path $ModuleDir))
{
    New-Item -Path $ModuleDir -ItemType Container -Force | Out-Null
}
else
{
    Remove-Item -Recurse -Force (Join-Path $ModuleDir "*")
}
$VersionDir = (Join-Path $ModuleDir $ModuleDef["ModuleVersion"])
if (-not (Test-Path $VersionDir))
{
    New-Item -Path $VersionDir -ItemType Container -Force | Out-Null
}
Copy-Item -Recurse -Path (Join-Path $PSScriptRoot "src\*") -Destination $VersionDir