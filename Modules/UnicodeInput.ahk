; UnicodeInput.ahk
; Модуль ввода Unicode-символов по HEX-коду.
;
; Поддерживает:
;   2014           -> —
;   0060 2014 0060 -> `—`
;   006020140060   -> `—`
;   0060 0020 2014 0020 0060 -> ` — `

UnicodeInput(mode := "insert") {
    mode := StrLower(Trim(mode))

    if (mode != "clipboard") {
        mode := "insert"
    }

    actionText := (mode = "clipboard")
        ? "Будет скопировано в буфер обмена."
        : "Будет вставлено в активное окно."

    title := (mode = "clipboard")
        ? "Unicode Input — буфер обмена"
        : "Unicode Input — вставка"

    ib := InputBox(
        "Введите Unicode-код в HEX:`n"
        . actionText,
        title,
        "w340 h130"
    )

    if (ib.Result != "OK") {
        return
    }

    input := Trim(ib.Value)

    if (input = "") {
        return
    }

    text := UnicodeHexToText(input)

    if (text = "") {
        SoundBeep(750, 120)
        return
    }

    UnicodeInput_ApplyResult(text, mode)
}


UnicodeInput_ApplyResult(text, mode) {
    if (mode = "clipboard") {
        UnicodeInput_CopyToClipboard(text)
        return
    }

    SendText(text)
}


UnicodeInput_CopyToClipboard(text) {
    global g_AppName

    oldClipboard := ClipboardAll()

    try {
        A_Clipboard := ""
        A_Clipboard := text

        if !ClipWait(0.5) {
            A_Clipboard := oldClipboard
            Notify("Буфер не успел обновиться. Исходный буфер обмена восстановлен", g_AppName " Unicode Input", "Icon!")
            return
        }

        Notify("Скопировано в буфер обмена", g_AppName " Unicode Input", "Iconi")
    } catch as err {
        try {
            A_Clipboard := oldClipboard
        }

        Notify("Ошибка копирования: " err.Message, g_AppName " Unicode Input", "Iconx")
    }
}


UnicodeHexToText(input) {
    input := Trim(input)

    ; Разрешаем только HEX-символы и пробелы.
    if !RegExMatch(input, "i)^[0-9A-F\s]+$") {
        return ""
    }

    ; Если есть пробелы — считаем их разделителями кодов.
    if RegExMatch(input, "\s") {
        codes := StrSplitByWhitespace(input)
    } else {
        ; Если пробелов нет — режем слитную строку на блоки по 4 HEX-символа.
        if (Mod(StrLen(input), 4) != 0) {
            return ""
        }

        codes := []

        Loop StrLen(input) // 4 {
            codes.Push(SubStr(input, ((A_Index - 1) * 4) + 1, 4))
        }
    }

    result := ""

    for hex in codes {
        hex := Trim(hex)

        if (hex = "") {
            continue
        }

        if !IsValidUnicodeHex(hex) {
            return ""
        }

        code := Integer("0x" hex)

        if !IsValidUnicodeCodepoint(code) {
            return ""
        }

        result .= Chr(code)
    }

    return result
}


StrSplitByWhitespace(text) {
    parts := []

    for part in StrSplit(RegExReplace(text, "\s+", " "), " ") {
        part := Trim(part)

        if (part != "") {
            parts.Push(part)
        }
    }

    return parts
}


IsValidUnicodeHex(hex) {
    return RegExMatch(hex, "i)^[0-9A-F]{1,6}$")
}


IsValidUnicodeCodepoint(code) {
    if (code < 1 || code > 0x10FFFF) {
        return false
    }

    ; Суррогатная зона UTF-16, невалидна как самостоятельный Unicode code point.
    if (code >= 0xD800 && code <= 0xDFFF) {
        return false
    }

    return true
}