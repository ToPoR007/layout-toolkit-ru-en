#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook

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
global g_ConfigDir := A_AppData "\LayoutToolkit"
global g_ConfigPath := g_ConfigDir "\settings.ini"

DirCreate(g_ConfigDir)

global g_LiveEnabled := IniRead(g_ConfigPath, "General", "LiveEnabled", "0") = "1"
global g_Suppress := false
global g_Buffer := ""
global g_Direction := ""          ; "EN_TO_RU" или "RU_TO_EN"
global g_LastSpaceTick := 0
global g_DoubleSpaceMs := 700
global g_MaxBufferChars := 300
global g_PendingBoundary := false
global g_AfterBoundarySpace := false
global g_LastWindow := WinExist("A")

SetupTrayMenu()

; Глобальный перехват печатных символов.
ih := InputHook("V")
ih.OnChar := IH_OnChar
ih.OnKeyDown := IH_OnKeyDown
ih.KeyOpt("{Backspace}{Enter}{Tab}{Esc}{Left}{Right}{Up}{Down}{Home}{End}{Delete}{PgUp}{PgDn}", "N")
ih.Start()

firstRunDone := IniRead(g_ConfigPath, "General", "FirstRunDone", "0")
if (firstRunDone != "1") {
    ShowTrainingGui()
} else {
    TrayTip("Запущено. Live: " (g_LiveEnabled ? "включён" : "выключен"), g_AppName, "Iconi")
}

; Сброс буфера при клике мышью.
~LButton::ResetTypingBuffer()
~RButton::ResetTypingBuffer()
~MButton::ResetTypingBuffer()

; Пробел ловим сами, чтобы второй пробел был командой, а не обычным вводом.
$Space::LiveSpacePressed()

; Горячие клавиши.
#F12::ConvertSelectedFullHotkey()
#F11::ConvertSelectedMajorityHotkey()
#F10::ToggleLiveMode()


SetupTrayMenu() {
    global g_AppName

    A_TrayMenu.Delete()
    A_TrayMenu.Add("Показать обучение", ShowTrainingGui)
    A_TrayMenu.Add("Включить/выключить live  Win+F10", ToggleLiveMode)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Выход", (*) => ExitApp())
    A_IconTip := g_AppName
}

ShowTrainingGui(*) {
    global g_LiveEnabled, g_ConfigPath, g_AppName

    guiObj := Gui("+AlwaysOnTop", g_AppName " — первое обучение")
    guiObj.SetFont("s10", "Segoe UI")

    guiObj.AddText("w720", "Это один общий AHK-скрипт для ручной и live-конвертации раскладки RU/EN.")
    guiObj.AddText("w720", "")
    guiObj.AddText("w720", "1) Win + F12 — выделенный кусок целиком в противоположную раскладку.")
    guiObj.AddText("w720", "   Пример: Ghbdtn/ Rfr ltkf&  →  Привет. Как дела?")
    guiObj.AddText("w720", "")
    guiObj.AddText("w720", "2) Win + F11 — смешанный выделенный текст привести к языку большинства.")
    guiObj.AddText("w720", "   Пример: Ghbdtn/ Я уже дома, сейчас включу компьютер. Rfr ltkf&")
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
    TrayTip("Готово. Live: " (g_LiveEnabled ? "включён" : "выключен"), g_AppName, "Iconi")
}

TrainingGuiCloseOnlyNow(guiObj) {
    global g_ConfigPath

    IniWrite("0", g_ConfigPath, "General", "FirstRunDone")
    guiObj.Destroy()
}

ToggleLiveMode(*) {
    global g_LiveEnabled, g_ConfigPath, g_AppName

    g_LiveEnabled := !g_LiveEnabled
    IniWrite(g_LiveEnabled ? "1" : "0", g_ConfigPath, "General", "LiveEnabled")

    ResetTypingBuffer()

    TrayTip(g_LiveEnabled ? "Live-конвертер включён" : "Live-конвертер выключен", g_AppName, g_LiveEnabled ? "Iconi" : "Icon!")
}


; ============================================================
; Win + F12: выделенный кусок целиком в противоположную раскладку
; ============================================================

