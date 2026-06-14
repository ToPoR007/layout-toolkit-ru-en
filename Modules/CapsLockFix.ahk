; CapsLockFix.ahk
; Исправление регистра выделенного текста.
;
; Примеры:
;   пРИВЕТ -> Привет
;   эТО ПРИМЕР -> Это пример
;   gITHUB -> GitHub
;   pOWERSHELL -> PowerShell

CapsLockFixSelectedHotkey() {
    global g_AppName

    oldClipboard := ClipboardAll()

    A_Clipboard := ""
    Send "^c"

    if !ClipWait(1.0) {
        A_Clipboard := oldClipboard
        Notify("Не удалось скопировать выделение", g_AppName " CapsLock Fix", "Icon!")
        return
    }

    text := A_Clipboard

    if (text = "") {
        A_Clipboard := oldClipboard
        Notify("Буфер пустой", g_AppName " CapsLock Fix", "Icon!")
        return
    }

    result := FixCapsLockText(text)

    if (result = text) {
        A_Clipboard := oldClipboard
        Notify("Нечего исправлять", g_AppName " CapsLock Fix", "Iconi")
        return
    }

    try {
        A_Clipboard := ""
        Sleep 30
        A_Clipboard := result

        if !ClipWait(0.5) {
            A_Clipboard := oldClipboard
            Notify("Буфер не успел обновиться. Исходный буфер обмена восстановлен", g_AppName " CapsLock Fix", "Icon!")
            return
        }

        Sleep 150
        Send "^v"

        Sleep 500
        A_Clipboard := oldClipboard

        Notify("Регистр исправлен", g_AppName " CapsLock Fix", "Iconi", true)
    } catch as err {
        try {
            A_Clipboard := oldClipboard
        }

        Notify("Ошибка вставки: " err.Message, g_AppName " CapsLock Fix", "Iconx")
    }
}


FixCapsLockText(text) {
    out := ""

    for part in SplitByWhitespace(text) {
        if part ~= "^\s+$" {
            out .= part
            continue
        }

        if IsExcludedToken(part) {
            canonical := GetCanonicalExcludedToken(part)

            if (canonical != "") {
                out .= canonical
            } else {
                out .= part
            }

            continue
        }

        out .= SmartCapsFixToken(part)
    }

    return out
}


SmartCapsFixToken(token) {
    trimChars := " `t`r`n'()[]{}<>.,;:!?" . Chr(34)

    core := Trim(token, trimChars)

    if (core = "") {
        return token
    }

    startPos := InStr(token, core)

    if (startPos <= 0) {
        return token
    }

    prefix := SubStr(token, 1, startPos - 1)
    suffix := SubStr(token, startPos + StrLen(core))

    if !ShouldSmartFixCore(core) {
        return token
    }

    fixed := SmartTitleCore(core)

    return prefix fixed suffix
}


ShouldSmartFixCore(core) {
    upperCount := 0
    lowerCount := 0

    for ch in StrSplit(core) {
        if IsUpperLetter(ch) {
            upperCount++
        } else if IsLowerLetter(ch) {
            lowerCount++
        }
    }

    if (upperCount = 0) {
        return false
    }

    ; ПРИВЕТ -> Привет
    if (upperCount > 0 && lowerCount = 0) {
        return true
    }

    ; пРИВЕТ / эТО / нАПИСАЛ -> Привет / Это / Написал
    if (upperCount > lowerCount) {
        return true
    }

    return false
}


SmartTitleCore(core) {
    result := ""
    firstLetterDone := false

    for ch in StrSplit(core) {
        if !firstLetterDone && IsAnyLetter(ch) {
            result .= StrUpper(ch)
            firstLetterDone := true
        } else {
            result .= StrLower(ch)
        }
    }

    return result
}


IsAnyLetter(ch) {
    return IsUpperLetter(ch) || IsLowerLetter(ch)
}


IsUpperLetter(ch) {
    return ch ~= "^[A-ZА-ЯЁ]$"
}


IsLowerLetter(ch) {
    return ch ~= "^[a-zа-яё]$"
}