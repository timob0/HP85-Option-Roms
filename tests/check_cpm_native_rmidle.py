#!/usr/bin/env python3
"""Static guards for experimental native HP-85 CMENU RMIDLE hook.

Passing these checks and CAPASM does NOT establish hardware safety.
The original AUXROM361 executive hook must always be invoked last;
K8 and LOADBIN unload must restore 7 bytes if this module still owns it.
"""
from pathlib import Path
import re

s=(Path(__file__).resolve().parents[1]/"src/cpm85.asm").read_text()
assert 'ASP "CMENU"' in s and 'VERMSG   ASP "CPM85 0.06b NATIVE RMIDLE"' in s
assert s.count("DEF MNRUN") == 1
assert "RMPATT  BYT 316,376,11,63,147,361,236" in s
assert "RMIDLE  DAD 102434" in s and "ROMJSB  DAD 4776" in s
assert "CRTBAD  DAD 177405" in s and "CRTDAT  DAD 177407" in s
assert "CRTRAM  DAD 100200" in s and "CRTBYT  DAD 100176" in s
assert "RMSAVE  BSZ 7" in s and "KHSAVE  BSZ 7" in s

menu=s.split("MNRUN   SAD",1)[1].split("! Optional manual release",1)[0]
assert menu.index("LDBD R20,X14,KHACT") < menu.index("LDBD R20,=CHIDLE")
assert "LDM R34,=RMIDLE" in menu and "LDM R36,=RMPATT" in menu
assert "CMB R22,R23" in menu and "JSB =ERRORP" in menu
assert menu.index("MNCOMP ") < menu.index("MNSAV   PUBD R22,+R40")
assert menu.index("MNSAV   PUBD R22,+R40") < menu.index("STMD R44,=RMIDLE")
assert "STMD R44,=CHIDLE" in menu and "STMD R44,=RMIDLE" in menu
assert "LDM R46,=RMHOOK" in menu and "STMD R46,X14,RMADDR" in menu
assert "LDB R20,=2\n        STBD R20,X14,KHACT" in menu
assert "BIN\n        PAD\n        RTN" in menu
assert "STBD R22,=CPKEY" not in menu
assert "STBD R20,=CPCTL" not in menu

hook=s.split("RMHOOK  BIN",1)[1].split("! RM native alpha-line painter.",1)[0]
for reg in ("R10","R20","R30","R40"):
    assert "PUMD "+reg+",+R6" in hook
    assert "POMD "+reg+",-R6" in hook
assert hook.index("PUMD R10,+R6") < hook.index("PUMD R40,+R6")
assert hook.index("POMD R40,-R6") < hook.index("POMD R10,-R6")
assert "RMDIG0" in hook and "RMDIG1" in hook and "RMDIG2" in hook
assert "RMTICK" in hook and "RMDIRTY" in hook
assert "JSB X14,RMDRAW" in hook
assert "JSB =ROMJSB\n        BYT 63,147,361" in hook
assert hook.index("POMD R10,-R6") < hook.index("JSB =ROMJSB")
assert hook.rstrip().endswith("BYT 63,147,361     ! exact HP ROMJSB descriptor: 063463, ROM361\n        RTN")
for forbidden in ("=CPKEY","=CPCTL","=CPARG","=CPOPC","=CPSTATE","=CPRPLY",
                  "=KEYHIT","=OUTSTR","=OUTCHR","=PRINTER"):
    assert forbidden not in hook,forbidden

draw=s.split("RMDRAW  LDMD R14,=BINTAB",1)[1].split("! KREL: restore",1)[0]
assert "LDBD R20,=CRTWRS" in draw
assert "LDMD R40,=CRTRAM" in draw
assert "STBD R40,=CRTBAD" in draw and "STBD R41,=CRTBAD" in draw
assert "STBD R22,=CRTDAT" in draw
assert "LDMD R40,=CRTBYT" in draw
assert "RMDWAIT " in draw and "DCB R31" in draw
assert "RMDIG2" in draw and "RMPAGE" in draw and "RMMODE" in draw
assert "JSB =OUTSTR" not in draw
assert "RMTMPL  ASP " + '"RMIDLE:000 PAGE:1 MODE:0 K8 EXIT"' in s
assert len("RMIDLE:000 PAGE:1 MODE:0 K8 EXIT")==32

release=s.split("KREL    BIN",1)[1].split("! All keys (including K8)",1)[0]
assert release.index("RMOWN") < release.index("KRKEY")
assert "CMM R22,R24" in release
assert "LDM R34,=RMSAVE" in release and "LDM R36,=RMIDLE" in release
assert release.index("LDM R36,=RMIDLE") < release.index("LDM R36,=CHIDLE")
key=s.split("KHOOK   BIN",1)[1].split("! Data must follow code",1)[0]
assert "CMB R22,=207" in key
assert key.index("CMB R22,=207") < key.index("CMB R20,=2")
assert key.index("CMB R20,=2") < key.index("STBD R22,=CPKEY")
for n in ("200","201","202","203"):
    assert "CMB R22,="+n in key
assert "JSB X14,KREL" in key
assert "STBD R20,X14,RMDIRTY" in key
assert "RMOWN" in s.split("INRESET",1)[1].split("INUNLD",1)[0]
print("PASS: native CMENU strict AUXROM361 chain, HP CRT only, bounded draw, K8 restore")
