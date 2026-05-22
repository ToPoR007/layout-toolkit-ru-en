# Layout Toolkit RU-EN

## Русский

Небольшая утилита для Windows, которая помогает исправлять текст, набранный в неправильной раскладке RU/EN.

Работает через **AutoHotkey v2**.

---

## Что умеет

### Win + F12 — полная конвертация выделенного текста

Используется, когда весь выделенный фрагмент набран в неправильной раскладке.

Пример:

```text
Ghbdtn/ Rfr ltkf&
```

станет:

```text
Привет. Как дела?
```

---

### Win + F11 — исправление смешанного текста

Используется, когда часть текста набрана нормально, а часть — в неправильной раскладке.

Скрипт определяет язык большинства и исправляет только “чужие” фрагменты.

Пример:

```text
Ghbdtn/ Я уже дома, сейчас включу компьютер. Rfr дела?
```

станет:

```text
Привет. Я уже дома, сейчас включу компьютер. Как дела?
```

---

### Win + F10 — включить или выключить live-режим

Live-режим позволяет исправлять текущий набранный фрагмент двойным пробелом.

Пример:

```text
Z gbie ntrcn/  
```

станет:

```text
Я пишу текст. 
```

---

## Быстрый запуск

1. Запустите `Run_Layout_Toolkit.cmd`.
2. Если AutoHotkey v2 не установлен, откроется официальный сайт AutoHotkey.
3. Установите AutoHotkey v2.
4. Снова запустите `Run_Layout_Toolkit.cmd`.

---

## Автозапуск

Запустите:

```text
Startup_Manager.cmd
```

В нём можно:

* добавить Layout Toolkit в автозагрузку Windows;
* удалить Layout Toolkit из автозагрузки Windows.

---

## Требования

* Windows 10 или Windows 11
* AutoHotkey v2

---

## Важное предупреждение

Live-режим сам нажимает:

```text
Backspace
Ctrl + V
```

Поэтому его лучше использовать только в:

* мессенджерах;
* поисковых строках;
* коротких полях ввода;
* быстрых заметках.

Для дипломов, книг, статей и длинных документов безопаснее использовать:

```text
Win + F11
Win + F12
```

---

## Известные ограничения

* Live-режим предназначен в основном для коротких сообщений.
* В некоторых приложениях автоматические Backspace / Ctrl+V могут работать нестандартно.
* Для длинных документов live-режим не рекомендуется.
* Требуется установленный AutoHotkey v2.

---

## English

A small Windows utility for fixing text typed in the wrong RU/EN keyboard layout.

Powered by **AutoHotkey v2**.

---

## Features

### Win + F12 — full selected text conversion

Use this when the entire selected fragment was typed in the wrong layout.

Example:

```text
Ghbdtn/ Rfr ltkf&
```

becomes:

```text
Привет. Как дела?
```

---

### Win + F11 — mixed text correction

Use this when part of the text is correct and another part was typed in the wrong layout.

The script detects the majority language and fixes only the “foreign” fragments.

Example:

```text
Ghbdtn/ Я уже дома, сейчас включу компьютер. Rfr ltkf&
```

becomes:

```text
Привет. Я уже дома, сейчас включу компьютер. Как дела?
```

---

### Win + F10 — toggle live mode

Live mode allows you to fix the current typed fragment with a double space.

Example:

```text
Z gbie ntrcn/  
```

becomes:

```text
Я пишу текст. 
```

---

## Quick start

1. Run `Run_Layout_Toolkit.cmd`.
2. If AutoHotkey v2 is not installed, the official AutoHotkey website will open.
3. Install AutoHotkey v2.
4. Run `Run_Layout_Toolkit.cmd` again.

---

## Startup

Run:

```text
Startup_Manager.cmd
```

There you can:

* add Layout Toolkit to Windows startup;
* remove Layout Toolkit from Windows startup.

---

## Requirements

* Windows 10 or Windows 11
* AutoHotkey v2

---

## Important warning

Live mode automatically sends:

```text
Backspace
Ctrl + V
```

So it is best used in:

* messengers;
* search fields;
* short input fields;
* quick notes.

For long documents, books, articles, and serious writing, it is safer to use:

```text
Win + F11
Win + F12
```

---

## Known limitations

* Live mode is intended mostly for short messages.
* Some applications may handle synthetic Backspace / Ctrl+V differently.
* Live mode is not recommended for long documents.
* AutoHotkey v2 is required.
