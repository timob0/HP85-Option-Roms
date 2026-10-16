! ============================================================
! PRINTER85 v0.03a RC1a -- HP-85 OPTION ROM
!
! RC1a assembler-only fix: CAPASM source is octal by default, so the five
! literal decimal-8 LPI comparisons/loads now use 8D explicitly.
! No runtime behavior has otherwise been changed from RC1.
!
! Baseline Option-ROM build derived from the hardware-verified PRINTER85
! v0.01a standalone LOADBIN implementation and the v0.02a Option-ROM port.
!
! v0.02b fixes two Option-ROM-specific issues established by hardware tests:
!
!   1. COPY/PAPER handled-key exit:
!      KHOOK returns normally through ROMJSB and a RAM trampoline performs
!      the documented R6 handled-key exit only after ROMJSB has unwound.
!
!   2. SII graphics hardcopy:
!      Use CRTWPO/CRTUNW for fast CRT reads without powering the CRT down.
!      Caller wipeout state is preserved; PRINTER85 unwipes only if it wiped.
!      Both routines are documented ROMJSB=N and are safe direct calls from
!      an external ROM.
!
! The v0.02d RC3 SII page-mode reliability sequence is retained unchanged:
! ESC S -> wait -> ESC J 0 -> wait -> ESC L -> wait -> page setup/raster -> FF.
! The proven CRTWPO/CRTUNW and RAM-trampoline architecture is also retained.
!
! ThinkJet support in PRINTER85 deliberately assumes HP control-sequence mode
! (switch 5 DOWN).  Alternate/Epson-emulation mode is outside project scope.
!
! Existing raster formatting and hardcopy behavior are otherwise unchanged.
!
! ROM number: 0241 octal
! ROM base:   060000 octal
! ROM complement byte: 0136 octal (0241 + 0136 = 0377)
!
! Public keywords:
!
!       PVER
!       PRTSCREEN device,driver[,zoom[,orientation]]
!       PRTSET    device,driver[,zoom[,orientation]]
!       PRTKEYS   mode
!       PRTPITCH  pitch
!       PRTLPI    lines_per_inch
!       PRTBOLD   mode
!       PRTUNDER  mode
!       PRTNORM
!       PRTZOOM   zoom
!       PRTORIENT orientation
!
! v0.03a RC1 adds the first common text/control utility layer for both
! ThinkJet and SII printers, plus a native HP-85 K1..K8 control panel:
!
!       K1 pitch        K5 line spacing
!       K2 bold         K6 underline
!       K3 COPY zoom    K7 COPY orientation
!       K4 previous     K8 next page
!
! RC1 contains only the COMMON key page; K4/K8 deliberately remain on it.
! KEY LABEL buffers are saved/restored by PRTKEYS 1/0.  Labels are rendered
! as seven visible characters plus one separating blank per 8-byte slot.
!
! Driver 1 = HP ThinkJet 2225A
! Driver 2 = SII IFD501 / CAPD345A
!
! ROM/RAM architecture:
!   - all executable code and immutable tables live in ROM 0241;
!   - 01600 octal (896 decimal) bytes are permanently reserved at power-on;
!   - BAS241 (102554 octal) holds the base address of that writable workspace;
!   - all former LOADBIN BSZ state/buffers are offsets in that RAM workspace;
!   - CHIDLE is still opt-in via PRTKEYS 1;
!   - a RAM trampoline lets ROMJSB unwind before the handled-key R6 exit is
!     performed.  CHIDLE contains JSB <RAM trampoline> / RTN.
!   - the RAM trampoline calls ROMJSB -> KHOOK in ROM 241, then performs the
!     proven handled-key pop only after ROMJSB has completely returned.
!
! Important: PRTKEYS is NOT installed automatically at power-on or RESET.
! ============================================================

        ABS ROM 60000
        BYT 241                 ! ROM number -- first byte
        BYT 136                 ! complement -- second byte
        DEF RUNTIM
        DEF P8ASCI
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
        DEF PKEYSP      ! PRTPITCH numeric expression
        DEF PKEYSP      ! PRTLPI numeric expression
        DEF PKEYSP      ! PRTBOLD numeric expression
        DEF PKEYSP      ! PRTUNDER numeric expression
        DEF PVERP       ! PRTNORM -- no arguments
        DEF PKEYSP      ! PRTZOOM numeric expression
        DEF PKEYSP      ! PRTORIENT numeric expression

RUNTIM  BYT 0,0
        DEF PVER.
        DEF PRNSCR.
        DEF PSET.
        DEF PKEYS.
        DEF PTCH.
        DEF LPI.
        DEF BOLD.
        DEF UND.
        DEF NORM.
        DEF ZOOM.
        DEF ORI.
        BYT 377,377

P8ASCI  ASP "PVER"
        ASP "PRTSCREEN"
        ASP "PRTSET"
        ASP "PRTKEYS"
        ASP "PRTPITCH"
        ASP "PRTLPI"
        ASP "PRTBOLD"
        ASP "PRTUNDER"
        ASP "PRTNORM"
        ASP "PRTZOOM"
        ASP "PRTORIENT"

ERMSG   BYT 377

! ============================================================
! INIT -- OPTION-ROM workspace lifecycle
!
! ROMFL=0 (power-on): reserve permanent writable RAM, publish its base in
! BAS241, call SCRAT+ as documented by HP, then clear the entire workspace.
!
! ROMFL=1 (RESET): SYSIN+ resets CHIDLE to RTN.  Preserve the stored printer
! profile but clear KHACT so a later PRTKEYS 1 can install the hook again.
!
! Other ROMINI reasons do not change PRINTER85 state.  In particular, LOAD,
! SCRATCH, STOP and PAUSE do not remove an Option ROM or its private RAM.
! ============================================================

INIT    BIN
        LDBD R34,=ROMFL
        CMB R34,=0
        JZR INIPWR

        CMB R34,=1
        JZR INIRST

        RTN


! Power-on.  HP's INIT contract requires us to decide the ROMFL reason before
! using registers below R34.  Having established ROMFL=0, R20+ are available.
!
! RAMSIZ = 01600 octal = 896 decimal bytes.
! Two-byte immediate 003/200 is encoded low byte first as =200,3.

INIPWR  LDMD R34,=FWUSER
        STMD R34,=BAS241

        ADM R34,=200,3
        STMD R34,=FWUSER

        JSB =ROMJSB
        DEF SCRAT+
        BYT 0

! Clear all private RAM so profile/hook flags and scratch state begin known.

        LDMD R34,=BAS241
        LDM R36,=200,3
        CLB R20

INICLR  PUBD R20,+R34
        DCM R36
        JNZ INICLR

! Cleared state encodes normal pitch/bold/underline/page 0 naturally.
! Line spacing is stored as its public value, so establish the 6-LPI default.

        LDMD R34,=BAS241
        LDB R20,=6
        STBD R20,X34,STLPI

        RTN


! RESET.  System initialization rewrites CHIDLE to RTN; reflect that fact in
! our private ownership flag.  PRTSET profile bytes deliberately survive RESET.

INIRST  LDMD R36,=BAS241
        TSM R36
        JZR INIRTN             ! ROM hot-added without prior power-on: do not write RAM

! If PRTKEYS owned the key-label buffers before RESET, restore the exact
! definitions that were present before PRTKEYS 1.  Do not force a CRT redraw
! from INIT; normal system reset/display initialization remains in control.

        LDBD R20,X36,KLGV
        CMB R20,=0
        JZR INRCLR

        LDM R34,=KLSAVE
        ADM R34,R36
        LDM R46,=LEG1
        LDB R20,=100           ! 0100 octal = 64 bytes

INRLLP  POBD R22,+R34
        PUBD R22,+R46
        DCB R20
        JNZ INRLLP

INRCLR  CLB R20
        STBD R20,X36,KHACT
        STBD R20,X36,KLGV
        STBD R20,X36,KPAGE

INIRTN  RTN


! ============================================================
! PVER PARSER -- external ROM
! ============================================================

PVERP   LDM R46,=370,241       ! external-ROM token + ROM number
        PUMD R46,+R12
        PUBD R43,+R12          ! keyword token

        JSB =ROMJSB
        DEF SCAN
        BYT 0

        GTO ROMRTN             ! parse routines must return with ROM 0 selected


! ============================================================
! PRTKEYS PARSER
!
!       PRTKEYS mode
! ============================================================

PKEYSP  PUBD R43,+R6

        JSB =ROMJSB
        DEF NUMVP
        BYT 0
        JEN PKPOK
        JMP PKPERR

PKPOK   POBD R47,-R6

        LDB R46,=241           ! ROM number
        LDB R45,=370           ! external-ROM system token
        PUMD R45,+R12          ! pushes 370,241,keyword-token

        GTO ROMRTN

PKPERR  POBD R47,-R6
        JSB =ERRORP
        BYT 81D


! ============================================================
! PRTSCREEN / PRTSET PARSER
!
!       PRTSCREEN device,driver[,zoom[,orientation]]
!
! First two numeric expressions required; third/fourth optional.
! Parser helpers are called through ROMJSB/ROM 0 as required for external ROMs.
! ============================================================

PRNSCP  PUBD R43,+R6

        JSB =ROMJSB
        DEF NUMVP
        BYT 0
        JEN PN1OK
        JMP PNERR

