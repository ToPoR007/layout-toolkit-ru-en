; SettingsGui.ahk
; Окно настроек Layout Toolkit.
;
; Здесь находится GUI настроек:
; - левая навигация по разделам
; - текстовые страницы состояния и описания функций
; - служебные кнопки для открытия файлов, перезагрузки настроек и сброса значений
; - версия читается из CHANGELOG.md
;
; Основная логика функций остаётся в главном скрипте и модулях.


g_SettingsGui := ""
g_SettingsContentTitle := ""
g_SettingsContentBody := ""

g_SettingsActionBtn1 := ""
g_SettingsActionBtn2 := ""
g_SettingsActionBtn3 := ""

g_SettingsAction1 := ""
g_SettingsAction2 := ""
g_SettingsAction3 := ""


OpenSettingsGui(*) {
    global g_SettingsGui, g_SettingsContentTitle, g_SettingsContentBody
    global g_SettingsActionBtn1, g_SettingsActionBtn2, g_SettingsActionBtn3
    global g_AppName

    if IsObject(g_SettingsGui) {
        try {
            g_SettingsGui.Show()
            SettingsGui_ShowPage("General")
            return
        }
    }

    g_SettingsGui := Gui("-Resize", g_AppName " — Настройки")
    g_SettingsGui.SetFont("s9", "Segoe UI")

    g_SettingsGui.OnEvent("Close", SettingsGui_OnClose)
    g_SettingsGui.OnEvent("Escape", SettingsGui_OnClose)

    navX := 12
    navY := 12
    navW := 150
    btnH := 30
    gap := 6

    SettingsGui_AddNavButton("Общее", "General", navX, navY, navW, btnH)
    navY += btnH + gap

    SettingsGui_AddNavButton("Layout Fix", "LayoutFix", navX, navY, navW, btnH)
    navY += btnH + gap

    SettingsGui_AddNavButton("Live-режим", "Live", navX, navY, navW, btnH)
    navY += btnH + gap

    SettingsGui_AddNavButton("Горячие клавиши", "Hotkeys", navX, navY, navW, btnH)
    navY += btnH + gap

    SettingsGui_AddNavButton("Unicode Input", "Unicode", navX, navY, navW, btnH)
    navY += btnH + gap

    SettingsGui_AddNavButton("CapsLock Fix", "CapsLock", navX, navY, navW, btnH)
    navY += btnH + gap

    SettingsGui_AddNavButton("Исключения", "Exclusions", navX, navY, navW, btnH)
    navY += btnH + gap

    SettingsGui_AddNavButton("О программе", "About", navX, navY, navW, btnH)

    g_SettingsContentTitle := g_SettingsGui.AddText("x180 y14 w560 h28", "")
    g_SettingsContentTitle.SetFont("s12 bold")

    g_SettingsContentBody := g_SettingsGui.AddEdit("x180 y48 w560 h325 ReadOnly +Wrap VScroll", "")
    g_SettingsContentBody.SetFont("s9", "Consolas")

    g_SettingsActionBtn1 := g_SettingsGui.AddButton("x180 y390 w165 h30 Hidden", "")
    g_SettingsActionBtn1.OnEvent("Click", SettingsGui_ActionButton1)
    
    g_SettingsActionBtn2 := g_SettingsGui.AddButton("x355 y390 w165 h30 Hidden", "")
    g_SettingsActionBtn2.OnEvent("Click", SettingsGui_ActionButton2)
    
    g_SettingsActionBtn3 := g_SettingsGui.AddButton("x530 y390 w165 h30 Hidden", "")
    g_SettingsActionBtn3.OnEvent("Click", SettingsGui_ActionButton3)
    
    closeBtn := g_SettingsGui.AddButton("x650 y425 w90 h30", "Закрыть")
    closeBtn.OnEvent("Click", SettingsGui_Close)

    SettingsGui_ShowPage("General")

    g_SettingsGui.Show("w760 h470")
}


