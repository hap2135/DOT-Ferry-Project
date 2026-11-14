<#
.SYNOPSIS
  Bare-bones LTE connectivity check for the nRF9151 Feather over its COM port.

.DESCRIPTION
  Requires the AT client firmware (firmware/at_client) on the board. Sends AT
  commands over the serial port and prints PASS/FAIL per check, plus a full
  transcript log file.

  -Mode SimIn   SIM inserted: expects SIM READY, network registration and an IP address.
  -Mode SimOut  SIM removed:  expects the modem to report no SIM and NOT register.

  Exit code 0 = all checks passed, 1 = a check failed, 2 = could not talk to the modem.

.EXAMPLE
  .\scripts\cell_check.ps1 -Mode SimOut
  .\scripts\cell_check.ps1 -Mode SimIn -Port COM5 -RegTimeoutSec 300
#>
param(
    [Parameter(Mandatory)] [ValidateSet('SimIn', 'SimOut')] [string]$Mode,
    [string]$Port = 'COM5',
    [int]$Baud = 115200,
    # SimIn: how long to wait for network registration (first attach can take minutes).
    [int]$RegTimeoutSec = 180,
    # SimOut: how long to watch and confirm the modem does NOT register.
    [int]$NoRegWatchSec = 30,
    # %XSYSTEMMODE: LTE-M, NB-IoT, GNSS, preference. Default: LTE-M + NB-IoT.
    [string]$SystemMode = '1,1,0,0',
    [string]$LogDir = '.'
)
$ErrorActionPreference = 'Stop'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = Join-Path $LogDir "cell_check_${Mode}_$stamp.log"
$results = New-Object System.Collections.Generic.List[object]

function Log([string]$line) {
    $ts = Get-Date -Format 'HH:mm:ss.fff'
    Add-Content -Path $logFile -Value "[$ts] $line"
}

function Add-Result([string]$name, [bool]$pass, [string]$detail) {
    $results.Add([pscustomobject]@{ Check = $name; Result = $(if ($pass) { 'PASS' } else { 'FAIL' }); Detail = $detail })
    $color = if ($pass) { 'Green' } else { 'Red' }
    Write-Host ("  [{0}] {1}: {2}" -f $(if ($pass) { 'PASS' } else { 'FAIL' }), $name, $detail) -ForegroundColor $color
}

function Add-Info([string]$name, [string]$detail) {
    $results.Add([pscustomobject]@{ Check = $name; Result = 'INFO'; Detail = $detail })
    Write-Host "  [INFO] ${name}: $detail" -ForegroundColor Gray
}

# Send one AT command; return @{ Ok = bool; Lines = string[]; Final = string }.
function Send-At([string]$cmd, [int]$timeoutMs = 5000) {
    $sp.DiscardInBuffer()
    Log ">> $cmd"
    $sp.Write("$cmd`r")
    $buf = ''
    $deadline = (Get-Date).AddMilliseconds($timeoutMs)
    while ((Get-Date) -lt $deadline) {
        $buf += $sp.ReadExisting()
        if ($buf -match '(?m)^(OK|ERROR|\+CME ERROR:.*|\+CMS ERROR:.*)\r?$') { break }
        Start-Sleep -Milliseconds 50
    }
    $lines = @($buf -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne $cmd })
    $lines | ForEach-Object { Log "<< $_" }
    $final = ($lines | Where-Object { $_ -match '^(OK|ERROR|\+CME ERROR|\+CMS ERROR)' } | Select-Object -Last 1)
    if (-not $final) { $final = 'TIMEOUT'; Log '<< (timeout)' }
    return @{ Ok = ($final -eq 'OK'); Lines = $lines; Final = $final }
}

function Body($r) { ($r.Lines | Where-Object { $_ -notmatch '^(OK|ERROR|\+CME ERROR|\+CMS ERROR)' }) -join ' | ' }

# CEREG <stat> meanings (3GPP + Nordic extension 90).
$ceregText = @{
    '0' = 'not registered, not searching'; '1' = 'registered, home network'
    '2' = 'not registered, searching';     '3' = 'registration denied'
    '4' = 'unknown (e.g. out of coverage)'; '5' = 'registered, roaming'
    '90' = 'not registered, SIM (UICC) failure / no SIM'
}
function Get-CeregStat {
    $r = Send-At 'AT+CEREG?'
    $line = $r.Lines | Where-Object { $_ -like '+CEREG:*' } | Select-Object -First 1
    if ($line -match '^\+CEREG:\s*\d+,(\d+)') { return $Matches[1] }
    return $null
}

Write-Host "DOT Ferry cellular check  mode=$Mode  port=$Port@$Baud"
Write-Host "Log: $logFile`n"
Log "cell_check mode=$Mode port=$Port baud=$Baud systemmode=$SystemMode"

$sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, 'None', 8, 'One'
$sp.DtrEnable = $true
$sp.Encoding = [System.Text.Encoding]::ASCII
try { $sp.Open() } catch {
    Write-Host "Cannot open ${Port}: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Close any other serial terminal using the port, and check the port number in Device Manager.'
    exit 2
}

