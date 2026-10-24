#!/usr/bin/env python3
"""Stage C1 HP BASIC keyboard pump and native CPUI integration guards."""
from pathlib import Path
import re

here = Path(__file__).resolve().parent
source = (here / "CPMCONSOLE_C1.bas").read_text()
asm = (here.parent / "src/cpm85.asm").read_text()
lines = source.splitlines()
statements = {}
for raw in lines:
    m = re.fullmatch(r"(\d+)\s+(.+)", raw)
    assert m, raw
    line = int(m.group(1))
    assert line not in statements, line
    statements[line] = m.group(2)
assert list(statements) == sorted(statements), "BASIC lines should be sorted"
for line, st in statements.items():
    for target in re.findall(r"\b(?:GOTO|GOSUB|THEN)\s+(\d+)(?:\s|$)", st):
        assert int(target) in statements, (line, st, target)

assert statements[70] == "KBDBUFFER 1"
assert statements[80] == "CPUI 0"
assert statements[90] == "IF KBDISKEY=0 THEN 90"
assert statements[100] == "K=KBDKEY"
assert statements[110] == "CPUI K"
assert statements[120] == "IF K=135 THEN 150"
assert statements[150] == "KBDBUFFER 0"
assert statements[170] == "END"

runnable = "\n".join(s for s in statements.values() if not s.startswith("REM "))
assert not re.search(r"\b(?:CPM|PRINT|PRINTER IS|OUTPUT|POKE|CPCTL|CPKEY)\b", runnable)
assert "DEF UIKPAR" in asm and "DEF UIRUN" in asm and 'ASP "CPUI"' in asm
assert "KHACT" in asm and "UIACT" in asm
assert 'UIBYE   ASP "CPM85 CONSOLE EXIT"' in asm
print("PASS: C1 keyboard pump interfaces safely with native CPUI without printer/bridge I/O")
