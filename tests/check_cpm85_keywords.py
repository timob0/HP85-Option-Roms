#!/usr/bin/env python3
"""Static regressions for the HP-85 CPM85 LOADBIN keyword/attribute ABI."""
from pathlib import Path
import re

src = Path(__file__).resolve().parents[1] / "src" / "cpm85.asm"
text = src.read_text()
table = text.split("ASCIIS  ", 1)[1].split("\n\nERMSG", 1)[0]
names = re.findall(r'^\s*ASP\s+"([A-Z]+)"', table, re.M)
assert names == ["CPM", "CPOFF", "CPVER", "CPCOUNT", "CPLAST", "CPSTATUS", "CPDMNT", "CPDUMNT", "CPRESET", "CPREBOOT", "CPDIMGS", "CPDMK", "CPDCAT", "CPEXPORT", "CPIMPORT", "CPXSTAT", "CPABORT", "CPXCODE", "CPLOOP"], names
assert len(set(names)) == len(names)
for a in names:
    for b in names:
        if a != b:
            assert not a.startswith(b), (a, b)
# 0,55 octal = NO arguments, numeric function.  40,55 octal
# indicates TWO numeric arguments and is only correct for TEST(x,y).
assert text.count("        BYT 0,55") == 3
assert "        BYT 40,55" not in text
assert re.search(r"BYT 0,55\s*CNTFUN\s+BIN", text)
assert re.search(r"BYT 0,55\s*LSTFUN\s+BIN", text)
assert re.search(r"BYT 0,55\s*CPXCODE\s+BIN", text)
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
assert "DEF TWOSTR" in text and "DEF ONESTR" in text and "DEF OPTEXP" in text
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
assert 'VERMSG   ASP "CPM85 0.07a LOOP PROBE"' in text
for port in ("177743", "177744", "177745", "177746"):
    assert port in text
for label in ("CPSTAT", "CPDMNT", "CPUMNT", "CPRESE", "CPRBOT", "CPIMGS", "CPMAKE", "CPCAT"):
    assert re.search(r"^" + label + r"\s+BIN", text, re.M), label
# CPRESET remains Z80-only opcode 4. New CPREBOOT uses the same
# no-argument parser and reply path, but opcode 8 is Teensy-local.
reset = text.split("CPRESE  BIN", 1)[1].split("CPRBOT  BIN", 1)[0]
reboot = text.split("CPRBOT  BIN", 1)[1].split("CPUMNT  BIN", 1)[0]
assert "LDB R22,=4" in reset and "JSB X14,CPGO" in reset
assert "LDB R22,=10" in reboot and "JSB X14,CPGO" in reboot
assert "LDB R22,=8\n" not in reboot  # bare 8 is invalid: CAPASM defaults to octal
assert "JSB X14,CPCLR" in reboot and "POMD" not in reboot
print("PASS: CPM85 CP/M drive-control ABI, CPREBOOT and string parsers")

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
                  ("CPRESE  BIN","CPRBOT  BIN"),
                  ("CPRBOT  BIN","CPUMNT  BIN"),
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
print("PASS: all CPM85 statements including CPREBOOT leave a fresh HP BASIC line")

# B2d v0.06a: quiet BASIC statements, trappable native errors and
# no keyboard-dependent Continue/Abort prompt.
assert 'DEF OPTEXP    ! CPEXPORT: one or two string expressions' in text
assert 'DEF TWOSTR    ! CPIMPORT' in text
assert 'DEF CPXCODE' in text and 'ASP "CPXCODE"' in text
for label in ("CPEXPT","CPIMPT","CPXFER","CXQRY","CXDRN","CPXCODE",
              "CXBUSY","CXCTRY","CXBERR","CXFERR"):
    assert re.search(r"^"+label+r"\s+",text,re.M),label
assert "LDB R22,=11       ! Octal 11 = decimal opcode 9" in text
assert "LDB R22,=12       ! Octal 12 = decimal opcode 10" in text
transfer=text.split("CPXFER  BIN",1)[1].split("\nCXQRY\n",1)[0]
assert "JSB =OUTSTR" not in transfer and "JSB =OUTCHR" not in transfer
assert "CXMSG1" not in transfer and "CXKEY" not in transfer
assert "JSB =ERRORP" in transfer
assert "BYT 74D" in transfer and "BYT 67D" in transfer
assert "JSB X14,CXQRY" in transfer
assert "LDB R22,=14" in transfer  # cancel pending before busy failure
assert "CMB R20,=102      ! B could also be a transient CCP transition" in transfer
assert "CMB R20,=102      ! B could also be a transient CCP transition\n        JZR CXWAIT" in transfer
assert "JZR CXWAIT" in transfer  # W/P have bounded grace
assert "CMB R20,=122" in transfer  # running BDOS cannot be aborted
assert "CPXRC   BSZ 1" in text
assert 'ONMSG   ASP "CONNECTED TO CP/M - K8 TO EXIT"' in text
startup=text.split("CPMRUN  SAD",1)[1].split("CPALRD  LDM",1)[0]
assert "LDM R36,=30D,0" in startup
assert 'VERMSG   ASP "CPM85 0.07a LOOP PROBE"' in text
print("PASS: B2d v0.06a silent file statements, trappable errors, CPXCODE, immediate busy cancellation")

