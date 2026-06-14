; UnicodeInput.ahk
; Модуль ввода Unicode-символов по HEX-коду.
;
; Поддерживает:
;   2014           -> —
;   0060 2014 0060 -> `—`
;   006020140060   -> `—`
;   0060 0020 2014 0020 0060 -> ` — `

UnicodeInput() {
    ib := InputBox(
        "Введи Unicode-код в HEX:`n`n"
        . "Примеры:`n"
        . "2013 = –`n"
        . "2014 = —`n"
        . "2212 = −`n"
        . "00B0 = °`n"
        . "03A9 = Ω`n`n"
        . "Можно несколько кодов:`n"
        . "0060 2014 0060 = `—``n"
        . "006020140060 = `—``n"
        . "0020 = пробел",
        "Unicode input",
        "w390 h300"
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

    SendText(text)
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