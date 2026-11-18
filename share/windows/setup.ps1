# powerbi-linux: one-time Windows setup (runs as the VM user at first logon, UAC is off).
#  - installs Power BI Desktop from C:\OEM after checking its Microsoft signature
#  - registers a logon task (C:\ProgramData\powerbi-linux\logon.ps1) that applies
#    pending updates and starts Power BI maximized
#  - hides the taskbar so the RDP window looks like "just Power BI"
# Progress is reported to the Linux host through \\host.lan\Data\status.txt

$ErrorActionPreference = 'Stop'
$Exchange = '\\host.lan\Data'
$AppDir   = 'C:\ProgramData\powerbi-linux'
$PbiExe   = 'C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe'

function Write-Status([hashtable]$kv) {
    $lines = $kv.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    for ($i = 0; $i -lt 30; $i++) {
        try { Set-Content -Path "$Exchange\status.txt" -Value $lines -Encoding ASCII; return }
        catch { Start-Sleep -Seconds 2 }
    }
}
function Log($m) { Write-Output ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $m) }

try {
    Log 'powerbi-linux setup started'
    Write-Status @{ stage = 'powerbi'; message = 'Windows is ready. Installing Power BI Desktop...' }

    # 0. Clock + time zone from the Linux host (C:\OEM\host.txt: timezone=<Windows ID>).
    #    The VM's hardware clock runs in UTC: tell Windows so, then sync via NTP now.
    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name RealTimeIsUniversal `
        -PropertyType DWord -Value 1 -Force | Out-Null
    if (Test-Path 'C:\OEM\host.txt') {
        $tz = (Get-Content 'C:\OEM\host.txt' | Where-Object { $_ -like 'timezone=*' }) -replace '^timezone=', ''
        if ($tz) {
            try { Set-TimeZone -Id $tz.Trim(); Log "time zone set to $tz" } catch { Log "could not set time zone '$tz': $_" }
        }
    }
    try {
        Set-Service w32time -StartupType Automatic; Start-Service w32time
        w32tm /config /manualpeerlist:time.windows.com /syncfromflags:manual /update | Out-Null
        for ($i = 0; $i -lt 6; $i++) {
            Start-Sleep -Seconds 5
            if ((w32tm /resync /force) -match 'completed successfully') { break }
        }
        Log "clock: $(Get-Date)"
    } catch { Log "time sync failed (fixed on next boot): $_" }

    # 1. Power BI Desktop (verify Authenticode signature first)
    $setup = 'C:\OEM\PBIDesktopSetup_x64.exe'
    $sig = Get-AuthenticodeSignature $setup
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        throw "Power BI installer signature check failed: $($sig.Status) $($sig.SignerCertificate.Subject)"
    }
    Log "signature ok: $($sig.SignerCertificate.Subject)"
    $p = Start-Process -FilePath $setup -ArgumentList '-quiet','-norestart','ACCEPT_EULA=1' -Wait -PassThru
    Log "installer exit code $($p.ExitCode)"
    if (-not (Test-Path $PbiExe)) { throw "Power BI installer finished (exit $($p.ExitCode)) but $PbiExe is missing" }
    $ver = (Get-Item $PbiExe).VersionInfo.ProductVersion

    # 2. Logon task: pending update + start Power BI maximized
    New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
    Copy-Item 'C:\OEM\logon.ps1' "$AppDir\logon.ps1" -Force
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                   -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$AppDir\logon.ps1`""
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
    Register-ScheduledTask -TaskName 'powerbi-linux' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Log 'logon task registered'

    # 3. Auto-hide the taskbar (StuckRects3 byte 8: 3 = auto-hide)
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    for ($i = 0; $i -lt 30 -and -not (Test-Path $k); $i++) { Start-Sleep -Seconds 2 }
    if (Test-Path $k) {
        $v = (Get-ItemProperty -Path $k -Name Settings).Settings
        $v[8] = 3
        Set-ItemProperty -Path $k -Name Settings -Value $v
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue   # restarts automatically
        Log 'taskbar set to auto-hide'
    } else { Log 'StuckRects3 not found; taskbar left as is' }

    # 4. No sleep / screen-off inside the VM (the host handles power)
    powercfg /change standby-timeout-ac 0; powercfg /change monitor-timeout-ac 0; powercfg /hibernate off

    Write-Status @{ stage = 'done'; powerbi_version = $ver; message = "Power BI Desktop $ver installed" }
    Log "done, Power BI $ver"
    Start-Process -FilePath $PbiExe -WindowStyle Maximized
}
catch {
    Log "ERROR: $_"
    Write-Status @{ stage = 'error'; error = ($_.ToString() -replace "[\r\n]+", ' '); message = 'Setup failed' }
    exit 1
}
