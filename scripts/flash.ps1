<#
.SYNOPSIS
  Flash a built firmware app to the nRF9151 Feather with probe-rs, then reset.
.EXAMPLE
  .\scripts\flash.ps1 -App at_client
#>
param(
    [ValidateSet('app', 'at_client')] [string]$App = 'app',
    [string]$Hex
)
$ErrorActionPreference = 'Stop'

$probeRs = (Get-Command probe-rs -ErrorAction SilentlyContinue).Source
if (-not $probeRs) { $probeRs = "$env:USERPROFILE\.cargo\bin\probe-rs.exe" }
if (-not (Test-Path $probeRs)) { throw "probe-rs not found. Install it (see README, Flash section)." }

if (-not $Hex) {
    $src = Join-Path $PSScriptRoot "..\firmware\$App"
    $Hex = if ($App -eq 'at_client') { "$src\build\merged.hex" } else { "$src\build\circuitdojo_feather_nrf9151\merged.hex" }
}
if (-not (Test-Path $Hex)) { throw "Not found: $Hex. Build first (scripts\build.ps1 -App $App)." }

& $probeRs download --chip nRF9151_xxAA --binary-format hex $Hex
if ($LASTEXITCODE -ne 0) { throw "probe-rs download failed ($LASTEXITCODE)" }
& $probeRs reset --chip nRF9151_xxAA
if ($LASTEXITCODE -ne 0) { throw "probe-rs reset failed ($LASTEXITCODE)" }
Write-Host "Flashed and reset: $Hex"
