! ============================================================
! PRINTER85 v0.01a -- STANDALONE LOADBIN SPLIT
!
! Extracted from the hardware-tested combined SIMON85 v0.11e source.
! This is the verification-stage LOADBIN build prior to conversion to an
! HP-85 Option ROM.  Printer algorithms and keyboard behavior are kept
! logically unchanged from the combined build.
!
! Public keywords:
!
!       PVER
!       PRTSCREEN device,driver[,zoom[,orientation]]
!       PRTSET    device,driver[,zoom[,orientation]]
!       PRTKEYS   mode
!
! Driver 1 = HP ThinkJet 2225A
! Driver 2 = SII IFD501 / CAPD345A
!
! PRINTER85 is deliberately independent of SIMON85.  It has its own CRT row
! reader, raster buffers, printer profile, HP-IB transport and CHIDLE state.
! No SIMON85-local symbol or writable workspace is referenced.
! ============================================================

        NAM PRT85

        DEF RUNTIM
        DEF ASCIIS
        DEF PARSE
        DEF ERMSG
        DEF INIT


! ============================================================
! TABLES
! ============================================================

PARSE   BYT 0,0
        DEF PVERP
        DEF PRNSCP      ! PRTSCREEN
        DEF PRNSCP      ! PRTSET: same argument syntax / validation
        DEF PKEYSP      ! PRTKEYS mode

RUNTIM  BYT 0,0
        DEF PVER.
        DEF PRNSCR.
        DEF PSET.
        DEF PKEYS.
        BYT 377,377

ASCIIS  ASP "PVER"
        ASP "PRTSCREEN"
        ASP "PRTSET"
        ASP "PRTKEYS"

ERMSG   BYT 377

! ============================================================
! INIT -- LOADBIN keyboard-hook/profile lifecycle
!
! PRTKEYS remains opt-in.  LOADBIN initializes only PRINTER85 private state;
! SCRATCH/LOAD restores the exact saved CHIDLE bytes if our hook is active.
! ============================================================

INIT    BIN
        LDBD R34,=ROMFL

        CMB R34,=3
        JZR KIINIT

        CMB R34,=2
        JZR KIUNLD

        CMB R34,=5
        JZR KIUNLD

        RTN


! LOADBIN: initialise only persistent hook/profile state.  CHIDLE itself is
! deliberately untouched.

KIINIT  LDMD R34,=BINTAB

        LDM R40,=KHACT
        ADM R40,R34
        CLM R36
        STBD R36,R40

! No keyboard printer destination is assumed at LOADBIN.  PRTSET must make
! the profile valid explicitly.

        LDM R40,=HCVLD
        ADM R40,R34
        STBD R36,R40

        RTN


! SCRATCH / LOAD de-initialization: if our hook is active, restore the exact
! previous seven-byte CHIDLE image.  No error is raised from INIT.

KIUNLD  LDMD R34,=BINTAB

        LDM R40,=KHACT
        ADM R40,R34
        LDBD R36,R40
        CMB R36,=0
        JZR KIRTN

        LDM R40,=KHSAVE
        ADM R40,R34
        LDM R42,=CHIDLE
        LDB R36,=7

KIRLOP  POBD R44,+R40
        PUBD R44,+R42
        DCB R36
        JNZ KIRLOP

        LDM R40,=KHACT
        ADM R40,R34
        CLB R36
        STBD R36,R40

KIRTN   RTN


! ============================================================
! PVER PARSER
! ============================================================

PVERP   LDB R47,R43

        LDB R45,=371
        PUMD R45,+R12

        JSB =SCAN

        RTN

! ============================================================
! PRTKEYS PARSER
!
!       PRTKEYS mode
!
! One required numeric expression.
! ============================================================

PKEYSP  PUBD R43,+R6

        JSB =NUMVP
        JEN PKPOK
        JMP PKPERR

PKPOK   POBD R47,-R6

        LDB R45,=371
        PUMD R45,+R12

        RTN

PKPERR  POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! PRTSCREEN / PRTSET PARSER
!
!       PRTSCREEN device,driver[,zoom[,orientation]]
!
! The first two numeric expressions are required.  Optional third and
! fourth expressions use the same trailing-comma pattern as CIRCLE.
! Runtime distinguishes 2/3/4 REAL arguments from R12 versus TOS.
! ============================================================

PRNSCP  PUBD R43,+R6

        JSB =NUMVP
        JEN PN1OK
        JMP PNERR

PN1OK   JSB =GETCM
        JSB =NUMVAL
        JEZ PNERR

! Optional zoom?  054 octal is comma.

        CMB R14,=54
        JNZ PNDONE

        JSB =NUMVP
        JEZ PNERR

! Optional orientation?

        CMB R14,=54
        JNZ PNDONE

        JSB =NUMVP
        JEZ PNERR

PNDONE  POBD R47,-R6

        LDB R45,=371
        PUMD R45,+R12

        RTN

PNERR   POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! PVER RUNTIME
! ============================================================

        BYT 241

PVER.   LDM R26,=HMSG
        ADMD R26,=BINTAB

        LDM R36,=16D,0

        JSB =OUTSTR

        RTN

! ============================================================
! PRTKEYS RUNTIME -- v0.11b keyboard takeover control
!
!       PRTKEYS 1    install PRINTER85 COPY/PAPER CHIDLE hook
!       PRTKEYS 0    restore the exact previously saved CHIDLE bytes
!
! PRTKEYS does not choose a printer.  Configure the independent keyboard
! hardcopy profile first with PRTSET.  If no valid PRTSET profile exists,
! COPY/PAPER are still consumed but produce no external-printer action.
!
! All non-COPY/PAPER keys remain under normal HP-85 handling.
! ============================================================

        BYT 241

PKEYS.  SAD
        BIN
        LDMD R14,=BINTAB

        JSB =ONER
        BIN
        STMD R#,X14,PKMODE

        LDMD R60,X14,PKMODE
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB

! Require an unsigned one-byte value and accept only 0 or 1.

        LDB R20,R77
        JNZ PKBAD

        CMB R76,=0
        JZR PKOFF

        CMB R76,=1
        JZR PKON

PKBAD   JSB =ERRORP
        BYT 89D


! PRTKEYS 1 is idempotent.  If PRINTER85 already owns CHIDLE, return without
! touching the installed hook.

PKON    LDBD R20,X14,KHACT
        CMB R20,=0
        JNZ PKRET

! Refuse to mask a foreign CHIDLE user.  The documented idle state begins
! with RTN (0236 octal).  We do not chain hooks in this diagnostic build.

        LDBD R20,=CHIDLE
        CMB R20,=236
        JNZ PKBAD

! Save all seven general-hook bytes, not merely the four bytes used by our
! JSB/RTN stub, so PRTKEYS 0 can restore the exact prior image.

        LDM R34,=CHIDLE
        LDM R36,=KHSAVE
        ADMD R36,=BINTAB
        LDB R20,=7

PKSVLP  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ PKSVLP

! Install the documented CHIDLE form: JSB absolute KHOOK ; RTN.
! This is the same construction used by HP's GCURSOR sample program.

        LDMD R14,=BINTAB
        LDM R46,=KHOOK
        ADM R46,R14
        STM R46,R45
        LDB R47,=236
        LDB R44,=316
        STMD R44,=CHIDLE

        LDB R20,=1
        STBD R20,X14,KHACT
        JMP PKRET


! PRTKEYS 0: restore the saved seven bytes only when PRINTER85 installed them.

PKOFF   LDBD R20,X14,KHACT
        CMB R20,=0
        JZR PKRET

        LDM R34,=KHSAVE
        ADM R34,R14
        LDM R36,=CHIDLE
        LDB R20,=7

PKRSLP  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ PKRSLP

        CLB R20
        STBD R20,X14,KHACT

PKRET   BIN
        PAD
        RTN


! ============================================================
! PRTSET RUNTIME -- stored keyboard hardcopy profile
!
!       PRTSET device,driver[,zoom[,orientation]]
!
! Uses the same PSARGS validation as PRTSCREEN, then copies the validated
! byte values into a persistent profile used only by physical COPY/PAPER.
! PRTSCREEN never modifies the stored HC* profile.
! ============================================================

        BYT 241

