#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook

#Include Modules\UnicodeInput.ahk
#Include Modules\CapsLockFix.ahk

; ============================================================
; Layout Toolkit RU/EN
;
; Win + F12:
;   выделенный текст -> копировать -> конвертировать весь кусок
;   в противоположную раскладку -> вставить обратно.
;
; Win + F11:
;   выделенный смешанный текст -> копировать -> подтянуть
;   чужие токены к языку большинства -> вставить обратно.
;
; Win + F10:
;   включить/выключить live-режим.
;
; Live-режим:
;   двойной пробел -> текущий набранный фрагмент от последней
;   границы до курсора тупо меняется в противоположную раскладку.
;
; ВАЖНО:
;   live-режим сам нажимает Backspace и Ctrl+V.
;   Для больших документов лучше держать live выключенным.
; ============================================================

Persistent
SendMode "Input"

global g_AppName := "Layout Toolkit"

; Ресурсы программы.
global g_AssetsDir := A_ScriptDir "\Assets"
global g_IconPath := g_AssetsDir "\icon.ico"
global g_DefaultExcludePath := g_AssetsDir "\exclude.default.txt"
global g_DefaultHotkeysPath := g_AssetsDir "\hotkeys.default.ini"

; Новое пользовательское хранилище:
; Documents\Layout Toolkit\
global g_ConfigDir := A_MyDocuments "\Layout Toolkit"
global g_ConfigPath := g_ConfigDir "\settings.ini"
global g_ExcludePath := g_ConfigDir "\exclude.txt"

; Старые пути нужны только для мягкой миграции.
global g_LegacyConfigDir := A_AppData "\LayoutToolkit"
global g_LegacyConfigPath := g_LegacyConfigDir "\settings.ini"
global g_LegacyExcludePath := A_ScriptDir "\exclude.txt"

global g_ExcludeWords := Map()

EnsureUserDataDir()
MigrateUserData()
EnsureExcludeFile()
LoadExcludeWords()

global g_ShowTrayTips := IniRead(g_ConfigPath, "Notifications", "ShowTrayTips", "1") = "1"
global g_PlaySound := IniRead(g_ConfigPath, "Notifications", "PlaySound", "0") = "1"

if FileExist(g_IconPath) {
    TraySetIcon(g_IconPath)
}

global g_LiveEnabled := IniRead(g_ConfigPath, "General", "LiveEnabled", "0") = "1"
global g_Suppress := false
global g_LiveBusy := false
global g_LivePendingRequest := false
global g_LivePendingBuffer := ""
global g_LivePendingLastSpaceTick := 0
global g_Buffer := ""
global g_Direction := ""          ; "EN_TO_RU" или "RU_TO_EN"
global g_LastSpaceTick := 0
global g_DoubleSpaceMs := 700
global g_MaxBufferChars := 300
global g_PendingBoundary := false
global g_AfterBoundarySpace := false
global g_LastWindow := WinExist("A")

EnsureUserDataDir() {
    global g_ConfigDir

    try {
        DirCreate(g_ConfigDir)
    } catch as err {
        MsgBox("Не удалось создать папку настроек:`n" g_ConfigDir "`n`n" err.Message, "Layout Toolkit", "Iconx")
    }
}


MigrateUserData() {
    global g_ConfigPath, g_ExcludePath
    global g_LegacyConfigPath, g_LegacyExcludePath

    ; settings.ini: старый AppData -> новый Documents
    if (!FileExist(g_ConfigPath) && FileExist(g_LegacyConfigPath)) {
        try {
            FileCopy(g_LegacyConfigPath, g_ConfigPath, false)
        }
    }

    ; exclude.txt: старый файл рядом со скриптом -> новый Documents
    if (!FileExist(g_ExcludePath) && FileExist(g_LegacyExcludePath)) {
        try {
            FileCopy(g_LegacyExcludePath, g_ExcludePath, false)
        }
    }
}

EnsureExcludeFile() {
    global g_ExcludePath, g_DefaultExcludePath

    if FileExist(g_ExcludePath) {
        return
    }

    ; Новый нормальный путь:
    ; Assets\exclude.default.txt -> Documents\Layout Toolkit\exclude.txt
    if FileExist(g_DefaultExcludePath) {
        try {
            FileCopy(g_DefaultExcludePath, g_ExcludePath, false)
            return
        }
    }

    ; Fallback, если Assets потеряли или запуск идёт из странной сборки.
    defaultText := ""
    defaultText .= "USB`n"
    defaultText .= "AHK`n"
    defaultText .= "PowerShell`n"
    defaultText .= "GitHub`n"
    defaultText .= "CMD`n"
    defaultText .= "Bash`n"
    defaultText .= "Python`n"
    defaultText .= "JavaScript`n"
    defaultText .= "C:\`n"
    defaultText .= "D:\`n"
    defaultText .= "http`n"
    defaultText .= "https`n"
    defaultText .= "www`n"
    defaultText .= ".com`n"
    defaultText .= ".ru`n"

    FileAppend(defaultText, g_ExcludePath, "UTF-8")
}