SettingsGui_AddNavButton(label, pageName, x, y, w, h) {
    global g_SettingsGui

    btn := g_SettingsGui.AddButton("x" x " y" y " w" w " h" h, label)
    btn.OnEvent("Click", (*) => SettingsGui_ShowPage(pageName))
}


SettingsGui_ShowPage(pageName, *) {
    global g_SettingsContentTitle, g_SettingsContentBody

    title := ""
    body := ""

    switch pageName {
        case "General":
            title := "Общее"
            body := SettingsGui_GetGeneralText()

        case "LayoutFix":
            title := "Layout Fix"
            body := SettingsGui_GetLayoutFixText()

        case "Live":
            title := "Live-режим"
            body := SettingsGui_GetLiveText()

        case "Hotkeys":
            title := "Горячие клавиши"
            body := SettingsGui_GetHotkeysText()

        case "Unicode":
            title := "Unicode Input"
            body := SettingsGui_GetUnicodeText()

        case "CapsLock":
            title := "CapsLock Fix"
            body := SettingsGui_GetCapsLockText()

        case "Exclusions":
            title := "Исключения"
            body := SettingsGui_GetExclusionsText()

        case "About":
            title := "О программе"
            body := SettingsGui_GetAboutText()

        default:
            title := "Layout Toolkit"
            body := "Неизвестный раздел: " pageName
    }

    g_SettingsContentTitle.Text := title
    g_SettingsContentBody.Value := body
    
    switch pageName {
        case "General":
            SettingsGui_SetActions(
                "Открыть папку данных", "OpenDataDir",
                "Перезапустить LT", "RestartToolkit",
                "Сменить язык", "ChangeLanguage"
            )

        case "Hotkeys":
            SettingsGui_SetActions(
                "Открыть hotkeys.ini", "OpenHotkeysFile",
                "Перезагрузить хоткеи", "ReloadHotkeys",
                "Сбросить стандартные", "RestoreDefaultHotkeys"
            )
			
        case "Unicode":
            SettingsGui_SetActions(
                "Открыть для копирования", "OpenUnicodeInputClipboard"
            )

        case "Exclusions":
            SettingsGui_SetActions(
                "Открыть exclude.txt", "OpenExcludeFile",
                "Перезагрузить", "ReloadExcludeWords",
                "Сбросить стандартные", "RestoreDefaultExcludeWords"
            )
    
        default:
            SettingsGui_SetActions()
    }
}


SettingsGui_GetGeneralText() {
    global g_ConfigDir
    global g_LiveEnabled, g_ShowTrayTips, g_PlaySound

    text := ""
    text .= "Статус:`r`n"
    text .= "Layout Toolkit запущен.`r`n"
    text .= "Live-режим: " SettingsGui_OnOff(g_LiveEnabled) "`r`n"
    text .= "Уведомления: " SettingsGui_OnOff(g_ShowTrayTips) "`r`n"
    text .= "Звук уведомлений: " SettingsGui_OnOff(g_PlaySound) "`r`n"
    text .= "`r`n"

    text .= "Папка данных пользователя:`r`n"
    text .= g_ConfigDir "`r`n"
    text .= "`r`n"
    
    text .= "О программе:`r`n"
    text .= "Layout Toolkit — фоновая утилита для быстрого исправления текста при ошибочной RU/EN-раскладке, случайном CapsLock и для ввода Unicode-символов.`r`n"
    text .= "`r`n"
    text .= "Основная работа идёт через горячие клавиши и трей-меню.`r`n"
    text .= "`r`n"
    text .= "Пользовательские данные хранятся в Documents\Layout Toolkit.`r`n"
    
    return text
}