PSET.   SAD
        BIN
        LDMD R14,=BINTAB

        JSB X14,PSARGS

        BIN
        LDMD R14,=BINTAB

        LDBD R20,X14,PSCODE
        STBD R20,X14,HCCODE
        LDBD R20,X14,PSADDR
        STBD R20,X14,HCADDR
        LDBD R20,X14,PSDRIV
        STBD R20,X14,HCDRIV
        LDBD R20,X14,PSZVAL
        STBD R20,X14,HCZOOM
        LDBD R20,X14,PSOVAL
        STBD R20,X14,HCORI

        LDB R20,=1
        STBD R20,X14,HCVLD

        PAD
        RTN


! ------------------------------------------------------------
! KHOOK -- v0.11d inherited v0.11c functional COPY/PAPER CHIDLE handler.
!
! COPY          = 0211 octal
! PAPER ADVANCE = 0212 octal
!
! Other keys immediately RTN to normal HP-85 handling.
! ------------------------------------------------------------

KHOOK   BIN
        LDMD R14,=BINTAB
        LDBD R22,=KEYHIT

        CMB R22,=211
        JZR KHCAP

        CMB R22,=212
        JZR KHPAP

KHRET   RTN


! ------------------------------------------------------------
! COPY
! ------------------------------------------------------------

KHCAP   BIN

! Mark the key handled before starting potentially long printer I/O.

        CLE
        JSB =EOJ2

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KHCREL

        JSB X14,HCLOAD

! CRTWRS bit 7: 0=alpha, 1=graphics.

        LDBD R37,=CRTWRS
        ANM R37,=200
        CMB R37,=0
        JZR KHCTXT

! Graphics COPY uses the existing v0.10j PRTSCREEN execution path with the
! validated PRTSET profile already copied to PS* state.

        JSB X14,KGRAPH
        JMP KHCREL

KHCTXT  JSB X14,TXTCOPY

KHCREL  JSB X14,KHREL

! Keep the handled-key exit local; a relative JMP to the common exit exceeded
! CAPASM's branch range in v0.11b.

        POMD R44,-R6
        CLE
        RTN


! ------------------------------------------------------------
! PAPER ADVANCE
! ------------------------------------------------------------

KHPAP   BIN
        LDMD R14,=BINTAB

! Preserve only the hardware-verified SHIFT discriminator needed after EOJ2.
! On the tested HP-85A, KEYSTS bit 3 (010 octal) is clear for PAPER ADVANCE
! and set for SHIFT+PAPER ADVANCE.

        LDBD R37,=KEYSTS
        ANM R37,=10
        STBD R37,X14,KSHIFT

        CLE
        JSB =EOJ2

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KHPREL

        JSB X14,HCLOAD
        JSB X14,HCOPEN

! Dispatch from the single private bit sampled before EOJ2.

        LDMD R14,=BINTAB
        LDBD R37,X14,KSHIFT
        CMB R37,=0
        JNZ KHPPAG

! Normal PAPER ADVANCE: send one LF immediately, then generate our own repeat
! while KEYSTS says the physical key is still held.

        JSB X14,HCLINE
        JSB X14,KFSLW
        CMB R22,=0
        JZR KHPCLS

KHPREP  JSB X14,HCLINE
        JSB X14,KFFST
        CMB R22,=0
        JNZ KHPREP
        JMP KHPCLS

! SHIFT+PAPER ADVANCE: one page-advance command only; no repeat.

KHPPAG  JSB X14,HCPAGE
        JSB X14,KHREL

KHPCLS  JSB X14,HCCLOSE
        JMP KPEOJ

KHPREL  JSB X14,KHREL

KPEOJ   POMD R44,-R6
        CLE
        RTN


! ------------------------------------------------------------
! KHREL -- wait until the physical key is released.
! Returns only when KEYSTS low bit indicates "not depressed".
! ------------------------------------------------------------

KHREL   LDBD R30,=KEYSTS
        LRB R30
        JEV KHRRT
        JMP KHREL

KHRRT   RTN


! ------------------------------------------------------------
! KFSLW / KFFST -- release-aware PAPER repeat delays.
!
! These are intentionally simple CPU delays for the first functional build.
! They can be tuned after physical timing tests without touching printer I/O.
!
! Return:
!       R22 = 0  key released during delay
!       R22 = 1  key still held after delay
! ------------------------------------------------------------

KFSLW   LDB R20,=200

KFSO    LDBD R30,=KEYSTS
        LRB R30
        JEV KFDREL

        LDB R21,=377
KFSI    DCB R21
        JNZ KFSI
        DCB R20
        JNZ KFSO

        LDB R22,=1
        RTN


KFFST   LDB R20,=30

KFFO    LDBD R30,=KEYSTS
        LRB R30
        JEV KFDREL

        LDB R21,=377
KFFI    DCB R21
        JNZ KFFI
        DCB R20
        JNZ KFFO

        LDB R22,=1
        RTN

KFDREL  CLB R22
        RTN


! ------------------------------------------------------------
! HCLOAD -- copy stored PRTSET profile to the existing PRTSCREEN PS* state.
! ------------------------------------------------------------

HCLOAD  BIN
        LDMD R14,=BINTAB

        LDBD R20,X14,HCCODE
        STBD R20,X14,PSCODE
        LDBD R20,X14,HCADDR
        STBD R20,X14,PSADDR
        LDBD R20,X14,HCDRIV
        STBD R20,X14,PSDRIV
        LDBD R20,X14,HCZOOM
        STBD R20,X14,PSZVAL
        LDBD R20,X14,HCORI
        STBD R20,X14,PSOVAL

        RTN


! ------------------------------------------------------------
! KGRAPH -- enter existing v0.10j graphics hardcopy execution path.
!
! PSSTRT is the shared internal hardcopy subroutine used by both physical
! graphics COPY and the BASIC PRTSCREEN wrapper.
! ------------------------------------------------------------

KGRAPH  BIN
        LDMD R14,=BINTAB

! PSSTRT is a shared internal subroutine.  Physical graphics COPY and the
! BASIC PRTSCREEN wrapper both call the same verified hardcopy executor.

        JSB X14,PSSTRT
        RTN


! ------------------------------------------------------------
! HCOPEN -- begin raw text/control output using current PS* device profile.
! No HPOUT transaction remains active when this routine returns.
! ------------------------------------------------------------

HCOPEN  BIN
        LDMD R14,=BINTAB
        JSB X14,HPIB7
        LDB R34,=20
        CLB R35
        JSB X14,HPCTRL
        JSB X14,HPADRO
        RTN


! ------------------------------------------------------------
! HCLINE -- send one ASCII LF (0Ah = 012 octal).
! HCOPEN must already have been called.
! ------------------------------------------------------------

HCLINE  BIN
        LDMD R14,=BINTAB
        LDM R30,=1,0
        LDM R32,=HCLF
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN


! ------------------------------------------------------------
! HCPAGE -- driver-specific page advance.
!
! ThinkJet: ASCII FF (0Ch = 014 octal)
! SII:      ESC d 66 (66 decimal = 0102 octal lines)
! ------------------------------------------------------------

HCPAGE  BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR HCPGTJ

        LDM R30,=3D,0
        LDM R32,=SIIPG
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN

HCPGTJ  LDM R30,=1,0
        LDM R32,=HCFF
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN


! ------------------------------------------------------------
! HCCLOSE -- raw text/control cleanup.
!
! ThinkJet uses the intended explicit UNLISTEN + CR16=2 path.
! SII uses the hardened v0.10i2 delayed double CR16=2 restore and deliberately
! does not send explicit UNLISTEN.
! ------------------------------------------------------------

HCCLOSE BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR HCTJCL

! SII cleanup.

        JSB X14,SIDELAY

        BIN
        LDMD R14,=BINTAB
        JSB X14,HPIB7
        LDB R34,=20
        LDB R35,=2
        JSB X14,HPCTRL

        JSB X14,SIDLY2

        BIN
        LDMD R14,=BINTAB
        JSB X14,HPIB7
        LDB R34,=20
        LDB R35,=2
        JSB X14,HPCTRL

        JSB X14,SIDLY2
        RTN

