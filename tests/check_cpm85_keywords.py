#!/usr/bin/env python3
"""Static regressions for the HP-85 CPM85 LOADBIN keyword/attribute ABI."""
from pathlib import Path
import re

src = Path(__file__).resolve().parents[1] / "src" / "cpm85.asm"
text = src.read_text()
table = text.split("ASCIIS  ", 1)[1].split("\n\nERMSG", 1)[0]
names = re.findall(r'^\s*ASP\s+"([A-Z]+)"', table, re.M)
assert names == ["CPM", "CPOFF", "CPVER", "CPCOUNT", "CPLAST", "CPSTATUS", "CPDMNT", "CPDUMNT", "CPRESET", "CPDIMGS", "CPDMK", "CPDCAT", "CPUI"], names
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
# HP-85 POMD/LDM/CMM/DCM extend to the NEXT register boundary.
# R30/R32 (octal) span 2 bytes, whereas R40 spans EIGHT. The first
# hardware CPDMNT v0.03e hung because four R40..R46 POMD operations
# consumed far more than the 8 bytes of two stacked string arguments.
for bad in ("POMD R40,-R12", "POMD R42,-R12",
            "POMD R44,-R12", "POMD R46,-R12"):
    assert bad not in text, bad
umount = text.split("CPUMNT  BIN", 1)[1].split("CPDMNT  BIN", 1)[0]
mount = text.split("CPDMNT  BIN", 1)[1].split("CPCLR   CLB", 1)[0]
assert umount.index("POMD R30,-R12") < umount.index("POMD R32,-R12")
assert mount.index("POMD R26,-R12") < mount.index("POMD R24,-R12")
assert mount.index("POMD R24,-R12") < mount.index("POMD R30,-R12")
assert mount.index("POMD R30,-R12") < mount.index("POMD R32,-R12")
assert mount.index("JSB X14,CPWRDR") < mount.index("STBD R20,=CPARG")
assert mount.index("LDM R30,R26") < mount.index("LDM R32,R24") < mount.index("JSB X14,CPWRIM")
for name in ("CPWRDR  BIN", "CPWRIM  BIN"):
    op = text.split(name, 1)[1].split("RTN", 1)[0]
    assert "CMM R32" in op and "POBD R20,+R30" in op and "DCM R32" in op
    assert "CMM R42" not in op and "POBD R20,+R40" not in op
assert 'VERMSG   ASP "CPM85 0.05a CONSOLE PROBE"' in text
for port in ("177743", "177744", "177745", "177746"):
    assert port in text
for label in ("CPSTAT", "CPDMNT", "CPUMNT", "CPRESE", "CPIMGS", "CPMAKE", "CPCAT"):
    assert re.search(r"^" + label + r"\s+BIN", text, re.M), label
print("PASS: CPM85 CP/M drive-control ABI and string parsers")

# HP CRT OUTCHR renders raw control bytes as graphics. Use the proven
# byte-by-byte printable-char path, and OUTSTR only for actual CRT newline.
# ASCII 10D is LF and 13D is CR; 12D and 15D were wrong (decimal!).
reply = text.split("CPREAD  LDMD R14,=BINTAB", 1)[1].split("CPTOUT  ASP", 1)[0]
assert "CPRLOOP LDBD R32,=CPRPLY" in reply
assert "CMB R32,=10D" in reply
assert "CMB R32,=13D" in reply
assert "CMB R32,=12D" not in reply
assert "CMB R32,=15D" not in reply
assert "JSB =OUTCHR" in reply
assert "JSB =OUTSTR" in reply
assert "LDM R36,=1D,0" in reply
assert "LDM R26,=CPSPACE" in reply
assert "STMD R56,X14,CPRBUD" in reply
assert "LDMD R56,X14,CPRBUD" in reply
assert "DCM R56" in reply
assert "STMD R50,X14,CPRBUD" not in reply
assert "CPRBUD  BSZ 2" in text
assert "CPWTOP  LDM R56,=177,377" in text
assert "DCM R56" in text.split("CPWTOP ", 1)[1].split("CPREAD ", 1)[0]
assert "CPSPACE BYT 40" in text
assert "CPBUF   BSZ" not in text
assert "CPPRINT BIN" not in text
print("PASS: CPM85 v0.03e correct ASCII LF/CR and 2-byte reply counter")

