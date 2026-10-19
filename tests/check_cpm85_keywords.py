#!/usr/bin/env python3
"""Static regressions for the HP-85 CPM85 LOADBIN keyword/attribute ABI."""
from pathlib import Path
import re

src = Path(__file__).resolve().parents[1] / "src" / "cpm85.asm"
text = src.read_text()
table = text.split("ASCIIS  ", 1)[1].split("\n\nERMSG", 1)[0]
names = re.findall(r'^\s*ASP\s+"([A-Z]+)"', table, re.M)
assert names == ["CPM", "CPOFF", "CPVER", "CPCOUNT", "CPLAST"], names
assert len(set(names)) == len(names)
for a in names:
    for b in names:
        if a != b:
            assert not a.startswith(b), (a, b)
# 0,55 octal = NO arguments, numeric function.  40,55 octal
# indicates TWO numeric arguments and is only correct for TEST(x,y).
assert text.count("        BYT 0,55") == 2
assert "        BYT 40,55" not in text
assert re.search(r"BYT 0,55\s*CNTFUN\s+BIN", text)
assert re.search(r"BYT 0,55\s*LSTFUN\s+BIN", text)
# The user-verified keyboard ownership remains unchanged.
assert "CMB R22,=207" in text
assert "STBD R22,=177741" in text
assert "STBD R20,=177742" in text
assert "STBD R22,=177742" in text
assert text.index("CMB R22,=207") < text.index("STBD R22,=177741")
assert "JSB =EOJ2" in text
assert "STMD R44,=CHIDLE" in text
assert "JSB X14,KREL" in text
print("PASS: unique alphabetic CPM85 keywords and 0-argument numeric descriptors")
