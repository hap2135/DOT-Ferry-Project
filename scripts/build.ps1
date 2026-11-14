<#
.SYNOPSIS
  Build a firmware app for the nRF9151 Feather from a plain PowerShell window.
.EXAMPLE
  .\scripts\build.ps1 -App at_client
  .\scripts\build.ps1 -App app
#>
param(
    [ValidateSet('app', 'at_client')] [string]$App = 'app',
    [string]$Toolchain = 'C:\ncs\toolchains\0b393f9e1b',
    [string]$Workspace = 'C:\nfed'
)
$ErrorActionPreference = 'Stop'

# Same environment the nRF Connect terminal sets up (from the toolchain's environment.json).
$rel = 'bin','mingw64\bin','opt\bin','opt\bin\Scripts','opt\nanopb\generator-bin',
       'opt\zephyr-sdk\arm-zephyr-eabi\bin','opt\zephyr-sdk\riscv64-zephyr-elf\bin'
$env:PATH = (@($Toolchain) + ($rel | ForEach-Object { Join-Path $Toolchain $_ }) -join ';') + ';' + $env:PATH
$env:PYTHONPATH = "$Toolchain\opt\bin;$Toolchain\opt\bin\Lib;$Toolchain\opt\bin\Lib\site-packages"
$env:ZEPHYR_TOOLCHAIN_VARIANT = 'zephyr'
$env:ZEPHYR_SDK_INSTALL_DIR = "$Toolchain\opt\zephyr-sdk"
$env:ZEPHYR_BASE = "$Workspace\external\zephyr"

$src = Join-Path $PSScriptRoot "..\firmware\$App" | Resolve-Path
# at_client uses a short build dir: TF-M's nested object paths otherwise exceed
# the Windows 260-character path limit ("opening dependency file ... No such file").
$out = if ($App -eq 'at_client') { Join-Path $src 'build' } else { Join-Path $src 'build\circuitdojo_feather_nrf9151' }

Push-Location $Workspace   # west must run inside the nfed workspace
try {
    west build -b circuitdojo_feather_nrf9151/nrf9151/ns -p always -s $src -d $out --sysbuild
    if ($LASTEXITCODE -ne 0) { throw "west build failed ($LASTEXITCODE)" }
} finally { Pop-Location }

Write-Host "`nBuilt: $out\merged.hex"
