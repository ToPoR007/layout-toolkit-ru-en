# Layout Toolkit RU-EN — Linux Wayland

Safe clipboard-based RU/EN layout conversion scripts for Linux Wayland.

This is the Linux Wayland version of Layout Toolkit RU-EN.  
For the main Windows AutoHotkey version, see the root `README.md`.

---

## What this version does

This version provides two safe clipboard-based commands:

```text
convert-layout
convert-layout-majority
```

There is no live mode on Wayland.

Workflow:

```text
Ctrl+C → hotkey → Ctrl+V
```

The scripts do not use `ydotool`, virtual keyboard input, automatic Backspace, or automatic Ctrl+V.

---

## Requirements

For Arch / Manjaro:

```bash
sudo pacman -S --needed wl-clipboard python
```

Optional notifications:

```bash
sudo pacman -S --needed libnotify
```

If `libnotify` is not installed, the scripts should still work, but desktop notifications may not appear.

---

## Install

From the `linux-wayland` folder:

```bash
chmod +x install.sh
./install.sh
```

This installs:

```text
~/.local/bin/convert-layout
~/.local/bin/convert-layout-majority
```

---

## Usage

### convert-layout

Converts the whole clipboard to the opposite layout.

Use it when the whole copied fragment was typed in the wrong keyboard layout.

Example:

```bash
printf 'Ghbdtn/ Rfr ltkf&' | wl-copy
~/.local/bin/convert-layout
wl-paste
```

Result:

```text
Привет. Как дела?
```

---

### convert-layout-majority

Fixes mixed text by majority language.

Use it when most of the text is already correct, but some separate words or fragments were typed in the wrong layout.

Important: the script chooses the target direction by counting letters in the whole clipboard.

If there are more Cyrillic letters, it converts Latin-only fragments to Russian.  
If there are more Latin letters, it converts Cyrillic-only fragments to English.

Example with Russian majority:

```bash
printf 'Ghbdtn/ Я уже дома. Rfr дела?' | wl-copy
~/.local/bin/convert-layout-majority
wl-paste
```

Result:

```text
Привет. Я уже дома. Как дела?
```

Example with English majority:

```bash
printf 'Hello, цщкдв!' | wl-copy
~/.local/bin/convert-layout-majority
wl-paste
```

Result:

```text
Hello, world!
```

---

## KDE Plasma shortcut example

Open:

```text
System Settings → Keyboard → Shortcuts → Custom Commands
```

Bind commands like this:

```text
Meta + F12 → /home/YOUR_USER/.local/bin/convert-layout
Meta + F11 → /home/YOUR_USER/.local/bin/convert-layout-majority
```

To get the correct full paths:

```bash
echo "$HOME/.local/bin/convert-layout"
echo "$HOME/.local/bin/convert-layout-majority"
```

Use the full absolute path in KDE shortcut fields.

Good:

```text
/home/YOUR_USER/.local/bin/convert-layout
```

Avoid:

```text
~/.local/bin/convert-layout
```

Some desktop shortcut systems do not expand `~` correctly.

---

## Common mistakes

### Using the wrong mode

Use `convert-layout` when the whole copied fragment is wrong:

```text
Ghbdtn/ Rfr ltkf&
```

Use `convert-layout-majority` when the text is mixed:

```text
Ghbdtn/ Я уже дома. Rfr дела?
```

---

### Expecting live mode

This Linux Wayland version has no live mode.

It will not automatically copy, replace, or paste text.

Correct workflow:

```text
Ctrl+C → hotkey → Ctrl+V
```

---

### Missing executable permissions

Fix:

```bash
chmod +x ~/.local/bin/convert-layout
chmod +x ~/.local/bin/convert-layout-majority
```

---

### Missing wl-clipboard

If you see:

```text
wl-paste: command not found
```

Install:

```bash
sudo pacman -S wl-clipboard
```

---

### Windows line endings

If you see:

```text
/usr/bin/env: ‘bash\r’: No such file or directory
```

Fix:

```bash
sed -i 's/\r$//' ~/.local/bin/convert-layout
sed -i 's/\r$//' ~/.local/bin/convert-layout-majority
```

---

### Binding an old file

If you installed the scripts with `install.sh`, bind these installed commands:

```text
~/.local/bin/convert-layout
~/.local/bin/convert-layout-majority
```

Do not bind old copies from `Downloads`, `Desktop`, or another temporary folder.

---

## Limitations

- No live mode on Wayland.
- No automatic copy/paste.
- No automatic Backspace.
- No virtual keyboard input.
- Works only with text clipboard content.
- The majority mode uses a simple letter-count heuristic, not language detection.
- Mixed words containing both Latin and Cyrillic letters are left unchanged to avoid damaging technical text.