SettingsGui_GetLayoutFixText() {
    global g_HotkeyLayoutFull, g_HotkeyLayoutMajority, g_HotkeyLiveToggle

    text := ""
    text .= "Исправление раскладки:`r`n"
    text .= "`r`n"
    text .= "Layout Fix исправляет текст, набранный в неправильной RU/EN-раскладке.`r`n"
    text .= "`r`n"

    text .= "Full mode:`r`n"
    text .= "Исправляет весь выделенный фрагмент как текст, полностью набранный в неверной раскладке.`r`n"
    text .= "Текущий хоткей: " HotkeyToDisplay(g_HotkeyLayoutFull) "`r`n"
    text .= "`r`n"

    text .= "Majority mode:`r`n"
    text .= "Исправляет смешанный текст осторожнее: анализирует слова и меняет только подозрительные фрагменты.`r`n"
    text .= "Текущий хоткей: " HotkeyToDisplay(g_HotkeyLayoutMajority) "`r`n"
    text .= "`r`n"

    text .= "Live mode:`r`n"
    text .= "Работает во время набора и исправляет текущий набранный фрагмент по двойному пробелу.`r`n"
    text .= "Переключение live-режима: " HotkeyToDisplay(g_HotkeyLiveToggle) "`r`n"
    text .= "`r`n"

    text .= "Изменить горячие клавиши можно в разделе “Горячие клавиши”.`r`n"

    return text
}


SettingsGui_GetLiveText() {
    global g_LiveEnabled, g_HotkeyLiveToggle

    text := ""
    text .= "Live-режим сейчас: " SettingsGui_OnOff(g_LiveEnabled) "`r`n"
    text .= "Хоткей переключения: " HotkeyToDisplay(g_HotkeyLiveToggle) "`r`n"
    text .= "`r`n"
    text .= "Планируемые настройки:`r`n"
    text .= "[ ] Включить live-режим`r`n"
    text .= "DoubleSpaceMs = 700`r`n"
    text .= "[ ] Показывать расширенную подсказку при первом включении`r`n"
    text .= "`r`n"
    text .= "Важно:`r`n"
    text .= "Live-режим должен быть легко выключаемым, потому что может мешать играм и отдельным приложениям.`r`n"

    return text
}


SettingsGui_GetHotkeysText() {
    global g_HotkeyLayoutFull, g_HotkeyLayoutMajority, g_HotkeyLiveToggle
    global g_HotkeyUnicodeInput, g_HotkeyCapsLockFix
    global g_HotkeysPath, g_DefaultHotkeysPath
    global g_Hotkeys

    factoryKeys := Map(
        "LayoutFull", true,
        "LayoutMajority", true,
        "LiveToggle", true,
        "UnicodeInput", true,
        "CapsLockFix", true
    )

    text := ""
    text .= "Текущие горячие клавиши:`r`n"
    text .= "`r`n"
    text .= "Layout full fix:      " HotkeyToDisplay(g_HotkeyLayoutFull) "`r`n"
    text .= "Layout majority fix:  " HotkeyToDisplay(g_HotkeyLayoutMajority) "`r`n"
    text .= "Live toggle:          " HotkeyToDisplay(g_HotkeyLiveToggle) "`r`n"
    text .= "Unicode Input:        " HotkeyToDisplay(g_HotkeyUnicodeInput) "`r`n"
    text .= "CapsLock Fix:         " HotkeyToDisplay(g_HotkeyCapsLockFix) "`r`n"
    text .= "`r`n"

    extraText := ""

    for name, value in g_Hotkeys {
        if factoryKeys.Has(name) {
            continue
        }

        extraText .= name ": " HotkeyToDisplay(value) "  [" value "]`r`n"
    }

    if (extraText != "") {
        text .= "Дополнительные хоткеи из hotkeys.ini:`r`n"
        text .= extraText
        text .= "`r`n"
    }

    text .= "Пользовательский файл хоткеев:`r`n"
    text .= g_HotkeysPath "`r`n"
    text .= "`r`n"

    text .= "Стандартные хоткеи:`r`n"
    text .= g_DefaultHotkeysPath "`r`n"
    text .= "`r`n"

    text .= "Изменение хоткеев через GUI будет добавлено отдельным этапом.`r`n"
    text .= "Сейчас значения уже читаются из hotkeys.ini.`r`n"
    text .= "`r`n"
    text .= "Для пользовательских модулей можно добавлять свои строки в [Hotkeys], например:`r`n"
    text .= "MyModule.DoThing=^!m`r`n"

    return text
}


