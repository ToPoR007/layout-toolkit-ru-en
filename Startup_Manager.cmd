@echo off
setlocal

set "APP_NAME=Layout Toolkit RU-EN"
set "SCRIPT=%~dp0Layout_Toolkit_RU_EN.ahk"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUP_LINK=%STARTUP%\Layout Toolkit RU-EN.lnk"
set "AHK="

:MENU
cls
echo ============================================
echo  Layout Toolkit RU-EN Startup Manager
echo ============================================
echo.
echo Script:
echo %SCRIPT%
echo.

if exist "%STARTUP_LINK%" (
    echo Current status: INSTALLED IN STARTUP
) else (
    echo Current status: NOT INSTALLED IN STARTUP
)

echo.
echo 1 - Add to startup
echo 2 - Remove from startup
echo 3 - Exit
echo.

choice /c 123 /n /m "Select option: "

if errorlevel 3 exit /b 0
if errorlevel 2 goto REMOVE
if errorlevel 1 goto INSTALL


:INSTALL
cls
echo Installing startup shortcut...
echo.

if not exist "%SCRIPT%" (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Layout_Toolkit_RU_EN.ahk was not found next to Startup_Manager.cmd.', 'Layout Toolkit', 'OK', 'Error')"
    pause
    goto MENU
)

call :FIND_AHK

if not defined AHK (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('AutoHotkey v2 is required, but it was not found. The official website will open now.', 'AutoHotkey v2 required', 'OK', 'Information')"
    start "" "https://www.autohotkey.com/"
    pause
    goto MENU
)

if not exist "%STARTUP%" (
    mkdir "%STARTUP%" >nul 2>nul
)

set "BASE=%~dp0"
set "PS1=%TEMP%\layout_toolkit_startup_%RANDOM%.ps1"

> "%PS1%" echo $w = New-Object -ComObject WScript.Shell
>> "%PS1%" echo $lnk = $w.CreateShortcut($env:STARTUP_LINK)
>> "%PS1%" echo $lnk.TargetPath = $env:AHK
>> "%PS1%" echo $lnk.Arguments = '"' + $env:SCRIPT + '"'
>> "%PS1%" echo $lnk.WorkingDirectory = $env:BASE
>> "%PS1%" echo $lnk.Description = $env:APP_NAME
>> "%PS1%" echo $lnk.IconLocation = $env:AHK + ',0'
>> "%PS1%" echo $lnk.Save()

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
del "%PS1%" >nul 2>nul

if exist "%STARTUP_LINK%" (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Startup shortcut has been installed.', 'Layout Toolkit', 'OK', 'Information')"
) else (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Failed to create startup shortcut.', 'Layout Toolkit', 'OK', 'Error')"
)

pause
goto MENU


:REMOVE
cls
echo Removing startup shortcut...
echo.

if exist "%STARTUP_LINK%" (
    del "%STARTUP_LINK%" >nul 2>nul
)

if exist "%STARTUP_LINK%" (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Failed to remove startup shortcut.', 'Layout Toolkit', 'OK', 'Error')"
) else (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Startup shortcut has been removed.', 'Layout Toolkit', 'OK', 'Information')"
)

pause
goto MENU


:FIND_AHK
set "AHK="

if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" set "AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey.exe" set "AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey.exe"
if not defined AHK if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe" set "AHK=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey.exe" set "AHK=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey.exe"

exit /b