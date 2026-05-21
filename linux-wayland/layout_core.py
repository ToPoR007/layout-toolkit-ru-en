#!/usr/bin/env python3
import re
import sys
from pathlib import Path


EXIT_NO_CHANGES = 10


EN_TO_RU = {
    "`": "ё", "~": "Ё",

    "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш", "o": "щ", "p": "з",
    "[": "х", "]": "ъ",
    "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л", "l": "д",
    ";": "ж", "'": "э",
    "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь",
    ",": "б", ".": "ю", "/": ".",

    "Q": "Й", "W": "Ц", "E": "У", "R": "К", "T": "Е", "Y": "Н", "U": "Г", "I": "Ш", "O": "Щ", "P": "З",
    "{": "Х", "}": "Ъ",
    "A": "Ф", "S": "Ы", "D": "В", "F": "А", "G": "П", "H": "Р", "J": "О", "K": "Л", "L": "Д",
    ":": "Ж", '"': "Э",
    "Z": "Я", "X": "Ч", "C": "С", "V": "М", "B": "И", "N": "Т", "M": "Ь",
    "<": "Б", ">": "Ю", "?": ",",

    "@": '"',
    "#": "№",
    "$": ";",
    "^": ":",
    "&": "?",
}

RU_TO_EN = {v: k for k, v in EN_TO_RU.items()}


def is_latin(ch: str) -> bool:
    return "a" <= ch.lower() <= "z"


def is_cyrillic(ch: str) -> bool:
    return ("а" <= ch.lower() <= "я") or ch in "ёЁ"


def detect_majority(text: str):
    latin = sum(is_latin(ch) for ch in text)
    cyrillic = sum(is_cyrillic(ch) for ch in text)

    if latin == 0 and cyrillic == 0:
        return None

    if latin > cyrillic:
        return "latin"

    if cyrillic > latin:
        return "cyrillic"

    return None


def convert_full(text: str) -> str | None:
    majority = detect_majority(text)

    if majority == "latin":
        table = str.maketrans(EN_TO_RU)
    elif majority == "cyrillic":
        table = str.maketrans(RU_TO_EN)
    else:
        return None

    return text.translate(table)


def convert_minority_tokens(text: str) -> str | None:
    majority = detect_majority(text)

    if majority == "latin":
        table = str.maketrans(RU_TO_EN)
        minority = is_cyrillic
        majority_fn = is_latin
    elif majority == "cyrillic":
        table = str.maketrans(EN_TO_RU)
        minority = is_latin
        majority_fn = is_cyrillic
    else:
        return None

    parts = re.findall(r"\s+|\S+", text)
    out = []
    changed = False

    for part in parts:
        if part.isspace():
            out.append(part)
            continue

        has_minority = any(minority(ch) for ch in part)
        has_majority = any(majority_fn(ch) for ch in part)

        if has_minority and not has_majority:
            out.append(part.translate(table))
            changed = True
        else:
            out.append(part)

    if not changed:
        return None

    return "".join(out)


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: layout_core.py MODE INPUT_FILE", file=sys.stderr)
        return 2

    mode = sys.argv[1]
    input_path = Path(sys.argv[2])
    text = input_path.read_text(encoding="utf-8", errors="ignore")

    if mode == "full":
        result = convert_full(text)
    elif mode == "majority":
        result = convert_minority_tokens(text)
    else:
        print(f"Unknown mode: {mode}", file=sys.stderr)
        return 2

    if result is None:
        return EXIT_NO_CHANGES

    sys.stdout.write(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
