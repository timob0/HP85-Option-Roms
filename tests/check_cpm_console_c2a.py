#!/usr/bin/env python3
"""Static safety regression for the source-free, hook-driven CMENU probe."""
from pathlib import Path
import re
s=(Path(__file__).resolve().parents[1]/"src"/"cpm85.asm").read_text()
names=re.findall(r'^[ \t]*ASP "([A-Z]+)"',s.split("ASCIIS  ",1)[1].split("\n\nERMSG",1)[0],re.M)
assert names[-1]=="CMENU"
parse=s.split("PARSE   BYT 0,0",1)[1].split("RUNTIM  BYT 0,0",1)[0]
runtime=s.split("RUNTIM  BYT 0,0",1)[1].split("ASCIIS  ",1)[0]
assert parse.rstrip().endswith("DEF NOPARS    ! CMENU source-free console experiment")
assert runtime.rstrip().endswith("DEF MNRUN\n        BYT 377,377")
block=s.split("MNRUN   SAD",1)[1].split("! Optional manual release",1)[0]
assert "LDBD R20,X14,KHACT" in block
assert "LDBD R20,=CHIDLE" in block
assert "LDM R34,=CHIDLE" in block and "LDM R36,=KHSAVE" in block
assert "LDM R46,=KHOOK" in block and "STMD R44,=CHIDLE" in block
assert "LDB R20,=2" in block and "STBD R20,=CPCTL" in block
assert "JSB =OUTSTR" in block
assert "BIN\n        PAD\n        RTN" in block
for forbidden in ["KEYHIT","K2POLL","K2ARM","CPGO","CPARG","CPSTATE","CPRPLY",
                  "DCM R56","JMP MNRUN","JSB =KHOOK","JSB =K2KEY"]:
    assert forbidden not in "\n".join(x for x in block.splitlines() if not x.startswith("!")), forbidden
assert 'VERMSG   ASP "CPM85 0.06a RMIDLE PROBE"' in s
assert "KHOOK   BIN" in s and "KREL    BIN" in s
assert "LDB R20,=4\n        STBD R20,=CPCTL" in s # RESET abort
msg=re.search(r'MNMSG\s+ASP "([^"]+)"',s).group(1)
lenref=re.search(r'LDM R26,=MNMSG\n\s+ADMD R26,=BINTAB\n\s+LDM R36,=(\d+)D,0',block)
assert lenref and int(lenref.group(1))==len(msg)
print("PASS: CMENU native resident K8-safe CHIDLE ownership; no busy loop/LST")
