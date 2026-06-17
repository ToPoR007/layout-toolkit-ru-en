# Layout Toolkit RU-EN

A small Windows utility for fixing text typed in the wrong RU/EN keyboard layout.

Небольшая утилита для Windows, которая помогает исправлять текст, набранный в неправильной RU/EN-раскладке.

Powered by **AutoHotkey v2**.

---

## Features / Возможности

- Fix selected text typed in the wrong RU/EN layout.
- Majority mode for mixed RU/EN text.
- Live mode: fix the current typed fragment with double space.
- Unicode Input: insert Unicode characters by HEX code.
- CapsLock Fix: repair accidental CapsLock case.
- Settings GUI with hotkeys, exclusions and live-mode settings.
- User files stored in `Documents\Layout Toolkit`.

---

## Quick start / Быстрый запуск

1. Install **AutoHotkey v2**.
2. Download the project or release archive.
3. Run:

```text
Run_Layout_Toolkit.cmd
````

If AutoHotkey v2 is missing, the launcher will open the official AutoHotkey website.

---

## Default hotkeys / Хоткеи по умолчанию

| Action                     | Hotkey              |
| -------------------------- | ------------------- |
| Full layout conversion     | `Win + F12`         |
| Majority layout conversion | `Win + F11`         |
| Toggle live mode           | `Win + F10`         |
| Unicode Input              | `Ctrl + Shift + U`  |
| CapsLock Fix               | `Win + Shift + F12` |

Hotkeys can be changed in:

```text
Documents\Layout Toolkit\hotkeys.ini
```

They can also be opened and reloaded from the Settings GUI.

---

## How it works / Как это работает

### Layout Fix

Use this when selected text was typed in the wrong layout.

```text
Ghbdtn/ Rfr ltkf&
```

becomes:

```text
Привет. Как дела?
```

### Majority mode

Useful for mixed text where only some fragments are in the wrong layout.

```text
Ghbdtn/ Я уже дома. Rfr дела?
```

becomes:

```text
Привет. Я уже дома. Как дела?
```

### Live mode

Live mode fixes the current typed fragment after a double space.

```text
Z gbie ntrcn/  
```

becomes:

```text
Я пишу текст. 
```

Live mode sends synthetic `Backspace` and paste actions, so it is best for messengers, search fields and short input fields.

For long documents, use selected-text conversion instead.

### Unicode Input

Input Unicode characters by HEX code:

```text
2014
```

inserts:

```text
—
```

Multiple codes are supported:

```text
0060 2014 0060
```

inserts:

```text
`—`
```

The Settings GUI can open Unicode Input in clipboard mode.

### CapsLock Fix

Fix selected text typed with accidental CapsLock:

```text
пРИВЕТ
```

becomes:

```text
Привет
```

```text
pOWERSHELL
```

can become:

```text
PowerShell
```

if `PowerShell` is listed in `exclude.txt`.

---

## User files / Пользовательские файлы

Layout Toolkit stores user data here:

```text
Documents\Layout Toolkit
```

Main files:

```text
settings.ini
hotkeys.ini
exclude.txt
```

* `settings.ini` — user settings.
* `hotkeys.ini` — user hotkeys.
* `exclude.txt` — exclusions and canonical spelling.

`exclude.txt` is useful for technical words, commands, paths, links and names like:

```text
PowerShell
GitHub
USB
https://
C:\
```

---

## Settings GUI

The Settings GUI can:

* show current hotkeys;
* open and reload `hotkeys.ini`;
* reset hotkeys to defaults;
* open and reload `exclude.txt`;
* reset exclusions to defaults;
* configure live mode;
* open Unicode Input in clipboard mode.

Open it from the tray menu or by double-clicking the Layout Toolkit tray icon.

---

## Startup / Автозапуск

Run:

```text
Startup_Manager.cmd
```

It can add or remove Layout Toolkit from Windows startup.

---

## Requirements / Требования

* Windows 10 or Windows 11
* AutoHotkey v2

---

## Known limitations / Ограничения

* Live mode is intended mostly for short messages.
* Some applications may handle synthetic `Backspace` / paste differently.
* For long documents, selected-text conversion is safer than live mode.

---

## Changelog

See:

```text
CHANGELOG.md
```