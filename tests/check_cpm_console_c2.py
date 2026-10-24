#!/usr/bin/env python3
"""Safety regression: CPKTEST is quarantined following physical HP crash.

C1 CPUI and the accepted CPM keyboard hook remain available.
No C2 busy loop, unsafe local absolute JSB, or UART/HP-IB I/O may return.
"""
from pathlib import Path
import re

asm=(Path(__file__).resolve().parents[1] / "src" / "cpm85.asm").read_text()
names=re.findall(r'^\s*ASP "([A-Z]+)"',
                 asm.split("ASCIIS  ",1)[1].split("\n\nERMSG",1)[0],re.M)
assert names[-3:]==["CPKTEST","CPKCOUNT","CPKLAST"],names
runtime=asm.split("RUNTIM  BYT 0,0",1)[1].split("ASCIIS  ",1)[0]
for n in ("K2RUN","K2CNT","K2LST"):
    assert "DEF "+n in runtime
block=asm.split("K2RUN   SAD",1)[1].split("! KREL: restore",1)[0]
disabled=block.split("BYT 0,55",1)[0]
assert "LDM R26,=K2STOP" in disabled
assert "JSB =OUTSTR" in disabled
assert "BIN\n        PAD\n        RTN" in disabled
assert 'K2STOP  ASP "CPKTEST DISABLED - SEE C2 DOC"' in asm
assert 'VERMSG   ASP "CPM85 0.05c C2 DISABLED"' in asm
assert re.search(r"BYT 0,55\s+K2CNT\s+BIN",block)
assert re.search(r"BYT 0,55\s+K2LST\s+BIN",block)
for old in ("K2ARM","K2POLL","K2RELD","K2SEEN","K2KEY",
            "K2DRAW","K2PREV","K2MODE","K2PAGE"):
    assert not re.search(r"^\s*"+old+r"\s+(?:BSZ|BIN|LDM|LDBD|JSB)",asm,re.M),old
for bad in ("LDBD R22,=KEYHIT","JSB =K2KEY","JSB =K2DRAW",
            "STBD R20,=CPCTL","STBD R22,=CPKEY",
            "STBD R20,=CPOPC"):
    assert bad not in disabled,bad
assert "KHACT" in asm and "UIACT" in asm
assert 'ASP "CPUI"' in asm and 'ASP "CPM"' in asm
assert "KHOOK   BIN" in asm and "CPMRUN  SAD" in asm
assert "UIDRAW  " in asm and "UIRUN   SAD" in asm

# Crash-prevention guard for the exact offending instruction class:
# JSB =LABEL jumps through an absolute address cell (DAD), and must never
# be used for a relocated LOADBIN code label (which needs JSB X14,LABEL).
targets=set(re.findall(r"\bJSB =([A-Za-z0-9+.$-]+)",asm))
address_cells=set(re.findall(r"^([A-Za-z0-9+.$-]+)\s+DAD\b",asm,re.M))
non_cell_calls=targets-address_cells
assert not non_cell_calls, ("Unsafe indirect JSB to non-DAD source label",sorted(non_cell_calls))

lit=re.search(r'K2STOP\s+ASP "([^"]+)"',asm).group(1)
count=re.search(r'LDM R26,=K2STOP\n\s+ADMD R26,=BINTAB\n\s+LDM R36,=(\d+)D,0',disabled)
assert count and len(lit)==int(count.group(1))

for line in asm.splitlines():
    if line and line[0]!=" " and not line.startswith("!"):
        word=line.split()[0]
        assert len(word)<=7,(word,line)

print("PASS: unsafe C2 foreground loop quarantined, CPKTEST safely disabled; C1 intact")
