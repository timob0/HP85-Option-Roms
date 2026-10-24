#!/usr/bin/env python3
"""Stage C2 native HP-85 foreground KEYHIT experiment: source-only gates.

These assertions do NOT prove KEYHIT is updated while native firmware is
running. That key detail requires a physical HP-85 hardware test.
"""
from pathlib import Path
import re

root=Path(__file__).resolve().parents[1]
asm=(root/"src/cpm85.asm").read_text()
names=re.findall(r'^\s*ASP "([A-Z]+)"',
                 asm.split("ASCIIS  ",1)[1].split("\n\nERMSG",1)[0],re.M)
assert names[-3:]==["CPKTEST","CPKCOUNT","CPKLAST"],names
parse=asm.split("PARSE   BYT 0,0",1)[1].split("RUNTIM  BYT 0,0",1)[0]
runtime=asm.split("RUNTIM  BYT 0,0",1)[1].split("ASCIIS  ",1)[0]
assert parse.count("DEF NOPARS")>=3
for n in ("K2RUN","K2CNT","K2LST"):
    assert "DEF "+n in runtime

block=asm.split("K2RUN   SAD",1)[1].split("! KREL: restore",1)[0]
for segment in ("K2POLL","K2SEEN","K2ARM","K2RELD","K2KEY",
                "K2DRAW","K2END","K2TOUT","K2BYE"):
    assert segment in block,segment
assert "LDBD R22,=KEYHIT" in block
assert "STBD R20,X14,K2PREV" in block
assert "CMB R22,R20" in block
assert "CMB R22,=207" in block
for scan in ("200","201","202","203"):
    assert "CMB R22,="+scan in block
assert "DCM R56" in block and "DCM R36" in block
assert "LDM R36,=3D,0" in block
assert "JSB =OUTSTR" in block
assert "JSB =CONBIN" in block
assert "K2COUNT" in block and "K2LAST" in block
assert "UIACT" in block and "KHACT" in block
assert "LDBD R20,=CHIDLE" in block
assert "BIN\n        PAD\n        RTN" in block
for forbidden in ("STBD R20,=CPCTL","STBD R22,=CPKEY",
                  "STBD R20,=CPOPC","JSB =HPIB7","=CPARG"):
    assert forbidden not in block,forbidden

# Ensure no new printer/back-end interaction. Only native CRT OUTSTR is used.
# CAPASM has a 7-character label limit; check label definitions.
for line in asm.splitlines():
    if line and line[0]!=" " and not line.startswith("!"):
        word=line.split()[0]
        assert len(word)<=7,(word,line)

# OUTSTR literal length must agree with the ASP content.
lits=dict(re.findall(r'^(K2[A-Z0-9]+)\s+ASP "([^"]+)"',asm,re.M))
pairs=re.findall(
    r"LDM R26,=(K2[A-Z0-9]+)\n\s+ADMD R26,=BINTAB\n\s+LDM R36,=(\d+)D,0",block)
assert len(pairs)==7,pairs
for label,width in pairs:
    assert label in lits,label
    assert len(lits[label])==int(width),(label,len(lits[label]),width)

# Both native diagnostic functions use a zero-argument REAL ABI.
assert re.search(r"BYT 0,55\s+K2CNT\s+BIN",block)
assert re.search(r"BYT 0,55\s+K2LST\s+BIN",block)
assert "K2COUNT BSZ 1" in asm
assert "K2LAST  BSZ 1" in asm
assert "K2PREV  BSZ 1" in asm

# C1 and the accepted legacy CPM runtime remain independently callable.
assert 'ASP "CPM"' in asm and 'ASP "CPUI"' in asm
assert "KHOOK   BIN" in asm and "CPMRUN  SAD" in asm
print("PASS: bounded native C2 KEYHIT probe isolated from CPM, CPUI and LST")
