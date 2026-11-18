# powerbi-linux: runs at every logon of the VM user (scheduled task 'powerbi-linux').
#  1. If the host dropped a new installer in \\host.lan\Data\update, verify and install it.
#  2. Start Power BI Desktop maximized (if it isn't running already).

$ErrorActionPreference = 'Continue'
$Exchange = '\\host.lan\Data'
$PbiExe   = 'C:\Program Files\Microsoft Power BI Desktop\bin\PBIDesktop.exe'
$LogFile  = 'C:\ProgramData\powerbi-linux\logon.log'
function Log($m) { Add-Content -Path $LogFile -Value ("[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $m) }

# wait for the host share (network comes up a few seconds after logon)
for ($i = 0; $i -lt 30 -and -not (Test-Path $Exchange); $i++) { Start-Sleep -Seconds 2 }

$update = "$Exchange\update\PBIDesktopSetup_x64.exe"
if (Test-Path $update) {
    $local = "$env:TEMP\PBIDesktopSetup_x64.exe"
    Copy-Item $update $local -Force
    $sig = Get-AuthenticodeSignature $local
    if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match 'O=Microsoft Corporation') {
        Log 'installing Power BI update'
        Get-Process PBIDesktop -ErrorAction SilentlyContinue | Stop-Process -Force
        # -quiet (not -passive): the passive UI can hang invisibly when nothing changes.
        $p = Start-Process -FilePath $local -ArgumentList '-quiet','-norestart','ACCEPT_EULA=1' -PassThru
        if (-not $p.WaitForExit(1800 * 1000)) {
            Log 'update installer timed out after 30 min; killing it'
            Get-Process PBIDesktopSetup_x64 -ErrorAction SilentlyContinue | Stop-Process -Force
        }
        Log "update installer exit code $($p.ExitCode)"
        if ($p.ExitCode -eq 0) {
            Remove-Item "$Exchange\update\*" -Force -ErrorAction SilentlyContinue
            $ver = (Get-Item $PbiExe).VersionInfo.ProductVersion
            Set-Content -Path "$Exchange\status.txt" -Encoding ASCII -Value @('stage=done', "powerbi_version=$ver", "message=Power BI Desktop $ver installed")
            Log "updated to $ver"
        }
    } else {
        Log "update rejected: bad signature ($($sig.Status))"
    }
    Remove-Item $local -Force -ErrorAction SilentlyContinue
}

if (-not (Get-Process PBIDesktop -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $PbiExe -WindowStyle Maximized
}
