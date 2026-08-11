[CmdletBinding()]
param(
    [ValidateSet("Run", "InstallStartup", "Resolve")]
    [string]$Action = "Resolve",

    [string]$ScriptPath = "",
    [string]$IconPath = "",
    [string]$StartupLink = "",
    [string]$CachePath = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

$script:AppName = "Layout Toolkit RU-EN"
$script:OfficialDownloadUrl = "https://www.autohotkey.com/download/ahk-v2.exe"
$script:OfficialDownloadPage = "https://www.autohotkey.com/download/"

if ([string]::IsNullOrWhiteSpace($CachePath)) {
    $CachePath = Join-Path $env:LOCALAPPDATA "Layout Toolkit\autohotkey-path.txt"
}


function Show-Message {
    param(
        [string]$Text,
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )

    return [System.Windows.Forms.MessageBox]::Show($Text, $script:AppName, $Buttons, $Icon)
}


function Test-AutoHotkeyV2 {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or ![System.IO.File]::Exists($Path)) {
        return $false
    }

    try {
        $item = Get-Item -LiteralPath $Path
        $version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($item.FullName)

        if ($item.Extension -ine ".exe" -or $item.Name -ieq "AutoHotkeyUX.exe") {
            return $false
        }

        if ($version.ProductName -ine "AutoHotkey" -or $version.ProductMajorPart -lt 2) {
            return $false
        }

        if ($version.FileDescription -match "(?i)installer|setup") {
            return $false
        }

        return $true
    } catch {
        return $false
    }
}