! ThinkJet cleanup.

HCTJCL  JSB X14,HPIB7
        LDB R35,=77
        JSB X14,HPSNDC
        LDB R34,=20
        LDB R35,=2
        JSB X14,HPCTRL
        RTN


! ------------------------------------------------------------
! TXTCOPY -- copy the currently visible HP-85 alpha screen as printer text.
!
! Visible alpha display = 16 rows x 32 characters.
! CRTRAM is the current display start/home nibble address.
! One alpha character occupies two CRT nibble addresses.
!
! Each printer row is:
!       32 display characters + CR + LF = 34 bytes
!
! Underline/cursor bit 7 is cleared from each CRT character.
! ------------------------------------------------------------

TXTCOPY BIN
        LDMD R14,=BINTAB

! Preserve caller's current CRT byte pointer.

        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT

! Select normal or wipeout-safe CRT read entry exactly as the graphics path.

        CLB R21
        LDBD R20,=CRTWRS
        LRB R20
        TSB R20
        JEV TXCRMD
        LDB R21,=1

TXCRMD  STBD R21,X14,CRTFLG

! Start at the actual currently displayed alpha home address.

        LDMD R46,=CRTRAM
        STMD R46,X14,TXTADR

        LDB R20,=20
        STBD R20,X14,TXTROWS

        JSB X14,HCOPEN


! Tiny outer loop.  Keeping the JNZ next to the counter is the same structural
! rule used elsewhere in PRINTER85 when a worker body exceeds relative range.

TXTLP   JSB X14,TXT1ROW

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,TXTROWS
        DCB R20
        STBD R20,X14,TXTROWS
        JNZ TXTLP

        JSB X14,HCCLOSE

        BIN
        LDMD R14,=BINTAB
        JSB X14,PREST
        RTN


! ------------------------------------------------------------
! TXT1ROW -- build and transmit one visible 32-character alpha row.
! Also advances TXTADR to the following alpha row with 010000-octal wrap.
! ------------------------------------------------------------

TXT1ROW BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,TXTADR

        LDB R34,R46
        LDB R35,R47
        JSB =BYTCR!

        BIN
        LDMD R14,=BINTAB
        LDM R34,=TXTBUF
        ADMD R34,=BINTAB
        LDB R22,=40

        LDBD R20,X14,CRTFLG
        CMB R20,=0
        JZR TXRNOR


! Wiped/off read path.

TXRFST  JSB =INCHR-
        LDB R37,R32
        ANM R37,=177
        PUBD R37,+R34
        DCB R22
        JNZ TXRFST
        JMP TXEOL


! Normal CRT read path.

TXRNOR  JSB =INCHR
        LDB R37,R32
        ANM R37,=177
        PUBD R37,+R34
        DCB R22
        JNZ TXRNOR


! Add CR/LF and send this complete text row.

TXEOL   LDB R37,=15
        PUBD R37,+R34
        LDB R37,=12
        PUBD R37,+R34

        BIN
        LDMD R14,=BINTAB
        LDM R30,=34D,0
        LDM R32,=TXTBUF
        ADMD R32,=BINTAB
        JSB X14,HPOUT

! Advance one 32-character alpha row = 64 decimal = 0100 octal nibble
! addresses.  Explicitly wrap 010000 -> 000000 so a visible page may straddle
! the end of the four-page alpha ring without entering graphics memory.

        BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,TXTADR
        ADM R46,=100,0

        LDM R56,R46
        SBM R56,=0,20
        JNG TXADOK
        LDM R46,R56

TXADOK  STMD R46,X14,TXTADR
        RTN


! ============================================================
! PRTSCREEN RUNTIME -- v0.10h1 generic HP-IB selector + ThinkJet/SII
!
!       PRTSCREEN device,driver[,zoom[,orientation]]
!
!       zoom        = 1 normal (default), 2 = 2x, 4 = 4x
!       orientation = 0 portrait/direct (default), 1 landscape/CW
!
! Driver 1 = HP ThinkJet 2225A.  Driver 2 = SII IFD501 / CAPD345A.
! ============================================================

        BYT 241

PRNSCR. SAD
        BIN
        LDMD R14,=BINTAB

        JSB X14,PSARGS
        JSB X14,PSSTRT

! Successful PRTSCREEN remains deliberately silent in v0.11d.

        PAD
        RTN


! ------------------------------------------------------------
! PSARGS -- common PRTSCREEN / PRTSET argument extraction and validation.
!
! Input:
!       2, 3 or 4 REAL arguments already on the BASIC operating stack
!
! Output:
!       PSCODE / PSADDR / PSDRIV / PSZVAL / PSOVAL validated
! ------------------------------------------------------------

PSARGS  BIN
        LDMD R14,=BINTAB

! Defaults for omitted optional arguments.

        LDB R20,=1
        STBD R20,X14,PSZVAL
        CLB R20
        STBD R20,X14,PSOVAL

! Determine whether 4, 3 or 2 REAL arguments are present.
! Four REALs = 32 decimal = 040 octal bytes on R12.
! Three REALs = 24 decimal = 030 octal.
! Two REALs   = 16 decimal = 020 octal.

        LDM R20,R12
        SBM R20,=40,0
        CMMD R20,=TOS
        JZR PSA4

        LDM R20,R12
        SBM R20,=30,0
        CMMD R20,=TOS
        JZR PSA3

        LDM R20,R12
        SBM R20,=20,0
        CMMD R20,=TOS
        JZR PSA2

        JMP PSE1

! Four args: orientation is on top of the operating stack.

PSA4    JSB =ONER
        BIN
        STMD R#,X14,PSORI

        LDMD R60,X14,PSORI
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB
        LDB R20,R77
        JNZ PSE1
        CMB R76,=0
        JZR PSO0
        CMB R76,=1
        JNZ PSE1
PSO0    STBD R76,X14,PSOVAL

! Three or four args: zoom is next.

PSA3    JSB =ONER
        BIN
        STMD R#,X14,PSZOOM

        LDMD R60,X14,PSZOOM
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB
        LDB R20,R77
        JNZ PSE1
        CMB R76,=1
        JZR PSZOK
        CMB R76,=2
        JZR PSZOK
        CMB R76,=4
        JNZ PSE1
PSZOK   STBD R76,X14,PSZVAL

! Optional-argument validation completed.
        JMP PSA2

PSE1    JSB =ERRORP
        BYT 89D

! Required arguments, reverse order: driver then device.

PSA2    JSB =ONER
        BIN
        STMD R#,X14,PSDRV

        JSB =ONER
        BIN
        STMD R#,X14,PSDEV

! Validate driver as integer 1 or 2.

        LDMD R60,X14,PSDRV
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB
        LDB R20,R77
        JNZ PSBAD
        CMB R76,=1
        JZR PSDRV1
        CMB R76,=2
        JNZ PSBAD

PSDRV1  STBD R76,X14,PSDRIV

! Decode the standard HP BASIC device selector:
!
!       selector = 100 * select_code + primary_address
!
! Supported translator select codes are 3..10; HP-IB primary address
! must be 0..30.  Examples: 311 -> SC3/address11, 702 -> SC7/address2.
!
! Repeated subtraction by 100 keeps the code small and independent of
! any new division helper.  The largest valid selector is 1030.

        LDMD R60,X14,PSDEV
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB

! CONINT result is R76/R77.  Reject negative selectors.

        LDM R46,R76
        LDM R56,R46
        SBM R56,=0,0
        JNG PSBAD

! R46/R47 = running remainder; R20 = select-code quotient.

        CLB R20

PSDCLP  LDM R56,R46
        SBM R56,=100D,0
        JNG PSDCDN

        LDM R46,R56
        ICB R20
        JMP PSDCLP

PSDCDN  BIN
        LDMD R14,=BINTAB

! Select code must be 3..10.

        LDB R21,R20
        SBB R21,=3
        JNG PSBAD

        LDB R21,=10D
        SBB R21,R20
        JNG PSBAD