LoadExcludeWords(*) {
    global g_ExcludePath, g_ExcludeWords

    g_ExcludeWords := Map()
    EnsureExcludeFile()

    try {
        content := FileRead(g_ExcludePath, "UTF-8")
    } catch {
        return
    }

    for line in StrSplit(content, "`n", "`r") {
        word := Trim(line)

        if (word = "") {
            continue
        }

        if (SubStr(word, 1, 1) = "#") {
            continue
        }

        g_ExcludeWords[StrLower(word)] := word
    }
}


SplitByWhitespace(text) {
    parts := []
    pos := 1

    while pos := RegExMatch(text, "\s+|\S+", &match, pos) {
        parts.Push(match[0])
        pos += StrLen(match[0])
    }

    return parts
}

GetCanonicalExcludedToken(token) {
    global g_ExcludeWords

    trimChars := " `t`r`n'()[]{}<>.,;:!?" . Chr(34)

    raw := Trim(token)
    cleaned := Trim(token, trimChars)

    rawKey := StrLower(raw)
    cleanedKey := StrLower(cleaned)

    ; Полное совпадение без обрезки пунктуации.
    if (rawKey != "" && g_ExcludeWords.Has(rawKey)) {
        return g_ExcludeWords[rawKey]
    }

    ; Совпадение с обрезкой пунктуации по краям.
    if (cleanedKey != "" && g_ExcludeWords.Has(cleanedKey)) {
        canonical := g_ExcludeWords[cleanedKey]

        startPos := InStr(token, cleaned)

        if (startPos > 0) {
            prefix := SubStr(token, 1, startPos - 1)
            suffix := SubStr(token, startPos + StrLen(cleaned))
            return prefix canonical suffix
        }

        return canonical
    }

    return ""
}


IsExcludedToken(token) {
    global g_ExcludeWords

    trimChars := " `t`r`n'()[]{}<>.,;:!?" . Chr(34)

    raw := StrLower(Trim(token))
    cleaned := StrLower(Trim(token, trimChars))

    candidates := [raw, cleaned]

    for _, candidate in candidates {
        if (candidate = "") {
            continue
        }

        ; Точное совпадение: USB, PowerShell, GitHub и т.д.
        if g_ExcludeWords.Has(candidate) {
            return true
        }

        ; Windows-пути: C:\Windows, D:\Games и т.д.
        if (StrLen(candidate) >= 3) {
            drivePrefix := SubStr(candidate, 1, 3)

            if (SubStr(drivePrefix, 2, 2) = ":\") {
                if g_ExcludeWords.Has(drivePrefix) {
                    return true
                }
            }
        }

        ; URL
        if g_ExcludeWords.Has("http") {
            if (SubStr(candidate, 1, 7) = "http://") {
                return true
            }
        }

        if g_ExcludeWords.Has("https") {
            if (SubStr(candidate, 1, 8) = "https://") {
                return true
            }
        }

        if g_ExcludeWords.Has("www") {
            if (SubStr(candidate, 1, 4) = "www.") {
                return true
            }
        }

        ; Доменные хвосты: github.com, site.ru
        for item, _ in g_ExcludeWords {
            if (SubStr(item, 1, 1) = ".") {
                if (StrLen(candidate) >= StrLen(item)) {
                    tail := SubStr(candidate, StrLen(candidate) - StrLen(item) + 1)

                    if (tail = item) {
                        return true
                    }
                }
            }
        }
    }

    return false
}


CountLayoutLetters(text, &latin, &cyrillic) {
    latin := 0
    cyrillic := 0

    for part in SplitByWhitespace(text) {
        if part ~= "^\s+$" {
            continue
        }

        if IsExcludedToken(part) {
            continue
        }

        for ch in StrSplit(part) {
            if IsLatin(ch) {
                latin++
            } else if IsCyrillic(ch) {
                cyrillic++
            }
        }
    }
}

SetupTrayMenu()

; Глобальный перехват печатных символов.
ih := InputHook("V")
ih.OnChar := IH_OnChar
ih.OnKeyDown := IH_OnKeyDown
ih.KeyOpt("{Backspace}{Enter}{Tab}{Esc}{Left}{Right}{Up}{Down}{Home}{End}{Delete}{PgUp}{PgDn}", "N")
if g_LiveEnabled {
    ih.Start()
}

firstRunDone := IniRead(g_ConfigPath, "General", "FirstRunDone", "0")
if (firstRunDone != "1") {
    ShowTrainingGui()
} else {
    Notify("Запущено. Live: " (g_LiveEnabled ? "включён" : "выключен"), g_AppName, "Iconi")
}

; Сброс буфера при клике мышью.
~LButton::ResetTypingBuffer()
~RButton::ResetTypingBuffer()
~MButton::ResetTypingBuffer()

; Пробел ловим сами, чтобы второй пробел был командой, а не обычным вводом.
#HotIf g_LiveEnabled
$Space::LiveSpacePressed()
#HotIf

