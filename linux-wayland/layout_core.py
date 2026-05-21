#!/usr/bin/env python3
import re
import sys
from pathlib import Path


EXIT_NO_CHANGES = 10

DEFAULT_EXCLUDES = [
    "USB",
    "AHK",
    "PowerShell",
    "GitHub",
    "CMD",
    "Bash",
    "Python",
    "JavaScript",
    "C:\\",
    "D:\\",
    "http",
    "https",
    "www",
    ".com",
    ".ru",
]


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


def get_exclude_path() -> Path:
    return Path(__file__).resolve().with_name("exclude.txt")


def ensure_exclude_file(path: Path) -> None:
    if path.exists():
        return

    path.write_text(
        "\n".join(DEFAULT_EXCLUDES) + "\n",
        encoding="utf-8",
    )


def load_exclude_words() -> set[str]:
    path = get_exclude_path()
    ensure_exclude_file(path)

    words: set[str] = set()

    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        word = line.strip()

        if not word:
            continue

        # Комментарии в exclude.txt можно писать через #
        if word.startswith("#"):
            continue

        words.add(word.casefold())

    return words


def is_latin(ch: str) -> bool:
    return "a" <= ch.lower() <= "z"


def is_cyrillic(ch: str) -> bool:
    return ("а" <= ch.lower() <= "я") or ch in "ёЁ"


def split_tokens(text: str) -> list[str]:
    return re.findall(
        r"https?://[^\s]+|"
        r"www\.[^\s]+|"
        r"[A-Za-z]:\\[^\s]*|"
        r"\.[A-Za-z0-9]+|"
        r"[A-Za-zА-Яа-яЁё0-9_]+|"
        r"\s+|"
        r"[^\s]",
        text,
    )


def is_excluded_token(token: str, exclude_words: set[str]) -> bool:
    normalized = token.strip().casefold()

    if not normalized:
        return False

    # Обычное точное совпадение: USB, GitHub, PowerShell и т.д.
    if normalized in exclude_words:
        return True

    # Пути Windows: C:\Windows, D:\Games и т.д.
    for item in exclude_words:
        if item.endswith(":\\") and normalized.startswith(item):
            return True

    # URL: http://..., https://..., www....
    if "http" in exclude_words and normalized.startswith("http://"):
        return True

    if "https" in exclude_words and normalized.startswith("https://"):
        return True

    if "www" in exclude_words and normalized.startswith("www."):
        return True

    # Доменные хвосты: github.com, site.ru и т.д.
    for item in exclude_words:
        if item.startswith(".") and normalized.endswith(item):
            return True

    return False


def detect_majority(text: str, exclude_words: set[str]) -> str | None:
    latin = 0
    cyrillic = 0

    for token in split_tokens(text):
        if token.isspace():
            continue

        if is_excluded_token(token, exclude_words):
            continue

        latin += sum(is_latin(ch) for ch in token)
        cyrillic += sum(is_cyrillic(ch) for ch in token)

    if latin == 0 and cyrillic == 0:
        return None

    if latin > cyrillic:
        return "latin"

    if cyrillic > latin:
        return "cyrillic"

    return None


def convert_full(text: str, exclude_words: set[str]) -> str | None:
    majority = detect_majority(text, exclude_words)

    if majority == "latin":
        table = str.maketrans(EN_TO_RU)
    elif majority == "cyrillic":
        table = str.maketrans(RU_TO_EN)
    else:
        return None

    out: list[str] = []

    for token in split_tokens(text):
        if is_excluded_token(token, exclude_words):
            out.append(token)
        else:
            out.append(token.translate(table))

    result = "".join(out)

    if result == text:
        return None

    return result


def convert_minority_tokens(text: str, exclude_words: set[str]) -> str | None:
    majority = detect_majority(text, exclude_words)

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

        if is_excluded_token(part, exclude_words):
            out.append(part)
            continue

        has_minority = any(minority(ch) for ch in part)
        has_majority = any(majority_fn(ch) for ch in part)

        # Конвертируем только токены меньшинства.
        # Если в токене смешаны обе письменности — не трогаем.
        if has_minority and not has_majority:
            converted = part.translate(table)
            out.append(converted)
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
    exclude_words = load_exclude_words()

    if mode == "full":
        result = convert_full(text, exclude_words)
    elif mode == "majority":
        result = convert_minority_tokens(text, exclude_words)
    else:
        print(f"Unknown mode: {mode}", file=sys.stderr)
        return 2

    if result is None:
        return EXIT_NO_CHANGES

    sys.stdout.write(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
