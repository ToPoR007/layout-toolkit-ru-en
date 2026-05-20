@echo off
setlocal

set "SCRIPT=%~dp0Layout_Toolkit_RU_EN.ahk"
set "AHK="

if not exist "%SCRIPT%" (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Layout_Toolkit_RU_EN.ahk was not found next to this launcher.', 'Layout Toolkit', 'OK', 'Error')"
    exit /b 1
)

rem Prefer installed AutoHotkey v2.
if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" set "AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey.exe" set "AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey.exe"
if not defined AHK if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe" set "AHK=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey.exe" set "AHK=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey.exe"

if defined AHK (
    start "" "%AHK%" "%SCRIPT%"
    exit /b 0
)

powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('AutoHotkey v2 is required, but it was not found. The official download page will open now. Click Download v2.0 and install it.', 'AutoHotkey v2 required', 'OK', 'Information')"
start "" "https://www.autohotkey.com/"
exit /b 1