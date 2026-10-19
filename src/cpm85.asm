! ======================================================================
! CPM85 v0.01b -- HP-85 STANDALONE LOADBIN KEYBOARD CAPTURE PROBE
!
! Standalone proof of a reversible keyboard handoff.  NO Z80 forwarding.
! User-facing:
!       LOADBIN "CPM85"
!       CPM            ! capture HP keyboard; K8 (SHIFT+K4) detaches
!       CPOFF         ! manual detach, if an alternative input is available
!       CPVER         ! display this test module's version
!       CPCOUNT       ! number of captured keystrokes, modulo 256
!       CPLAST        ! last captured RAW HP keycode, including K8
!
! CPM, CPOFF, CPVER, CPCOUNT and CPLAST diverge at character three;
! HP BASIC's abbreviated keyword matching makes CPMCOUNT collide with CPM.
! v0.01a C85COUNT/C85LAST returned Error 89 INVALID PARM.
! The proven root cause in the source was the erroneous TEST(x,y)
! attribute (40,55 = TWO numeric parameters) copied for these
! ZERO-argument numeric functions.  Correct descriptor: 0,55.
! Names are also changed to eliminate digits as a potential lexer issue.
!
! v0.01a K8 capture and release are USER-VERIFIED on physical HP-85.
! v0.01b fixes attributes and keyword names; numeric functions untested.
!
! CAUTION: experimental hardware build.  PRINTER85 PRTKEYS 1 installs
! CHIDLE and must be disabled before CPM.  This code refuses a CHIDLE
! hook it does not recognize as idle RTN (octal 236); it never chains.
! Dedicated capture uses HP's proven CHIDLE/EOJ2 flow from PRINTER85
! standalone LOADBIN, independent of AUXROM KBDBUFFER.
! Original CHIDLE image restored when K8 is received or CPOFF runs.
! SCRATCH/LOAD unload callbacks attempt to restore the hook.
!
! STOP or RESET may interrupt ordinary operation; user should initially
! run the separate BASIC AUXROM keyboard probe before this binary.
! ======================================================================

        NAM CPM85

        DEF RUNTIM
        DEF ASCIIS
        DEF PARSE
        DEF ERMSG
        DEF INIT

PARSE   BYT 0,0
        DEF NOPARS
        DEF NOPARS
        DEF NOPARS
        BSZ 2
        BSZ 2

RUNTIM  BYT 0,0
        DEF CPMRUN
        DEF OFFRUN
        DEF VERRUN
        DEF CNTFUN
        DEF LSTFUN
        BYT 377,377

ASCIIS  ASP "CPM"
        ASP "CPOFF"
        ASP "CPVER"
        ASP "CPCOUNT"
        ASP "CPLAST"

ERMSG   BYT 377

! No-argument statement parser: identical to proven PVERP in PRINTER85.
NOPARS  LDB R47,R43
        LDB R45,=371
        PUMD R45,+R12
        JSB =SCAN
        RTN

! Standalone binary lifetime.  ROMFL=3 is LOADBIN, =2/5 unload as used
! by PRINTER85's validated standalone build; ROMFL=1 indicates RESET
! rewrote the system intercept, so only clear our state flag.
INIT    BIN
        LDBD R34,=ROMFL
        CMB R34,=3
        JZR INLOAD
        CMB R34,=1
        JZR INRESET
        CMB R34,=2
        JZR INUNLD
        CMB R34,=5
        JZR INUNLD
        RTN

INLOAD  LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,KHACT
        STBD R20,X14,KCOUNT
        STBD R20,X14,KLAST
        RTN

INRESET LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,KHACT
        RTN

INUNLD  LDMD R14,=BINTAB
        JSB X14,KREL
        RTN

! CPM: print the instructions before taking the keyboard.
! The CHIDLE hook runs after this BASIC statement returns to the editor.
        BYT 241
CPMRUN  SAD
        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,KHACT
        CMB R20,=0
        JNZ CPMRET

        LDBD R20,=CHIDLE
        CMB R20,=236
        JNZ CPBUSY

        LDM R26,=ONMSG
        ADMD R26,=BINTAB
        LDM R36,=42D,0
        JSB =OUTSTR

        BIN
        LDMD R14,=BINTAB
        LDM R34,=CHIDLE
        LDM R36,=KHSAVE
        ADM R36,R14
        LDB R20,=7
CPSAVE  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ CPSAVE

! Install exact 4-byte CHIDLE stub JSB <BINTAB + KHOOK>; RTN, keeping
! all seven original bytes saved for restoration (PRINTER85 pattern).
        LDMD R14,=BINTAB
        LDM R46,=KHOOK
        ADM R46,R14
        STM R46,R45
        LDB R47,=236
        LDB R44,=316
        STMD R44,=CHIDLE
        LDB R20,=1
        STBD R20,X14,KHACT
        JMP CPMRET