! Primary address is the remainder and must be 0..30.

        LDM R56,=30D,0
        SBM R56,R46
        JNG PSBAD

        STBD R20,X14,PSCODE
        STBD R46,X14,PSADDR

! Driver 2 targets the 576-dot CAPD345A.  zoom 4 would be wider than
! the mechanism in both portrait (1024 dots) and landscape (768 dots),
! so reject that combination before touching interface/CRT state.

        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR PSARGOK

        LDBD R20,X14,PSZVAL
        CMB R20,=4
        JZR PSBAD

PSARGOK RTN

PSBAD   JSB =ERRORP
        BYT 89D

! Sample CRT read mode and preserve caller's CRT byte pointer.
!
! CRTFLG=1 means CRTWRS wipeout bit 1 was already set, so the fast INCHR-
! read path is already safe and the caller's CRT state must be left alone.
! PSAUTO is cleared here and set only if driver 2 itself calls CRTPOF.

PSSTRT  LDB R21,=0
        LDBD R20,=CRTWRS
        LRB R20
        TSB R20
        JEV PSCRSV
        LDB R21,=1

PSCRSV  LDMD R14,=BINTAB
        STBD R21,X14,CRTFLG
        CLB R20
        STBD R20,X14,PSAUTO
        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT

! v0.10j: automatically wipe/power down the CRT for SII driver 2 only.
! If the caller already has CRTWRS wipeout set, INCHR- is already valid and
! no power-state change is made.  ThinkJet driver 1 remains unchanged.

        LDBD R20,X14,PSDRIV
        CMB R20,=2
        JNZ PSIOGO

        LDBD R20,X14,CRTFLG
        CMB R20,=1
        JZR PSIOGO

        JSB =CRTPOF

        BIN
        LDMD R14,=BINTAB
        LDB R20,=1
        STBD R20,X14,CRTFLG
        STBD R20,X14,PSAUTO

! Select the decoded translator, suppress automatic EOL, address listener.

PSIOGO  JSB X14,HPIB7
        LDB R34,=20
        CLB R35
        JSB X14,HPCTRL
        JSB X14,HPADRO

! Dispatch printer driver.  Both drivers share the proven HP-IB transport,
! CRT-state sampling and caller-pointer preservation above.

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR PSJT

! Driver 2: SII IFD501 / CAPD345A.
! v0.10h5 uses a dedicated close path.  SICLOSE waits briefly, then restores CR16 on the
! translator selected dynamically from PSCODE and deliberately does NOT send
! the explicit UNLISTEN command used by the ThinkJet close path.
        JSB X14,SIIDRV
        JMP SICLOSE

! Driver 1: ThinkJet high-density graphics resolution.
! ESC*r192S selects 192 dpi horizontally (96 dpi vertically); it is
! a resolution command, not a raster-height declaration.

PSJT    LDM R30,=7D,0
        LDM R32,=TJ192S
        ADMD R32,=BINTAB
        JSB X14,HPOUT

        LDM R30,=4D,0
        LDM R32,=TJSTAR
        ADMD R32,=BINTAB
        JSB X14,HPOUT

! Execute portrait or 90-degree clockwise landscape raster path.

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSOVAL
        CMB R20,=0
        JNZ PSLGO

        JSB X14,TJPOR
        JMP PSDONE

PSLGO   JSB X14,TJLND

! End ThinkJet raster graphics.

PSDONE  BIN
        LDMD R14,=BINTAB
        JSB X14,HPIB7
        LDM R30,=4D,0
        LDM R32,=TJEND
        ADMD R32,=BINTAB
        JSB X14,HPOUT

! ------------------------------------------------------------
! SICLOSE -- v0.10h5 SII-specific interface cleanup.
!
! Hardware test result:
!
!       CONTROL <select-code>,16;2
!
! reliably repairs every observed post-PRTSCREEN failure.  Therefore restore
! CR16 directly and immediately after the final SII HPOUT has completed.
!
! IMPORTANT: HPIB7 is generic.  It derives the translator register pair from
! PSCODE, which was decoded from the first PRTSCREEN argument.  No select
! code is hardcoded here.
!
! Do NOT send the old explicit 077-octal UNLISTEN in the SII path.  In failing
! v0.10h3 runs that value was seen by the printer as ASCII '?' (decimal 63),
! indicating that the command could escape as peripheral data.
! ------------------------------------------------------------

SICLOSE BIN
        LDMD R14,=BINTAB

! EBTKS settling delay.  Physical testing proved that BASIC
!     CONTROL <select-code>,16;2
! always repairs the virtual HP-IB interface.  v0.10h5/v0.10i1 made this
! substantially more reliable by delaying the assembler-side CR16 restore,
! but one residual text-corruption case remained.  v0.10i2 therefore uses a
! longer initial quiet interval and performs the CR16=2 write twice, with a
! shorter quiet interval between writes and again before returning to BASIC.
!
! All delays are CPU-only.  Generic HPIB7 is called immediately before each
! HPCTRL so the translator always comes from PSCODE decoded from PRTSCREEN's
! first parameter; no select code is hardcoded here.

        JSB X14,SIDELAY

! First CR16=2 restore.

        BIN
        LDMD R14,=BINTAB
        JSB X14,HPIB7
        LDB R34,=20
        LDB R35,=2
        JSB X14,HPCTRL

! Give EBTKS a short quiet interval, then repeat the same control write.

        JSB X14,SIDLY2

        BIN
        LDMD R14,=BINTAB
        JSB X14,HPIB7
        LDB R34,=20
        LDB R35,=2
        JSB X14,HPCTRL

! One final short settling interval before local screen output / BASIC resumes.

        JSB X14,SIDLY2

! v0.10j: restore the CRT only if this PRTSCREEN call blanked it.
! PSAUTO=0 means the caller already had CRT wipeout/off active (or this is not
! the SII path), so preserve that state exactly as found.

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSAUTO
        CMB R20,=0
        JZR SICRET

        JSB =CRTPUP

SICRET  JMP PSRET


! ------------------------------------------------------------
! SIDELAY -- initial deterministic CPU-only settling delay.
!
! 0200 octal outer loops = 128 decimal, double the v0.10h5/v0.10i1 delay.
! No CRT, HP-IB or system I/O occurs here.
! ------------------------------------------------------------

SIDELAY LDB R20,=200

SIDLO1  LDB R21,=377
SIDLO2  DCB R21
        JNZ SIDLO2
        DCB R20
        JNZ SIDLO1
        RTN


! ------------------------------------------------------------
! SIDLY2 -- shorter CPU-only interval between/after CR16 writes.
!
! 0040 octal outer loops = 32 decimal.
! ------------------------------------------------------------

SIDLY2  LDB R20,=40

SID2L1  LDB R21,=377
SID2L2  DCB R21
        JNZ SID2L2
        DCB R20
        JNZ SID2L1
        RTN


! ------------------------------------------------------------
! PSCLOSE -- proven ThinkJet close path, unchanged in behavior.
!
! Driver 1 retains its explicit UNLISTEN followed by CR16=2 restoration.
! HPIB7 remains generic and uses PSCODE decoded from PRTSCREEN device.
! ------------------------------------------------------------

PSCLOSE BIN
        LDMD R14,=BINTAB
        JSB X14,HPIB7

        LDB R35,=77
        JSB X14,HPSNDC
        LDB R34,=20
        LDB R35,=2
        JSB X14,HPCTRL


! ------------------------------------------------------------
! PSRET -- common return path after interface cleanup.
! ------------------------------------------------------------

PSRET   BIN
        LDMD R14,=BINTAB

! Restore caller's CRT byte pointer and return to whichever wrapper invoked
! the shared hardcopy executor.

        JSB X14,PREST
        RTN


! ============================================================
! HP-IB LOW-LEVEL TRANSPORT -- v0.10e
!
! The routines below are direct adaptations of the utility
! subroutines in HP's Assembly Language I/O Reference Manual.
! Register conventions are kept intentionally close to the manual:
!
!       R24,R25  CCR / PSR address
!       R26,R27  output / input buffer address
!       R30,R31  byte count
!       R32,R33  source pointer
!       R34      control-register number
!       R35      bus/interface byte
!       R36      protocol command or data byte
!       R37      PSR/CCR scratch
!
! v0.10h1+ selects HP-IB interfaces dynamically from PSCODE (3..10).
! ============================================================