; Горячие клавиши.
#F12::ConvertSelectedFullHotkey()
#F11::ConvertSelectedMajorityHotkey()
#F10::ToggleLiveMode()

; Temporary hotkey until configurable hotkeys GUI is implemented.
^+u::UnicodeInput()
#+F12::CapsLockFixSelectedHotkey()


SetupTrayMenu() {
    global g_AppName, g_ShowTrayTips, g_PlaySound, g_LiveEnabled

    A_TrayMenu.Delete()

    A_TrayMenu.Add("Показать обучение", ShowTrainingGui)
    A_TrayMenu.Add("Открыть папку Layout Toolkit", OpenUserDataDir)
    A_TrayMenu.Add("Открыть exclude.txt", OpenExcludeFile)
    A_TrayMenu.Add("Перезагрузить словарь исключений", ReloadExcludeWords)
    A_TrayMenu.Add()

    A_TrayMenu.Add("Показывать уведомления", ToggleTrayTips)
    A_TrayMenu.Add("Звук уведомлений", ToggleNotificationSound)

    if g_ShowTrayTips {
        A_TrayMenu.Check("Показывать уведомления")
    } else {
        A_TrayMenu.Uncheck("Показывать уведомления")
    }

    if g_PlaySound {
        A_TrayMenu.Check("Звук уведомлений")
    } else {
        A_TrayMenu.Uncheck("Звук уведомлений")
    }

    A_TrayMenu.Add()
    A_TrayMenu.Add("Live-режим  Win+F10", ToggleLiveMode)

    if g_LiveEnabled {
        A_TrayMenu.Check("Live-режим  Win+F10")
    } else {
        A_TrayMenu.Uncheck("Live-режим  Win+F10")
    }

    A_TrayMenu.Add()
    A_TrayMenu.Add("Выход", (*) => ExitApp())

    A_IconTip := g_AppName
}

Notify(message, title := "", options := "Iconi", playSound := false) {
    global g_AppName, g_ShowTrayTips, g_PlaySound

    if (title = "") {
        title := g_AppName
    }

    if !g_ShowTrayTips {
        return
    }

    finalOptions := options

    if !g_PlaySound {
        finalOptions := finalOptions " Mute"
    }

    TrayTip(message, title, finalOptions)
}

OpenUserDataDir(*) {
    global g_ConfigDir

    EnsureUserDataDir()

    try {
        Run('explorer.exe "' g_ConfigDir '"')
    } catch as err {
        Notify("Не удалось открыть папку Layout Toolkit: " err.Message, "Layout Toolkit", "Iconx")
    }
}

OpenExcludeFile(*) {
    global g_ExcludePath

    EnsureExcludeFile()

    try {
        Run('notepad.exe "' g_ExcludePath '"')
    } catch as err {
        Notify("Не удалось открыть exclude.txt: " err.Message, "Layout Toolkit", "Iconx")
    }
}

ReloadExcludeWords(*) {
    global g_AppName, g_ExcludeWords

    LoadExcludeWords()
    Notify("Словарь исключений перезагружен. Записей: " g_ExcludeWords.Count, g_AppName, "Iconi")
}


ToggleTrayTips(*) {
    global g_ShowTrayTips, g_ConfigPath, g_AppName

    g_ShowTrayTips := !g_ShowTrayTips
    IniWrite(g_ShowTrayTips ? "1" : "0", g_ConfigPath, "Notifications", "ShowTrayTips")

    SetupTrayMenu()

    if g_ShowTrayTips {
        Notify("Уведомления включены", g_AppName, "Iconi")
    }
}


ToggleNotificationSound(*) {
    global g_PlaySound, g_ConfigPath, g_AppName

    g_PlaySound := !g_PlaySound
    IniWrite(g_PlaySound ? "1" : "0", g_ConfigPath, "Notifications", "PlaySound")

    SetupTrayMenu()

    Notify(g_PlaySound ? "Звук уведомлений включён" : "Звук уведомлений выключен", g_AppName, "Iconi", g_PlaySound)
}