SettingsGui_GetUnicodeText() {
    global g_HotkeyUnicodeInput

    text := ""
    text .= "Unicode Input:`r`n"
    text .= "`r`n"
    text .= "Хоткей: " HotkeyToDisplay(g_HotkeyUnicodeInput) "`r`n"
    text .= "Открывает Unicode Input и вставляет результат в активное окно.`r`n"
    text .= "`r`n"
    text .= "Кнопка ниже открывает то же окно, но результат кладётся в буфер обмена.`r`n"
    text .= "`r`n"
    text .= "Поддерживаемые форматы:`r`n"
    text .= "2014 → —`r`n"
    text .= "0060 2014 0060 → несколько кодов через пробел`r`n"
    text .= "006020140060 → слитная строка блоками по 4 HEX-символа`r`n"
    text .= "0020 → пробел`r`n"
    text .= "`r`n"
    text .= "Позже сюда нормально ляжет предпросмотр, история и избранные символы.`r`n"

    return text
}


SettingsGui_GetCapsLockText() {
    global g_HotkeyCapsLockFix

    text := ""
    text .= "CapsLock Fix:`r`n"
    text .= "`r`n"
    text .= HotkeyToDisplay(g_HotkeyCapsLockFix) " — исправить регистр выделенного текста.`r`n"
    text .= "`r`n"
    text .= "Текущий режим: sentence case.`r`n"
    text .= "`r`n"
    text .= "Примеры:`r`n"
    text .= "пРИВЕТ → Привет`r`n"
    text .= "тАК бЛЯТЬ → Так блять`r`n"
    text .= "тАК. бЛЯТЬ → Так. Блять`r`n"
    text .= "pOWERSHELL → PowerShell, если PowerShell есть в exclude.txt`r`n"
    text .= "`r`n"
    text .= "exclude.txt используется как словарь канонического написания.`r`n"

    return text
}


SettingsGui_GetExclusionsText() {
    global g_ExcludePath, g_DefaultExcludePath, g_ExcludeWords

    text := ""
    text .= "Рабочий файл исключений:`r`n"
    text .= g_ExcludePath "`r`n"
    text .= "`r`n"
    text .= "Стандартный словарь:`r`n"
    text .= g_DefaultExcludePath "`r`n"
    text .= "`r`n"
    text .= "Загружено записей: " g_ExcludeWords.Count "`r`n"
    text .= "`r`n"
    text .= "Логика:`r`n"
    text .= "Documents\Layout Toolkit\exclude.txt — пользовательский живой словарь.`r`n"
    text .= "Assets\exclude.default.txt — заводской словарь для восстановления.`r`n"
    text .= "`r`n"
    text .= "Слова и фрагменты из exclude.txt не конвертируются.`r`n"
    text .= "Также exclude.txt используется как словарь канонического написания.`r`n"
    text .= "`r`n"
    text .= "Примеры:`r`n"
    text .= "USB останется USB.`r`n"
    text .= "PowerShell поможет восстановить pOWERSHELL → PowerShell.`r`n"
    text .= "C:\, D:\, http, https, www, .com, .ru помогают не ломать пути и ссылки.`r`n"
    text .= "`r`n"
    text .= "После ручного изменения exclude.txt нажми кнопку “Перезагрузить”.`r`n"
    text .= "Кнопка “Сбросить стандартные” перезаписывает пользовательский exclude.txt заводским словарём.`r`n"

    return text
}


SettingsGui_GetAboutText() {
    version := SettingsGui_GetVersionFromChangelog()

    text := ""
    text .= "Layout Toolkit`r`n"
    text .= "Версия: " version "`r`n"
    text .= "`r`n"
    text .= "RU/EN layout correction utility.`r`n"
    text .= "`r`n"
    text .= "Модули:`r`n"
    text .= "- Layout Fix`r`n"
    text .= "- Live Mode`r`n"
    text .= "- Unicode Input`r`n"
    text .= "- CapsLock Fix`r`n"
    text .= "- Settings GUI`r`n"
    text .= "`r`n"
    text .= "Версия берётся из CHANGELOG.md.`r`n"
    text .= "Если версия не найдена, используется fallback: dev.`r`n"

    return text
}