! ------------------------------------------------------------
! HPIB7 -- decoded HP-IB translator pointers.
!
! Legacy entry label retained intentionally: the verified ThinkJet code
! continues to call HPIB7 unchanged.  PSCODE contains select code 3..10.
!
! HP-85 translator register map:
!
!       SC3  CCR/PSR = 177520, OB/IB = 177521
!       SC4             177522          177523
!       ...
!       SC7             177530          177531
!       ...
!       SC10            177536          177537
!
! Offset from SC3 is 2 * (PSCODE-3).
! ------------------------------------------------------------

HPIB7   BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSCODE
        SBB R20,=3
        LLB R20

        LDM R24,=120,377
        ADB R24,R20

        LDM R26,=121,377
        ADB R26,R20
        RTN


! ------------------------------------------------------------
! HPOBF0 -- wait until output buffer is empty.
! Manual utility: OBF=0.
! ------------------------------------------------------------

HPOBF0  LDBD R37,R24
        ANM R37,=2
        JNZ HPOBF0
        RTN


! ------------------------------------------------------------
! HPDONE -- wait until OBF=0 and BUSY=0.
! Manual utility: O=B=0.
! ------------------------------------------------------------

HPDONE  LDBD R37,R24
        ANM R37,=202
        JNZ HPDONE
        RTN


! ------------------------------------------------------------
! HPDIR -- send protocol command in R36 by direct method.
! Manual utility: DIRCMD.
! ------------------------------------------------------------

HPDIR   JSB X14,HPDONE

        LDB R37,=2
        STBD R37,R24
        STBD R36,R26

        JSB X14,HPOBF0

        CLB R37
        STBD R37,R24

        RTN


! ------------------------------------------------------------
! HPSNDC -- send byte in R35 as HP-IB bus command.
! Manual utility: SNDCMD.
! ------------------------------------------------------------

HPSNDC  LDB R36,=260
        JSB X14,HPDIR

        LDB R37,=4
        STBD R37,R24
        STBD R35,R26

        JSB X14,HPDONE
        RTN


! ------------------------------------------------------------
! HPCTRL -- write one interface control register.
!
!       R34 = register number
!       R35 = one-byte value
!
! This is the one-byte specialization of the manual CONTREL
! routine.  Opcode 200 octal is Write Control.
! ------------------------------------------------------------

HPCTRL  LDB R36,=200
        ORB R36,R34
        JSB X14,HPDIR

        JSB X14,HPOBF0

        LDB R37,=4
        STBD R37,R24
        STBD R35,R26

        JSB X14,HPDONE
        RTN


! ------------------------------------------------------------
! HPADRO -- configure HP-IB for output to PSADDR.
!
! Manual sequence:
!
!       077     Unlisten
!       105     Send My Talk Address protocol command
!       040+n   listener address n
! ------------------------------------------------------------

HPADRO  LDB R35,=77
        JSB X14,HPSNDC

        LDB R36,=105
        JSB X14,HPDIR

        LDBD R35,X14,PSADDR
        ADB R35,=40
        JSB X14,HPSNDC

        RTN


! ------------------------------------------------------------
! HPOUT -- simple output.
!
!       R30,R31 = byte count (must be non-zero)
!       R32,R33 = source pointer
!
! Protocol 240 octal is the manual's simple-output operation.
! CED is asserted only for the final byte.  Because CR16 is zero
! while this routine executes, the IOP appends no EOL sequence.
! ------------------------------------------------------------

HPOUT   LDB R36,=240
        JSB X14,HPDIR

HPOUT1  POBD R36,+R32
        JSB X14,HPOBF0

        DCM R30
        JZR HPOUTE

        STBD R36,R26
        JMP HPOUT1

HPOUTE  LDB R37,=4
        STBD R37,R24
        STBD R36,R26

        JSB X14,HPDONE
        RTN


! ============================================================
! THINKJET DRIVER 1 -- v0.10g
! ============================================================

! ------------------------------------------------------------
! TJPOR -- portrait/direct raster.
!
! z1: 256 x 192,  32 bytes/row, 1 vertical copy
! z2: 512 x 384,  64 bytes/row, 2 vertical copies
! z4: 1024 x 768, 128 bytes/row, 4 vertical copies
! ------------------------------------------------------------

TJPOR   BIN
        LDMD R14,=BINTAB
        LDM R46,=0,20
        STMD R46,X14,PSRADR
        CLB R20
        STBD R20,X14,PSROW

TPLOOP  BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PSRADR
        JSB X14,READROW
        JSB X14,TPROW

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSROW
        CMB R20,=277
        JZR TPDONE

        ICB R20
        STBD R20,X14,PSROW
        LDMD R46,X14,PSRADR
        ADM R46,=100,0
        STMD R46,X14,PSRADR
        JMP TPLOOP

TPDONE  RTN

! TPROW -- transmit the current ROWBUF at the selected zoom.

TPROW   BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSZVAL
        CMB R20,=1
        JZR TPZ1
        CMB R20,=2
        JZR TPZ2
        JMP TPZ4

! z1: unchanged v0.10f row transfer.

TPZ1    JSB X14,HPIB7
        LDM R30,=6D,0
        LDM R32,=TJ32W
        ADMD R32,=BINTAB
        JSB X14,HPOUT

        LDM R30,=32D,0
        LDM R32,=ROWBUF
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN

! z2: expand 32 bytes -> 64 bytes, then send row twice.

TPZ2    LDM R30,=32D,0
        LDM R32,=ROWBUF
        ADMD R32,=BINTAB
        JSB X14,TJEXP2

        JSB X14,HPIB7
        JSB X14,TP64R
        JSB X14,TP64R
        RTN

! z4: expand 32 bytes -> 128 bytes, then send row four times.

TPZ4    LDM R30,=32D,0
        LDM R32,=ROWBUF
        ADMD R32,=BINTAB
        JSB X14,TJEXP4

        JSB X14,HPIB7
        JSB X14,TP128R
        JSB X14,TP128R
        JSB X14,TP128R
        JSB X14,TP128R
        RTN

! Send one expanded portrait row (64 bytes).

TP64R   LDM R30,=6D,0
        LDM R32,=TJ64W
        ADMD R32,=BINTAB
        JSB X14,HPOUT

        LDM R30,=64D,0
        LDM R32,=TJSBUF
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN

! Send one 4x portrait row (128 bytes).  Header is 7 bytes because
! the decimal byte count has three digits.

TP128R  LDM R30,=7D,0
        LDM R32,=TJ128W
        ADMD R32,=BINTAB
        JSB X14,HPOUT

        LDM R30,=128D,0
        LDM R32,=TJ4BUF
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN


! ------------------------------------------------------------
! TJLND -- 90-degree clockwise landscape.
!
! Mapping in image coordinates:
!       x' = 191-y
!       y' = x
!
! Eight adjacent source X columns are accumulated into eight 24-byte
! destination rows.  Source Y is traversed 191..0 so destination x'
! advances naturally from 0..191.  Only 192 bytes of rotation buffer
! are required.
! ------------------------------------------------------------

TJLND   BIN
        LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,PSLBND

TLBLOP  JSB X14,TJLBD
        JSB X14,TJLSND

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSLBND
        CMB R20,=37
        JZR TLDONE
        ICB R20
        STBD R20,X14,PSLBND
        JMP TLBLOP

TLDONE  RTN


! ------------------------------------------------------------
! TJLBD -- build one group of eight rotated output rows.
! ------------------------------------------------------------

TJLBD   JSB X14,TJCLR

        BIN
        LDMD R14,=BINTAB

! First destination byte in row 0 and MSB of that byte.

        LDM R34,=TLBUF
        ADMD R34,=BINTAB
        STMD R34,X14,PSLDP
        LDB R20,=200
        STBD R20,X14,PSLMSK

! Bottom physical source row = 037700 octal.  Add 2*byte-column.

        LDM R46,=300,77
        LDBD R20,X14,PSLBND
        LLB R20
        ADB R46,R20
        STMD R46,X14,PSLSRC

