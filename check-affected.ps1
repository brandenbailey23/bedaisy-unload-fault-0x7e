<#
    check-affected.ps1

    Gathers everything needed to add a reproduction report to this repository:
      "BEDaisy.sys fault in its minifilter unload path - 0x7E at +0x1720619"

    Read-only. Changes nothing. Runs unelevated.

    NOTE ON MEMORY INTEGRITY (HVCI)
      This defect is NOT related to HVCI. It reproduces with Memory Integrity both enabled and
      disabled. HVCI state is collected below for completeness only - do not disable a security
      feature to test this.

    Usage:
      pwsh -NoProfile -ExecutionPolicy Bypass -File check-affected.ps1

    Then paste the output into a new issue.
#>

$ErrorActionPreference = 'Continue'
$knownBad = '184F28E4AC5C178AE05078F57AB54F3F3AE9864BC2FEA8CE20CB62AB8F3ECB7A'

function Line($k, $v) { "{0,-28} {1}" -f ($k + ':'), $v }

Write-Output '=== Windows ========================================='
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
Line 'ProductName'    $cv.ProductName
Line 'DisplayVersion' $cv.DisplayVersion
Line 'Build'          ("{0}.{1}" -f $cv.CurrentBuild, $cv.UBR)
Line 'BuildLabEx'     $cv.BuildLabEx

Write-Output ''
Write-Output '=== BattlEye driver ================================='
$be = 'C:\Program Files (x86)\Common Files\BattlEye\BEDaisy.sys'
if (Test-Path $be) {
    $i = Get-Item $be
    $h = (Get-FileHash $be -Algorithm SHA256).Hash
    Line 'Size'        ("{0:N0} bytes" -f $i.Length)
    Line 'Modified'    $i.LastWriteTime
    Line 'SHA-256'     $h
    Line 'Reported build?' $(if ($h -eq $knownBad) { 'YES - byte-identical to the reported driver' } else { 'no - different build' })
} else {
    Write-Output '  BEDaisy.sys not present (BattlEye not currently deployed - normal when no game is running)'
}

Write-Output ''
Write-Output '=== Bugchecks in the last 90 days ==================='
$since = (Get-Date).AddDays(-90)
$bc = @(Get-WinEvent -FilterHashtable @{
            LogName = 'System'; Id = 1001
            ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'
            StartTime = $since
        } -ErrorAction SilentlyContinue)
if (-not $bc.Count) {
    Write-Output '  none'
} else {
    foreach ($e in $bc) {
        $code = if ($e.Message -match 'bugcheck was:\s*(0x[0-9a-fA-F]+)') { $matches[1] } else { '?' }
        $addr = if ($e.Message -match 'bugcheck was:\s*0x[0-9a-fA-F]+\s*\(\s*0x[0-9a-fA-F]+,\s*(0x[0-9a-fA-F`]+)') { $matches[1] } else { '' }
        # Fault addresses from this defect always end in 0619 (64 KB-aligned base + offset 0x1720619)
        $suffix = if ($addr) { if ($addr -match '0619$') { '  <- address ends 0619: CONSISTENT with this defect' } else { '  <- address does NOT end 0619' } } else { '' }
        Line $e.TimeCreated.ToString('yyyy-MM-dd HH:mm') "$code $addr$suffix"
    }
}