ShowTrainingGui(*) {
    global g_LiveEnabled, g_ConfigPath, g_AppName

    guiObj := Gui("+AlwaysOnTop", g_AppName " — первое обучение")
    guiObj.SetFont("s10", "Segoe UI")

    guiObj.AddText("w720", "Это один общий AHK-скрипт для ручной и live-конвертации раскладки RU/EN.")
    guiObj.AddText("w720", "")
    guiObj.SetFont("s10 bold", "Segoe UI")
    guiObj.AddText("xm w500", "Словарь исключений:")
    btnOpenExclude := guiObj.AddButton("x+10 yp-4 w190 h26", "Открыть exclude.txt")
    btnOpenExclude.OnEvent("Click", OpenExcludeFile)
    
    guiObj.SetFont("s10 norm", "Segoe UI")
    guiObj.AddText("xm y+8 w720", "Файл exclude.txt хранится в папке Documents\Layout Toolkit. Слова и фразы из него не конвертируются: USB, PowerShell, GitHub, C:\Windows, ссылки и т.п.")
    guiObj.AddText("xm w720", "Файл можно редактировать вручную. После изменения нажмите в трее: Перезагрузить словарь исключений.")
    guiObj.AddText("xm w720", "")
    guiObj.AddText("w720", "1) Win + F12 — выделенный кусок целиком в противоположную раскладку.")
    guiObj.AddText("w720", "   Пример: Ghbdtn/ Rfr ltkf&  →  Привет. Как дела?")
    guiObj.AddText("w720", "")
    guiObj.AddText("w720", "2) Win + F11 — смешанный выделенный текст привести к языку большинства.")
    guiObj.AddText("w720", "   Пример: Ghbdtn/ Я уже дома, сейчас включу компьютер. Rfr дела?")
    guiObj.AddText("w720", "        → Привет. Я уже дома, сейчас включу компьютер. Как дела?")
    guiObj.AddText("w720", "")
    guiObj.AddText("w720", "3) Win + F10 — включить/выключить live-режим.")
    guiObj.AddText("w720", "   Live-режим: двойной пробел исправляет текущий набранный фрагмент.")
    guiObj.AddText("w720", "   Пример: Z gbie ntrcn/ + двойной пробел")
    guiObj.AddText("w720", "        → Я пишу текст.")
    guiObj.AddText("w720", "")

    guiObj.SetFont("s10 bold", "Segoe UI")
    guiObj.AddText("w720", "Предупреждение:")
    guiObj.SetFont("s10 norm", "Segoe UI")
    guiObj.AddText("w720", "Live-режим сам нажимает Backspace и Ctrl+V. Для дипломов, книг и длинных документов лучше держать его выключенным и пользоваться Win+F11/F12.")
    guiObj.AddText("w720", "")

    chk := guiObj.AddCheckbox("vStartLive w720", "Сразу включить live-режим после закрытия этого окна")
    chk.Value := g_LiveEnabled ? 1 : 0

    guiObj.AddText("w720", "")

    btnOk := guiObj.AddButton("Default w220", "Понял, больше не показывать")
    btnCloseOnly := guiObj.AddButton("x+10 w180", "Закрыть только сейчас")

    btnOk.OnEvent("Click", (*) => TrainingGuiOk(guiObj))
    btnCloseOnly.OnEvent("Click", (*) => TrainingGuiCloseOnlyNow(guiObj))

    guiObj.OnEvent("Close", (*) => TrainingGuiCloseOnlyNow(guiObj))

    guiObj.Show()
}


TrainingGuiOk(guiObj) {
    global g_LiveEnabled, g_ConfigPath, g_AppName

    data := guiObj.Submit(false)

    g_LiveEnabled := data.StartLive = 1

    IniWrite("1", g_ConfigPath, "General", "FirstRunDone")
    IniWrite(g_LiveEnabled ? "1" : "0", g_ConfigPath, "General", "LiveEnabled")

    guiObj.Destroy()

    ResetTypingBuffer()
    Notify("Готово. Live: " (g_LiveEnabled ? "включён" : "выключен"), g_AppName, "Iconi")
}

TrainingGuiCloseOnlyNow(guiObj) {
    global g_ConfigPath

    IniWrite("0", g_ConfigPath, "General", "FirstRunDone")
    guiObj.Destroy()
}

ToggleLiveMode(*) {
    global g_LiveEnabled, g_ConfigPath, g_AppName, ih

    g_LiveEnabled := !g_LiveEnabled
    IniWrite(g_LiveEnabled ? "1" : "0", g_ConfigPath, "General", "LiveEnabled")

    ResetTypingBuffer()

    try {
        if g_LiveEnabled {
            ih.Start()
        } else {
            ih.Stop()
        }
    } catch as err {
        Notify("Ошибка переключения live-хука: " err.Message, g_AppName, "Icon!")
        return
    }

    SetupTrayMenu()

    Notify(
        g_LiveEnabled ? "Live-конвертер включён" : "Live-конвертер выключен",
        g_AppName,
        g_LiveEnabled ? "Iconi" : "Icon!"
    )
}


; ============================================================
; Win + F12: выделенный кусок целиком в противоположную раскладку
; ============================================================

ConvertSelectedFullHotkey() {
    global g_AppName

    oldClipboard := ClipboardAll()

    A_Clipboard := ""
    Send "^c"

    if !ClipWait(1.0) {
        A_Clipboard := oldClipboard
        Notify("Не удалось скопировать выделение", g_AppName " F12", "Icon!")
        return
    }

    text := A_Clipboard

    if (text = "") {
        A_Clipboard := oldClipboard
        Notify("Буфер пустой", g_AppName " F12", "Icon!")
        return
    }

    result := ConvertWholeByDetectedMajority(text)

    if (result = text) {
        A_Clipboard := oldClipboard
        Notify("Не стал конвертировать: баланс или без букв", g_AppName " F12", "Iconi")
        return
    }

    try {
        A_Clipboard := ""
	Sleep 30
	A_Clipboard := result
	
	if !ClipWait(0.5) {
		A_Clipboard := oldClipboard
		Notify("Буфер не успел обновиться. Исходный буфер обмена восстановлен", g_AppName " F12", "Icon!")
		return
	}
	
	Sleep 150
	Send "^v"
	
	Sleep 500
	A_Clipboard := oldClipboard

        Notify("Конвертировано и вставлено", g_AppName " F12", "Iconi", true)
    } catch as err {
        try {
            A_Clipboard := oldClipboard
        }
        Notify("Ошибка вставки: " err.Message, g_AppName " F12", "Iconx")
    }
}