! 192 source rows.

        LDB R20,=300
        STBD R20,X14,PSLCNT

TLRLOP  JSB X14,TJLRD
        JSB X14,TJLSCT

        BIN
        LDMD R14,=BINTAB

! Advance destination bit; after each 8 source rows move one byte right.

        LDBD R22,X14,PSLMSK
        LRB R22
        JNZ TLSMSV

        LDB R22,=200
        STBD R22,X14,PSLMSK
        LDMD R34,X14,PSLDP
        ICM R34
        STMD R34,X14,PSLDP
        JMP TLSMAD

TLSMSV  STBD R22,X14,PSLMSK

TLSMAD  LDBD R20,X14,PSLCNT
        DCB R20
        STBD R20,X14,PSLCNT
        JZR TLBFIN

! Move one physical CRT row upward.

        LDMD R46,X14,PSLSRC
        SBM R46,=100,0
        STMD R46,X14,PSLSRC
        JMP TLRLOP

TLBFIN  RTN


! ------------------------------------------------------------
! TJLRD -- read one source CRT byte for landscape conversion.
! Returns source byte in R36.
! ------------------------------------------------------------

TJLRD   BIN
        LDMD R14,=BINTAB
        LDMD R34,X14,PSLSRC
        JSB =BYTCR!

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,CRTFLG
        CMB R20,=0
        JZR TLNORM

        JSB =INCHR-
        JMP TLRDON

TLNORM  JSB =INCHR

TLRDON  LDB R36,R32
        RTN


! ------------------------------------------------------------
! TJLSCT -- scatter the eight pixels in R36 into the eight rotated
! output rows at their current common destination bit position.
! ------------------------------------------------------------

TJLSCT  BIN
        LDMD R14,=BINTAB
        LDMD R34,X14,PSLDP
        LDBD R22,X14,PSLMSK
        LDB R23,=200
        LDB R24,=10

TLSBIT  LDB R20,R36
        ORB R20,R23
        CMB R20,R36
        JNZ TLSKIP

        LDBD R21,R34
        ORB R21,R22
        STBD R21,R34

TLSKIP  ADM R34,=30,0
        LRB R23
        DCB R24
        JNZ TLSBIT
        RTN


! ------------------------------------------------------------
! TJCLR -- clear the 8 x 24-byte landscape band buffer.
! ------------------------------------------------------------

TJCLR   BIN
        LDM R34,=TLBUF
        ADMD R34,=BINTAB
        LDM R30,=192D,0
        CLB R20

TCLLOP  PUBD R20,+R34
        DCM R30
        JNZ TCLLOP
        RTN


! ------------------------------------------------------------
! TJLSND -- transmit the eight rotated rows currently in TLBUF.
! z1: 24 bytes per row, one vertical copy.
! z2: expand to 48 bytes and transmit every row twice.
! z4: expand to 96 bytes and transmit every row four times.
! ------------------------------------------------------------

TJLSND  BIN
        LDMD R14,=BINTAB
        LDM R34,=TLBUF
        ADMD R34,=BINTAB
        STMD R34,X14,PSLOUT
        CLB R20
        STBD R20,X14,PSLRNO

TLSLOP  JSB X14,TJLSR

        BIN
        LDMD R14,=BINTAB
        LDMD R34,X14,PSLOUT
        ADM R34,=30,0
        STMD R34,X14,PSLOUT

        LDBD R20,X14,PSLRNO
        ICB R20
        STBD R20,X14,PSLRNO
        CMB R20,=10
        JNZ TLSLOP
        RTN

! TJLSR -- transmit one current rotated row at selected zoom.

TJLSR   BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSZVAL
        CMB R20,=1
        JZR TLSZ1
        CMB R20,=2
        JZR TLSZ2
        JMP TLSZ4

TLSZ1   JSB X14,HPIB7
        LDM R30,=6D,0
        LDM R32,=TJ24W
        ADMD R32,=BINTAB
        JSB X14,HPOUT

        BIN
        LDMD R14,=BINTAB
        LDM R30,=24D,0
        LDMD R32,X14,PSLOUT
        JSB X14,HPOUT
        RTN

TLSZ2   LDM R30,=24D,0
        LDMD R32,X14,PSLOUT
        JSB X14,TJEXP2

        JSB X14,HPIB7
        JSB X14,TL48R
        JSB X14,TL48R
        RTN

TLSZ4   LDM R30,=24D,0
        LDMD R32,X14,PSLOUT
        JSB X14,TJEXP4

        JSB X14,HPIB7
        JSB X14,TL96R
        JSB X14,TL96R
        JSB X14,TL96R
        JSB X14,TL96R
        RTN

! Send one expanded landscape row (48 bytes).

TL48R   LDM R30,=6D,0
        LDM R32,=TJ48W
        ADMD R32,=BINTAB
        JSB X14,HPOUT

        LDM R30,=48D,0
        LDM R32,=TJSBUF
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN

TL96R   LDM R30,=6D,0
        LDM R32,=TJ96W
        ADMD R32,=BINTAB
        JSB X14,HPOUT

        LDM R30,=96D,0
        LDM R32,=TJ4BUF
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN


! ------------------------------------------------------------
! TJEXP2 -- horizontal 2x expansion.
!
! Input:
!       R30/R31 = source byte count (24 or 32)
!       R32/R33 = absolute source pointer
! Output:
!       TJSBUF contains 2*count bytes.
!
! Each nibble is expanded through DUP4, where every source bit becomes
! two adjacent output bits.  High nibble is emitted before low nibble.
! ------------------------------------------------------------

TJEXP2  BIN
        LDM R34,=TJSBUF
        ADMD R34,=BINTAB

TXLOOP  POBD R36,+R32
        JSB X14,T2BYTE
        DCM R30
        JNZ TXLOOP
        RTN

T2BYTE  LDB R20,R36
        LRB R20
        LRB R20
        LRB R20
        LRB R20
        CLM R46
        LDB R46,R20
        LDM R76,=DUP4
        ADMD R76,=BINTAB
        ADM R76,R46
        LDBD R22,R76
        PUBD R22,+R34

        LDB R20,R36
        LLB R20
        LLB R20
        LLB R20
        LLB R20
        LRB R20
        LRB R20
        LRB R20
        LRB R20
        CLM R46
        LDB R46,R20
        LDM R76,=DUP4
        ADMD R76,=BINTAB
        ADM R76,R46
        LDBD R22,R76
        PUBD R22,+R34
        RTN


! ------------------------------------------------------------
! TJEXP4 -- horizontal 4x expansion.
!
! Input is identical to TJEXP2.  QUAD4 maps each 4-bit nibble to
! two output bytes in which every source bit is repeated four times.
! Output is written to TJ4BUF (max 128 bytes).
! ------------------------------------------------------------

TJEXP4  BIN
        LDM R34,=TJ4BUF
        ADMD R34,=BINTAB

T4LOOP  POBD R36,+R32
        JSB X14,T4BYTE
        DCM R30
        JNZ T4LOOP
        RTN

T4BYTE  LDB R20,R36
        LRB R20
        LRB R20
        LRB R20
        LRB R20
        CLM R46
        LDB R46,R20
        LLB R46
        LDM R76,=QUAD4
        ADMD R76,=BINTAB
        ADM R76,R46
        POBD R22,+R76
        PUBD R22,+R34
        POBD R22,+R76
        PUBD R22,+R34

        LDB R20,R36
        LLB R20
        LLB R20
        LLB R20
        LLB R20
        LRB R20
        LRB R20
        LRB R20
        LRB R20
        CLM R46
        LDB R46,R20
        LLB R46
        LDM R76,=QUAD4
        ADMD R76,=BINTAB
        ADM R76,R46
        POBD R22,+R76
        PUBD R22,+R34
        POBD R22,+R76
        PUBD R22,+R34
        RTN


