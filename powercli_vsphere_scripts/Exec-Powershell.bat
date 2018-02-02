:: This is how a powershell script is executed from a batch script
:: When a vCenter alarm is configured to run a script only a batch
:: script can be executed. Really VMware..
:: So this batch script is used for alarms with syntax
:: Exec-Powershell.bat <powershell_script_path>
@echo off
set CMD=C:\Windows\system32\cmd.exe /c
set POWERSHELL=C:\WINDOWS\system32\windowspowershell\v1.0\powershell.exe
%CMD% %POWERSHELL% -command "&'%1'"