ConvertWholeByDetectedMajority(text) {
    CountLayoutLetters(text, &latin, &cyrillic)

    if ((latin = 0 && cyrillic = 0) || latin = cyrillic) {
        return text
    }

    direction := latin > cyrillic ? "EN_TO_RU" : "RU_TO_EN"
    return ConvertTextByDirection(text, direction)
}


; ============================================================
; Win + F11: смешанный текст подтянуть к языку большинства
; ============================================================

ConvertSelectedMajorityHotkey() {
    global g_AppName

    oldClipboard := ClipboardAll()

    A_Clipboard := ""
    Send "^c"

    if !ClipWait(1.0) {
        A_Clipboard := oldClipboard
        Notify("Не удалось скопировать выделение", g_AppName " F11", "Icon!")
        return
    }

    text := A_Clipboard

    if (text = "") {
        A_Clipboard := oldClipboard
        Notify("Буфер пустой", g_AppName " F11", "Icon!")
        return
    }

    result := ConvertToMajority(text)

    if (result = text) {
        A_Clipboard := oldClipboard
        Notify("Не стал конвертировать: нечего чинить или баланс", g_AppName " F11", "Iconi")
        return
    }

    try {
    A_Clipboard := ""
	Sleep 30
	A_Clipboard := result
	
	if !ClipWait(0.5) {
		A_Clipboard := oldClipboard
		Notify("Буфер не успел обновиться. Исходный буфер обмена восстановлен", g_AppName " F11", "Icon!")
		return
	}

	Sleep 150
	Send "^v"

	Sleep 500
	A_Clipboard := oldClipboard

        Notify("Приведено к большинству и вставлено", g_AppName " F11", "Iconi", true)
    } catch as err {
        try {
            A_Clipboard := oldClipboard
        }
        Notify("Ошибка вставки: " err.Message, g_AppName " F11", "Iconx")
    }
}


ConvertToMajority(text) {
    CountLayoutLetters(text, &latin, &cyrillic)

    if ((latin = 0 && cyrillic = 0) || latin = cyrillic) {
        return text
    }

    if (latin > cyrillic) {
        ; Английского больше: чиним только русские токены в EN.
        table := GetConversionTable("RU_TO_EN")
        minorityCheck := IsCyrillic
        majorityCheck := IsLatin
    } else {
        ; Русского больше: чиним только английские токены в RU.
        table := GetConversionTable("EN_TO_RU")
        minorityCheck := IsLatin
        majorityCheck := IsCyrillic
    }

    out := ""
    token := ""
    changed := false

    for ch in StrSplit(text) {
        if IsWhitespaceChar(ch) {
            if (token != "") {
                converted := ConvertTokenIfMinority(token, table, minorityCheck, majorityCheck, &didChange)
                out .= converted
                changed := changed || didChange
                token := ""
            }

            out .= ch
        } else {
            token .= ch
        }
    }

    if (token != "") {
        converted := ConvertTokenIfMinority(token, table, minorityCheck, majorityCheck, &didChange)
        out .= converted
        changed := changed || didChange
    }

    return changed ? out : text
}


ConvertTokenIfMinority(token, table, minorityCheck, majorityCheck, &didChange) {
    if IsExcludedToken(token) {
        didChange := false
        return token
    }

    hasMinority := false
    hasMajority := false

    for ch in StrSplit(token) {
        if minorityCheck(ch) {
            hasMinority := true
        }

        if majorityCheck(ch) {
            hasMajority := true
        }
    }

    ; Конвертируем только чистые токены меньшинства.
    ; Если в одном токене смешаны RU и EN — не трогаем.
    if !(hasMinority && !hasMajority) {
        didChange := false
        return token
    }

    out := ""

    for ch in StrSplit(token) {
        out .= table.Has(ch) ? table[ch] : ch
    }

    didChange := true
    return out
}


; ============================================================
; Live double-space
; ============================================================

AppendLivePendingChar(char) {
    global g_LivePendingBuffer, g_LivePendingLastSpaceTick
    global g_MaxBufferChars

    g_LivePendingBuffer .= char

    if (StrLen(g_LivePendingBuffer) > g_MaxBufferChars) {
        g_LivePendingBuffer := SubStr(g_LivePendingBuffer, StrLen(g_LivePendingBuffer) - g_MaxBufferChars + 1)
    }

    ; Любой не-пробельный символ сбрасывает ожидание двойного пробела.
    g_LivePendingLastSpaceTick := 0
}