try {
    # 1. Modem alive (retry: the firmware needs ~2 s after reset).
    $alive = $false
    for ($i = 0; $i -lt 10 -and -not $alive; $i++) {
        $alive = (Send-At 'AT' 1000).Ok
        if (-not $alive) { Start-Sleep -Milliseconds 500 }
    }
    Add-Result 'Modem responds to AT' $alive $(if ($alive) { 'OK' } else { 'no response. Is the at_client firmware flashed? (scripts\flash.ps1 -App at_client)' })
    if (-not $alive) { exit 2 }

    # 2. Identity (informational).
    Add-Info 'Modem model' (Body (Send-At 'AT+CGMM'))
    Add-Info 'Modem firmware' (Body (Send-At 'AT+CGMR'))
    Add-Info 'IMEI' ((Body (Send-At 'AT+CGSN=1')) -replace '^\+CGSN:\s*"?([^"]*)"?.*', '$1')

    # 3. Configure and turn the radio on.
    [void](Send-At 'AT+CFUN=0' 10000)
    $sm = Send-At "AT%XSYSTEMMODE=$SystemMode"
    Add-Info 'System mode' "$SystemMode -> $($sm.Final)"
    [void](Send-At 'AT+CEREG=5')
    $on = Send-At 'AT+CFUN=1' 10000
    Add-Result 'Radio on (AT+CFUN=1)' $on.Ok $on.Final
    Start-Sleep -Seconds 3

    # 4. SIM state.
    $cpin = Send-At 'AT+CPIN?'
    $cpinBody = Body $cpin
    $simReady = $cpin.Ok -and ($cpinBody -match 'READY')
    $xsim = Body (Send-At 'AT%XSIM?')
    $iccid = Send-At 'AT%XICCID'
    $iccidVal = (Body $iccid) -replace '^%XICCID:\s*', ''
    $imsi = Send-At 'AT+CIMI'
    $imsiVal = Body $imsi

    if ($Mode -eq 'SimIn') {
        Add-Result 'SIM ready (AT+CPIN?)' $simReady $(if ($cpinBody) { $cpinBody } else { $cpin.Final })
        Add-Info 'SIM detected (AT%XSIM?)' $xsim
        Add-Result 'ICCID readable' ($iccid.Ok -and $iccidVal) $(if ($iccidVal) { $iccidVal } else { $iccid.Final })
        Add-Info 'IMSI' $(if ($imsi.Ok) { $imsiVal } else { $imsi.Final })

        # 5. Network registration.
        Write-Host "  ... waiting up to $RegTimeoutSec s for network registration"
        $stat = $null; $t0 = Get-Date
        while (((Get-Date) - $t0).TotalSeconds -lt $RegTimeoutSec) {
            $stat = Get-CeregStat
            if ($stat -in '1', '5', '3') { break }
            Start-Sleep -Seconds 5
        }
        $elapsed = [int]((Get-Date) - $t0).TotalSeconds
        $registered = $stat -in '1', '5'
        Add-Result 'Network registration (AT+CEREG?)' $registered ("stat={0} ({1}) after {2} s" -f $stat, $ceregText["$stat"], $elapsed)

        if ($registered) {
            Add-Info 'Operator (AT+COPS?)' (Body (Send-At 'AT+COPS?'))
            Add-Info 'Signal (AT+CESQ)' (Body (Send-At 'AT+CESQ'))
            Add-Info 'Monitor (AT%XMONITOR)' (Body (Send-At 'AT%XMONITOR'))
            Add-Info 'APN (AT+CGDCONT?)' (Body (Send-At 'AT+CGDCONT?'))
            $ip = Body (Send-At 'AT+CGPADDR')
            $hasIp = $ip -match '\+CGPADDR:\s*\d+,"?[0-9A-Fa-f\.:]{3,}'
            Add-Result 'IP address assigned (AT+CGPADDR)' $hasIp $(if ($ip) { $ip } else { 'none' })
        }
    }
    else {
        Add-Result 'No SIM reported (AT+CPIN?)' (-not $simReady) $(if ($cpinBody) { $cpinBody } else { $cpin.Final })
        Add-Info 'SIM detected (AT%XSIM?)' $xsim
        Add-Result 'No ICCID readable' (-not ($iccid.Ok -and $iccidVal)) $(if ($iccidVal) { $iccidVal } else { $iccid.Final })

        Write-Host "  ... watching $NoRegWatchSec s to confirm the modem does not register"
        $everRegistered = $false; $stat = $null; $t0 = Get-Date
        while (((Get-Date) - $t0).TotalSeconds -lt $NoRegWatchSec) {
            $stat = Get-CeregStat
            if ($stat -in '1', '5') { $everRegistered = $true; break }
            Start-Sleep -Seconds 5
        }
        Add-Result 'Does not register without SIM' (-not $everRegistered) ("stat={0} ({1})" -f $stat, $ceregText["$stat"])
    }

    # Leave the radio off.
    [void](Send-At 'AT+CFUN=0' 10000)
}
finally {
    if ($sp.IsOpen) { $sp.Close() }
}

$failed = @($results | Where-Object Result -eq 'FAIL').Count
Write-Host ''
$results | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Host
$results | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Add-Content -Path $logFile
if ($failed -eq 0) {
    Write-Host "OVERALL: PASS ($Mode)" -ForegroundColor Green; Log "OVERALL: PASS"; exit 0
} else {
    Write-Host "OVERALL: FAIL ($Mode, $failed check(s) failed)" -ForegroundColor Red; Log "OVERALL: FAIL"; exit 1
}
