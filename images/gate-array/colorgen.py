#!/usr/bin/env python3
"""
Генератор PNG-картинок для аппаратной палитры Gate Array Amstrad CPC.

Именование файлов: ./colors/rgb_RRR_GGG_BBB.png
где RRR, GGG, BBB — процентные значения компонентов (0..100).

Требуется: Pillow (pip install Pillow)
"""

import os
from pathlib import Path
from PIL import Image

# ---------------------------------------------------------------------------
# Настройки
# ---------------------------------------------------------------------------

OUTPUT_DIR = Path("./colors")
IMAGE_SIZE = (64, 64)          # размер квадратика в пикселях
BACKGROUND = None              # None = прозрачный фон (не используется, т.к. заливаем)

# ---------------------------------------------------------------------------
# Аппаратная палитра Amstrad CPC (32 записи, 27 уникальных цветов)
# Значения — проценты (0..100) для R, G, B.
# Формат: (номер, название, R%, G%, B%)
# ---------------------------------------------------------------------------

PALETTE = [
    (0,  "White",             50,  50,  50),
    (1,  "White",             50,  50,  50),   # дубликат
    (2,  "Sea Green",          0, 100,  50),
    (3,  "Pastel Yellow",     50,  50,   0),
    (4,  "Blue",               0,   0,  50),
    (5,  "Purple",           100,   0,  50),
    (6,  "Cyan",               0,  50,  50),
    (7,  "Pink",             100,  50,  50),
    (8,  "Purple",           100,   0,  50),   # дубликат
    (9,  "Pastel Yellow",     50,  50,   0),   # дубликат
    (10, "Bright Yellow",    100, 100,   0),
    (11, "Bright White",     100, 100, 100),
    (12, "Bright Red",       100,   0,   0),
    (13, "Bright Magenta",   100,   0, 100),
    (14, "Orange",           100,  50,   0),
    (15, "Pastel Magenta",   100,  50, 100),
    (16, "Blue",               0,   0,  50),   # дубликат
    (17, "Sea Green",          0, 100,  50),   # дубликат
    (18, "Bright Green",       0, 100,   0),
    (19, "Bright Cyan",        0, 100, 100),
    (20, "Black",              0,   0,   0),
    (21, "Bright Blue",        0,   0, 100),
    (22, "Green",              0,  50,   0),
    (23, "Sky Blue",           0,  50, 100),
    (24, "Magenta",           50,   0,  50),
    (25, "Pastel Green",      50, 100,   0),
    (26, "Lime",              50, 100,   0),
    (27, "Pastel Cyan",       50, 100, 100),
    (28, "Red",               50,   0,   0),
    (29, "Mauve",             50,   0, 100),
    (30, "Yellow",            50,  50,   0),
    (31, "Pastel Blue",       50,  50, 100),
]

# ---------------------------------------------------------------------------
# Вспомогательные функции
# ---------------------------------------------------------------------------

def pct_to_byte(pct: int) -> int:
    """Переводит процент (0..100) в байт (0..255)."""
    pct = max(0, min(100, pct))
    return round(pct * 255 / 100)


def filename_for(r: int, g: int, b: int) -> str:
    """Формирует имя файла по схеме rgb_RRR_GGG_BBB.png."""
    return f"rgb_{r:03d}_{g:03d}_{b:03d}.png"


def make_image(r: int, g: int, b: int) -> Image.Image:
    """Создаёт однотонное RGB-изображение заданного размера."""
    rgb = (pct_to_byte(r), pct_to_byte(g), pct_to_byte(b))
    return Image.new("RGB", IMAGE_SIZE, rgb)


# ---------------------------------------------------------------------------
# Основной сценарий
# ---------------------------------------------------------------------------

def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    created = {}   # имя файла -> (R%, G%, B%)

    for num, name, r, g, b in PALETTE:
        fname = filename_for(r, g, b)
        if fname in created:
            # Уже сгенерирован — просто пропускаем (дубликаты цвета)
            continue

        img = make_image(r, g, b)
        path = OUTPUT_DIR / fname
        img.save(path)
        created[fname] = (r, g, b)
        print(f"#{num:2d}  {name:<16}  R={r:3d}%  G={g:3d}%  B={b:3d}%  -> {path}")

    print()
    print(f"Готово. Создано {len(created)} уникальных файлов в '{OUTPUT_DIR}'.")


if __name__ == "__main__":
    main()