ConvertSelectedFullHotkey() {
    global g_AppName

    oldClipboard := ClipboardAll()

    A_Clipboard := ""
    Send "^c"

    if !ClipWait(0.7) {
        A_Clipboard := oldClipboard
        TrayTip("Не удалось скопировать выделение", g_AppName " F12", "Icon!")
        return
    }

    text := A_Clipboard

    if (text = "") {
        A_Clipboard := oldClipboard
        TrayTip("Буфер пустой", g_AppName " F12", "Icon!")
        return
    }

    result := ConvertWholeByDetectedMajority(text)

    if (result = text) {
        A_Clipboard := oldClipboard
        TrayTip("Не стал конвертировать: баланс или без букв", g_AppName " F12", "Iconi")
        return
    }

    try {
        A_Clipboard := result
        Sleep 50
        Send "^v"

        Sleep 200
        A_Clipboard := oldClipboard

        TrayTip("Конвертировано и вставлено", g_AppName " F12", "Iconi")
    } catch as err {
        try {
            A_Clipboard := oldClipboard
        }
        TrayTip("Ошибка вставки: " err.Message, g_AppName " F12", "Iconx")
    }
}


ConvertWholeByDetectedMajority(text) {
    latin := 0
    cyrillic := 0

    for ch in StrSplit(text) {
        if IsLatin(ch) {
            latin++
        } else if IsCyrillic(ch) {
            cyrillic++
        }
    }

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

    if !ClipWait(0.7) {
        A_Clipboard := oldClipboard
        TrayTip("Не удалось скопировать выделение", g_AppName " F11", "Icon!")
        return
    }

    text := A_Clipboard

    if (text = "") {
        A_Clipboard := oldClipboard
        TrayTip("Буфер пустой", g_AppName " F11", "Icon!")
        return
    }

    result := ConvertToMajority(text)

    if (result = text) {
        A_Clipboard := oldClipboard
        TrayTip("Не стал конвертировать: нечего чинить или баланс", g_AppName " F11", "Iconi")
        return
    }

    try {
        A_Clipboard := result
        Sleep 50
        Send "^v"

        Sleep 200
        A_Clipboard := oldClipboard

        TrayTip("Приведено к большинству и вставлено", g_AppName " F11", "Iconi")
    } catch as err {
        try {
            A_Clipboard := oldClipboard
        }
        TrayTip("Ошибка вставки: " err.Message, g_AppName " F11", "Iconx")
    }
}


ConvertToMajority(text) {
    latin := 0
    cyrillic := 0

    for ch in StrSplit(text) {
        if IsLatin(ch) {
            latin++
        } else if IsCyrillic(ch) {
            cyrillic++
        }
    }

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

LiveSpacePressed() {
    global g_LiveEnabled, g_Suppress
    global g_Buffer, g_Direction
    global g_LastSpaceTick, g_DoubleSpaceMs, g_MaxBufferChars
    global g_PendingBoundary, g_AfterBoundarySpace
    global g_LastWindow

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

    g_Suppress := true
    Send "{Blind}{Space}"
    Sleep 10
    g_Suppress := false
}


IH_OnChar(ih, char) {
    global g_LiveEnabled, g_Suppress
    global g_Buffer, g_Direction
    global g_LastSpaceTick, g_MaxBufferChars
    global g_PendingBoundary, g_AfterBoundarySpace
    global g_LastWindow

    if (!g_LiveEnabled || g_Suppress) {
        return
    }

    ; Пробелы отдельно ловит $Space.
    if (char = " ") {
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


IH_OnKeyDown(ih, vk, sc) {
    global g_LiveEnabled, g_Suppress, g_Buffer

    if (!g_LiveEnabled || g_Suppress) {
        return
    }

    keyName := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))

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
    global g_Suppress

    fragment := RTrim(rawFragment, " `t`r`n")

    if (fragment = "") {
        TrayTip("Буфер фрагмента пустой", title, "Icon!")
        return
    }

    direction := DetectDirectionFromText(fragment)

    if (direction = "") {
        TrayTip("Не понял направление", title, "Icon!")
        return
    }

    converted := ConvertTextByDirection(fragment, direction)

    if (converted = fragment) {
        TrayTip("Нечего менять", title, "Iconi")
        return
    }

    deleteCount := StrLen(rawFragment)

    if (deleteCount <= 0) {
        return
    }

    oldClipboard := ClipboardAll()
    g_Suppress := true

    try {
        A_Clipboard := converted . " "
        Sleep 60

        Send "{Backspace " . deleteCount . "}"
        Sleep 60

        Send "^v"
        Sleep 220

        A_Clipboard := oldClipboard

        ResetTypingBuffer(false)
        TrayTip("Исправлено: " SubStr(converted, 1, 60) (StrLen(converted) > 60 ? "..." : ""), title, "Iconi")
    } catch as err {
        try {
            A_Clipboard := oldClipboard
        }

        TrayTip("Ошибка конвертации: " err.Message, title, "Iconx")
    }

    g_Suppress := false
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

    for ch in StrSplit(text) {
        out .= table.Has(ch) ? table[ch] : ch
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
