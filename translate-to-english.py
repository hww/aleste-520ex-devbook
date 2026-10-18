#!/usr/bin/env python3
"""
translate-to-english.py — пакетный перевод .md на английский через Ollama.
Использование:
    python3 translate-to-english.py <out_dir> <file1.md> [file2.md ...]
Пример:
    python3 translate-to-english.py en/ ru/*.md
"""
import sys, re, pathlib, requests

OLLAMA = "http://localhost:11434/api/chat"
MODEL  = "qwen2.5:7b"

SYSTEM = """You are a professional technical translator. Translate the user's Markdown text from Russian to English.
Rules:
- Preserve ALL Markdown syntax exactly: headings (#), lists (-, *, 1.), code fences (```), inline code (`), links [text](url), images ![alt](src), tables (|), blockquotes (>), bold/italic.
- Do NOT translate: code inside fences, inline code, URLs, file paths, port names (#7F00), register names, identifiers, hex values.
- Translate only natural-language prose and comments inside code blocks.
- Keep the original line structure and blank lines.
- Output ONLY the translated Markdown, no explanations."""

def translate(text: str) -> str:
    r = requests.post(OLLAMA, json={
        "model": MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user",   "content": text},
        ],
        "stream": False,
        "options": {"temperature": 0.2},
    }, timeout=600)
    r.raise_for_status()
    return r.json()["message"]["content"]

def split_md(text: str, max_chars: int = 6000):
    """Режем по абзацам, чтобы не превышать контекст и не терять разметку."""
    parts, buf = [], ""
    for block in re.split(r"(\n\s*\n)", text):
        if len(buf) + len(block) > max_chars and buf:
            parts.append(buf); buf = block
        else:
            buf += block
    if buf:
        parts.append(buf)
    return parts

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 translate-to-english.py <out_dir> <file1.md> [file2.md ...]")
        sys.exit(1)

    out_dir = pathlib.Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)

    files = [pathlib.Path(p) for p in sys.argv[2:]]
    if not files:
        print("No input files."); sys.exit(1)

    for src_path in files:
        if not src_path.is_file():
            print(f"skip (not a file): {src_path}")
            continue

        print(f"translating: {src_path} -> {out_dir / src_path.name}")
        src = src_path.read_text(encoding="utf-8")

        try:
            out = "\n".join(translate(chunk) for chunk in split_md(src))
        except requests.HTTPError as e:
            print(f"  ERROR: {e}"); continue
        except Exception as e:
            print(f"  ERROR: {e}"); continue

        dst = out_dir / src_path.name          # то же имя, но в en/
        # если хочешь суффикс .en.md — раскомментируй:
        # dst = out_dir / (src_path.stem + ".en.md")
        dst.write_text(out, encoding="utf-8")
        print(f"  done: {dst}")

if __name__ == "__main__":
    main()