# New CPDIMGS / CPDMK must preserve the same bounded, HP BASIC ABI.
image_list = text.split("CPIMGS  BIN", 1)[1].split("CPMAKE  BIN", 1)[0]
image_create = text.split("CPMAKE  BIN", 1)[1].split("CPCLR   CLB", 1)[0]
assert "LDB R22,=5" in image_list and "JSB X14,CPGO" in image_list
assert "POMD R30,-R12" in image_create and "POMD R32,-R12" in image_create
assert "JSB X14,CPWRIM" in image_create and "LDB R22,=6" in image_create
assert "LDM R36,=250D,0" in text
assert "CMB R22,=6" in text
assert "CMB R22,=207" not in image_create
catalog = text.split("CPCAT   BIN", 1)[1].split("CPBANN  BIN", 1)[0]
assert "POMD R30,-R12" in catalog and "POMD R32,-R12" in catalog
assert catalog.index("JSB X14,CPWRDR") < catalog.index("LDB R22,=7") < catalog.index("JSB X14,CPGO")
assert "CMB R22,=7" in text
print("PASS: HP CPM85 image and CPDCAT command ABI, string pair width, bounded timeout")

# HP must display CPDMK's filename before the long wait using the native
# OUTSTR path, never by interpreting raw LF as an OUTCHR glyph.
make = text.split("CPMAKE  BIN",1)[1].split("CPBANN  BIN",1)[0]
banner = text.split("CPBANN  BIN",1)[1].split("CPCLR   CLB",1)[0]
assert make.index("STMD R30,X14,CPNMADR") < make.index("JSB X14,CPWRIM")
assert make.index("STMD R32,X14,CPNMLEN") < make.index("JSB X14,CPWRIM")
assert make.index("JSB X14,CPWRIM") < make.index("JSB X14,CPBANN")
assert make.index("JSB X14,CPBANN") < make.index("LDB R22,=6")
assert 'CPMKPFX ASP "CREATING "' in text
assert "LDMD R30,X14,CPNMADR" in banner
assert "LDMD R32,X14,CPNMLEN" in banner
assert "LDM R36,=12D,0" in banner
assert "JSB =OUTSTR" in banner
assert "CPMKBUF BSZ 96D" in text  # decimal literal: CAPASM defaults to octal
assert "CPENDNL BSZ 1" in text
reply = text.split("CPREAD  LDMD R14,=BINTAB",1)[1].split("CPTOUT  ASP",1)[0]
assert "STBD R20,X14,CPENDNL" in reply
assert "CPDONE  LDMD R14,=BINTAB" in reply
assert "LDBD R20,X14,CPENDNL" in reply
assert "JZR CPFIN" in reply
assert "JSB =OUTSTR       ! native HP-85 CRT newline" in reply
assert "JSB =OUTCHR" in reply
print("PASS: CPDMK named progress and final native HP-85 BASIC newline")

# All statement commands (as distinct from CPCOUNT/CPLAST numeric
# functions) must return with an HP CRT native newline. The CPM startup
# message, already-attached and busy paths all need their own OUTSTR.
startup = text.split("CPMRUN  SAD",1)[1].split("OFFRUN  SAD",1)[0]
assert "JNZ CPALRD" in startup
for entry, following in (("CPALRD  LDM","CPBUSY  LDM"),
                         ("CPBUSY  LDM","CPMRET  BIN")):
    path = startup.split(entry,1)[1].split(following,1)[0]
    assert "JSB =OUTSTR" in path, entry
    assert "JMP CPMRET" in path or entry.startswith("CPBUSY"), entry
assert 'ALRMSG  ASP "CPM85 KEY CAPTURE ACTIVE"' in text
assert "JSB =OUTSTR" in startup.split("CPMRUN  SAD",1)[-1].split("CPALRD  LDM",1)[0]
for start,end in (("OFFRUN  SAD", "VERRUN  LDM"),
                  ("VERRUN  LDM", "CNTFUN  BIN")):
    assert "JSB =OUTSTR" in text.split(start,1)[1].split(end,1)[0], start