# Fail-safe: exhausting the unknown/armed grace MUST fall through into
# CXBUSY remote CANCEL, not a backward loop/relay (regression v0.06a).
assert "JNZ CXLOOP\nCXBUSY  LDB R20,=1" in text
assert "CXBUSY  LDB R20,=1\n        STBD R20,X14,CPXRC\n        JMP CXCTRY" in text
assert "CXRELY JMP CXLOOP" in text
assert "LDB R20,=8D" in transfer
print("PASS: bounded unknown CCP wait ends in atomic CANCEL before BASIC error")

# v0.06b: a single BUSY phase at the CCP prompt must not trigger
# instant cancellation; transition grace is bounded before CANCEL.
assert "CMB R20,=102      ! B could also be a transient CCP transition\n        JZR CXWAIT" in transfer
assert "JNZ CXLOOP\nCXBUSY  LDB R20,=1" in transfer
assert 'VERMSG   ASP "CPM85 0.07a LOOP PROBE"' in text
print("PASS: v0.06b safe CCP transient debounce")

# v0.06c optional export destination, HP-85 four-byte string stack.
assert "OPTEXP  PUBD R43,+R6" in text
assert "CMB R14,=54" in text
opt=text.split("OPTEXP  PUBD",1)[1].split("TWOSTR  PUBD",1)[0]
assert "JSB =STREX+" in opt and "JSB =GETCMA" in opt
assert "JSB =STREXP" in opt
ex=text.split("CPEXPT  BIN",1)[1].split("CPIMPT  BIN",1)[0]
assert "CMMD R20,=TOS" in ex and "SBM R20,=4,0" in ex
assert "POMD R26,-R12" in ex and "POMD R24,-R12" in ex
assert "CPEXONE" in ex and "STBD R20,=CPARG" in ex
assert "TOS     DAD 101132" in text
assert "CMB R20,=105      ! E: transport/ownership rejection" in transfer
print("PASS: optional CPEXPORT parser, HP-85 stack arity, E-phase separation")

# v0.06d hardware regression: status response must be fully consumed
# before issuing another Teensy mailbox opcode (state clears on NUL).
# Diagnostic CPXSTAT/CPABORT instead leave body for CPREAD to display.
transfer=text.split("CPXFER  BIN",1)[1].split("! Numeric last-transfer status",1)[0]
assert transfer.count("JSB X14,CXQST")==3
assert "JSB X14,CXQRY" not in transfer
wrapper=text.split("\nCXQST\n",1)[1].split("\nCXQRY\n",1)[0]
assert "JSB X14,CXQRY" in wrapper
assert "JSB X14,CXDRN" in wrapper
assert wrapper.index("JSB X14,CXQRY") < wrapper.index("JSB X14,CXDRN")
diagnostics=text.split("CXSHOW  LDMD",1)[1].split("CPXFER  BIN",1)[0]
assert "JSB X14,CXQRY" in diagnostics and "JSB X14,CPREAD" in diagnostics
print("PASS: full mailbox NUL drain on START/STATUS/CANCEL while diagnostics retain text")

# B3a experimental foreground keyboard session: separate from known-good CPM.
probe=text.split("CPLOOP  SAD",1)[1].split("! Optional manual release",1)[0]
assert "LDBD R22,=KEYSTS" in probe and "ANM R22,=2" in probe
assert "LDBD R22,=KEYCOD" in probe and "CMB R22,=207" in probe
assert "STBD R22,=CPKEY" in probe and "STBD R20,=CPCTL" in probe
assert "JSB =EOJ2" not in probe and "JSB =HPOUT" not in probe
assert "JMP CPLTOP" in probe and "PAD" in probe and "RTN" in probe
assert probe.index("CMB R22,=207") < probe.index("STBD R22,=CPKEY")
print("PASS: B3a separate foreground polling probe and K8 local detach")
