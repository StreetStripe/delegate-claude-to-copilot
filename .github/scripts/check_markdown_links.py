#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
MARKDOWN_FILES = [ROOT / "README.md", ROOT / "docs" / "HOWTO.md"]

LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
IMAGE_PREFIXES = ("http://", "https://")
SKIP_PREFIXES = ("http://", "https://", "mailto:", "#")


def normalize_target(markdown_file: Path, target: str) -> Path | None:
    cleaned = target.strip()
    if not cleaned or cleaned.startswith(SKIP_PREFIXES):
        return None

    cleaned = cleaned.split("#", 1)[0]
    if not cleaned:
        return None

    return (markdown_file.parent / cleaned).resolve()


def main() -> int:
    errors: list[str] = []

    for markdown_file in MARKDOWN_FILES:
        if not markdown_file.exists():
            errors.append(f"Missing markdown file: {markdown_file.relative_to(ROOT)}")
            continue

        content = markdown_file.read_text(encoding="utf-8")
        for _, target in LINK_RE.findall(content):
            if target.startswith(IMAGE_PREFIXES):
                continue

            resolved = normalize_target(markdown_file, target)
            if resolved is None:
                continue

            if not resolved.exists():
                errors.append(
                    f"{markdown_file.relative_to(ROOT)} -> missing target: {target}"
                )

    if errors:
        print("Broken markdown links found:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Markdown link check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