CPBUSY  LDM R26,=BSYMSG
        ADMD R26,=BINTAB
        LDM R36,=38D,0
        JSB =OUTSTR

CPMRET  BIN
        PAD
        RTN

! Optional manual release for the case of an external keyboard injector.
        BYT 241
OFFRUN  SAD
        BIN
        LDMD R14,=BINTAB
        JSB X14,KREL
        BIN
        LDM R26,=OFFMSG
        ADMD R26,=BINTAB
        LDM R36,=21D,0
        JSB =OUTSTR
        BIN
        PAD
        RTN

        BYT 241
VERRUN  LDM R26,=VERMSG
        ADMD R26,=BINTAB
        LDM R36,=33D,0
        JSB =OUTSTR
        RTN

! Implied numeric functions: HP BASIC function attribute bytes precede
! the runtime.  0,55 OCTAL = zero args, numeric system function.
! The previous 40,55 was TEST(x,y)'s two-numeric-argument descriptor
! and caused Error 89 INVALID PARM on hardware.
! Convert unsigned 8-bit count/last code to HP floating number using
! ROM 0 CONBIN, then push 8-byte HP REAL onto BASIC's R12 stack.
        BYT 0,55
CNTFUN  BIN
        LDMD R14,=BINTAB
        LDM R36,=0,0
        LDBD R36,X14,KCOUNT
        JSB =CONBIN
        BIN
        PUMD R40,+R12
        RTN

        BYT 0,55
LSTFUN  BIN
        LDMD R14,=BINTAB
        LDM R36,=0,0
        LDBD R36,X14,KLAST
        JSB =CONBIN
        BIN
        PUMD R40,+R12
        RTN

! KREL: restore all 7 CHIDLE bytes if this module owns the hook.
! Called by BASIC CPOFF, LOAD/SCRATCH unload, or from K8 processing.
KREL    BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,KHACT
        CMB R20,=0
        JZR KRRET
        LDM R34,=KHSAVE
        ADM R34,R14
        LDM R36,=CHIDLE
        LDB R20,=7
KRLOOP  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ KRLOOP
        LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,KHACT
KRRET   RTN

! All keys (including K8) are consumed, so no text reaches HP BASIC.
! The proven CHIDLE handled-key exit is EOJ2 + pop one hook R6 frame,
! then CLE/RTN.  Do not add IO, display or SPI operations in this hook.
!
! K8 is octal 0207 (135 decimal), SHIFT + physical K4.
KHOOK   BIN
        LDMD R14,=BINTAB
        LDBD R22,=KEYHIT
        STBD R22,X14,KLAST
        LDBD R20,X14,KCOUNT
        ADB R20,=1
        STBD R20,X14,KCOUNT
        CMB R22,=207
        JZR KHEXIT

! Consume an ordinary key and return to BASIC's key-wait loop.
KHCAPT  CLE
        JSB =EOJ2
        BIN
        POMD R44,-R6
        CLE
        RTN

! Consume K8, then restore CHIDLE from RAM.  CP/M is not touched.
KHEXIT  CLE
        JSB =EOJ2
        BIN
        LDMD R14,=BINTAB
        JSB X14,KREL
        BIN
        POMD R44,-R6
        CLE
        RTN

! Data must follow code in a LOADBIN object; BINTAB holds relocation base.
KHACT   BSZ 1
KHSAVE  BSZ 7
KCOUNT  BSZ 1
KLAST   BSZ 1

! Message bytes (ASCII subset).  Lengths are decimal, not null-terminated.
ONMSG   ASP "CPM85 KEY CAPTURE ON - K8 RETURNS TO BASIC"
BSYMSG   ASP "CPM85: KEYBOARD HOOK BUSY (PRTKEYS 0?)"
OFFMSG   ASP "CPM85 KEY CAPTURE OFF"
VERMSG   ASP "CPM85 0.01b TEST - NO ESP32 INPUT"
ONLEN   EQU 42D
BSYLEN  EQU 38D
OFFLEN  EQU 21D
VERLEN  EQU 33D

! HP-85 addresses, all OCTAL (copied from tested PRINTER85 LOADBIN).
BINTAB  DAD 101233
ROMFL   DAD 101231
CHIDLE  DAD 102416
KEYHIT  DAD 100671
EOJ2    DAD 34772
SCAN    DAD 11262
OUTSTR  DAD 35052
CONBIN  DAD 03572

        FIN
