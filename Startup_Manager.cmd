@echo off
setlocal

set "APP_NAME=Layout Toolkit RU-EN"
set "SCRIPT=%~dp0Layout_Toolkit_RU_EN.ahk"
set "CORE=%~dp0Resolve_AutoHotkey.ps1"
set "ICON=%~dp0Assets\icon.ico"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "STARTUP_LINK=%STARTUP%\Layout Toolkit RU-EN.lnk"

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

if not exist "%CORE%" (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Resolve_AutoHotkey.ps1 was not found next to Startup_Manager.cmd.', 'Layout Toolkit', 'OK', 'Error')"
    pause
    goto MENU
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%CORE%" -Action InstallStartup -ScriptPath "%SCRIPT%" -IconPath "%ICON%" -StartupLink "%STARTUP_LINK%"
if errorlevel 2 goto MENU
if errorlevel 1 (
    powershell -NoProfile -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('PowerShell failed to create startup shortcut.', 'Layout Toolkit', 'OK', 'Error')"
    pause
    goto MENU
)

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