# These six HP BASIC statements have no independent print paths: each must
# reach CPGO, which handles success, error, timeout and reply-limit newlines.
for start,end in (("CPCAT   BIN","CPBANN  BIN"),
                  ("CPSTAT  BIN","CPRESE  BIN"),
                  ("CPRESE  BIN","CPUMNT  BIN"),
                  ("CPUMNT  BIN","CPDMNT  BIN"),
                  ("CPDMNT  BIN","CPIMGS  BIN"),
                  ("CPIMGS  BIN","CPMAKE  BIN"),
                  ("CPMAKE  BIN","CPBANN  BIN")):
    body=text.split(start,1)[1].split(end,1)[0]
    assert "JSB X14,CPGO" in body, start
transport=text.split("CPGO    BIN",1)[1].split("CPTOUT  ASP",1)[0]
assert "CPTOUT" in transport and "JSB =OUTSTR" in transport.split("CPTOUT",1)[1].split("CPREAD  ",1)[0]
assert "CPRLONG" in transport and "JSB =OUTSTR" in transport.split("CPRLONG",1)[1].split("CPDONE  ",1)[0]
assert "JZR CPDONE" in transport
assert "JZR CPNEWLN" in transport
assert "CPNEWLN LDMD" in transport
assert "STBD R20,X14,CPENDNL" in transport
assert "CPDONE  LDMD" in transport and "JZR CPFIN" in transport
for start,end in (("CNTFUN  BIN","LSTFUN  BIN"),
                  ("LSTFUN  BIN","CPSTAT  BIN")):
    assert "JSB =OUTSTR" not in text.split(start,1)[1].split(end,1)[0]
print("PASS: all ten CPM85 statements leave a fresh HP BASIC input line; numeric functions unchanged")


# C1 is a deliberately isolated native UI/state implementation, not a
# replacement for the physically proven CPM CHIDLE keyboard capture.
assert "DEF UIKPAR" in text and "DEF UIRUN" in text
assert 'ASP "CPUI"' in text
assert "UIKPAR  PUBD R43,+R6" in text
assert "JSB =NUMVP" in text
native_ui = text.split("UIRUN   SAD",1)[1].split("! KREL: restore",1)[0]
assert "JSB =ONER" in native_ui and "JSB =CONINT" in native_ui
assert "STMD R#,X14,UIREAL" in native_ui
assert "LDB R20,R77" in native_ui
assert "UIINIT" in native_ui and "UISWCH" in native_ui and "UIEXIT" in native_ui
assert "UIACT" in native_ui and "UIMODE" in native_ui and "UIPAGE" in native_ui
assert "CMB R22,=207" in native_ui and "CMB R22,=203" in native_ui
for key in ("200","201","202"):
    assert "CMB R22,="+key in native_ui
assert "LDBD R20,=CHIDLE" in native_ui  # no simultaneous printer hook
assert "STBD R20,=CPCTL" not in native_ui
assert "STBD R22,=CPKEY" not in native_ui
assert "JSB =OUTSTR" in native_ui
assert "JSB =OUTCHR" not in native_ui
assert "UIREAL  BSZ 8D" in text
for name in ("UIACT","UIMODE","UIPAGE"):
    assert name+"   BSZ 1" in text or name+"  BSZ 1" in text
# Regression against the literal-length error: every native OUTSTR
# display block must transmit exactly the bytes in its ASP message.
pairs = re.findall(
    r"LDM R26,=(UI[A-Z]+)\n\s+ADMD R26,=BINTAB\n\s+LDM R36,=(\d+)D,0",
    native_ui)
assert len(pairs)==8, pairs
for name, n in pairs:
    m = re.search(r'^'+name+r'\s+ASP "([^"]+)"', text, re.M)
    assert m and int(n)==len(m.group(1)), (name,n,m.group(1) if m else None)

assert "NUMVP   DAD 12407" in text
assert "ONER    DAD 56215" in text
assert "CONINT  DAD 44321" in text
print("PASS: C1 isolated native CPUI keycode, mode, CRT, lengths and legacy CPM safety")
