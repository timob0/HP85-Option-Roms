#!/usr/bin/env python3
"""Static regressions for the HP-85 CPM85 LOADBIN keyword/attribute ABI."""
from pathlib import Path
import re

src = Path(__file__).resolve().parents[1] / "src" / "cpm85.asm"
text = src.read_text()
table = text.split("ASCIIS  ", 1)[1].split("\n\nERMSG", 1)[0]
names = re.findall(r'^\s*ASP\s+"([A-Z]+)"', table, re.M)
assert names == ["CPM", "CPOFF", "CPVER", "CPCOUNT", "CPLAST", "CPSTATUS", "CPDMNT", "CPDUMNT", "CPRESET"], names
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
assert "CPKEY   DAD 177741" in text and "CPCTL   DAD 177742" in text
assert "STBD R22,=CPKEY" in text
assert "STBD R20,=CPCTL" in text
assert "STBD R22,=CPCTL" in text
assert text.index("CMB R22,=207") < text.index("STBD R22,=CPKEY")
assert "JSB =EOJ2" in text
assert "STMD R44,=CHIDLE" in text
assert "JSB X14,KREL" in text
print("PASS: unique alphabetic CPM85 keywords and 0-argument numeric descriptors")

# Drive control adds two HP BASIC string-expression parsers and keeps
# original keyboard numeric functions' ABI and ISR forwarding untouched.
assert "DEF TWOSTR" in text and "DEF ONESTR" in text
assert "JSB =STREX+" in text and "JSB =STREXP" in text
assert "POMD R40,-R12" in text and "POMD R42,-R12" in text
for port in ("177743", "177744", "177745", "177746"):
    assert port in text
for label in ("CPSTAT", "CPDMNT", "CPUMNT", "CPRESE"):
    assert re.search(r"^" + label + r"\s+BIN", text, re.M), label
print("PASS: CPM85 CP/M drive-control ABI and string parsers")