PN1OK   JSB =ROMJSB
        DEF GETCM
        BYT 0

        JSB =ROMJSB
        DEF NUMVAL
        BYT 0
        JEZ PNERR

! Optional zoom?  054 octal is comma.

        CMB R14,=54
        JNZ PNDONE

        JSB =ROMJSB
        DEF NUMVP
        BYT 0
        JEZ PNERR

! Optional orientation?

        CMB R14,=54
        JNZ PNDONE

        JSB =ROMJSB
        DEF NUMVP
        BYT 0
        JEZ PNERR

PNDONE  POBD R47,-R6

        LDB R46,=241
        LDB R45,=370
        PUMD R45,+R12

        GTO ROMRTN

PNERR   POBD R47,-R6
        JSB =ERRORP
        BYT 81D


! ============================================================
! PVER RUNTIME
! ============================================================

        BYT 241

PVER.   LDM R26,=HMSG

        LDM R36,=19D,0

        JSB =OUTSTR

        RTN

! ============================================================
! PRTKEYS RUNTIME -- keyboard takeover and native key-label panel
!
!       PRTKEYS 1    install PRINTER85 COPY/PAPER/K1..K8 CHIDLE hook
!       PRTKEYS 0    restore saved CHIDLE bytes and native key labels
!
! PRTKEYS does not choose a printer.  Configure the independent keyboard
! hardcopy profile first with PRTSET.  If no valid PRTSET profile exists,
! COPY/PAPER and the six setting keys are consumed but do not change/send a
! printer setting; K4/K8 remain panel navigation controls.
!
! Keys outside COPY/PAPER/K1..K8 remain under normal HP-85 handling.
! ============================================================

        BYT 241

PKEYS.  SAD
        BIN
        LDMD R14,=BAS241

        JSB =ONER
        BIN
        STMD R#,X14,PKMODE

        LDMD R60,X14,PKMODE
        JSB =CONINT
        BIN
        LDMD R14,=BAS241

! Require an unsigned one-byte value and accept only 0 or 1.

        LDB R20,R77
        JNZ PKBAD

        CMB R76,=0
        JZR PK0ST

        CMB R76,=1
        JZR PKON

PKBAD   JSB =ERRORP
        BYT 89D

! Keep the 0-branch target close to the numeric dispatcher.  PKOFF grew when
! native legend save/restore was added, so an absolute local call avoids the
! CAPASM relative-branch range limit.

PK0ST   JSB =PKOFF
        RTN


! PRTKEYS 1 is idempotent.  If PRINTER85 already owns CHIDLE, return without
! touching the installed hook.

PKON    LDBD R20,X14,KHACT
        CMB R20,=0
        JZR PKNEW

! Already active: treat PRTKEYS 1 as a harmless panel refresh.

        JSB =KREFR
        BIN
        PAD
        RTN

PKNEW   BIN

! Refuse to mask a foreign CHIDLE user.  The documented idle state begins
! with RTN (0236 octal).  We do not chain hooks in this first Option-ROM build.

        LDBD R20,=CHIDLE
        CMB R20,=236
        JNZ PKBAD

! Save all seven general-hook bytes, not merely the four bytes used by our
! JSB/RTN stub, so PRTKEYS 0 can restore the exact prior image.

        LDM R34,=CHIDLE
        LDM R36,=KHSAVE
        ADMD R36,=BAS241
        LDB R20,=7

PKSVLP  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ PKSVLP

! Save the exact 64 bytes of the current K1..K8 label definitions before
! installing the PRINTER85 panel.  LEG1..LEG8 span LEGEND/LEGEN2 contiguously.

        LDM R34,=LEG1
        LDM R36,=KLSAVE
        ADMD R36,=BAS241
        LDB R20,=100           ! 0100 octal = 64 bytes

PKLSSV  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ PKLSSV

        LDMD R14,=BAS241
        LDB R20,=1
        STBD R20,X14,KLGV
        CLB R20
        STBD R20,X14,KPAGE

! Build the executable RAM trampoline first.  The trampoline is copied from
! the relocatable ROM template KRTPL into the private workspace.  All
! branches inside the template are relative; its only absolute calls/references
! are system addresses and the fixed KHOOK ROM entry.

        LDM R34,=KRTPL
        LDM R36,=KTRAMP
        ADMD R36,=BAS241
        LDB R20,=32            ! 032 octal bytes = exact trampoline length

PKINLP  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ PKINLP

! Install the same four-byte direct-RAM general-hook form that was physically
! proven in the old LOADBIN build:
!
!       JSB <BAS241+KTRAMP>
!       RTN
!
! The remaining three CHIDLE bytes are left untouched and are restored from
! KHSAVE by PRTKEYS 0.

        LDMD R14,=BAS241
        LDM R46,=KTRAMP
        ADM R46,R14
        STM R46,R45
        LDB R47,=236           ! RTN
        LDB R44,=316           ! JSB absolute
        STMD R44,=CHIDLE

        CLB R20
        STBD R20,X14,KHAND
        LDB R20,=1
        STBD R20,X14,KHACT

! Install/update the COMMON key-label page and show it immediately in alpha
! mode.  In graphics mode KREFR updates only the legend buffers.

        JSB =KREFR
        BIN
        PAD
        RTN


! PRTKEYS 0: restore the saved seven bytes only when PRINTER85 installed them.

PKOFF   LDBD R20,X14,KHACT
        CMB R20,=0
        JNZ PKOACT

        BIN
        PAD
        RTN

PKOACT  BIN

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

! Restore the exact key-label definitions saved by PRTKEYS 1.  If alpha mode
! is visible, redraw them immediately so the PRINTER85 panel disappears.
! In graphics mode only the buffers are restored; native KEY LABEL later
! displays the recovered definitions.

        LDBD R20,X14,KLGV
        CMB R20,=0
        JNZ PKOLAB

        BIN
        PAD
        RTN

PKOLAB  BIN

        LDM R34,=KLSAVE
        ADM R34,R14
        LDM R36,=LEG1
        LDB R20,=100

PKLSRS  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ PKLSRS

        BIN
        LDMD R14,=BAS241
        CLB R20
        STBD R20,X14,KLGV
        STBD R20,X14,KPAGE

        JSB =KREDR

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
        LDMD R14,=BAS241

        JSB =PSARGS

        BIN
        LDMD R14,=BAS241

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

! If the PRINTER85 control panel is active, reflect the new COPY zoom and
! orientation immediately in its native HP-85 key labels.

        JSB =KREFR

        PAD
        RTN



! ============================================================
! COMMON TEXT / COPY PROFILE UTILITIES -- v0.03a RC1
!
! All numeric commands accept full BASIC numeric expressions because they
! reuse the same NUMVP parser as PRTKEYS.  The runtime converts the evaluated
! REAL to a 16-bit integer before validating the public value.
!
!       PRTPITCH  0..3
!           0 normal             ThinkJet 12.0 cpi
!           1 expanded           ThinkJet  6.0 cpi
!           2 compressed         ThinkJet 21.3 cpi
!           3 expanded-compr.    ThinkJet 10.7 cpi
!
!       PRTLPI    6 | 8
!       PRTBOLD   0 | 1
!       PRTUNDER  0 | 1
!       PRTNORM               normal pitch, 6 LPI, bold/underline off
!       PRTZOOM   1 | 2 | 4  (4 only for ThinkJet)
!       PRTORIENT 0 | 1      (portrait / clockwise landscape)
!
! Text-style commands require a valid PRTSET profile because they immediately
! send the corresponding control sequence to that configured printer.
! PRTZOOM/PRTORIENT change only the stored COPY profile.
! ============================================================


! ------------------------------------------------------------
! GTINT -- pop one BASIC REAL argument and convert to binary integer.
!
! Output:
!       R76/R77 = converted 16-bit binary integer
!       R14     = BAS241 on return
! ------------------------------------------------------------

GTINT   BIN
        LDMD R14,=BAS241

        JSB =ONER
        BIN
        STMD R#,X14,PKMODE

        LDMD R60,X14,PKMODE
        JSB =CONINT
        BIN
        LDMD R14,=BAS241
        RTN


! ------------------------------------------------------------
! CKDEV -- require a valid PRTSET target for a printer-setting command.
! ------------------------------------------------------------

CKDEV   LDBD R20,X14,HCVLD
        CMB R20,=0
        JNZ CKDOK

        JSB =ERRORP
        BYT 89D

CKDOK   RTN


! ------------------------------------------------------------
! TXBEG / TXEND -- open/close one short text-control transaction.
! ------------------------------------------------------------

TXBEG   JSB =HCLOAD
        JSB =HCOPEN
        RTN

TXEND   JSB =HCCLOSE
        JSB =KREFR
        RTN


! ------------------------------------------------------------
! PRTPITCH pitch
! ------------------------------------------------------------

        BYT 241

PTCH.   SAD
        BIN
        JSB =GTINT

        LDB R20,R77
        JNZ PTCBAD

        CMB R76,=0
        JZR PTCOK
        CMB R76,=1
        JZR PTCOK
        CMB R76,=2
        JZR PTCOK
        CMB R76,=3
        JNZ PTCBAD

PTCOK   JSB =CKDEV
        STBD R76,X14,STPIT

        JSB =TXBEG
        JSB =SETPIT
        JSB =TXEND

        PAD
        RTN

PTCBAD  JSB =ERRORP
        BYT 89D


