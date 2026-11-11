#!/usr/bin/env python3
"""Keep user-facing LaTeX command reference synchronized with ROM keyword tables."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
guides = {
    "SIMON85": ("src/SIMON85_rom.asm", "KWTABL", "ERMSG", "v0.13a2"),
    "PRINTER85": ("src/printer85_rom.asm", "P8ASCI", "ERMSG", "v0.03b RC1c"),
    "CPM85": ("src/cpm85.asm", "ASCIIS", "ERMSG", "v0.06d"),
}
for name, (source, begin, end, version) in guides.items():
    rom = (root / source).read_text()
    guide = (root / "manuals" / f"{name}-pocket-guide.tex").read_text()
    table = rom.split("\n" + begin + " ", 1)[1].split("\n" + end + " ", 1)[0]
    keywords = re.findall(r'^\s*(?:\w+\s+)?ASP\s+"([A-Z0-9]+)"', table, re.M)
    documented = re.findall(r'\\entry\{([A-Z0-9]+)\}', guide)
    assert keywords, f"{name}: empty ROM keyword table"
    assert len(keywords) == len(set(keywords)), f"{name}: duplicate ROM keywords"
    assert documented == keywords, (
        f"{name}: guide entries need updating to match source order!\n"
        f"Source: {keywords}\nGuide: {documented}"
    )
    assert version in rom and version in guide, (
        f"{name}: version mismatch: expected {version}"
    )
    assert r"\usepackage{pocketguide}" in guide
    assert r"\section{Getting Started}" in guide
    assert r"\section{Commands}" in guide or name == "CPM85"
    assert guide.count(r"\begin{document}") == guide.count(r"\end{document}") == 1
    print(f"PASS {name}: {len(keywords)} documented keywords, {version}")

style = (root / "manuals" / "pocketguide.sty").read_text()
assert "paperwidth=86mm,paperheight=152mm" in style
assert r"\newcommand{\entry}" in style
print("PASS shared pocket style and page size")