HandleLiveSpaceWhileBusy() {
    global g_LivePendingBuffer, g_LivePendingRequest, g_LivePendingLastSpaceTick
    global g_DoubleSpaceMs, g_MaxBufferChars

    ; Если во время busy прилетел второй пробел подряд —
    ; не отправляем его в приложение, а ставим отложенную live-конвертацию.
    if (EndsWithSpace(g_LivePendingBuffer) && (A_TickCount - g_LivePendingLastSpaceTick) <= g_DoubleSpaceMs) {
        g_LivePendingLastSpaceTick := 0
        g_LivePendingRequest := true
        return
    }

    ; Иначе это первый обычный пробел нового фрагмента:
    ; отправляем его в приложение и запоминаем в pending-буфере.
    g_LivePendingBuffer .= " "

    if (StrLen(g_LivePendingBuffer) > g_MaxBufferChars) {
        g_LivePendingBuffer := SubStr(g_LivePendingBuffer, StrLen(g_LivePendingBuffer) - g_MaxBufferChars + 1)
    }

    g_LivePendingLastSpaceTick := A_TickCount
    SendPlainSpace()
}


FlushLivePendingAfterOperation(title) {
    global g_LivePendingRequest, g_LivePendingBuffer, g_LivePendingLastSpaceTick
    global g_Buffer

    pendingRequest := g_LivePendingRequest
    pendingBuffer := g_LivePendingBuffer

    g_LivePendingRequest := false
    g_LivePendingBuffer := ""
    g_LivePendingLastSpaceTick := 0

    if (pendingBuffer = "") {
        return
    }

    ; Если пользователь реально успел попросить вторую live-конвертацию,
    ; пробуем выполнить её после завершения старой операции.
    ; Но не показываем "буфер пуст", если pending оказался мусорным/пустым.
    if pendingRequest {
        fragment := RTrim(pendingBuffer, " `t`r`n")

        if (fragment = "") {
            return
        }

        direction := DetectDirectionFromText(fragment)

        if (direction = "") {
            return
        }

        converted := ConvertTextByDirection(fragment, direction)

        if (converted = fragment) {
            return
        }

        DoLiveConvertAndReplace(pendingBuffer, title)
        return
    }

    ; Если пользователь печатал во время busy, но не просил вторую конвертацию,
    ; переносим накопленное в обычный live-буфер, чтобы границы не потерялись.
    g_Buffer := pendingBuffer
    RecalculateBufferState()
}

LiveSpacePressed() {
    global g_LiveEnabled, g_Suppress, g_LiveBusy
    global g_Buffer, g_Direction
    global g_LastSpaceTick, g_DoubleSpaceMs, g_MaxBufferChars
    global g_PendingBoundary, g_AfterBoundarySpace
    global g_LastWindow

    ; Если live уже выполняет замену, не запускаем вторую операцию параллельно.
    ; Вместо этого собираем новый ввод в pending-буфер.
    if g_LiveBusy {
        HandleLiveSpaceWhileBusy()
        return
    }

    ; Если live-режим выключен или мы сами что-то отправляем — просто пропускаем пробел.
    if (!g_LiveEnabled || g_Suppress) {
        SendPlainSpace()
        return
    }

    ; Не ломаем сочетания типа Ctrl+Space / Alt+Space / Win+Space.
    if (GetKeyState("Ctrl", "P") || GetKeyState("Alt", "P") || GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) {
        Send "{Blind}{Space}"
        return
    }

    currentWindow := WinExist("A")
    if (currentWindow != g_LastWindow) {
        g_LastWindow := currentWindow
        ResetTypingBuffer()
    }

    ; Если это второй пробел подряд — НЕ отправляем его в приложение.
    ; Вместо этого конвертируем фрагмент, где уже есть первый пробел.
    if (EndsWithSpace(g_Buffer) && (A_TickCount - g_LastSpaceTick) <= g_DoubleSpaceMs) {
        g_LastSpaceTick := 0
        TryLiveConvertDoubleSpace()
        return
    }

    ; Первый обычный пробел: отправляем в приложение и добавляем в буфер.
    g_Buffer .= " "

    if (StrLen(g_Buffer) > g_MaxBufferChars) {
        g_Buffer := SubStr(g_Buffer, StrLen(g_Buffer) - g_MaxBufferChars + 1)
        RecalculateBufferState()
    }

    g_LastSpaceTick := A_TickCount
    SendPlainSpace()

    if (g_PendingBoundary) {
        g_AfterBoundarySpace := true
    }
}


SendPlainSpace() {
    global g_Suppress

    oldSuppress := g_Suppress
    g_Suppress := true

    Send "{Blind}{Space}"
    Sleep 10

    g_Suppress := oldSuppress
}