! ============================================================
! SII / EPSON DRIVER 2 -- v0.10i eight-row batched raster output
!
! Target hardware:
!       Seiko Instruments IFD501-01UK-E
!       CAPD345A 576-dot thermal mechanism
!
! Protocol per output block:
!       GS v 0 m xL xH 8 0 [eight raster rows]
!
! m=0 : native 203 x 203 dpi
! m=3 : printer-native double width + double height
!
! v0.10i keeps the stable v0.10h5 HP-IB/CR16 behaviour but reduces SII
! transaction overhead by batching eight adjacent raster rows into each
! self-contained GS v 0 command.
!
! Portrait:
!       24 commands x (8-byte header + 8*32-byte rows)
!       = 24 x 264-byte transactions
!
! Landscape:
!       32 commands x (8-byte header + 8*24-byte rows)
!       = 32 x 200-byte transactions
!
! No HP-IB simple-output transaction remains active while CRT memory is read.
! A dedicated 264-byte SIIPKT buffer holds the largest complete command.
! ============================================================

SIIDRV  BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSOVAL
        CMB R20,=0
        JNZ SIILGO

        JSB X14,SIIPOR
        JMP SIIFEED

SIILGO  JSB X14,SIILND

! Feed four lines after the completed image so the hardcopy clears the
! mechanism.  This remains identical in intent to the v0.10h5 path.

SIIFEED BIN
        LDMD R14,=BINTAB
        JSB X14,HPIB7
        LDM R30,=3D,0
        LDM R32,=SIIFD4
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN


! ------------------------------------------------------------
! SIIPOR -- portrait, 256 x 192 source raster, eight rows per command.
!
! zoom 1: m=0, x=32 bytes, y=8 dots -> 24 blocks
! zoom 2: m=3, x=32 bytes, y=8 dots -> 24 blocks, printer-side 2x scale
!
! Each block is built completely in SIIPKT before HPOUT begins:
!
!       8-byte GS v 0 header
!       8 x 32-byte CRT rows = 256 bytes
!       total = 264 decimal bytes
!
! 192 source rows divide exactly into 24 complete eight-row blocks.
! ------------------------------------------------------------

SIIPOR  BIN
        LDMD R14,=BINTAB

! Start at physical top CRT row.

        LDM R46,=0,20
        STMD R46,X14,PSRADR
        CLB R20
        STBD R20,X14,PSROW

! Begin a new eight-row packet and copy the appropriate header.

SIPBAT  BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSZVAL
        CMB R20,=1
        JZR SIPBH1

        LDM R46,=SIP2B8
        JMP SIPBHG

SIPBH1  LDM R46,=SIP1B8

SIPBHG  ADMD R46,=BINTAB
        JSB X14,SIIHDR

        BIN
        LDMD R14,=BINTAB
        LDB R20,=10
        STBD R20,X14,SIIBCT

! Capture one CRT row and append its 32 bytes to SIIPKT.

SIPRLP  BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PSRADR
        JSB X14,READROW

        BIN
        LDMD R14,=BINTAB
        LDM R30,=32D,0
        LDM R32,=ROWBUF
        ADMD R32,=BINTAB
        JSB X14,SIICPY

! Row 191 is the final source row.  The current packet is then necessarily
! complete because 192 is divisible by eight; send it and finish.

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSROW
        CMB R20,=277
        JZR SIPFIN

! Advance to the next physical CRT row.

        ICB R20
        STBD R20,X14,PSROW
        LDMD R46,X14,PSRADR
        ADM R46,=100,0
        STMD R46,X14,PSRADR

! Continue until eight rows have been appended.

        LDBD R20,X14,SIIBCT
        DCB R20
        STBD R20,X14,SIIBCT
        JNZ SIPRLP

! Send one complete 264-byte block, then build the next one.

        LDM R30,=8D,1
        JSB X14,SIISND
        JMP SIPBAT

SIPFIN  LDM R30,=8D,1
        JSB X14,SIISND
        RTN


! ------------------------------------------------------------
! SIILND -- 90-degree clockwise landscape, 192 x 256 result.
!
! TJLBD already produces exactly eight consecutive 24-byte rotated rows in
! TLBUF.  v0.10i therefore maps one transpose band directly to one SII block:
!
!       8-byte GS v 0 header
!       192-byte TLBUF payload
!       total = 200 decimal bytes
!
! 32 source-byte bands -> 32 printer transactions instead of 256.
! ------------------------------------------------------------

SIILND  BIN
        LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,PSLBND

SILLOP  JSB X14,TJLBD

! Copy the appropriate y=8 landscape header into SIIPKT.

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSZVAL
        CMB R20,=1
        JZR SILBH1

        LDM R46,=SIL2B8
        JMP SILBHG

SILBH1  LDM R46,=SIL1B8

SILBHG  ADMD R46,=BINTAB
        JSB X14,SIIHDR

! Append all eight rotated rows in one contiguous 192-byte copy.

        BIN
        LDMD R14,=BINTAB
        LDM R30,=192D,0
        LDM R32,=TLBUF
        ADMD R32,=BINTAB
        JSB X14,SIICPY

! Send the complete 200-byte block.

        LDM R30,=200D,0
        JSB X14,SIISND

! Advance source-byte band 0..31 (00..37 octal).

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PSLBND
        CMB R20,=37
        JZR SILDON

        ICB R20
        STBD R20,X14,PSLBND
        JMP SILLOP

SILDON  RTN


! ------------------------------------------------------------
! SIIHDR -- initialize SIIPKT with an 8-byte GS v 0 block header.
!
! Input:
!       R46/R47 = absolute pointer to 8-byte header
!
! Output:
!       SIIPKT[0..7] = header
!       SIIDST        = absolute pointer to SIIPKT+8
! ------------------------------------------------------------

SIIHDR  BIN
        LDMD R14,=BINTAB
        LDM R34,=SIIPKT
        ADMD R34,=BINTAB
        LDB R22,=10

SIHHLP  POBD R36,+R46
        PUBD R36,+R34
        DCB R22
        JNZ SIHHLP

        BIN
        LDMD R14,=BINTAB
        STMD R34,X14,SIIDST
        RTN


! ------------------------------------------------------------
! SIICPY -- append a source block to the current SII packet.
!
! Input:
!       R30/R31 = byte count, non-zero
!       R32/R33 = absolute source pointer
!
! SIIDST is advanced by the copied byte count.
! ------------------------------------------------------------

SIICPY  BIN
        LDMD R14,=BINTAB
        LDMD R34,X14,SIIDST

SICPLP  POBD R36,+R32
        PUBD R36,+R34
        DCM R30
        JNZ SICPLP

        BIN
        LDMD R14,=BINTAB
        STMD R34,X14,SIIDST
        RTN


! ------------------------------------------------------------
! SIISND -- transmit the complete packet currently in SIIPKT.
!
! Input:
!       R30/R31 = total packet length (264 portrait, 200 landscape)
!
! HPOUT remains the proven self-contained simple-output transaction.  The
! selected HP-IB translator is reconstructed dynamically by HPIB7/PSCODE.
! ------------------------------------------------------------

SIISND  BIN
        LDMD R14,=BINTAB
        LDM R56,R30
        JSB X14,HPIB7

        BIN
        LDMD R14,=BINTAB
        LDM R30,R56
        LDM R32,=SIIPKT
        ADMD R32,=BINTAB
        JSB X14,HPOUT
        RTN


! ============================================================
! PREST -- restore caller's CRT byte pointer after hardcopy reads.
! ============================================================

PREST   BIN
        LDMD R14,=BINTAB
        LDMD R34,X14,SAVCRT
        JSB =BYTCR!
        JSB =CHKSTS
        BIN
        RTN


! ============================================================
! READROW
!
! Read the complete 256-pixel physical scanline:
!
!       32 sequential CRT bytes -> ROWBUF
!
!
! Input:
!
!       R46/R47 = physical CRT row-base nibble address
!
!
! BREAD-style strategy:
!
!       BYTCR! once
!
!       CRTFLG = 0:  repeated INCHR
!       CRTFLG = 1:  repeated INCHR-
!
! Both routines return the CRT byte in R32 and advance CRTBAD.
! The mode decision is made once per scanline, not once per byte.
! ============================================================

READROW BIN


! ------------------------------------------------------------
! Position at first byte of physical scanline.
! ------------------------------------------------------------

        LDB R34,R46
        LDB R35,R47

        JSB =BYTCR!