function Save-AutoHotkeyPath {
    param([string]$Path)

    $directory = Split-Path -Parent $CachePath
    if (![string]::IsNullOrWhiteSpace($directory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    [System.IO.File]::WriteAllText(
        $CachePath,
        $fullPath,
        [System.Text.UTF8Encoding]::new($false)
    )

    return $fullPath
}


function Find-AutoHotkeyV2 {
    $candidates = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    function Add-Candidate {
        param([string]$Path)

        if ([string]::IsNullOrWhiteSpace($Path)) {
            return
        }

        $expanded = [System.Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
        if ($seen.Add($expanded)) {
            $candidates.Add($expanded) | Out-Null
        }
    }

    function Add-InstallRoot {
        param([string]$Root)

        if ([string]::IsNullOrWhiteSpace($Root)) {
            return
        }

        foreach ($relativePath in @(
            "v2\AutoHotkey64.exe",
            "v2\AutoHotkey.exe",
            "v2\AutoHotkey32.exe",
            "AutoHotkey64.exe",
            "AutoHotkey.exe",
            "AutoHotkey32.exe"
        )) {
            Add-Candidate (Join-Path $Root $relativePath)
        }

        if ([System.IO.Directory]::Exists($Root)) {
            Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^v2(?:\.|$)' } |
                Sort-Object Name -Descending |
                ForEach-Object {
                    Add-Candidate (Join-Path $_.FullName "AutoHotkey64.exe")
                    Add-Candidate (Join-Path $_.FullName "AutoHotkey.exe")
                    Add-Candidate (Join-Path $_.FullName "AutoHotkey32.exe")
                }
        }
    }

    Add-Candidate $env:LAYOUT_TOOLKIT_AHK

    if ([System.IO.File]::Exists($CachePath)) {
        try {
            Add-Candidate ([System.IO.File]::ReadAllText($CachePath).Trim())
        } catch {
        }
    }

    Add-InstallRoot $PSScriptRoot

    foreach ($registryPath in @(
        "Registry::HKEY_CURRENT_USER\Software\AutoHotkey",
        "Registry::HKEY_LOCAL_MACHINE\Software\AutoHotkey",
        "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\AutoHotkey",
        "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\AutoHotkey",
        "Registry::HKEY_CURRENT_USER\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\AutoHotkey",
        "Registry::HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\AutoHotkey"
    )) {
        try {
            $entry = Get-ItemProperty -Path $registryPath -ErrorAction Stop
            Add-InstallRoot $entry.InstallDir
            Add-InstallRoot $entry.InstallLocation
        } catch {
        }
    }

    foreach ($associationPath in @(
        "Registry::HKEY_CURRENT_USER\Software\Classes\AutoHotkeyScript\Shell\Open\Command",
        "Registry::HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Open\Command"
    )) {
        try {
            $command = (Get-Item -Path $associationPath -ErrorAction Stop).GetValue("")
            if ($command -match '^\s*"([^"]+)"') {
                $registeredExe = $matches[1]
                if ([System.IO.Path]::GetFileName($registeredExe) -ieq "AutoHotkeyUX.exe") {
                    Add-InstallRoot (Split-Path -Parent (Split-Path -Parent $registeredExe))
                } else {
                    Add-Candidate $registeredExe
                }
            }
        } catch {
        }
    }

    foreach ($commandName in @("AutoHotkey64.exe", "AutoHotkey.exe", "AutoHotkey32.exe")) {
        try {
            Get-Command $commandName -CommandType Application -All -ErrorAction Stop |
                ForEach-Object { Add-Candidate $_.Source }
        } catch {
        }
    }

    $knownRoots = [System.Collections.Generic.List[string]]::new()
    foreach ($basePath in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (![string]::IsNullOrWhiteSpace($basePath)) {
            $knownRoots.Add((Join-Path $basePath "AutoHotkey")) | Out-Null
        }
    }
    if (![string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $knownRoots.Add((Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey")) | Out-Null
    }

    foreach ($root in $knownRoots) {
        Add-InstallRoot $root
    }

    foreach ($candidate in $candidates) {
        if (Test-AutoHotkeyV2 $candidate) {
            return Save-AutoHotkeyPath $candidate
        }
    }

    return $null
}


function Select-AutoHotkeyV2 {
    while ($true) {
        $dialog = [System.Windows.Forms.OpenFileDialog]::new()
        $dialog.Title = "Укажите AutoHotkey v2"
        $dialog.Filter = "AutoHotkey executable (*.exe)|*.exe"
        $dialog.CheckFileExists = $true
        $dialog.Multiselect = $false

        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            return $null
        }

        if (Test-AutoHotkeyV2 $dialog.FileName) {
            return Save-AutoHotkeyPath $dialog.FileName
        }

        Show-Message `
            "Выбранный файл не является AutoHotkey v2. Укажите AutoHotkey.exe версии 2 или отмените выбор." `
            ([System.Windows.Forms.MessageBoxButtons]::OK) `
            ([System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
}


function Install-AutoHotkeyV2 {
    $installerPath = Join-Path (
        [System.IO.Path]::GetTempPath()
    ) ("AutoHotkey_v2_setup_{0}.exe" -f [System.Guid]::NewGuid().ToString("N"))

    try {
        [System.Net.ServicePointManager]::SecurityProtocol =
            [System.Net.ServicePointManager]::SecurityProtocol -bor
            [System.Net.SecurityProtocolType]::Tls12

        Invoke-WebRequest `
            -Uri $script:OfficialDownloadUrl `
            -OutFile $installerPath `
            -UseBasicParsing

        $version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($installerPath)
        if ($version.ProductName -ine "AutoHotkey Setup" -or $version.ProductMajorPart -lt 2) {
            throw "Официальный сервер вернул файл, который не прошёл проверку версии AutoHotkey."
        }

        $destination = Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey"
        $arguments = @(
            "/silent",
            "/user",
            "/installto",
            ('"{0}"' -f $destination)
        )

        $process = Start-Process `
            -FilePath $installerPath `
            -ArgumentList $arguments `
            -Wait `
            -PassThru

        if ($process.ExitCode -ne 0) {
            throw "Установщик AutoHotkey завершился с кодом $($process.ExitCode)."
        }

        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            $resolved = Find-AutoHotkeyV2
            if ($resolved) {
                return $resolved
            }
            Start-Sleep -Milliseconds 250
        }

        throw "Установка завершилась, но AutoHotkey v2 не удалось найти."
    } finally {
        if ([System.IO.File]::Exists($installerPath)) {
            Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}


function Ensure-AutoHotkeyV2 {
    $resolved = Find-AutoHotkeyV2
    if ($resolved) {
        return $resolved
    }

    $choice = Show-Message `
        "AutoHotkey v2 не найден.`n`nОн необходим для работы Layout Toolkit.`n`nНажмите «Да / Yes», чтобы скачать актуальную версию с официального сайта и установить её для текущего пользователя.`n`nНажмите «Нет / No», чтобы указать уже существующий AutoHotkey.exe.`n`n«Отмена / Cancel» закроет запуск." `
        ([System.Windows.Forms.MessageBoxButtons]::YesNoCancel) `
        ([System.Windows.Forms.MessageBoxIcon]::Information)

    if ($choice -eq [System.Windows.Forms.DialogResult]::No) {
        return Select-AutoHotkeyV2
    }

    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
        return $null
    }

    try {
        return Install-AutoHotkeyV2
    } catch {
        $openPage = Show-Message `
            "Не удалось автоматически установить AutoHotkey v2.`n`n$($_.Exception.Message)`n`nОткрыть официальную страницу загрузки?" `
            ([System.Windows.Forms.MessageBoxButtons]::YesNo) `
            ([System.Windows.Forms.MessageBoxIcon]::Error)

        if ($openPage -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process $script:OfficialDownloadPage
        }

        return Select-AutoHotkeyV2
    }
}


function Install-StartupShortcut {
    param(
        [string]$AutoHotkeyPath,
        [string]$FullScriptPath,
        [string]$FullIconPath,
        [string]$FullStartupLink
    )

    $startupDirectory = Split-Path -Parent $FullStartupLink
    [System.IO.Directory]::CreateDirectory($startupDirectory) | Out-Null

    $powershellPath = Join-Path $PSHOME "powershell.exe"
    $arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Action Run -ScriptPath "{1}"' -f $PSCommandPath, $FullScriptPath

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($FullStartupLink)
    $shortcut.TargetPath = $powershellPath
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = Split-Path -Parent $FullScriptPath
    $shortcut.Description = $script:AppName
    $shortcut.WindowStyle = 7

    if ([System.IO.File]::Exists($FullIconPath)) {
        $shortcut.IconLocation = $FullIconPath
    } else {
        $shortcut.IconLocation = "$AutoHotkeyPath,0"
    }

    $shortcut.Save()

    if (![System.IO.File]::Exists($FullStartupLink)) {
        throw "Не удалось создать ярлык автозагрузки."
    }
}


function Invoke-Main {
    if ($Action -in @("Run", "InstallStartup")) {
        if ([string]::IsNullOrWhiteSpace($ScriptPath) -or ![System.IO.File]::Exists($ScriptPath)) {
            throw "Layout_Toolkit_RU_EN.ahk не найден рядом с файлами запуска."
        }
        $ScriptPath = [System.IO.Path]::GetFullPath($ScriptPath)
    }

    $autoHotkeyPath = Ensure-AutoHotkeyV2
    if (!$autoHotkeyPath) {
        return 2
    }

    switch ($Action) {
        "Resolve" {
            # The resolved path is persisted in CachePath for callers which
            # need it. Keeping stdout empty makes CMD integration predictable.
        }

        "Run" {
            Start-Process `
                -FilePath $autoHotkeyPath `
                -ArgumentList ('"{0}"' -f $ScriptPath) `
                -WorkingDirectory (Split-Path -Parent $ScriptPath)
        }

        "InstallStartup" {
            if ([string]::IsNullOrWhiteSpace($StartupLink)) {
                throw "Не указан путь к ярлыку автозагрузки."
            }

            $resolvedIconPath = ""
            if (![string]::IsNullOrWhiteSpace($IconPath)) {
                $resolvedIconPath = [System.IO.Path]::GetFullPath($IconPath)
            }

            Install-StartupShortcut `
                -AutoHotkeyPath $autoHotkeyPath `
                -FullScriptPath $ScriptPath `
                -FullIconPath $resolvedIconPath `
                -FullStartupLink ([System.IO.Path]::GetFullPath($StartupLink))
        }
    }

    return 0
}


try {
    $exitCode = Invoke-Main
} catch {
    Show-Message `
        "Не удалось запустить Layout Toolkit.`n`n$($_.Exception.Message)" `
        ([System.Windows.Forms.MessageBoxButtons]::OK) `
        ([System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    $exitCode = 1
}

exit $exitCode