! ------------------------------------------------------------
! PRTLPI lines_per_inch
! ------------------------------------------------------------

        BYT 241

LPI.    SAD
        BIN
        JSB =GTINT

        LDB R20,R77
        JNZ LPIBAD

        CMB R76,=6
        JZR LPIOK
        CMB R76,=8D
        JNZ LPIBAD

LPIOK   JSB =CKDEV
        STBD R76,X14,STLPI

        JSB =TXBEG
        JSB =SETLPI
        JSB =TXEND

        PAD
        RTN

LPIBAD  JSB =ERRORP
        BYT 89D


! ------------------------------------------------------------
! PRTBOLD mode
!
! ThinkJet HP mode uses ESC(s1B / ESC(s0B.  On later firmware this is the
! same state documented as Quality Mode.  SII maps to ESC E 1 / ESC E 0.
! ------------------------------------------------------------

        BYT 241

BOLD.   SAD
        BIN
        JSB =GTINT

        LDB R20,R77
        JNZ BLDBAD
        CMB R76,=0
        JZR BLDOK
        CMB R76,=1
        JNZ BLDBAD

BLDOK   JSB =CKDEV
        STBD R76,X14,STBOLD

        JSB =TXBEG
        JSB =SETBLD
        JSB =TXEND

        PAD
        RTN

BLDBAD  JSB =ERRORP
        BYT 89D


! ------------------------------------------------------------
! PRTUNDER mode
! ------------------------------------------------------------

        BYT 241

UND.    SAD
        BIN
        JSB =GTINT

        LDB R20,R77
        JNZ UNDBAD
        CMB R76,=0
        JZR UNDOK
        CMB R76,=1
        JNZ UNDBAD

UNDOK   JSB =CKDEV
        STBD R76,X14,STUND

        JSB =TXBEG
        JSB =SETUND
        JSB =TXEND

        PAD
        RTN

UNDBAD  JSB =ERRORP
        BYT 89D


! ------------------------------------------------------------
! PRTNORM
!
! Restore only PRINTER85's common text attributes.  COPY zoom/orientation and
! printer selection are deliberately unchanged; no full printer reset occurs.
! ------------------------------------------------------------

        BYT 241

NORM.   BIN
        LDMD R14,=BAS241
        JSB =CKDEV

        CLB R20
        STBD R20,X14,STPIT
        STBD R20,X14,STBOLD
        STBD R20,X14,STUND
        LDB R20,=6
        STBD R20,X14,STLPI

        JSB =TXBEG
        JSB =SETALL
        JSB =TXEND
        RTN


! ------------------------------------------------------------
! PRTZOOM zoom
! ------------------------------------------------------------

        BYT 241

ZOOM.   SAD
        BIN
        JSB =GTINT

        LDB R20,R77
        JNZ ZOOBAD

        JSB =CKDEV

        CMB R76,=1
        JZR ZOOOK
        CMB R76,=2
        JZR ZOOOK
        CMB R76,=4
        JNZ ZOOBAD

! 4x COPY is available only on the ThinkJet driver.

        LDBD R20,X14,HCDRIV
        CMB R20,=1
        JNZ ZOOBAD

ZOOOK   STBD R76,X14,HCZOOM
        JSB =KREFR

        PAD
        RTN

ZOOBAD  JSB =ERRORP
        BYT 89D


! ------------------------------------------------------------
! PRTORIENT orientation
! ------------------------------------------------------------

        BYT 241

ORI.    SAD
        BIN
        JSB =GTINT

        LDB R20,R77
        JNZ ORIBAD

        JSB =CKDEV

        CMB R76,=0
        JZR ORIOK
        CMB R76,=1
        JNZ ORIBAD

ORIOK   STBD R76,X14,HCORI
        JSB =KREFR

        PAD
        RTN

ORIBAD  JSB =ERRORP
        BYT 89D


! ------------------------------------------------------------
! KRTPL -- RAM-trampoline template (copied to BAS241+KTRAMP).
!
! IMPORTANT: the handled-key R6 manipulation occurs here, in RAM, only after
! ROMJSB has returned and removed its own ROM-switching frame.  At that point
! the stack layout is again the same as the physically-proven LOADBIN hook.
!
! KHAND=0: unrelated key -> normal return through CHIDLE, native handling runs.
! KHAND=1: COPY/PAPER/K1..K8 -> discard the two documented hook returns after
!                               ROMJSB unwinds, suppressing native handling.
! ------------------------------------------------------------

KRTPL   JSB =ROMJSB
        DEF KHOOK
        BYT 241
        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,KHAND
        CMB R20,=0
        JZR KRTRTN

        POMD R44,-R6
        CLE
        RTN

KRTRTN  RTN


! ------------------------------------------------------------
! KHOOK -- ROM-resident COPY/PAPER/K1..K8 handler.
!
! COPY          = 0211 octal
! PAPER ADVANCE = 0212 octal
! K1..K8        = 0200..0207 octal
!
! Other keys immediately RTN to normal HP-85 handling.
! ------------------------------------------------------------

KHOOK   BIN
        LDMD R14,=BAS241
        CLB R20
        STBD R20,X14,KHAND
        LDBD R22,=KEYHIT

        CMB R22,=211
        JZR KHCST

        CMB R22,=212
        JZR KHPST

! K1..K8 are 0200..0207 octal.  Keep the conditional targets close to the
! dispatcher and use absolute local JSB calls so growth in the handlers cannot
! create CAPASM relative-branch range problems.

        CMB R22,=200
        JZR KHK1
        CMB R22,=201
        JZR KHK2
        CMB R22,=202
        JZR KHK3
        CMB R22,=203
        JZR KHK4
        CMB R22,=204
        JZR KHK5
        CMB R22,=205
        JZR KHK6
        CMB R22,=206
        JZR KHK7
        CMB R22,=207
        JZR KHK8

KHRET   RTN

KHCST   JSB =KHCAP
        RTN
KHPST   JSB =KHPAP
        RTN
KHK1    JSB =KF1
        RTN
KHK2    JSB =KF2
        RTN
KHK3    JSB =KF3
        RTN
KHK4    JSB =KF4
        RTN
KHK5    JSB =KF5
        RTN
KHK6    JSB =KF6
        RTN
KHK7    JSB =KF7
        RTN
KHK8    JSB =KF8
        RTN


! ------------------------------------------------------------
! COPY
! ------------------------------------------------------------

KHCAP   BIN

! Mark the key handled before starting potentially long printer I/O.

        LDB R20,=1
        STBD R20,X14,KHAND
        CLE
        JSB =EOJ2

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KHCREL

        JSB =HCLOAD

! CRTWRS bit 7: 0=alpha, 1=graphics.

        LDBD R37,=CRTWRS
        ANM R37,=200
        CMB R37,=0
        JZR KHCTXT

! Graphics COPY uses the existing v0.10j PRTSCREEN execution path with the
! validated PRTSET profile already copied to PS* state.

        JSB =KGRAPH
        JMP KHCREL

KHCTXT  JSB =TXTCOPY

KHCREL  JSB =KHREL

! Return normally through ROMJSB.  The RAM trampoline performs the handled-key
! stack exit only after ROMJSB has completely unwound.

        CLE
        RTN


! ------------------------------------------------------------
! PAPER ADVANCE
! ------------------------------------------------------------

KHPAP   BIN
        LDMD R14,=BAS241

! Preserve only the hardware-verified SHIFT discriminator needed after EOJ2.
! On the tested HP-85A, KEYSTS bit 3 (010 octal) is clear for PAPER ADVANCE
! and set for SHIFT+PAPER ADVANCE.

        LDBD R37,=KEYSTS
        ANM R37,=10
        STBD R37,X14,KSHIFT

        LDB R20,=1
        STBD R20,X14,KHAND
        CLE
        JSB =EOJ2

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KHPREL

        JSB =HCLOAD
        JSB =HCOPEN

! Dispatch from the single private bit sampled before EOJ2.

        LDMD R14,=BAS241
        LDBD R37,X14,KSHIFT
        CMB R37,=0
        JNZ KHPPAG

! Normal PAPER ADVANCE: send one LF immediately, then generate our own repeat
! while KEYSTS says the physical key is still held.

        JSB =HCLINE
        JSB =KFSLW
        CMB R22,=0
        JZR KHPCLS

KHPREP  JSB =HCLINE
        JSB =KFFST
        CMB R22,=0
        JNZ KHPREP
        JMP KHPCLS

! SHIFT+PAPER ADVANCE: one page-advance command only; no repeat.

KHPPAG  JSB =HCPAGE
        JSB =KHREL

KHPCLS  JSB =HCCLOSE
        JMP KPEOJ

KHPREL  JSB =KHREL

KPEOJ   CLE                    ! RAM trampoline suppresses native handler
        RTN



! ============================================================
! K1..K8 PRINTER CONTROL PANEL -- COMMON PAGE
!
! Physical HP-85 arrangement:
!
!       lower legend row: K1 K2 K3 K4
!       upper legend row: K5 K6 K7 K8  (SHIFT + K1..K4)
!
! RC1 implements only page 0 (COMMON).  K4/K8 are already reserved as
! previous/next page controls and simply remain on page 0 until driver-specific
! pages are added.
! ============================================================


! ------------------------------------------------------------
! KFBGN / KFEND -- common one-shot F-key entry/exit.
! ------------------------------------------------------------

KFBGN   BIN
        LDMD R14,=BAS241
        LDB R20,=1
        STBD R20,X14,KHAND
        CLE
        JSB =EOJ2

        BIN
        LDMD R14,=BAS241
        RTN

KFEND   JSB =KHREL
        CLE
        RTN


! ------------------------------------------------------------
! K1 -- cycle pitch.
! ThinkJet: 0->1->2->3->0.
! SII uses the same four public states through approximate pitch mappings.
! ------------------------------------------------------------

KF1     JSB =KFBGN

        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KF1X

        LDBD R20,X14,STPIT
        ICB R20
        CMB R20,=4
        JNZ KF1SV
        CLB R20

KF1SV   STBD R20,X14,STPIT

        JSB =HCLOAD
        JSB =HCOPEN
        JSB =SETPIT
        JSB =HCCLOSE
        JSB =KREFR

KF1X    JSB =KFEND
        RTN


! ------------------------------------------------------------
! K2 -- toggle bold / ThinkJet software Quality state.
! ------------------------------------------------------------

KF2     JSB =KFBGN

        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KF2X

        LDBD R20,X14,STBOLD
        CMB R20,=0
        JZR KF2ON
        CLB R20
        JMP KF2SV

KF2ON   LDB R20,=1

KF2SV   STBD R20,X14,STBOLD

        JSB =HCLOAD
        JSB =HCOPEN
        JSB =SETBLD
        JSB =HCCLOSE
        JSB =KREFR

KF2X    JSB =KFEND
        RTN


! ------------------------------------------------------------
! K3 -- cycle stored graphics COPY zoom.
!
! ThinkJet: 1 -> 2 -> 4 -> 1
! SII:      1 -> 2 -> 1
! ------------------------------------------------------------

KF3     JSB =KFBGN

        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KF3X

        LDBD R20,X14,HCZOOM
        CMB R20,=1
        JZR KF3Z2
        CMB R20,=2
        JZR KF3A

! Invalid/4x state falls back to 1 unless the ThinkJet branch below selected 4.

        LDB R20,=1
        JMP KF3SV

KF3A    LDBD R21,X14,HCDRIV
        CMB R21,=1
        JZR KF3Z4

        LDB R20,=1
        JMP KF3SV

KF3Z2   LDB R20,=2
        JMP KF3SV

KF3Z4   LDB R20,=4

KF3SV   STBD R20,X14,HCZOOM
        JSB =KREFR

KF3X    JSB =KFEND
        RTN


! ------------------------------------------------------------
! K4 -- previous page.  RC1 has only COMMON page 0.
! ------------------------------------------------------------

KF4     JSB =KFBGN
        CLB R20
        STBD R20,X14,KPAGE
        JSB =KREFR
        JSB =KFEND
        RTN


! ------------------------------------------------------------
! K5 -- toggle 6 / 8 LPI.
! ------------------------------------------------------------

KF5     JSB =KFBGN

        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KF5X

        LDBD R20,X14,STLPI
        CMB R20,=6
        JZR KF5E8
        LDB R20,=6
        JMP KF5SV

KF5E8   LDB R20,=8D

KF5SV   STBD R20,X14,STLPI

        JSB =HCLOAD
        JSB =HCOPEN
        JSB =SETLPI
        JSB =HCCLOSE
        JSB =KREFR

KF5X    JSB =KFEND
        RTN


! ------------------------------------------------------------
! K6 -- toggle underline.
! ------------------------------------------------------------

KF6     JSB =KFBGN

        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KF6X

        LDBD R20,X14,STUND
        CMB R20,=0
        JZR KF6ON
        CLB R20
        JMP KF6SV

KF6ON   LDB R20,=1

KF6SV   STBD R20,X14,STUND

        JSB =HCLOAD
        JSB =HCOPEN
        JSB =SETUND
        JSB =HCCLOSE
        JSB =KREFR

KF6X    JSB =KFEND
        RTN


! ------------------------------------------------------------
! K7 -- toggle stored graphics COPY orientation.
! ------------------------------------------------------------

KF7     JSB =KFBGN

        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KF7X

        LDBD R20,X14,HCORI
        CMB R20,=0
        JZR KF7L
        CLB R20
        JMP KF7SV

KF7L    LDB R20,=1

KF7SV   STBD R20,X14,HCORI
        JSB =KREFR

KF7X    JSB =KFEND
        RTN


! ------------------------------------------------------------
! K8 -- next page.  RC1 has only COMMON page 0.
! ------------------------------------------------------------

KF8     JSB =KFBGN
        CLB R20
        STBD R20,X14,KPAGE
        JSB =KREFR
        JSB =KFEND
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



! ============================================================
! NATIVE HP-85 KEY-LABEL PANEL
!
! LEG1..LEG4 are the bottom row (K1..K4).
! LEG5..LEG8 are the shifted/upper row (K5..K8).
! Each hardware slot is eight characters wide.  PRINTER85 deliberately uses
! at most seven visible characters and leaves the final byte blank so adjacent
! labels remain visually separated.
! ============================================================


! ------------------------------------------------------------
! KREFR -- update PRINTER85 labels when PRTKEYS owns the panel.
!
! Always updates LEGEND/LEGEN2 while active.  KREDR performs a visible KEY LABEL
! redraw only in alpha mode; graphics mode is never disturbed.
! ------------------------------------------------------------

KREFR   BIN
        LDMD R14,=BAS241
        LDBD R20,X14,KHACT
        CMB R20,=0
        JZR KRFRT

        JSB =KLABS
        JSB =KREDR

KRFRT   RTN


! ------------------------------------------------------------
! KREDR -- invoke the native HP-85 KEY LABEL runtime only in alpha mode.
!
! CRTWRS bit 7: 0=alpha, 1=graphics.  ROMJSB is used deliberately here because
! KEYLA. is a system runtime whose external-ROM calling contract is not
! explicitly documented in the assembler manual.
! ------------------------------------------------------------

KREDR   LDBD R20,=CRTWRS
        ANM R20,=200
        JNZ KRDRT

        JSB =ROMJSB
        DEF KEYLA.
        BYT 0

        BIN

KRDRT   RTN


! ------------------------------------------------------------
! KCP8 -- copy one 8-byte ROM label into one system legend slot.
!
! Input:
!       R34/R35 = source
!       R36/R37 = destination
! ------------------------------------------------------------

KCP8    LDB R20,=10            ! octal 10 = 8 decimal bytes

KC8LP   POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ KC8LP
        RTN


! ------------------------------------------------------------
! KLABS -- render COMMON page 0 into all eight native legend slots.
! ------------------------------------------------------------

KLABS   BIN
        LDMD R14,=BAS241

! RC1 has only page 0.  Sanitize any stale/future value.

        LDBD R20,X14,KPAGE
        CMB R20,=0
        JZR KLCOM
        CLB R20
        STBD R20,X14,KPAGE

KLCOM   BIN

! K1 -- pitch.

        LDMD R14,=BAS241
        LDBD R20,X14,STPIT
        CMB R20,=0
        JZR KLP0
        CMB R20,=1
        JZR KLP1
        CMB R20,=2
        JZR KLP2
        LDM R34,=LBP3
        JMP KLPGO

KLP0    LDM R34,=LBP0
        JMP KLPGO
KLP1    LDM R34,=LBP1
        JMP KLPGO
KLP2    LDM R34,=LBP2

KLPGO   LDM R36,=LEG1
        JSB =KCP8

! K2 -- bold / ThinkJet quality.

        LDMD R14,=BAS241
        LDBD R20,X14,STBOLD
        CMB R20,=0
        JZR KLB0
        LDM R34,=LBB1
        JMP KLBGO

KLB0    LDM R34,=LBB0

KLBGO   LDM R36,=LEG2
        JSB =KCP8

! K3 -- COPY zoom.  Show unknown when no PRTSET profile is valid.

        LDMD R14,=BAS241
        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KLZQ

        LDBD R20,X14,HCZOOM
        CMB R20,=1
        JZR KLZ1
        CMB R20,=2
        JZR KLZ2
        CMB R20,=4
        JZR KLZ4

KLZQ    LDM R34,=LBZQ
        JMP KLZGO
KLZ1    LDM R34,=LBZ1
        JMP KLZGO
KLZ2    LDM R34,=LBZ2
        JMP KLZGO
KLZ4    LDM R34,=LBZ4

KLZGO   LDM R36,=LEG3
        JSB =KCP8

! K4 -- previous page.

        LDM R34,=LBPRV
        LDM R36,=LEG4
        JSB =KCP8

! K5 -- line spacing.

        LDMD R14,=BAS241
        LDBD R20,X14,STLPI
        CMB R20,=8D
        JZR KLL8
        LDM R34,=LBL6
        JMP KLLGO

KLL8    LDM R34,=LBL8

KLLGO   LDM R36,=LEG5
        JSB =KCP8

! K6 -- underline.

        LDMD R14,=BAS241
        LDBD R20,X14,STUND
        CMB R20,=0
        JZR KLU0
        LDM R34,=LBU1
        JMP KLUGO

KLU0    LDM R34,=LBU0

KLUGO   LDM R36,=LEG6
        JSB =KCP8

! K7 -- COPY orientation.  Show unknown when no PRTSET profile is valid.

        LDMD R14,=BAS241
        LDBD R20,X14,HCVLD
        CMB R20,=0
        JZR KLOQ

        LDBD R20,X14,HCORI
        CMB R20,=0
        JZR KLO0
        LDM R34,=LBO1
        JMP KLOGO

KLO0    LDM R34,=LBO0
        JMP KLOGO

KLOQ    LDM R34,=LBOQ

KLOGO   LDM R36,=LEG7
        JSB =KCP8

! K8 -- next page.

        LDM R34,=LBNXT
        LDM R36,=LEG8
        JSB =KCP8
        RTN


! ------------------------------------------------------------
! HCLOAD -- copy stored PRTSET profile to the existing PRTSCREEN PS* state.
! ------------------------------------------------------------

HCLOAD  BIN
        LDMD R14,=BAS241

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
        LDMD R14,=BAS241

! PSSTRT is a shared internal subroutine.  Physical graphics COPY and the
! BASIC PRTSCREEN wrapper both call the same verified hardcopy executor.

        JSB =PSSTRT
        RTN


! ------------------------------------------------------------
! HCOPEN -- begin raw text/control output using current PS* device profile.
! No HPOUT transaction remains active when this routine returns.
! ------------------------------------------------------------

HCOPEN  BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDB R34,=20
        CLB R35
        JSB =HPCTRL
        JSB =HPADRO
        RTN



! ============================================================
! COMMON TEXT ATTRIBUTE EMISSION
!
! HCOPEN must already have addressed the current PS* printer.  These routines
! emit only control bytes; HCCLOSE is performed by the caller.
! ============================================================


! ------------------------------------------------------------
! SETPIT -- apply STPIT to current driver.
!
! SII approximations at the native 203-dpi mechanism pitch:
!   0: Font A 12 dots + 5 spacing = 17 dots  -> 11.94 cpi
!   1: same, x2 width                         ->  5.97 cpi
!   2: Font B  8 dots + 2 spacing = 10 dots  -> 20.30 cpi
!   3: same, x2 width                         -> 10.15 cpi
! ------------------------------------------------------------

SETPIT  BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR SPTTJ

! SII.

        LDBD R20,X14,STPIT
        CMB R20,=0
        JZR SPTS0
        CMB R20,=1
        JZR SPTS1
        CMB R20,=2
        JZR SPTS2
        LDM R32,=SIPT3
        JMP SPTSND

SPTS0   LDM R32,=SIPT0
        JMP SPTSND
SPTS1   LDM R32,=SIPT1
        JMP SPTSND
SPTS2   LDM R32,=SIPT2

SPTSND  LDM R30,=9D,0
        JSB =HPOUT
        RTN

! ThinkJet HP mode.

SPTTJ   LDBD R20,X14,STPIT
        CMB R20,=0
        JZR SPTT0
        CMB R20,=1
        JZR SPTT1
        CMB R20,=2
        JZR SPTT2
        LDM R32,=TJPT3
        JMP SPTTS

SPTT0   LDM R32,=TJPT0
        JMP SPTTS
SPTT1   LDM R32,=TJPT1
        JMP SPTTS
SPTT2   LDM R32,=TJPT2

SPTTS   LDM R30,=5D,0
        JSB =HPOUT
        RTN


! ------------------------------------------------------------
! SETBLD -- apply STBOLD.
! ------------------------------------------------------------

SETBLD  BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR SBLTJ

        LDBD R20,X14,STBOLD
        CMB R20,=0
        JZR SBLS0
        LDM R32,=SIBL1
        JMP SBLSS

SBLS0   LDM R32,=SIBL0

SBLSS   LDM R30,=3D,0
        JSB =HPOUT
        RTN

SBLTJ   LDBD R20,X14,STBOLD
        CMB R20,=0
        JZR SBLT0
        LDM R32,=TJBL1
        JMP SBLTS

SBLT0   LDM R32,=TJBL0

SBLTS   LDM R30,=5D,0
        JSB =HPOUT
        RTN


! ------------------------------------------------------------
! SETUND -- apply STUND.
! ------------------------------------------------------------

SETUND  BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR SUNTJ

        LDBD R20,X14,STUND
        CMB R20,=0
        JZR SUNS0
        LDM R32,=SIUN1
        JMP SUNSS

SUNS0   LDM R32,=SIUN0

SUNSS   LDM R30,=3D,0
        JSB =HPOUT
        RTN

SUNTJ   LDBD R20,X14,STUND
        CMB R20,=0
        JZR SUNT0
        LDM R32,=TJUN1
        JMP SUNTS

SUNT0   LDM R32,=TJUN0

SUNTS   LDM R30,=4D,0
        JSB =HPOUT
        RTN


! ------------------------------------------------------------
! SETLPI -- apply STLPI (6 or 8).
!
! SII 8-LPI is ESC 3,25 decimal.  At the default 1/203-inch vertical pitch
! that is 25/203 inch per line = 8.12 LPI, the closest integer-dot setting.
! ------------------------------------------------------------

SETLPI  BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR SLPTJ

        LDBD R20,X14,STLPI
        CMB R20,=8D
        JZR SLPS8

        LDM R30,=2D,0
        LDM R32,=SILP6
        JSB =HPOUT
        RTN

SLPS8   LDM R30,=3D,0
        LDM R32,=SILP8
        JSB =HPOUT
        RTN

SLPTJ   LDBD R20,X14,STLPI
        CMB R20,=8D
        JZR SLPT8

        LDM R32,=TJLP6
        JMP SLPTS

SLPT8   LDM R32,=TJLP8

SLPTS   LDM R30,=5D,0
        JSB =HPOUT
        RTN


! ------------------------------------------------------------
! SETALL -- reapply the complete common text profile.
! ------------------------------------------------------------

SETALL  JSB =SETPIT
        JSB =SETBLD
        JSB =SETUND
        JSB =SETLPI
        RTN


! ------------------------------------------------------------
! HCLINE -- send one ASCII LF (0Ah = 012 octal).
! HCOPEN must already have been called.
! ------------------------------------------------------------

HCLINE  BIN
        LDMD R14,=BAS241
        LDM R30,=1,0
        LDM R32,=HCLF
        JSB =HPOUT
        RTN


! ------------------------------------------------------------
! HCPAGE -- driver-specific page advance.
!
! ThinkJet: ASCII FF (0Ch = 014 octal)
! SII:      ESC d 66 (66 decimal = 0102 octal lines)
! ------------------------------------------------------------

HCPAGE  BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR HCPGTJ

        LDM R30,=3D,0
        LDM R32,=SIIPG
        JSB =HPOUT
        RTN

HCPGTJ  LDM R30,=1,0
        LDM R32,=HCFF
        JSB =HPOUT
        RTN


! ------------------------------------------------------------
! HCCLOSE -- raw text/control cleanup.
!
! ThinkJet uses the intended explicit UNLISTEN + CR16=2 path.
! SII uses the hardened v0.10i2 delayed double CR16=2 restore and deliberately
! does not send explicit UNLISTEN.
! ------------------------------------------------------------

HCCLOSE BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR HCTJCL

! SII cleanup.

        JSB =SIDELAY

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDB R34,=20
        LDB R35,=2
        JSB =HPCTRL

        JSB =SIDLY2

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDB R34,=20
        LDB R35,=2
        JSB =HPCTRL

        JSB =SIDLY2
        RTN

! ThinkJet cleanup.

HCTJCL  JSB =HPIB7
        LDB R35,=77
        JSB =HPSNDC
        LDB R34,=20
        LDB R35,=2
        JSB =HPCTRL
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
        LDMD R14,=BAS241

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

        JSB =HCOPEN

! Reassert the stored common text profile before every alpha-screen COPY.
! This also makes text COPY a deterministic recovery point after graphics jobs.

        JSB =SETALL


! Tiny outer loop.  Keeping the JNZ next to the counter is the same structural
! rule used elsewhere in PRINTER85 when a worker body exceeds relative range.

TXTLP   JSB =TXT1ROW

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,TXTROWS
        DCB R20
        STBD R20,X14,TXTROWS
        JNZ TXTLP

        JSB =HCCLOSE

        BIN
        LDMD R14,=BAS241
        JSB =PREST
        RTN


! ------------------------------------------------------------
! TXT1ROW -- build and transmit one visible 32-character alpha row.
! Also advances TXTADR to the following alpha row with 010000-octal wrap.
! ------------------------------------------------------------

TXT1ROW BIN
        LDMD R14,=BAS241
        LDMD R46,X14,TXTADR

        LDB R34,R46
        LDB R35,R47
        JSB =BYTCR!

        BIN
        LDMD R14,=BAS241
        LDM R34,=TXTBUF
        ADMD R34,=BAS241
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
        LDMD R14,=BAS241
        LDM R30,=34D,0
        LDM R32,=TXTBUF
        ADMD R32,=BAS241
        JSB =HPOUT

! Advance one 32-character alpha row = 64 decimal = 0100 octal nibble
! addresses.  Explicitly wrap 010000 -> 000000 so a visible page may straddle
! the end of the four-page alpha ring without entering graphics memory.

        BIN
        LDMD R14,=BAS241
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
        LDMD R14,=BAS241

        JSB =PSARGS
        JSB =PSSTRT

! Successful PRTSCREEN remains deliberately silent.

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
        LDMD R14,=BAS241

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
        LDMD R14,=BAS241
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
        LDMD R14,=BAS241
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
        LDMD R14,=BAS241
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
        LDMD R14,=BAS241

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
        LDMD R14,=BAS241

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

! D6 diagnostic: use HP's dedicated CRT wipeout/unwipe pair.
! CRTWPO leaves CRT memory intact and avoids a CRT power cycle; HP explicitly
! documents it as useful for speeding transfers.  CRTUNW restores display.
! Both routines are ROMJSB=N, so direct calls are valid from Option ROM 241.
!
! CRTFLG=1 means CRTWRS wipeout bit 1 was already set, or that this call
! deliberately wiped the CRT for fast INCHR- reads.
! PSWIPE=1 means this call itself executed CRTWPO and must execute CRTUNW.

PSSTRT  LDB R21,=0
        LDBD R20,=CRTWRS
        LRB R20
        TSB R20
        JEV PSCRSV
        LDB R21,=1

PSCRSV  LDMD R14,=BAS241
        STBD R21,X14,CRTFLG
        CLB R20
        STBD R20,X14,PSWIPE
        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT

! Only SII graphics requests automatic wipeout.  If the caller already has
! CRT wipeout active, preserve that state and use INCHR- without changing it.

        LDBD R20,X14,PSDRIV
        CMB R20,=2
        JNZ PSIOGO

        LDBD R20,X14,CRTFLG
        CMB R20,=1
        JZR PSIOGO

! CRTWPO is ROMJSB=N and may be called directly from external ROM.

        JSB =CRTWPO

        BIN
        LDMD R14,=BAS241
        LDB R20,=1
        STBD R20,X14,CRTFLG
        STBD R20,X14,PSWIPE

! Select the decoded translator, suppress automatic EOL, address listener.

PSIOGO  JSB =HPIB7
        LDB R34,=20
        CLB R35
        JSB =HPCTRL
        JSB =HPADRO

! Dispatch printer driver.  Both drivers share the proven HP-IB transport,
! CRT-state sampling and caller-pointer preservation above.

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSDRIV
        CMB R20,=1
        JZR PSJT

! Driver 2: SII IFD501 / CAPD345A.
! v0.10h5 uses a dedicated close path.  SICLOSE waits briefly, then restores CR16 on the
! translator selected dynamically from PSCODE and deliberately does NOT send
! the explicit UNLISTEN command used by the ThinkJet close path.
        JSB =SIIDRV
        JMP SICLOSE

! Driver 1: ThinkJet high-density graphics resolution.
! ESC*r192S selects 192 dpi horizontally (96 dpi vertically); it is
! a resolution command, not a raster-height declaration.

PSJT    LDM R30,=7D,0
        LDM R32,=TJ192S
        JSB =HPOUT

        LDM R30,=4D,0
        LDM R32,=TJSTAR
        JSB =HPOUT

! Execute portrait or 90-degree clockwise landscape raster path.

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSOVAL
        CMB R20,=0
        JNZ PSLGO

        JSB =TJPOR
        JMP PSDONE

PSLGO   JSB =TJLND

! End ThinkJet raster graphics.

PSDONE  BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDM R30,=4D,0
        LDM R32,=TJEND
        JSB =HPOUT

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
        LDMD R14,=BAS241

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

        JSB =SIDELAY

! First CR16=2 restore.

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDB R34,=20
        LDB R35,=2
        JSB =HPCTRL

! Give EBTKS a short quiet interval, then repeat the same control write.

        JSB =SIDLY2

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDB R34,=20
        LDB R35,=2
        JSB =HPCTRL

! One final short settling interval before local CRT output / BASIC resumes.

        JSB =SIDLY2

! Restore the visible CRT only if this hardcopy call executed CRTWPO.
! CRTUNW is ROMJSB=N, so a direct call is valid from external ROM.

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSWIPE
        CMB R20,=0
        JZR SICRET

        JSB =CRTUNW

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
        LDMD R14,=BAS241
        JSB =HPIB7

        LDB R35,=77
        JSB =HPSNDC
        LDB R34,=20
        LDB R35,=2
        JSB =HPCTRL


! ------------------------------------------------------------
! PSRET -- common return path after interface cleanup.
! ------------------------------------------------------------

PSRET   BIN
        LDMD R14,=BAS241

! Restore caller's CRT byte pointer and return to whichever wrapper invoked
! the shared hardcopy executor.

        JSB =PREST
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
        LDMD R14,=BAS241
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

HPDIR   JSB =HPDONE

        LDB R37,=2
        STBD R37,R24
        STBD R36,R26

        JSB =HPOBF0

        CLB R37
        STBD R37,R24

        RTN


! ------------------------------------------------------------
! HPSNDC -- send byte in R35 as HP-IB bus command.
! Manual utility: SNDCMD.
! ------------------------------------------------------------

HPSNDC  LDB R36,=260
        JSB =HPDIR

        LDB R37,=4
        STBD R37,R24
        STBD R35,R26

        JSB =HPDONE
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
        JSB =HPDIR

        JSB =HPOBF0

        LDB R37,=4
        STBD R37,R24
        STBD R35,R26

        JSB =HPDONE
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
        JSB =HPSNDC

        LDB R36,=105
        JSB =HPDIR

        LDBD R35,X14,PSADDR
        ADB R35,=40
        JSB =HPSNDC

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
        JSB =HPDIR

HPOUT1  POBD R36,+R32
        JSB =HPOBF0

        DCM R30
        JZR HPOUTE

        STBD R36,R26
        JMP HPOUT1

HPOUTE  LDB R37,=4
        STBD R37,R24
        STBD R36,R26

        JSB =HPDONE
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
        LDMD R14,=BAS241
        LDM R46,=0,20
        STMD R46,X14,PSRADR
        CLB R20
        STBD R20,X14,PSROW

TPLOOP  BIN
        LDMD R14,=BAS241
        LDMD R46,X14,PSRADR
        JSB =READROW
        JSB =TPROW

        BIN
        LDMD R14,=BAS241
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
        LDMD R14,=BAS241
        LDBD R20,X14,PSZVAL
        CMB R20,=1
        JZR TPZ1
        CMB R20,=2
        JZR TPZ2
        JMP TPZ4

! z1: unchanged v0.10f row transfer.

TPZ1    JSB =HPIB7
        LDM R30,=6D,0
        LDM R32,=TJ32W
        JSB =HPOUT

        LDM R30,=32D,0
        LDM R32,=ROWBUF
        ADMD R32,=BAS241
        JSB =HPOUT
        RTN

! z2: expand 32 bytes -> 64 bytes, then send row twice.

TPZ2    LDM R30,=32D,0
        LDM R32,=ROWBUF
        ADMD R32,=BAS241
        JSB =TJEXP2

        JSB =HPIB7
        JSB =TP64R
        JSB =TP64R
        RTN

! z4: expand 32 bytes -> 128 bytes, then send row four times.

TPZ4    LDM R30,=32D,0
        LDM R32,=ROWBUF
        ADMD R32,=BAS241
        JSB =TJEXP4

        JSB =HPIB7
        JSB =TP128R
        JSB =TP128R
        JSB =TP128R
        JSB =TP128R
        RTN

! Send one expanded portrait row (64 bytes).

TP64R   LDM R30,=6D,0
        LDM R32,=TJ64W
        JSB =HPOUT

        LDM R30,=64D,0
        LDM R32,=TJSBUF
        ADMD R32,=BAS241
        JSB =HPOUT
        RTN

! Send one 4x portrait row (128 bytes).  Header is 7 bytes because
! the decimal byte count has three digits.

TP128R  LDM R30,=7D,0
        LDM R32,=TJ128W
        JSB =HPOUT

        LDM R30,=128D,0
        LDM R32,=TJ4BUF
        ADMD R32,=BAS241
        JSB =HPOUT
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
        LDMD R14,=BAS241
        CLB R20
        STBD R20,X14,PSLBND

TLBLOP  JSB =TJLBD
        JSB =TJLSND

        BIN
        LDMD R14,=BAS241
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

TJLBD   JSB =TJCLR

        BIN
        LDMD R14,=BAS241

! First destination byte in row 0 and MSB of that byte.

        LDM R34,=TLBUF
        ADMD R34,=BAS241
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

TLRLOP  JSB =TJLRD
        JSB =TJLSCT

        BIN
        LDMD R14,=BAS241

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
        LDMD R14,=BAS241
        LDMD R34,X14,PSLSRC
        JSB =BYTCR!

        BIN
        LDMD R14,=BAS241
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
        LDMD R14,=BAS241
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
        ADMD R34,=BAS241
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
        LDMD R14,=BAS241
        LDM R34,=TLBUF
        ADMD R34,=BAS241
        STMD R34,X14,PSLOUT
        CLB R20
        STBD R20,X14,PSLRNO

TLSLOP  JSB =TJLSR

        BIN
        LDMD R14,=BAS241
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
        LDMD R14,=BAS241
        LDBD R20,X14,PSZVAL
        CMB R20,=1
        JZR TLSZ1
        CMB R20,=2
        JZR TLSZ2
        JMP TLSZ4

TLSZ1   JSB =HPIB7
        LDM R30,=6D,0
        LDM R32,=TJ24W
        JSB =HPOUT

        BIN
        LDMD R14,=BAS241
        LDM R30,=24D,0
        LDMD R32,X14,PSLOUT
        JSB =HPOUT
        RTN

TLSZ2   LDM R30,=24D,0
        LDMD R32,X14,PSLOUT
        JSB =TJEXP2

        JSB =HPIB7
        JSB =TL48R
        JSB =TL48R
        RTN

TLSZ4   LDM R30,=24D,0
        LDMD R32,X14,PSLOUT
        JSB =TJEXP4

        JSB =HPIB7
        JSB =TL96R
        JSB =TL96R
        JSB =TL96R
        JSB =TL96R
        RTN

! Send one expanded landscape row (48 bytes).

TL48R   LDM R30,=6D,0
        LDM R32,=TJ48W
        JSB =HPOUT

        LDM R30,=48D,0
        LDM R32,=TJSBUF
        ADMD R32,=BAS241
        JSB =HPOUT
        RTN

TL96R   LDM R30,=6D,0
        LDM R32,=TJ96W
        JSB =HPOUT

        LDM R30,=96D,0
        LDM R32,=TJ4BUF
        ADMD R32,=BAS241
        JSB =HPOUT
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
        ADMD R34,=BAS241

TXLOOP  POBD R36,+R32
        JSB =T2BYTE
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
        ADMD R34,=BAS241

T4LOOP  POBD R36,+R32
        JSB =T4BYTE
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
        ADM R76,R46
        POBD R22,+R76
        PUBD R22,+R34
        POBD R22,+R76
        PUBD R22,+R34
        RTN


! ============================================================
! SII / EPSON DRIVER 2 -- v0.02d RC3 PAGE MODE / RELIABLE ENTRY
!
! Target hardware:
!       Seiko Instruments IFD501-01UK-E
!       CAPD345A 576-dot thermal mechanism
!
! Page-mode sequence used here:
!
!       ESC S                       force/cancel any residual page mode
!       [settling delay]
!       ESC J 0                     flush standard line buffer, zero feed
!       [settling delay]
!       ESC L                       enter page mode from known line start
!       [settling delay]
!       ESC W x y dx dy             define exact image print area
!       ESC T 0                     top-left, left-to-right
!       ESC $ 0 0                   horizontal deployment position = 0
!       GS  $ 0 0                   vertical deployment position = 0
!       GS v 0 ...                  ONE complete raster image command
!       [payload streamed in chunks]
!       FF                          batch print + return to standard mode
!
! RC3 addresses the intermittent failure where GS v 0 payload bytes were
! visibly printed as structured text.  ESC L is documented as valid only at
! the beginning of a line.  The conservative ESC S / ESC J 0 / ESC L preamble
! establishes standard mode and a clean line start before page-mode selection.
! ESC J 0 has zero feed distance; if residual line data exists it flushes one
! line and leaves the next position at the beginning of a line.
!
! The IFD501 manual recommends explicitly establishing a deployment position
! after entering page mode / setting the print area.  ESC $ and GS $ do that;
! no LF or ESC 3 line-spacing commands are used inside page mode.
!
! Important: the GS v 0 raster is deliberately one logical image, not a set of
! eight-row images.  HPOUT transaction boundaries do not add printer data.  The
! physically-proven v0.10h SII driver already streamed one GS v 0 header followed
! by many independent HPOUT payload chunks, so this preserves that proven parser
! behaviour while page mode absorbs the entire image before the final FF.
!
! Default IFD501 basic calculation pitch is x=y=203, i.e. one CAPD345 dot.
! ESC W therefore uses physical output dimensions in dots:
!
!       portrait  z1 : 256 x 192
!       portrait  z2 : 512 x 384
!       landscape z1 : 192 x 256
!       landscape z2 : 384 x 512
! ============================================================

SIIDRV  BIN
        LDMD R14,=BAS241

! Select page setup and full-raster header from orientation + zoom.

        LDBD R20,X14,PSOVAL
        CMB R20,=0
        JNZ SIPGLND

! Portrait.

        LDBD R20,X14,PSZVAL
        CMB R20,=1
        JZR SIPGP1

        LDM R46,=SIPG2
        LDM R32,=SIP2HD
        JMP SIPGSET

SIPGP1  LDM R46,=SIPG1
        LDM R32,=SIP1HD
        JMP SIPGSET

! Landscape.

SIPGLND LDBD R20,X14,PSZVAL
        CMB R20,=1
        JZR SIPGL1

        LDM R46,=SILG2
        LDM R32,=SIL2HD
        JMP SIPGSET

SIPGL1  LDM R46,=SILG1
        LDM R32,=SIL1HD

! R46/R47 -> 21-byte page-mode setup table beginning with ESC W.
! R32/R33 -> 8-byte full-image GS v 0 header.
! Preserve the header pointer across the setup output in SIIDST.
!
! Reliable-entry preamble:
!   1. ESC S   -- if still in page mode, return to standard mode and discard
!                 stale page data; ignored when already in standard mode.
!   2. ESC J 0 -- in standard mode, flush any residual line buffer with zero
!                 feed distance and leave the next position at line start.
!   3. ESC L   -- enter page mode from the documented required line-start state.
!
! Each state-changing command is sent as its own HPOUT transaction and followed
! by the existing conservative SII settling delay.  The actual GS v 0 header and
! payload remain contiguous logically and receive no inserted delays.

SIPGSET STMD R32,X14,SIIDST

! Force/cancel residual page mode.

        JSB =HPIB7
        LDM R30,=2D,0
        LDM R32,=SIISTD
        JSB =HPOUT
        JSB =SIDELAY

! Establish a clean beginning-of-line in standard mode without paper advance.

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDM R30,=3D,0
        LDM R32,=SIIJ0
        JSB =HPOUT
        JSB =SIDELAY

! Enter page mode only after standard mode + line start are established.

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDM R30,=2D,0
        LDM R32,=SIIPGM
        JSB =HPOUT
        JSB =SIDELAY

! Complete page setup: ESC W, ESC T, ESC $, GS $.

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDM R30,=21D,0
        LDM R32,R46
        JSB =HPOUT
        JSB =SIDLY2

! Issue the one full-image raster header; payload follows immediately.

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDM R30,=8D,0
        LDMD R32,X14,SIIDST
        JSB =HPOUT

! Stream the 6144-byte raster payload as one logical GS v 0 image.

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSOVAL
        CMB R20,=0
        JNZ SIPGLGO

        JSB =SIIPOR
        JMP SIPGFF

SIPGLGO JSB =SIILND

! FF is sent alone.  In page mode it batch-prints the developed page and returns
! the IFD501 to standard mode.  Do not append ESC d here; keep the first page-mode
! diagnostic to the documented terminating command only.

SIPGFF  BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDM R30,=1,0
        LDM R32,=HCFF
        JSB =HPOUT
        RTN


! ------------------------------------------------------------
! SIIPOR -- portrait payload for the already-issued full-image GS v 0 command.
!
! The header declared x=32 bytes and y=192 source dots.  Each row is generated
! into ROWBUF and sent as a 32-byte payload chunk.  Total payload = 6144 bytes.
! m=3 performs the 2x scaling inside the IFD501; payload size stays unchanged.
! ------------------------------------------------------------

SIIPOR  BIN
        LDMD R14,=BAS241

        LDM R46,=0,20
        STMD R46,X14,PSRADR
        CLB R20
        STBD R20,X14,PSROW

SIPLOP  BIN
        LDMD R14,=BAS241
        LDMD R46,X14,PSRADR
        JSB =READROW

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDM R30,=32D,0
        LDM R32,=ROWBUF
        ADMD R32,=BAS241
        JSB =HPOUT

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSROW
        CMB R20,=277
        JZR SIPDON

        ICB R20
        STBD R20,X14,PSROW
        LDMD R46,X14,PSRADR
        ADM R46,=100,0
        STMD R46,X14,PSRADR
        JMP SIPLOP

SIPDON  RTN


! ------------------------------------------------------------
! SIILND -- landscape payload for the already-issued full-image GS v 0 command.
!
! The header declared x=24 bytes and y=256 source dots.  TJLBD produces eight
! consecutive 24-byte rotated rows in TLBUF.  Send all 192 bytes as one payload
! chunk; 32 chunks = 6144 bytes.  No page-mode positioning occurs between chunks
! because they are all data belonging to the SAME GS v 0 command.
! ------------------------------------------------------------

SIILND  BIN
        LDMD R14,=BAS241
        CLB R20
        STBD R20,X14,PSLBND

SILLOP  JSB =TJLBD

        BIN
        LDMD R14,=BAS241
        JSB =HPIB7
        LDM R30,=192D,0
        LDM R32,=TLBUF
        ADMD R32,=BAS241
        JSB =HPOUT

        BIN
        LDMD R14,=BAS241
        LDBD R20,X14,PSLBND
        CMB R20,=37
        JZR SILDON

        ICB R20
        STBD R20,X14,PSLBND
        JMP SILLOP

SILDON  RTN


! ============================================================
! PREST -- restore caller's CRT byte pointer after hardcopy reads.
! ============================================================

PREST   BIN
        LDMD R14,=BAS241
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

        ADMD R34,=BAS241


! ------------------------------------------------------------
! 32 decimal bytes = 40 octal.
! ------------------------------------------------------------

        LDB R22,=40


! ------------------------------------------------------------
! Select the read loop once for this scanline.
! ------------------------------------------------------------

        LDMD R14,=BAS241

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

HMSG    ASC "PRINTER85 0.03A RC1"

! ------------------------------------------------------------
! COMMON native K-key labels -- exactly 8 bytes each.
! Visible text is limited to 7 characters; final byte is always blank.
! ------------------------------------------------------------

LBP0    ASC "12CPI   "
LBP1    ASC "6CPI    "
LBP2    ASC "21.3CPI "
LBP3    ASC "10.7CPI "

LBB0    ASC "BOLDOFF "
LBB1    ASC "BOLDON  "

LBZQ    ASC "ZOOM ?  "
LBZ1    ASC "ZOOM1X  "
LBZ2    ASC "ZOOM2X  "
LBZ4    ASC "ZOOM4X  "

LBL6    ASC "6 LPI   "
LBL8    ASC "8 LPI   "

LBU0    ASC "UND OFF "
LBU1    ASC "UND ON  "

LBOQ    ASC "ORIENT? "
LBO0    ASC "PORT    "
LBO1    ASC "LANDSC  "

LBPRV   ASC "<PREV   "
LBNXT   ASC "NEXT>   "


! ------------------------------------------------------------
! ThinkJet HP-mode common text controls.
! ------------------------------------------------------------

TJPT0   BYT 33
        ASC "&k0S"
TJPT1   BYT 33
        ASC "&k1S"
TJPT2   BYT 33
        ASC "&k2S"
TJPT3   BYT 33
        ASC "&k3S"

TJBL0   BYT 33
        ASC "(s0B"
TJBL1   BYT 33
        ASC "(s1B"

TJUN0   BYT 33
        ASC "&d@"
TJUN1   BYT 33
        ASC "&dD"

TJLP6   BYT 33
        ASC "&l6D"
TJLP8   BYT 33
        ASC "&l8D"


! ------------------------------------------------------------
! SII common text controls.
!
! Pitch tables are:
!       ESC M n       font A/B
!       ESC SP n      character right spacing
!       GS  ! n       horizontal scale (020 octal = x2 width)
! ------------------------------------------------------------

SIPT0   BYT 33,115,0,33,40,5,35,41,0
SIPT1   BYT 33,115,0,33,40,5,35,41,20
SIPT2   BYT 33,115,1,33,40,2,35,41,0
SIPT3   BYT 33,115,1,33,40,2,35,41,20

SIBL0   BYT 33,105,0
SIBL1   BYT 33,105,1

SIUN0   BYT 33,55,0
SIUN1   BYT 33,55,1

SILP6   BYT 33,62
SILP8   BYT 33,63,31


! Raw text / keyboard paper-control bytes.
! All byte constants are octal.
HCLF    BYT 12                  ! ASCII LF = 0Ah
HCFF    BYT 14                  ! ASCII FF = 0Ch (ThinkJet page advance)
SIIPG   BYT 33,144,102          ! ESC d 66 decimal (0102 octal)

! SII IFD501 page-mode entry commands and setup tables.  All constants octal.
!
! SIISTD = ESC S     return page mode -> standard mode (ignored in standard)
! SIIJ0  = ESC J 0   print/flush residual standard line, feed distance zero
! SIIPGM = ESC L     enter page mode; valid only at beginning of a line
SIISTD  BYT 33,123
SIIJ0   BYT 33,112,0
SIIPGM  BYT 33,114
!
! Sequence in each 21-byte setup table:
!       ESC W xL xH yL yH dxL dxH dyL dyH
!       ESC T 0
!       ESC $ 0 0
!       GS  $ 0 0
!
! Default GS P pitch is 203 x 203, one CAPD345 mechanism dot per unit.
!
! Portrait z1:  x=0 y=0, dx=256 (0000,0001), dy=192 (0300,0000)
SIPG1   BYT 33,127,0,0,0,0,0,1,300,0,33,124,0,33,44,0,0,35,44,0,0
!
! Portrait z2:  dx=512 (0000,0002), dy=384 (0200,0001)
SIPG2   BYT 33,127,0,0,0,0,0,2,200,1,33,124,0,33,44,0,0,35,44,0,0
!
! Landscape z1: dx=192 (0300,0000), dy=256 (0000,0001)
SILG1   BYT 33,127,0,0,0,0,300,0,0,1,33,124,0,33,44,0,0,35,44,0,0
!
! Landscape z2: dx=384 (0200,0001), dy=512 (0000,0002)
SILG2   BYT 33,127,0,0,0,0,200,1,0,2,33,124,0,33,44,0,0,35,44,0,0

! Full-image GS v 0 headers.  One header is followed by all 6144 payload bytes.
! Portrait: 32 bytes x 192 dots.  Landscape: 24 bytes x 256 dots.
SIP1HD  BYT 35,166,60,0,40,0,300,0
SIP2HD  BYT 35,166,60,3,40,0,300,0
SIL1HD  BYT 35,166,60,0,30,0,0,1
SIL2HD  BYT 35,166,60,3,30,0,0,1

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
! ============================================================
! PRINTER85 PRIVATE RAM WORKSPACE -- OFFSETS FROM BAS241
!
! These EQU values generate no ROM bytes.  v0.03a RC1 reserves 01600 octal
! bytes (896 decimal) at power-on and stores the base in BAS241.  All verified
! v0.02d RC3 printer/raster offsets remain unchanged; the new common text state
! and 64-byte saved key-label image are appended after the proven workspace.
! ============================================================

PKMODE  EQU 0            ! 8-byte REAL
KHACT   EQU 10           ! hook ownership flag
KSHIFT  EQU 11           ! PAPER SHIFT sample
KHSAVE  EQU 12           ! 7 bytes, through 020

HCVLD   EQU 21
HCCODE  EQU 22
HCADDR  EQU 23
HCDRIV  EQU 24
HCZOOM  EQU 25
HCORI   EQU 26

TXTADR  EQU 27           ! 2 bytes
TXTROWS EQU 31
TXTBUF  EQU 32           ! 042 octal bytes

PSDEV   EQU 74           ! 8-byte REAL
PSDRV   EQU 104          ! 8-byte REAL
PSZOOM  EQU 114          ! 8-byte REAL
PSORI   EQU 124          ! 8-byte REAL
PSCODE  EQU 134
PSADDR  EQU 135
PSDRIV  EQU 136
PSZVAL  EQU 137
PSOVAL  EQU 140
PSRADR  EQU 142          ! 2 bytes
PSROW   EQU 144

PSLBND  EQU 145
PSLCNT  EQU 146
PSLMSK  EQU 147
PSLSRC  EQU 150          ! 2 bytes
PSLDP   EQU 152          ! 2 bytes
PSLOUT  EQU 154          ! 2 bytes
PSLRNO  EQU 156

TLBUF   EQU 157          ! 0300 octal bytes = 192 decimal
TJSBUF  EQU 457          ! 0100 octal bytes = 64 decimal
TJ4BUF  EQU 557          ! 0200 octal bytes = 128 decimal

SIIDST  EQU 757          ! 2 bytes
SIIBCT  EQU 761
SIIPKT  EQU 762          ! 0410 octal bytes = 264 decimal

SAVCRT  EQU 1372         ! 2 bytes
CRTFLG  EQU 1374
ROWBUF  EQU 1375         ! 040 octal bytes = 32 decimal

! Hook-return state is appended after the existing verified workspace so none
! of the established printer-buffer offsets move.
KHAND   EQU 1435         ! 1 = key handled by PRINTER85
KTRAMP  EQU 1436         ! 032 octal bytes executable RAM trampoline
PSWIPE  EQU 1470         ! 1 iff this graphics call executed CRTWPO

! v0.03a RC1 common text/profile state and native key-label ownership.

STPIT   EQU 1471         ! common pitch state 0..3
STLPI   EQU 1472         ! line spacing, stored as 6 or 8
STBOLD  EQU 1473         ! 0/1
STUND   EQU 1474         ! 0/1
KPAGE   EQU 1475         ! key-panel page; RC1 implements page 0 only
KLGV    EQU 1476         ! saved native legend image valid
KLSAVE  EQU 1477         ! 0100 octal bytes = saved LEGEND + LEGEN2

RAMEND  EQU 1577         ! first byte after used workspace
RAMSIZ  EQU 1600         ! rounded allocation = 896 decimal bytes

! ============================================================
! HP-85 SYSTEM SYMBOLS -- all addresses OCTAL
! ============================================================

ROMFL   DAD 101231
FWUSER  DAD 100000
BAS241  DAD 102554
ROMJSB  DAD 4776
ROMRTN  DAD 4762
SCRAT+  DAD 4344
CHIDLE  DAD 102416
KEYHIT  DAD 100671
KEYSTS  DAD 177402
EOJ2    DAD 34772
KEYLA.  DAD 35454

! Native HP-85 key-label slots: 8 bytes each.
! K1..K4 are the bottom row, K5..K8 the shifted/upper row.

LEG1    DAD 100710
LEG2    DAD 100720
LEG3    DAD 100730
LEG4    DAD 100740
LEG5    DAD 100750
LEG6    DAD 100760
LEG7    DAD 100770
LEG8    DAD 101000

CRTBYT  DAD 100176
CRTRAM  DAD 100200
CRTWRS  DAD 101016
TOS     DAD 101132
CRTWPO  DAD 35661
CRTUNW  DAD 36067

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

OUTSTR  DAD 35052

        FIN