! ------------------------------------------------------------
! R34/R35 can now be reused as the RAM destination pointer.
! Hardware CRTBAD retains the row address.
! ------------------------------------------------------------

        BIN

        LDM R34,=ROWBUF

        ADMD R34,=BINTAB


! ------------------------------------------------------------
! 32 decimal bytes = 40 octal.
! ------------------------------------------------------------

        LDB R22,=40


! ------------------------------------------------------------
! Select the read loop once for this scanline.
! ------------------------------------------------------------

        LDMD R14,=BINTAB

        LDBD R20,X14,CRTFLG

        CMB R20,=0

        JZR RRNORM


! ------------------------------------------------------------
! FAST LOOP - CRT is wiped out.
! ------------------------------------------------------------

RRFST   JSB =INCHR-

        PUBD R32,+R34

        DCB R22

        JNZ RRFST

        RTN


! ------------------------------------------------------------
! NORMAL LOOP - CRT is active.
! ------------------------------------------------------------

RRNORM  JSB =INCHR

        PUBD R32,+R34

        DCB R22

        JNZ RRNORM

        RTN


! ============================================================
! ============================================================
! LOCAL DATA
! ============================================================

HMSG    ASC "PRINTER85 V0.01A"

! Raw text / keyboard paper-control bytes.
! All byte constants are octal.
HCLF    BYT 12                  ! ASCII LF = 0Ah
HCFF    BYT 14                  ! ASCII FF = 0Ch (ThinkJet page advance)
SIIPG   BYT 33,144,102          ! ESC d 66 decimal (0102 octal)

! SII IFD501 eight-row raster headers.  All byte constants are octal.
!
! GS v 0 m xL xH yL yH, with y=8 (010 octal) for each batched command.
! Portrait x=32 bytes (040 octal); landscape x=24 bytes (030 octal).
! m=0 native size, m=3 double width + double height.
SIP1B8  BYT 35,166,60,0,40,0,10,0
SIP2B8  BYT 35,166,60,3,40,0,10,0
SIL1B8  BYT 35,166,60,0,30,0,10,0
SIL2B8  BYT 35,166,60,3,30,0,10,0

! ESC d 4 -- feed four lines after raster output.
SIIFD4  BYT 33,144,4

! ThinkJet 2225A protocol bytes.  ESC*r192S selects the 192 x 96 dpi
! high-density graphics grid (maximum 1280 dots per raster row).
! Decimal ESC=27 is octal 033.
TJ192S  BYT 33
        ASC "*r192S"
TJSTAR  BYT 33
        ASC "*rA"
TJ32W   BYT 33
        ASC "*b32W"
TJ64W   BYT 33
        ASC "*b64W"
TJ128W  BYT 33
        ASC "*b128W"
TJ24W   BYT 33
        ASC "*b24W"
TJ48W   BYT 33
        ASC "*b48W"
TJ96W   BYT 33
        ASC "*b96W"
TJEND   BYT 33
        ASC "*rB"

! 4-bit -> 8-bit 2x pixel-doubling lookup.
DUP4    BYT 0,3,14,17,60,63,74,77
        BYT 300,303,314,317,360,363,374,377

! 4-bit -> 16-bit 4x pixel-doubling lookup, stored in print order
! (high output byte first).
QUAD4   BYT 0,0,0,17,0,360,0,377
        BYT 17,0,17,17,17,360,17,377
        BYT 360,0,360,17,360,360,360,377
        BYT 377,0,377,17,377,360,377,377
! ------------------------------------------------------------
! v0.11d inherited keyboard hardcopy / CHIDLE state
! ------------------------------------------------------------

PKMODE  BSZ 10          ! PRTKEYS BASIC mode parameter as HP REAL
KHACT   BSZ 1           ! 1 iff PRINTER85 installed the current CHIDLE stub
KSHIFT  BSZ 1           ! sampled KEYSTS bit 3 for PAPER vs SHIFT+PAPER
KHSAVE  BSZ 7           ! exact previous seven-byte CHIDLE image

! Independent keyboard printer profile set by PRTSET.
HCVLD   BSZ 1           ! 1 iff PRTSET contains a valid profile
HCCODE  BSZ 1           ! HP-IB select code 3..10
HCADDR  BSZ 1           ! HP-IB primary address 0..30
HCDRIV  BSZ 1           ! 1 ThinkJet, 2 SII
HCZOOM  BSZ 1           ! graphics COPY zoom
HCORI   BSZ 1           ! graphics COPY orientation

! Alpha COPY state.
TXTADR  BSZ 2           ! current alpha-row nibble address
TXTROWS BSZ 1           ! visible rows remaining
TXTBUF  BSZ 42          ! 34 decimal bytes = 32 chars + CR + LF


! ------------------------------------------------------------
! PRTSCREEN / HP-IB transport state
! ------------------------------------------------------------

PSDEV   BSZ 10          ! requested BASIC device selector as REAL
PSDRV   BSZ 10          ! requested driver as REAL
PSZOOM  BSZ 10          ! optional zoom REAL
PSORI   BSZ 10          ! optional orientation REAL
PSCODE  BSZ 1           ! decoded HP-IB select code 3..10
PSADDR  BSZ 1           ! decoded HP-IB primary address 0..30
PSDRIV  BSZ 1           ! validated driver number
PSZVAL  BSZ 1           ! validated zoom 1, 2 or 4
PSOVAL  BSZ 1           ! validated orientation 0 or 1
PSAUTO  BSZ 1           ! 1 iff SII PRTSCREEN itself called CRTPOF
PSRADR  BSZ 2           ! portrait current physical CRT row address
PSROW   BSZ 1           ! portrait current physical raster row 0..191

! Landscape conversion state.
PSLBND  BSZ 1           ! source byte-column band 0..31
PSLCNT  BSZ 1           ! remaining source rows in current band
PSLMSK  BSZ 1           ! destination bit mask within current output byte
PSLSRC  BSZ 2           ! current source CRT byte nibble address
PSLDP   BSZ 2           ! row-0 pointer to current destination byte
PSLOUT  BSZ 2           ! current rotated row pointer while transmitting
PSLRNO  BSZ 1           ! rotated row number within current 8-row band

! Rotation and horizontal-expansion buffers.
! TLBUF  = 8 rows x 24 bytes = 192 bytes = 0300 octal.
! TJSBUF = max 64 bytes for 2x expansion = 0100 octal.
! TJ4BUF = max 128 bytes for 4x expansion = 0200 octal.
TLBUF   BSZ 300
TJSBUF  BSZ 100
TJ4BUF  BSZ 200

! SII v0.10i batched-raster workspace.
! SIIPKT = 0410 octal = 264 decimal bytes, enough for the largest packet:
!          8-byte header + 8 x 32-byte portrait rows.
! SIIDST = current absolute append pointer; SIIBCT = portrait rows left in batch.
SIIDST  BSZ 2
SIIBCT  BSZ 1
SIIPKT  BSZ 410

! Saved caller CRT byte address for hardcopy operations.
SAVCRT  BSZ 2

! Private CRT read mode used by alpha/graphics hardcopy row readers.
CRTFLG  BSZ 1

! Private 32-byte graphics scanline buffer (040 octal bytes).
ROWBUF  BSZ 40

! ============================================================
! HP-85 SYSTEM SYMBOLS -- all addresses OCTAL
! ============================================================

BINTAB  DAD 101233
ROMFL   DAD 101231
CHIDLE  DAD 102416
KEYHIT  DAD 100671
KEYSTS  DAD 177402
EOJ2    DAD 34772

CRTBYT  DAD 100176
CRTRAM  DAD 100200
CRTWRS  DAD 101016
TOS     DAD 101132

SCAN    DAD 11262
NUMVP   DAD 12407
NUMVAL  DAD 12412
GETCM   DAD 13414
ERRORP  DAD 6611

ONER    DAD 56215
CONINT  DAD 44321

BYTCR!  DAD 35422
CHKSTS  DAD 36335
INCHR   DAD 35244
INCHR-  DAD 35220
CRTPOF  DAD 35703
CRTPUP  DAD 35716

OUTSTR  DAD 35052

        FIN
