@echo off
setlocal

set "SCRIPT=%~dp0Layout_Toolkit_RU_EN.ahk"
set "CORE=%~dp0Resolve_AutoHotkey.ps1"

if not exist "%SCRIPT%" (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Layout_Toolkit_RU_EN.ahk was not found next to this launcher.', 'Layout Toolkit', 'OK', 'Error')"
    exit /b 1
)

if not exist "%CORE%" (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Resolve_AutoHotkey.ps1 was not found next to this launcher.', 'Layout Toolkit', 'OK', 'Error')"
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%CORE%" -Action Run -ScriptPath "%SCRIPT%"
exit /b %errorlevel%