IH_OnChar(ih, char) {
    global g_LiveEnabled, g_Suppress, g_LiveBusy
    global g_Buffer, g_Direction
    global g_LastSpaceTick, g_MaxBufferChars
    global g_PendingBoundary, g_AfterBoundarySpace
    global g_LastWindow

    if (!g_LiveEnabled) {
        return
    }

    ; Пробелы отдельно ловит $Space.
    if (char = " ") {
        return
    }

    ; Если live сейчас занят заменой текста, физический ввод пользователя
    ; складываем во временный pending-буфер, а не теряем.
    if g_LiveBusy {
        AppendLivePendingChar(char)
        return
    }

    if g_Suppress {
        return
    }

    currentWindow := WinExist("A")
    if (currentWindow != g_LastWindow) {
        g_LastWindow := currentWindow
        ResetTypingBuffer()
    }

    ; Если после границы и пробела начался новый текст — начинаем новый фрагмент.
    if (g_PendingBoundary && g_AfterBoundarySpace && !IsWhitespaceChar(char)) {
        ResetTypingBuffer(false)
    }

    g_Buffer .= char

    if (StrLen(g_Buffer) > g_MaxBufferChars) {
        g_Buffer := SubStr(g_Buffer, StrLen(g_Buffer) - g_MaxBufferChars + 1)
        RecalculateBufferState()
    }

    ; Определяем направление по первой букве фрагмента.
    if (g_Direction = "") {
        d := DirectionFromChar(char)
        if (d != "") {
            g_Direction := d
        }
    }

    ; Любой не-пробельный символ сбрасывает ожидание двойного пробела.
    g_LastSpaceTick := 0

    ; Адаптивные границы фрагмента.
    if (g_Direction != "" && IsBoundaryChar(char, g_Direction)) {
        g_PendingBoundary := true
        g_AfterBoundarySpace := false
    } else if (g_PendingBoundary && IsWhitespaceChar(char)) {
        g_AfterBoundarySpace := true
    }
}

IsLiveSpaceArmBreakerKey(keyName) {
    static ignored := Map(
        "Space", true,
        "Shift", true,
        "LShift", true,
        "RShift", true,
        "Ctrl", true,
        "Control", true,
        "LControl", true,
        "RControl", true,
        "Alt", true,
        "LAlt", true,
        "RAlt", true,
        "LWin", true,
        "RWin", true,
        "CapsLock", true,
        "NumLock", true,
        "ScrollLock", true
    )

    return !ignored.Has(keyName)
}


IH_OnKeyDown(ih, vk, sc) {
    global g_LiveEnabled, g_Suppress, g_LiveBusy
    global g_Buffer, g_LastSpaceTick
    global g_LivePendingLastSpaceTick

    if (!g_LiveEnabled) {
        return
    }

    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))

    ; Важно:
    ; $Space ловит пробел отдельно.
    ; Но если между двумя пробелами была любая обычная клавиша,
    ; значит это НЕ двойной пробел для live-конвертации.
    if IsLiveSpaceArmBreakerKey(keyName) {
        if g_LiveBusy {
            g_LivePendingLastSpaceTick := 0
        } else {
            g_LastSpaceTick := 0
        }
    }

    if g_Suppress {
        return
    }

    switch keyName {
        case "Backspace":
            if (StrLen(g_Buffer) > 0) {
                g_Buffer := SubStr(g_Buffer, 1, StrLen(g_Buffer) - 1)
                RecalculateBufferState()
            }

        case "Enter", "Tab", "Esc", "Escape", "Left", "Right", "Up", "Down", "Home", "End", "Delete", "PgUp", "PgDn":
            ResetTypingBuffer()
    }
}


TryLiveConvertDoubleSpace() {
    global g_Buffer

    rawFragment := g_Buffer
    DoLiveConvertAndReplace(rawFragment, "Раскладка live")
}


DoLiveConvertAndReplace(rawFragment, title) {
    global g_Suppress, g_LiveBusy

    fragment := RTrim(rawFragment, " `t`r`n")

    if (fragment = "") {
        Notify("Буфер фрагмента пустой", title, "Icon!")
        return
    }

    direction := DetectDirectionFromText(fragment)

    if (direction = "") {
        Notify("Не понял направление", title, "Icon!")
        return
    }

    converted := ConvertTextByDirection(fragment, direction)

    if (converted = fragment) {
        Notify("Нечего менять", title, "Iconi")
        return
    }

    deleteCount := StrLen(rawFragment)

    if (deleteCount <= 0) {
        return
    }

    oldClipboard := ClipboardAll()
    g_Suppress := true
    g_LiveBusy := true

    try {
	A_Clipboard := ""
	Sleep 30
	A_Clipboard := converted . " "
	
        if !ClipWait(0.5) {
            A_Clipboard := oldClipboard
            g_Suppress := false
            g_LiveBusy := false
            FlushLivePendingAfterOperation(title)
            Notify("Буфер не успел обновиться. Исходный буфер обмена восстановлен", title, "Icon!")
            return
        }
	
	Sleep 100
	
	Send "{Backspace " . deleteCount . "}"
	Sleep 100
	
	Send "^v"
	Sleep 450
	
	A_Clipboard := oldClipboard

        ResetTypingBuffer(false)
        Notify("Исправлено: " SubStr(converted, 1, 60) (StrLen(converted) > 60 ? "..." : ""), title, "Iconi", true)
    } catch as err {
        try {
            A_Clipboard := oldClipboard
        }

        Notify("Ошибка конвертации: " err.Message, title, "Iconx")
    }

    g_Suppress := false
    g_LiveBusy := false
    FlushLivePendingAfterOperation(title)
}


