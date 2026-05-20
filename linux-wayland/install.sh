#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin"

cp ./convert-layout "$HOME/.local/bin/convert-layout"
cp ./convert-layout-majority "$HOME/.local/bin/convert-layout-majority"

chmod +x "$HOME/.local/bin/convert-layout"
chmod +x "$HOME/.local/bin/convert-layout-majority"

echo "Installed:"
echo "$HOME/.local/bin/convert-layout"
echo "$HOME/.local/bin/convert-layout-majority"
echo
echo "Now bind these commands in your desktop environment shortcuts."
