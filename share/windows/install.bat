@echo off
rem powerbi-linux: runs once at the end of the unattended Windows install
rem (dockur/windows executes C:\OEM\install.bat at first logon).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\OEM\setup.ps1" > "C:\OEM\setup.log" 2>&1
if exist "\\host.lan\Data" copy /Y "C:\OEM\setup.log" "\\host.lan\Data\setup.log" >nul