ResetTypingBuffer(resetWindow := true) {
    global g_Buffer, g_Direction
    global g_LastSpaceTick
    global g_PendingBoundary, g_AfterBoundarySpace
    global g_LastWindow

    g_Buffer := ""
    g_Direction := ""
    g_LastSpaceTick := 0
    g_PendingBoundary := false
    g_AfterBoundarySpace := false

    if (resetWindow) {
        g_LastWindow := WinExist("A")
    }
}


RecalculateBufferState() {
    global g_Buffer, g_Direction
    global g_PendingBoundary, g_AfterBoundarySpace

    g_Direction := DetectDirectionFromText(g_Buffer)
    g_PendingBoundary := false
    g_AfterBoundarySpace := false

    if (g_Direction = "") {
        return
    }

    chars := StrSplit(g_Buffer)

    Loop chars.Length {
        ch := chars[A_Index]

        if (IsBoundaryChar(ch, g_Direction)) {
            g_PendingBoundary := true
            g_AfterBoundarySpace := false
        } else if (g_PendingBoundary && IsWhitespaceChar(ch)) {
            g_AfterBoundarySpace := true
        } else if (g_PendingBoundary && g_AfterBoundarySpace && !IsWhitespaceChar(ch)) {
            g_PendingBoundary := false
            g_AfterBoundarySpace := false
        }
    }
}


DetectDirectionFromText(text) {
    for ch in StrSplit(text) {
        d := DirectionFromChar(ch)
        if (d != "") {
            return d
        }
    }

    return ""
}


DirectionFromChar(ch) {
    if (IsLatin(ch)) {
        return "EN_TO_RU"
    }

    if (IsCyrillic(ch)) {
        return "RU_TO_EN"
    }

    return ""
}


IsBoundaryChar(ch, direction) {
    if (direction = "EN_TO_RU") {
        ; Когда русский текст ошибочно набран в EN-раскладке:
        ; / → .
        ; & → ?
        ; ! → !
        return ch = "/" || ch = "&" || ch = "!"
    }

    if (direction = "RU_TO_EN") {
        ; Когда английский текст ошибочно набран в RU-раскладке:
        ; ю → .
        ; , → ?
        ; ! → !
        return ch = "ю" || ch = "Ю" || ch = "," || ch = "!"
    }

    return false
}


IsWhitespaceChar(ch) {
    return ch = " " || ch = "`t" || ch = "`n" || ch = "`r"
}


EndsWithSpace(text) {
    return StrLen(text) > 0 && SubStr(text, StrLen(text), 1) = " "
}


IsLatin(ch) {
    code := Ord(ch)
    return ((code >= 65 && code <= 90) || (code >= 97 && code <= 122))
}


IsCyrillic(ch) {
    code := Ord(ch)
    return ((code >= 1040 && code <= 1103) || code = 1025 || code = 1105)
}


ConvertTextByDirection(text, direction) {
    table := GetConversionTable(direction)
    out := ""

    for part in SplitByWhitespace(text) {
        if IsExcludedToken(part) {
            out .= part
            continue
        }

        for ch in StrSplit(part) {
            out .= table.Has(ch) ? table[ch] : ch
        }
    }

    return out
}


GetConversionTable(direction) {
    static enToRu := Map(
        Chr(96), "ё", "~", "Ё",

        "q", "й", "w", "ц", "e", "у", "r", "к", "t", "е", "y", "н", "u", "г", "i", "ш", "o", "щ", "p", "з",
        "[", "х", "]", "ъ",
        "a", "ф", "s", "ы", "d", "в", "f", "а", "g", "п", "h", "р", "j", "о", "k", "л", "l", "д",
        ";", "ж", "'", "э",
        "z", "я", "x", "ч", "c", "с", "v", "м", "b", "и", "n", "т", "m", "ь",
        ",", "б", ".", "ю", "/", ".",
        "?", ",",

        "Q", "Й", "W", "Ц", "E", "У", "R", "К", "T", "Е", "Y", "Н", "U", "Г", "I", "Ш", "O", "Щ", "P", "З",
        "{", "Х", "}", "Ъ",
        "A", "Ф", "S", "Ы", "D", "В", "F", "А", "G", "П", "H", "Р", "J", "О", "K", "Л", "L", "Д",
        ":", "Ж", Chr(34), "Э",
        "Z", "Я", "X", "Ч", "C", "С", "V", "М", "B", "И", "N", "Т", "M", "Ь",
        "<", "Б", ">", "Ю",

        "@", Chr(34),
        "#", "№",
        "$", ";",
        "^", ":",
        "&", "?"
    )

    static ruToEn := Map()

    if (ruToEn.Count = 0) {
        for en, ru in enToRu {
            ruToEn[ru] := en
        }
    }

    return direction = "EN_TO_RU" ? enToRu : ruToEn
}