Write-Output ''
Write-Output '=== Installer / filter-driver activity near bugchecks ='
Write-Output '   (the trigger is BEDaisy unloading while installer activity churns kernel filters)'
if (-not $bc.Count) {
    Write-Output '  (no bugchecks to correlate)'
} else {
    foreach ($e in $bc) {
        $t0 = $e.TimeCreated.AddMinutes(-10); $t1 = $e.TimeCreated.AddSeconds(5)
        $hits = @()
        # Service Control Manager 7045 = a service was installed in the system
        $hits += @(Get-WinEvent -FilterHashtable @{LogName='System'; Id=7045; StartTime=$t0; EndTime=$t1} -ErrorAction SilentlyContinue) |
                 ForEach-Object { '  7045 service installed' }
        # MsiInstaller activity
        $hits += @(Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='MsiInstaller'; StartTime=$t0; EndTime=$t1} -ErrorAction SilentlyContinue) |
                 ForEach-Object { '  MsiInstaller event' }
        # Filter Manager
        $hits += @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-FilterManager'; StartTime=$t0; EndTime=$t1} -ErrorAction SilentlyContinue) |
                 ForEach-Object { '  FilterManager event' }
        if ($hits.Count) {
            Line $e.TimeCreated.ToString('yyyy-MM-dd HH:mm') ("{0} installer/filter event(s) in the 10 min before" -f $hits.Count)
            $hits | Select-Object -Unique | ForEach-Object { Write-Output $_ }
        } else {
            Line $e.TimeCreated.ToString('yyyy-MM-dd HH:mm') 'no installer/filter events in the 10 min before'
        }
    }
}

Write-Output ''
Write-Output '=== "Possibly related driver" events (WER 1019) ====='
$rd = @(Get-WinEvent -FilterHashtable @{
            LogName = 'System'; Id = 1019
            ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'
            StartTime = $since
        } -ErrorAction SilentlyContinue)
if (-not $rd.Count) {
    Write-Output '  none'
} else {
    foreach ($e in $rd) {
        $drv = ($e.Message -replace '.*Possibly related driver:\s*', '') -replace '\.\s*$', ''
        Line $e.TimeCreated.ToString('yyyy-MM-dd HH:mm') $drv.Trim()
    }
}

Write-Output ''
Write-Output '=== Virtualisation-based security (completeness only) ='
Write-Output '   Not the cause of this defect - do not disable HVCI to test.'
$dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
if ($dg) {
    Line 'VBS status'          $dg.VirtualizationBasedSecurityStatus
    Line 'Services configured' ($dg.SecurityServicesConfigured -join ',')
    Line 'Services running'    ($dg.SecurityServicesRunning -join ',')
    Line 'HVCI running'        [bool]($dg.SecurityServicesRunning -contains 2)
    Write-Output '   (VBS status: 0=off 1=enabled/not running 2=running; service 2 = HVCI)'
} else {
    Write-Output '  (Win32_DeviceGuard unavailable)'
}
$hv = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -ErrorAction SilentlyContinue
if ($hv) { Line 'HVCI\Enabled (registry)' $hv.Enabled }

Write-Output ''
Write-Output '=== Crash dumps on disk ============================='
foreach ($p in 'C:\Windows\Minidump', 'C:\Windows\MEMORY.DMP') {
    if (Test-Path $p) {
        if ((Get-Item $p -Force).PSIsContainer) {
            $n = @(Get-ChildItem $p -Filter *.dmp -ErrorAction SilentlyContinue).Count
            Line $p "$n dump(s)"
        } else {
            Line $p ("{0:N0} bytes" -f (Get-Item $p -Force).Length)
        }
    } else {
        Line $p 'absent'
    }
}
Write-Output '   (C:\Windows\Minidump and MEMORY.DMP are not readable without elevation - "absent" here may be a permissions artefact)'

Write-Output ''
Write-Output '=== Other security software ========================='
$bem = Get-Process -Name BemSvc -ErrorAction SilentlyContinue
Line 'HP Wolf BemSvc running' [bool]$bem
$flt = Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -match 'vlflt|Gemma|atc|BdDci|BEDaisy' } |
       ForEach-Object { "{0}={1}" -f $_.Name, $_.State }
if ($flt) { Line 'Filter/minifilter drivers' ($flt -join ' ') } else { Line 'Filter/minifilter drivers' 'none matched' }

Write-Output ''
Write-Output '=== -------------------------------------------------'
Write-Output 'Paste everything above into a new issue in this repository.'
Write-Output ''