SettingsGui_GetVersionFromChangelog() {
    changelogPath := A_ScriptDir "\CHANGELOG.md"

    if !FileExist(changelogPath) {
        return "dev"
    }

    try {
        text := FileRead(changelogPath, "UTF-8")
    } catch {
        return "dev"
    }

    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line)

        if RegExMatch(line, "^##\s+\[([^\]]+)\]", &match) {
            return match[1]
        }
    }

    return "dev"
}

SettingsGui_SetActions(label1 := "", action1 := "", label2 := "", action2 := "", label3 := "", action3 := "") {
    global g_SettingsActionBtn1, g_SettingsActionBtn2, g_SettingsActionBtn3
    global g_SettingsAction1, g_SettingsAction2, g_SettingsAction3

    g_SettingsAction1 := action1
    g_SettingsAction2 := action2
    g_SettingsAction3 := action3

    SettingsGui_SetActionButton(g_SettingsActionBtn1, label1)
    SettingsGui_SetActionButton(g_SettingsActionBtn2, label2)
    SettingsGui_SetActionButton(g_SettingsActionBtn3, label3)
}


SettingsGui_SetActionButton(btn, label) {
    if !IsObject(btn) {
        return
    }

    if (label = "") {
        btn.Text := ""
        btn.Visible := false
        return
    }

    btn.Text := label
    btn.Visible := true
}


SettingsGui_ActionButton1(*) {
    global g_SettingsAction1

    SettingsGui_RunAction(g_SettingsAction1)
}


SettingsGui_ActionButton2(*) {
    global g_SettingsAction2

    SettingsGui_RunAction(g_SettingsAction2)
}


SettingsGui_ActionButton3(*) {
    global g_SettingsAction3

    SettingsGui_RunAction(g_SettingsAction3)
}


SettingsGui_RunAction(actionName) {
    switch actionName {
        case "OpenDataDir":
            OpenUserDataDir()

        case "RestartToolkit":
            SettingsGui_RestartToolkit()

        case "ChangeLanguage":
            SettingsGui_ShowLanguagePlaceholder()
			
        case "OpenUnicodeInputClipboard":
            UnicodeInput("clipboard")

        case "OpenHotkeysFile":
            OpenHotkeysFile()

        case "ReloadHotkeys":
            ReloadHotkeys()
            SettingsGui_ShowPage("Hotkeys")

        case "RestoreDefaultHotkeys":
            RestoreDefaultHotkeys()
            SettingsGui_ShowPage("Hotkeys")

        case "OpenExcludeFile":
            OpenExcludeFile()

        case "ReloadExcludeWords":
            ReloadExcludeWords()
            SettingsGui_ShowPage("Exclusions")

        case "RestoreDefaultExcludeWords":
            RestoreDefaultExcludeWords()
            SettingsGui_ShowPage("Exclusions")

        default:
            return
    }
}

SettingsGui_RestartToolkit(*) {
    global g_AppName

    result := MsgBox(
        "Перезапустить Layout Toolkit?",
        g_AppName,
        "YesNo Icon?"
    )

    if (result != "Yes") {
        return
    }

    try {
        Run('"' A_AhkPath '" "' A_ScriptFullPath '"')
        ExitApp()
    } catch as err {
        Notify("Не удалось перезапустить Layout Toolkit: " err.Message, g_AppName, "Iconx")
    }
}


SettingsGui_ShowLanguagePlaceholder(*) {
    global g_AppName

    MsgBox(
        "Смена языка интерфейса будет добавлена позже.",
        g_AppName,
        "Iconi"
    )
}

SettingsGui_OnOff(value) {
    return value ? "включён" : "выключен"
}


SettingsGui_Close(*) {
    global g_SettingsGui

    if IsObject(g_SettingsGui) {
        g_SettingsGui.Hide()
    }
}


SettingsGui_OnClose(guiObj, *) {
    guiObj.Hide()
    return true
}