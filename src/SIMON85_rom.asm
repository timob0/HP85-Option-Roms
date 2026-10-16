! ============================================================
! SIMON85 v0.13a2 -- HP-85 OPTION ROM CONVERSION / FINAL GLOBAL-SYMBOL WARNING CLEANUP
!
! Functionally based on v0.12b.  First option-ROM development build.
! ROM number 102 octal; writable workspace is reserved in RAM via UNBAS2.
!
! Derived from the hardware-tested combined SIMON85 v0.11e source.
! Retains the v0.11d incremental ARC/CIRCLE trigonometry optimization
! and the v0.11e streamed MOVE/DRAW polyline optimization.
!
! Public keywords:
!
!       SVER
!       BLOCK x1,y1,x2,y2,f
!       HIRES j,k
!       LINE x1,y1,x2,y2,f
!       REC x,y,b,h,f
!       ARC mx,my,ws,we,ww,rx,ry,f
!       CIRCLE x,y,rx,ry,f[,n]
!       ANGL x,y,w,rx,ry,f
!       PAINT x,y,f
!       PLOTP x,y,f
!       TEST(x,y)
!
! f: 0=CLEAR, 1=SET, 2=XOR
!
! PRINTER85 is deliberately independent.  This source contains no printer
! drivers, HP-IB hardcopy transport, PRTSET/PRTKEYS state, or CHIDLE hook.
! Normal f=1 vector graphics still use HP Printer/Plotter ROM 360 for the
! established device-aware GCLEAR/SCALE/PEN/MOVE/DRAW services.
! ============================================================

! OPTION-ROM BUILD NOTES:
!   - assembled origin: 60000 octal
!   - ROM number: 102 octal; complement 275 octal
!   - requires HP Printer/Plotter ROM 360
!   - reserves 5204 octal (2692 decimal) bytes of RAM via UNBAS2 at power-on
!   - intended to coexist with PRINTER85 when PRINTER85 uses a different
!     stolen-RAM base pointer / ROM number.
!
        ABS ROM 60000

ROMNUM  EQU 102       ! SIMON85 option-ROM number (octal)

        BYT 102       ! ROM number -- must be first byte
        BYT 275       ! ones-complement of ROM number
        DEF RUNTIM
        DEF KWTABL
        DEF PARSE
        DEF ERMSG
        DEF INIT


! ============================================================
! TABLES
! ============================================================

PARSE   BYT 0,0
        DEF SVERP
        DEF BLOCKP
        DEF HIRESP
        DEF BLOCKP      ! LINE:   five numeric parameters
        DEF BLOCKP      ! REC:    five numeric parameters
        DEF ARCP        ! ARC:    eight numeric parameters
        DEF CIRCLP      ! CIRCLE: five + optional sixth numeric parameter
        DEF ANGLP       ! ANGL:   six numeric parameters
        DEF PAINTP      ! PAINT:  three numeric parameters
        DEF PAINTP      ! PLOTP:  three numeric parameters
        BSZ 2           ! TEST:   implied function parser from attributes

RUNTIM  BYT 0,0
        DEF SVRUN.
        DEF BLOCK.
        DEF HIRES.
        DEF LINE.
        DEF REC.
        DEF ARC.
        DEF CIRCL.
        DEF ANGL.
        DEF PAINT.
        DEF PLTPRT.
        DEF TEST.
        BYT 377,377

KWTABL  ASP "SVER"
        ASP "BLOCK"
        ASP "HIRES"
        ASP "LINE"
        ASP "REC"
        ASP "ARC"
        ASP "CIRCLE"
        ASP "ANGL"
        ASP "PAINT"
        ASP "PLOTP"
        ASP "TEST"

ERMSG   BYT 377

! ============================================================
! INIT -- reserve the v0.13a1 writable workspace at power-on.
!
! WORKSZ = 5204 octal = 2692 decimal bytes.
! UNBAS2 is used as SIMON85's private RAM-base pointer.
! Non-power-on initialization leaves the already-reserved RAM intact.
! ============================================================

INIT    BIN
        LDBD R34,=ROMFL
        JNZ INIRTN

        LDMD R34,=FWUSER
        STMD R34,=UNBAS2
        ADM R34,=204,12  ! +05204 octal bytes (low byte 0204, high 0012)
        STMD R34,=FWUSER

        JSB =ROMJSB
        DEF SCRAT+
        BYT 0

INIRTN  RTN

! ============================================================
! SVER PARSER
! ============================================================

SVERP   LDB R47,R43

        LDB R46,=ROMNUM
        LDB R45,=370
        PUMD R45,+R12

        JSB =P_SCAN

        GTO ROMRTN

! ============================================================
! BLOCK PARSER
!
!       BLOCK x1,y1,x2,y2,f
! ============================================================

BLOCKP  PUBD R43,+R6

        JSB =P_NUMVP
        JEN B1OK
        JMP BERR

B1OK    JSB =P_GETCM
        JSB =P_NUMVL
        JEZ BERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ BERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ BERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ BERR

        POBD R47,-R6

        LDB R46,=ROMNUM
        LDB R45,=370
        PUMD R45,+R12

        GTO ROMRTN


BERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! HIRES PARSER
!
!       HIRES j,k
! ============================================================

HIRESP  PUBD R43,+R6

        JSB =P_NUMVP
        JEN H1OK
        JMP HERR

H1OK    JSB =P_GETCM
        JSB =P_NUMVL
        JEZ HERR

        POBD R47,-R6

        LDB R46,=ROMNUM
        LDB R45,=370
        PUMD R45,+R12

        GTO ROMRTN


HERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! CIRCLE PARSER
!
!       CIRCLE x,y,rx,ry,f[,n]
!
! The first five numeric expressions are required.  After the
! fifth NUMVAL, R14 already contains the next SCAN token.  HP's
! own GCURSOR sample uses token 054 octal to detect an optional
! trailing comma; NUMVP (NUMVA+) then SCANs and parses the sixth
! numeric expression.
! ============================================================

CIRCLP  PUBD R43,+R6

        JSB =P_NUMVP
        JEN C1OK
        JMP CERR

C1OK    JSB =P_GETCM
        JSB =P_NUMVL
        JEZ CERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ CERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ CERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ CERR


! Optional sixth numeric parameter?  054 octal is comma.

        CMB R14,=54
        JNZ CDONE

        JSB =P_NUMVP
        JEZ CERR

CDONE   POBD R47,-R6

        LDB R46,=ROMNUM
        LDB R45,=370
        PUMD R45,+R12

        GTO ROMRTN

CERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! ANGL PARSER
!
!       ANGL x,y,w,rx,ry,f
! ============================================================

ANGLP   PUBD R43,+R6

        JSB =P_NUMVP
        JEN A1OK
        JMP AERR

A1OK    JSB =P_GETCM
        JSB =P_NUMVL
        JEZ AERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ AERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ AERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ AERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ AERR

        POBD R47,-R6

        LDB R46,=ROMNUM
        LDB R45,=370
        PUMD R45,+R12

        GTO ROMRTN

AERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! ARC PARSER
!
!       ARC mx,my,ws,we,ww,rx,ry,f
! ============================================================

ARCP    PUBD R43,+R6

        JSB =P_NUMVP
        JEN G1OK
        JMP GERR

G1OK    JSB =P_GETCM
        JSB =P_NUMVL
        JEZ GERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ GERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ GERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ GERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ GERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ GERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ GERR

        POBD R47,-R6

        LDB R46,=ROMNUM
        LDB R45,=370
        PUMD R45,+R12

        GTO ROMRTN

GERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! PAINT PARSER
!
!       PAINT x,y,f
! ============================================================

PAINTP  PUBD R43,+R6

        JSB =P_NUMVP
        JEN P1OK
        JMP PERR

P1OK    JSB =P_GETCM
        JSB =P_NUMVL
        JEZ PERR

        JSB =P_GETCM
        JSB =P_NUMVL
        JEZ PERR

        POBD R47,-R6

        LDB R46,=ROMNUM
        LDB R45,=370
        PUMD R45,+R12

        GTO ROMRTN

PERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================

! ============================================================
! ROM-SAFE PARSER GATEWAYS
!
! Parser helpers may select ROM 0 or other ROMs internally.  ROMJSB
! restores SIMON85 before returning to these wrappers.  Completed parse
! routines themselves leave through ROMRTN so the interpreter regains ROM 0.
! ============================================================

P_SCAN  JSB =ROMJSB
        DEF SCAN
        BYT 0
        RTN

P_NUMVP JSB =ROMJSB
        DEF NUMVP
        BYT 0
        RTN

P_GETCM JSB =ROMJSB
        DEF GETCM
        BYT 0
        RTN

P_NUMVL JSB =ROMJSB
        DEF NUMVAL
        BYT 0
        RTN

! SVER RUNTIME
! ============================================================

        BYT 241

SVRUN.   LDM R26,=HMSG
        ! HMSG is an absolute ROM address in this build.

        LDM R36,=14D,0

        JSB =OUTSTR

        RTN

! ============================================================
! HIRES RUNTIME -- v0.06j
!
!       HIRES j,k
!
! Equivalent to:
!
!       GCLEAR
!       SCALE 0,320,200,0
!       PEN j
!
! k is consumed and ignored for Simons' BASIC compatibility.
! j is preserved as evaluated and passed to ROM360 PEN without
! any SIMON85 range check or clamping.
! ============================================================

        BYT 241

HIRES.  SAD

        BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! k -- compatibility parameter, deliberately ignored.
! ------------------------------------------------------------

        JSB =ONER
        BIN


! ------------------------------------------------------------
! j -- preserve evaluated REAL exactly for the later PEN test.
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,HPEN


! ------------------------------------------------------------
! GCLEAR via Printer/Plotter ROM 360.
!
! ROM360 token 5 (GCLEAR) has runtime entry 064557 octal.
! This uses the same device-aware graphics layer as the SCALE
! and PEN calls below.  No optional parameter is supplied.
! ------------------------------------------------------------

        JSB =ROMJSB
        DEF PPGCLR
        BYT 360
        BIN


! ------------------------------------------------------------
! SCALE 0,320,200,0 via Printer/Plotter ROM 360.
!
! ROM360 token 8 (SCALE) has runtime entry 064041 octal.
! The routine consumes four 8-byte numeric values from R12 in
! the normal SCALE source order.  CONBIN converts the 16-bit
! binary value in R36/R37 to an HP REAL in R40.
!
! Constants below are octal:
!
!       320 decimal = 0500 octal = low 0100, high 0001
!       200 decimal = 0310 octal = low 0310, high 0000
!
! An external-ROM call must go through ROMJSB even when the
! caller is a RAM binary program.
! ------------------------------------------------------------

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        PUMD R40,+R12

        LDM R36,=100,1
        JSB =CONBIN
        BIN
        PUMD R40,+R12

        LDM R36,=310,0
        JSB =CONBIN
        BIN
        PUMD R40,+R12

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPSCAL
        BYT 360
        BIN


! ------------------------------------------------------------
! PEN j via Printer/Plotter ROM 360.
!
! ROM360 token 17 (PEN) has runtime entry 064241 octal.
! Reload the original evaluated REAL j and push it unchanged.
! The ROM itself implements the HP PEN semantics; SIMON85 does
! not validate, clamp or otherwise transform j.
! ------------------------------------------------------------

        LDMD R14,=UNBAS2
        LDMD R40,X14,HPEN
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPPEN
        BYT 360
        BIN

        PAD
        RTN


! ============================================================
! LINE RUNTIME -- v0.07c
!
!       LINE x1,y1,x2,y2,f
!
! f=1:
!       ROM360 MOVE x1,y1
!       ROM360 DRAW x2,y2
!       Uses the current ROM360 PEN selected by HIRES j,k.
!       This physically-proven v0.07a path is unchanged.
!
! f=0:
!       Direct CRT Bresenham raster path in CLEAR mode.
!       Nothing is sent to the physical plotter.
!
! f=2:
!       Direct CRT Bresenham raster path in XOR mode.
!       Nothing is sent to the physical plotter.
!
! v0.07c clips the f=0/f=2 mapped segment to the 256 x 192 CRT
! before passing the accepted segment to the physically-proven
! v0.07b Bresenham rasterizer.
! ============================================================

        BYT 241

LINE.   SAD

        BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! f
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,LFLAG


! ------------------------------------------------------------
! y2
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,LY2


! ------------------------------------------------------------
! x2
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,LX2


! ------------------------------------------------------------
! y1
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,LY1


! ------------------------------------------------------------
! x1
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,LX1


! ------------------------------------------------------------
! Convert f to one-byte mode.
! ------------------------------------------------------------

        LDMD R60,X14,LFLAG

        JSB =CONINT

        BIN

        LDMD R14,=UNBAS2

        STBD R76,X14,LMODE

        LDBD R20,X14,LMODE

        CMB R20,=1
        JZR LSET

        CMB R20,=0
        JZR LRAS

        CMB R20,=2
        JZR LRAS


! ------------------------------------------------------------
! Other f values: no-op.
! ------------------------------------------------------------

        PAD
        RTN


! ------------------------------------------------------------
! f=1 -- current ROM360 pen, unchanged from v0.07a.
! ------------------------------------------------------------

LSET    LDMD R14,=UNBAS2
        JSB =LNDRAW

        BIN
        PAD
        RTN


! ------------------------------------------------------------
! f=0 / f=2 -- direct CRT raster path.
! ------------------------------------------------------------

LRAS    LDMD R14,=UNBAS2
        JSB =LRAST

        BIN
        PAD
        RTN


! ============================================================
! LNDRAW -- common ROM360 MOVE/DRAW vector path
!
! Uses the raw BASIC coordinates saved by LINE.  MOVE and DRAW
! each consume two REAL values in source order.
! ============================================================

LNDRAW  BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,LX1
        PUMD R40,+R12

        LDMD R40,X14,LY1
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPMOVE
        BYT 360
        BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,LX2
        PUMD R40,+R12

        LDMD R40,X14,LY2
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPDRAW
        BYT 360
        BIN

        RTN


! ============================================================
! LRAST -- direct CRT LINE raster path for f=0 and f=2
!
! Steps:
!
!       1. read current ROM360 SCALE coefficients
!       2. map both BASIC endpoints using MAPXY
!       3. Cohen-Sutherland clip in mapped REAL coordinates
!       4. reject if the segment is completely outside
!       5. convert accepted endpoints to integer CRT coordinates
!       6. convert logical Y to raster Y = 191-Y
!       7. initialize current byte address + bit mask
!       8. run the physically-proven v0.07b integer Bresenham
!
! No plotter output occurs on this path.
! ============================================================

LRAST   BIN

        LDMD R14,=UNBAS2

        JSB =READMAP


! ------------------------------------------------------------
! Map endpoint 1.
! ------------------------------------------------------------

        BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,LX1
        LDMD R50,X14,LY1

        JSB =MAPXY

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,MX1
        STMD R50,X14,MY1


! ------------------------------------------------------------
! Map endpoint 2.
! ------------------------------------------------------------

        LDMD R40,X14,LX2
        LDMD R50,X14,LY2

        JSB =MAPXY

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,MX2
        STMD R50,X14,MY2


! ------------------------------------------------------------
! Build REAL constants 0, 255, 191.
! ------------------------------------------------------------

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CZERO

        LDM R36,=377,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CXMAX

        LDM R36,=277,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CYMAX


! ============================================================
! v0.07c SEGMENT CLIPPING
!
! LCLIP performs Cohen-Sutherland clipping in the mapped REAL
! coordinate space.  This avoids converting an out-of-range REAL
! to a 15-bit integer before it has been clipped.
!
! Return:
!       R20 = 0 -> accepted; MX1/MY1/MX2/MY2 are on-screen
!       R20 = 1 -> trivially rejected / no visible segment
! ============================================================

        LDMD R14,=UNBAS2
        JSB =LCLIP

        BIN

        CMB R20,=0
        JZR LCVRT

        RTN


! ============================================================
! Convert mapped REAL endpoints to integer logical coordinates.
! ============================================================

LCVRT   BIN

        LDMD R14,=UNBAS2

        LDMD R60,X14,MX1
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2
        STBD R76,X14,IX1

        LDMD R60,X14,MY1
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2
        STBD R76,X14,IY1

        LDMD R60,X14,MX2
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2
        STBD R76,X14,IX2

        LDMD R60,X14,MY2
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2
        STBD R76,X14,IY2


! ------------------------------------------------------------
! Logical Y -> physical raster Y.
! ------------------------------------------------------------

        LDB R20,=277
        LDBD R21,X14,IY1
        SBB R20,R21
        STBD R20,X14,LRY1

        LDB R20,=277
        LDBD R21,X14,IY2
        SBB R20,R21
        STBD R20,X14,LRY2


! ============================================================
! Save CRT state used by the direct raster path.
! ============================================================

        LDB R21,=0

        LDBD R20,=CRTWRS

        LRB R20
        TSB R20

        JEV LCFSA

        LDB R21,=1

LCFSA   LDMD R14,=UNBAS2
        STBD R21,X14,CRTFLG

        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT


! ------------------------------------------------------------
! Initialize current CRT byte address and bit mask from endpoint 1.
! ------------------------------------------------------------

        JSB =LINIT


! ------------------------------------------------------------
! Compute dx, dy and X/Y directions.
! ------------------------------------------------------------

        BIN

        LDMD R14,=UNBAS2

        JSB =LDELT


! ============================================================
! Select major axis.  dx and dy are positive 16-bit values.
! ============================================================

        BIN

        LDMD R14,=UNBAS2

        LDMD R46,X14,LDX
        LDMD R56,X14,LDY

        CMM R46,R56
        JNG LYMJR


! ------------------------------------------------------------
! X-major: REM=dx, ERR=dx/2.
! ------------------------------------------------------------

        STMD R46,X14,LREM

        LDM R36,R46
        LRM R37
        STMD R36,X14,LERR

        JSB =LBRESX

        JMP LRFIN


! ------------------------------------------------------------
! Y-major: REM=dy, ERR=dy/2.
! ------------------------------------------------------------

LYMJR   STMD R56,X14,LREM

        LDM R36,R56
        LRM R37
        STMD R36,X14,LERR

        JSB =LBRESY


! ============================================================
! Restore caller's CRT byte address.
! ============================================================

LRFIN   BIN

        LDMD R14,=UNBAS2
        LDMD R34,X14,SAVCRT

        JSB =BYTCR!
        JSB =CHKSTS

        BIN
        RTN


! ============================================================
! LINIT -- initialize LINE raster byte address and pixel mask
!
! Uses IX1 and LRY1.
!
! Result:
!       LADR  = CRT nibble address of first byte
!       LMASK = bit mask of first pixel
! ============================================================

LINIT   BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Row base = 010000 + rasterY * 0100.
! ------------------------------------------------------------

        LDM R30,=0,20

        LDBD R24,X14,LRY1

        CMB R24,=0
        JZR LIXINI

LIYADD  ADM R30,=100,0

        DCB R24
        JNZ LIYADD


! ------------------------------------------------------------
! Determine x byte column and starting bit mask.
! ------------------------------------------------------------

LIXINI  LDB R22,=0
        LDB R23,=200
        LDB R25,=0

        LDBD R24,X14,IX1

        CMB R24,=0
        JZR LIBADR

LIXLOP  LRB R23
        ICB R22

        CMB R22,=10
        JNZ LIXDEC

        LDB R22,=0
        LDB R23,=200
        ICB R25

LIXDEC  DCB R24
        JNZ LIXLOP


! ------------------------------------------------------------
! Add 2 nibble addresses for each graphics byte column.
! ------------------------------------------------------------

LIBADR  LDB R24,R25

        CMB R24,=0
        JZR LISAVE

LIBADD  ADM R30,=2,0

        DCB R24
        JNZ LIBADD

LISAVE  LDMD R14,=UNBAS2

        STMD R30,X14,LADR
        STBD R23,X14,LMASK

        RTN


! ============================================================
! LDELT -- compute Bresenham deltas and directions
!
! LDX / LDY are positive 16-bit binary quantities.
! LXDIR / LYDIR:
!       1 = increment coordinate
!       0 = decrement coordinate
! ============================================================

LDELT   BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! dx = abs(x2-x1)
! ------------------------------------------------------------

        CLM R46
        LDBD R46,X14,IX2

        CLM R56
        LDBD R56,X14,IX1

        SBM R46,R56
        JNG LDXNEG

        STMD R46,X14,LDX

        LDB R20,=1
        STBD R20,X14,LXDIR

        JMP LDYCAL

LDXNEG  TCM R46
        STMD R46,X14,LDX

        LDB R20,=0
        STBD R20,X14,LXDIR


! ------------------------------------------------------------
! dy = abs(rasterY2-rasterY1)
! ------------------------------------------------------------

LDYCAL  CLM R46
        LDBD R46,X14,LRY2

        CLM R56
        LDBD R56,X14,LRY1

        SBM R46,R56
        JNG LDYNEG

        STMD R46,X14,LDY

        LDB R20,=1
        STBD R20,X14,LYDIR

        RTN

LDYNEG  TCM R46
        STMD R46,X14,LDY

        LDB R20,=0
        STBD R20,X14,LYDIR

        RTN


! ============================================================
! LBRESX -- X-major Bresenham driver
!
! LBXIT performs exactly one pixel/step iteration and returns:
!       R20 = 0 -> continue
!       R20 = 1 -> finished
! ============================================================

LBRESX  BIN

LBXDRV  LDMD R14,=UNBAS2
        JSB =LBXIT

        BIN

        CMB R20,=0
        JZR LBXDRV

        RTN


! ============================================================
! LBXIT -- one X-major Bresenham iteration
! ============================================================

LBXIT   BIN

        LDMD R14,=UNBAS2
        JSB =LPIX

        BIN

        LDMD R14,=UNBAS2

        LDMD R36,X14,LREM
        TSM R36
        JNZ LBXGO

        LDB R20,=1
        RTN


! ------------------------------------------------------------
! One major-axis step remains.
! ------------------------------------------------------------

LBXGO   DCM R36
        STMD R36,X14,LREM

        JSB =LSTPX

        BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! ERR -= dy
! ------------------------------------------------------------

        LDMD R36,X14,LERR
        LDMD R46,X14,LDY

        SBM R36,R46
        JNG LBXNEG

        STMD R36,X14,LERR

        LDB R20,=0
        RTN


! ------------------------------------------------------------
! ERR < 0: step Y and ERR += dx.
! ------------------------------------------------------------

LBXNEG  STMD R36,X14,LERR

        JSB =LSTPY

        BIN

        LDMD R14,=UNBAS2

        LDMD R36,X14,LERR
        LDMD R46,X14,LDX

        ADM R36,R46
        STMD R36,X14,LERR

        LDB R20,=0
        RTN


! ============================================================
! LBRESY -- Y-major Bresenham driver
! ============================================================

LBRESY  BIN

LBYDRV  LDMD R14,=UNBAS2
        JSB =LBYIT

        BIN

        CMB R20,=0
        JZR LBYDRV

        RTN


! ============================================================
! LBYIT -- one Y-major Bresenham iteration
! ============================================================

LBYIT   BIN

        LDMD R14,=UNBAS2
        JSB =LPIX

        BIN

        LDMD R14,=UNBAS2

        LDMD R36,X14,LREM
        TSM R36
        JNZ LBYGO

        LDB R20,=1
        RTN


! ------------------------------------------------------------
! One major-axis step remains.
! ------------------------------------------------------------

LBYGO   DCM R36
        STMD R36,X14,LREM

        JSB =LSTPY

        BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! ERR -= dx
! ------------------------------------------------------------

        LDMD R36,X14,LERR
        LDMD R46,X14,LDX

        SBM R36,R46
        JNG LBYNEG

        STMD R36,X14,LERR

        LDB R20,=0
        RTN


! ------------------------------------------------------------
! ERR < 0: step X and ERR += dy.
! ------------------------------------------------------------

LBYNEG  STMD R36,X14,LERR

        JSB =LSTPX

        BIN

        LDMD R14,=UNBAS2

        LDMD R36,X14,LERR
        LDMD R46,X14,LDY

        ADM R36,R46
        STMD R36,X14,LERR

        LDB R20,=0
        RTN


! ============================================================
! LSTPX -- step current pixel one position in X
!
! LXDIR = 1 -> x+1
! LXDIR = 0 -> x-1
!
! LADR and LMASK are updated together, so the Bresenham loop
! never has to recalculate a full CRT address from x,y.
! ============================================================

LSTPX   BIN

        LDMD R14,=UNBAS2

        LDBD R20,X14,LXDIR
        LDBD R23,X14,LMASK

        CMB R20,=0
        JZR LXDWN


! ------------------------------------------------------------
! X + 1: shift mask right; cross byte when it becomes zero.
! ------------------------------------------------------------

        LRB R23
        JNZ LXSAV

        LDB R23,=200

        LDMD R30,X14,LADR
        ADM R30,=2,0
        STMD R30,X14,LADR

LXSAV   STBD R23,X14,LMASK
        RTN


! ------------------------------------------------------------
! X - 1: shift mask left; cross byte when it becomes zero.
! ------------------------------------------------------------

LXDWN   LLB R23
        JNZ LXDSAV

        LDB R23,=1

        LDMD R30,X14,LADR
        SBM R30,=2,0
        STMD R30,X14,LADR

LXDSAV  STBD R23,X14,LMASK
        RTN


! ============================================================
! LSTPY -- step current pixel one physical raster row in Y
!
! LYDIR = 1 -> rasterY+1 -> address +0100 octal
! LYDIR = 0 -> rasterY-1 -> address -0100 octal
! ============================================================

LSTPY   BIN

        LDMD R14,=UNBAS2

        LDBD R20,X14,LYDIR
        LDMD R30,X14,LADR

        CMB R20,=0
        JZR LYDWN

        ADM R30,=100,0
        STMD R30,X14,LADR
        RTN

LYDWN   SBM R30,=100,0
        STMD R30,X14,LADR
        RTN


! ============================================================
! LPIX -- modify one CRT pixel at current LADR / LMASK
!
! LMODE = 0 -> CLEAR
! LMODE = 2 -> XOR
!
! The read path reuses the physically-proven BLOCK rule:
!
!       CRTFLG=0 -> INCHR
!       CRTFLG=1 -> INCHR-
!
! Reading advances the CRT pointer, so LADR is restored before
! writing the modified byte back.
! ============================================================

LPIX    BIN

        LDMD R14,=UNBAS2

        LDMD R34,X14,LADR
        JSB =BYTCR!

        BIN

        LDMD R14,=UNBAS2

        LDBD R40,X14,CRTFLG

        CMB R40,=0
        JZR LPNORM

        JSB =INCHR-
        JMP LPRDON

LPNORM  JSB =INCHR

LPRDON  BIN

        LDB R36,R32

        LDMD R14,=UNBAS2

        LDBD R23,X14,LMASK
        LDBD R40,X14,LMODE

        CMB R40,=0
        JNZ LPXOR


! ------------------------------------------------------------
! CLEAR bit: old AND NOT mask, using proven OR/XOR idiom.
! ------------------------------------------------------------

        ORB R36,R23
        XRB R36,R23
        JMP LPWRIT


! ------------------------------------------------------------
! XOR bit.
! ------------------------------------------------------------

LPXOR   XRB R36,R23


! ------------------------------------------------------------
! Save result, reposition after read, and write byte.
! ------------------------------------------------------------

LPWRIT  STBD R36,X14,LNEW

        LDMD R34,X14,LADR
        JSB =BYTCR!

        BIN

        LDMD R14,=UNBAS2
        LDBD R32,X14,LNEW

        JSB =CHKSTS
        STBD R32,=CRTDAT

        BIN
        RTN



! ============================================================
! LCLIP -- Cohen-Sutherland segment clipper for LINE f=0/f=2
!
! Works entirely on mapped HP REAL coordinates:
!
!       MX1,MY1  -> endpoint 1
!       MX2,MY2  -> endpoint 2
!
! Outcode bits:
!
!       1       LEFT    x < 0
!       2       RIGHT   x > 255
!       4       BOTTOM  y < 0
!       10      TOP     y > 191       (octal bit value = 8 dec)
!
! LCLCHK evaluates accept/reject/clip-one-endpoint state.
! LCLONE computes one boundary intersection and replaces the
! selected endpoint.  A 10-iteration guard prevents pathological
! floating-point round-off from looping indefinitely.
!
! Return:
!       R20 = 0 accepted
!       R20 = 1 rejected
! ============================================================

LCLIP   BIN

        LDMD R14,=UNBAS2

        LDB R20,=10D
        STBD R20,X14,LCCNT

LCLP0   LDMD R14,=UNBAS2
        JSB =LCLCHK

        BIN

        CMB R20,=0
        JNZ LCLNAC

        RTN

LCLNAC  CMB R20,=1
        JNZ LCLSTP

        RTN

LCLSTP  LDMD R14,=UNBAS2
        JSB =LCLONE

        BIN

        LDMD R14,=UNBAS2
        LDBD R20,X14,LCCNT
        DCB R20
        STBD R20,X14,LCCNT

        JNZ LCLP0

        LDB R20,=1
        RTN


! ============================================================
! LCLCHK -- classify current segment
!
! Return:
!       R20 = 0 -> accept
!       R20 = 1 -> reject
!       R20 = 2 -> clip endpoint selected in LSEL, code in LCOUT
! ============================================================

LCLCHK  BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,MX1
        LDMD R50,X14,MY1
        JSB =LCODE

        BIN
        LDMD R14,=UNBAS2
        STBD R20,X14,LCOD1

        LDMD R40,X14,MX2
        LDMD R50,X14,MY2
        JSB =LCODE

        BIN
        LDMD R14,=UNBAS2
        STBD R20,X14,LCOD2


! ------------------------------------------------------------
! Both zero -> trivially accept.
! ------------------------------------------------------------

        LDBD R20,X14,LCOD1
        CMB R20,=0
        JNZ LCCAND

        LDBD R20,X14,LCOD2
        CMB R20,=0
        JNZ LCCAND

        LDB R20,=0
        RTN


! ------------------------------------------------------------
! code1 AND code2 != 0 -> trivially reject.
! R22/R23 and R24/R25 are aligned two-byte register sections.
! ------------------------------------------------------------

LCCAND  CLM R22
        LDBD R22,X14,LCOD1

        CLM R24
        LDBD R24,X14,LCOD2

        ANM R22,R24
        TSM R22
        JZR LCCSEL

        LDB R20,=1
        RTN


! ------------------------------------------------------------
! Select one outside endpoint for the next clipping step.
! ------------------------------------------------------------

LCCSEL  LDBD R20,X14,LCOD1
        CMB R20,=0
        JZR LCCS2

        STBD R20,X14,LCOUT

        LDB R20,=1
        STBD R20,X14,LSEL

        LDB R20,=2
        RTN

LCCS2   LDBD R20,X14,LCOD2
        STBD R20,X14,LCOUT

        LDB R20,=2
        STBD R20,X14,LSEL

        LDB R20,=2
        RTN


! ============================================================
! LCODE -- build Cohen-Sutherland outcode
!
! Input:
!       R40 = x REAL
!       R50 = y REAL
!
! Output:
!       R20 = one-byte outcode
! ============================================================

LCODE   BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,LCTX
        STMD R50,X14,LCTY

        CLB R20
        STBD R20,X14,LCODV


! ------------------------------------------------------------
! LEFT: x < 0
! ------------------------------------------------------------

        LDMD R40,X14,LCTX
        LDMD R50,X14,CZERO
        JSB =COMFLT
        JEN LCDLFT

        BIN
        JMP LCDRCK

LCDLFT  BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,LCODV
        ADB R20,=1
        STBD R20,X14,LCODV


! ------------------------------------------------------------
! RIGHT: x > 255  <=> 255 < x
! ------------------------------------------------------------

LCDRCK  BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,CXMAX
        LDMD R50,X14,LCTX
        JSB =COMFLT
        JEN LCDRGT

        BIN
        JMP LCDBCK

LCDRGT  BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,LCODV
        ADB R20,=2
        STBD R20,X14,LCODV


! ------------------------------------------------------------
! BOTTOM: y < 0
! ------------------------------------------------------------

LCDBCK  BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,LCTY
        LDMD R50,X14,CZERO
        JSB =COMFLT
        JEN LCDBOT

        BIN
        JMP LCDTCK

LCDBOT  BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,LCODV
        ADB R20,=4
        STBD R20,X14,LCODV


! ------------------------------------------------------------
! TOP: y > 191  <=> 191 < y
! ------------------------------------------------------------

LCDTCK  BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,CYMAX
        LDMD R50,X14,LCTY
        JSB =COMFLT
        JEN LCDTOP

        BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,LCODV
        RTN

LCDTOP  BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,LCODV
        ADB R20,=10
        STBD R20,X14,LCODV
        RTN


! ============================================================
! LCLONE -- clip selected endpoint against one boundary
!
! Boundary priority follows the standard Cohen-Sutherland order:
! TOP, BOTTOM, RIGHT, LEFT.
! ============================================================

LCLONE  BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Test TOP bit 10 octal.
! ------------------------------------------------------------

        CLM R22
        LDBD R22,X14,LCOUT
        CLM R24
        LDB R24,=10
        ANM R22,R24
        TSM R22
        JZR LCOBOT

        LDMD R40,X14,CYMAX
        STMD R40,X14,LBOUND

        JSB =LINTY

        BIN
        LDMD R14,=UNBAS2
        JSB =LCREPL
        RTN


! ------------------------------------------------------------
! Test BOTTOM bit 4.
! ------------------------------------------------------------

LCOBOT  CLM R22
        LDBD R22,X14,LCOUT
        CLM R24
        LDB R24,=4
        ANM R22,R24
        TSM R22
        JZR LCORGT

        LDMD R40,X14,CZERO
        STMD R40,X14,LBOUND

        JSB =LINTY

        BIN
        LDMD R14,=UNBAS2
        JSB =LCREPL
        RTN


! ------------------------------------------------------------
! Test RIGHT bit 2.
! ------------------------------------------------------------

LCORGT  CLM R22
        LDBD R22,X14,LCOUT
        CLM R24
        LDB R24,=2
        ANM R22,R24
        TSM R22
        JZR LCOLFT

        LDMD R40,X14,CXMAX
        STMD R40,X14,LBOUND

        JSB =LINTX

        BIN
        LDMD R14,=UNBAS2
        JSB =LCREPL
        RTN


! ------------------------------------------------------------
! LEFT is the only remaining possible bit.
! ------------------------------------------------------------

LCOLFT  LDMD R40,X14,CZERO
        STMD R40,X14,LBOUND

        JSB =LINTX

        BIN
        LDMD R14,=UNBAS2
        JSB =LCREPL
        RTN


! ============================================================
! LINTY -- intersect line with horizontal boundary y=LBOUND
!
!       t = (yb-y1)/(y2-y1)
!       x = x1 + (x2-x1)*t
!       y = yb
!
! Result is stored in LNX/LNY.
! Every HP math result left on R12 is explicitly discarded.
! ============================================================

LINTY   BIN

        LDMD R14,=UNBAS2


! numerator = boundary - y1

        LDMD R50,X14,LBOUND
        LDMD R40,X14,MY1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,LTMP1


! denominator = y2 - y1

        LDMD R50,X14,MY2
        LDMD R40,X14,MY1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,LTMP2


! t = numerator / denominator

        LDMD R50,X14,LTMP1
        LDMD R40,X14,LTMP2
        JSB =DIV10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,LTVAL


! dx = x2 - x1

        LDMD R50,X14,MX2
        LDMD R40,X14,MX1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2


! dx * t

        LDMD R50,X14,LTVAL
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2


! x = x1 + dx*t

        LDMD R50,X14,MX1
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2

        STMD R40,X14,LNX

        LDMD R40,X14,LBOUND
        STMD R40,X14,LNY

        RTN


! ============================================================
! LINTX -- intersect line with vertical boundary x=LBOUND
!
!       t = (xb-x1)/(x2-x1)
!       y = y1 + (y2-y1)*t
!       x = xb
! ============================================================

LINTX   BIN

        LDMD R14,=UNBAS2


! numerator = boundary - x1

        LDMD R50,X14,LBOUND
        LDMD R40,X14,MX1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,LTMP1


! denominator = x2 - x1

        LDMD R50,X14,MX2
        LDMD R40,X14,MX1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,LTMP2


! t = numerator / denominator

        LDMD R50,X14,LTMP1
        LDMD R40,X14,LTMP2
        JSB =DIV10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,LTVAL


! dy = y2 - y1

        LDMD R50,X14,MY2
        LDMD R40,X14,MY1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2


! dy * t

        LDMD R50,X14,LTVAL
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2


! y = y1 + dy*t

        LDMD R50,X14,MY1
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2

        STMD R40,X14,LNY

        LDMD R40,X14,LBOUND
        STMD R40,X14,LNX

        RTN


! ============================================================
! LCREPL -- replace endpoint selected by LSEL with LNX/LNY
! ============================================================

LCREPL  BIN

        LDMD R14,=UNBAS2

        LDBD R20,X14,LSEL
        CMB R20,=1
        JNZ LCRP2

        LDMD R40,X14,LNX
        STMD R40,X14,MX1
        LDMD R40,X14,LNY
        STMD R40,X14,MY1
        RTN

LCRP2   LDMD R40,X14,LNX
        STMD R40,X14,MX2
        LDMD R40,X14,LNY
        STMD R40,X14,MY2
        RTN


! ============================================================
! SHLINE -- internal LINE dispatcher used by composite shapes
!
! Input is held in the proven LINE locals:
!
!       LX1,LY1,LX2,LY2,LFLAG
!
! This deliberately duplicates LINE.'s mode dispatch rather than
! changing the physically-proven LINE runtime itself.
! ============================================================

SHLINE  BIN

        LDMD R14,=UNBAS2
        LDMD R60,X14,LFLAG

        JSB =CONINT

        BIN
        LDMD R14,=UNBAS2

        STBD R76,X14,LMODE
        LDBD R20,X14,LMODE

        CMB R20,=1
        JZR SHSET

        CMB R20,=0
        JZR SHRAS

        CMB R20,=2
        JZR SHRAS

        RTN

SHSET   LDMD R14,=UNBAS2
        JSB =LNDRAW
        BIN
        RTN

SHRAS   LDMD R14,=UNBAS2
        JSB =LRAST
        BIN
        RTN


! ============================================================
! PLMODE / PLMOVE / PLDRAW -- ARC/CIRCLE streamed polyline path
!
! PLMODE converts the composite primitive's REAL SF mode once and caches
! it in LMODE.  PLMOVE emits the initial ROM360 MOVE only for f=1.
! PLDRAW then emits only DRAW endpoints for f=1; f=0/f=2 continue through
! the existing direct CRT LRAST path using SPX/SPY -> PTX/PTY.
!
! This avoids the old per-chord CONINT and, for normal f=1 vector output,
! avoids the redundant MOVE which LNDRAW performs before every DRAW.
! ============================================================

PLMODE  BIN

        LDMD R14,=UNBAS2
        LDMD R60,X14,SF
        JSB =CONINT

        BIN
        LDMD R14,=UNBAS2
        STBD R76,X14,LMODE
        RTN


! Initial polyline position: only vector SET mode has a ROM360 current point.

PLMOVE  BIN

        LDMD R14,=UNBAS2
        LDBD R20,X14,LMODE
        CMB R20,=1
        JZR PLMV1
        RTN

PLMV1   LDMD R40,X14,SPX
        PUMD R40,+R12

        LDMD R40,X14,SPY
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPMOVE
        BYT 360
        BIN
        RTN


! Draw one polyline segment from SPX/SPY to PTX/PTY.

PLDRAW  BIN

        LDMD R14,=UNBAS2
        LDBD R20,X14,LMODE

        CMB R20,=1
        JZR PLDSET

        CMB R20,=0
        JZR PLDRAS

        CMB R20,=2
        JZR PLDRAS

        RTN


! f=1: current ROM360 position is already SPX/SPY; send only new endpoint.

PLDSET  LDMD R40,X14,PTX
        PUMD R40,+R12

        LDMD R40,X14,PTY
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPDRAW
        BYT 360
        BIN
        RTN


! f=0/f=2: retain the proven CRT raster line path.

PLDRAS  LDMD R14,=UNBAS2

        LDMD R40,X14,SPX
        STMD R40,X14,LX1
        LDMD R40,X14,SPY
        STMD R40,X14,LY1
        LDMD R40,X14,PTX
        STMD R40,X14,LX2
        LDMD R40,X14,PTY
        STMD R40,X14,LY2

        JSB =LRAST
        BIN
        RTN


! ============================================================
! REC RUNTIME
!
!       REC x,y,b,h,f
!
! x,y is the upper-left corner in Simons coordinates.  Four LINE
! segments are emitted.  Because LINE includes both endpoints,
! f=2 naturally reproduces the original Simons double-XOR corner
! behaviour.
! ============================================================

        BYT 241

REC.    SAD
        BIN
        LDMD R14,=UNBAS2

        JSB =ONER
        BIN
        STMD R#,X14,REF

        JSB =ONER
        BIN
        STMD R#,X14,REH

        JSB =ONER
        BIN
        STMD R#,X14,REB

        JSB =ONER
        BIN
        STMD R#,X14,REY

        JSB =ONER
        BIN
        STMD R#,X14,REX


! x2 = x + b

        LDMD R40,X14,REX
        LDMD R50,X14,REB
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,REX2


! y2 = y + h

        LDMD R40,X14,REY
        LDMD R50,X14,REH
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,REY2


! top: (x,y) -> (x2,y)

        LDMD R40,X14,REX
        STMD R40,X14,LX1
        LDMD R40,X14,REY
        STMD R40,X14,LY1
        LDMD R40,X14,REX2
        STMD R40,X14,LX2
        LDMD R40,X14,REY
        STMD R40,X14,LY2
        LDMD R40,X14,REF
        STMD R40,X14,LFLAG
        JSB =SHLINE


! right: (x2,y) -> (x2,y2)

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,REX2
        STMD R40,X14,LX1
        LDMD R40,X14,REY
        STMD R40,X14,LY1
        LDMD R40,X14,REX2
        STMD R40,X14,LX2
        LDMD R40,X14,REY2
        STMD R40,X14,LY2
        LDMD R40,X14,REF
        STMD R40,X14,LFLAG
        JSB =SHLINE


! bottom: (x2,y2) -> (x,y2)

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,REX2
        STMD R40,X14,LX1
        LDMD R40,X14,REY2
        STMD R40,X14,LY1
        LDMD R40,X14,REX
        STMD R40,X14,LX2
        LDMD R40,X14,REY2
        STMD R40,X14,LY2
        LDMD R40,X14,REF
        STMD R40,X14,LFLAG
        JSB =SHLINE


! left: (x,y2) -> (x,y)

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,REX
        STMD R40,X14,LX1
        LDMD R40,X14,REY2
        STMD R40,X14,LY1
        LDMD R40,X14,REX
        STMD R40,X14,LX2
        LDMD R40,X14,REY
        STMD R40,X14,LY2
        LDMD R40,X14,REF
        STMD R40,X14,LFLAG
        JSB =SHLINE

        BIN
        PAD
        RTN


! ============================================================
! TRGON / TRGOFF -- temporarily force degree-mode trig
!
! Simons ARC/ANGL angles are degrees independent of the HP-85's
! current DEG/RAD setting.  Save the HP system DRG byte, call DEG.,
! then restore that exact byte after the composite primitive.
! ============================================================

TRGON   BIN

        LDBD R20,=DRG
        LDMD R14,=UNBAS2
        STBD R20,X14,SDRG

        JSB =ROMJSB
        DEF DEG.
        BYT 0
        BIN
        RTN

TRGOFF  BIN

        LDMD R14,=UNBAS2
        LDBD R20,X14,SDRG
        STBD R20,=DRG

        RTN


! ============================================================
! ANGPT -- ellipse point from Simons angle
!
! Shared input:
!       SMX,SMY = centre
!       SRX,SRY = radii
!       SANG    = degrees
!
! Output:
!       PTX = mx + rx*SIN(angle)
!       PTY = my - ry*COS(angle)
!
! Thus 0 degrees is above the centre and 90 degrees is right.
! TRGON must have been called by the owner before entry.
! ============================================================

ANGPT   BIN

        LDMD R14,=UNBAS2


! X = mx + rx*sin(angle)

        LDMD R40,X14,SANG
        PUMD R40,+R12
        BCD
        JSB =SIN10
        POMD R70,-R12
        BIN

        LDMD R14,=UNBAS2
        LDMD R50,X14,SRX
        JSB =MPY10
        POMD R70,-R12
        BIN

        LDMD R14,=UNBAS2
        LDMD R50,X14,SMX
        JSB =ADD10
        POMD R70,-R12
        BIN

        LDMD R14,=UNBAS2
        STMD R40,X14,PTX


! Y = my - ry*cos(angle)

        LDMD R40,X14,SANG
        PUMD R40,+R12
        BCD
        JSB =COS10
        POMD R70,-R12
        BIN

        LDMD R14,=UNBAS2
        LDMD R50,X14,SRY
        JSB =MPY10
        POMD R70,-R12
        BIN

        LDMD R14,=UNBAS2
        LDMD R50,X14,SMY
        JSB =SUB10
        POMD R70,-R12
        BIN

        LDMD R14,=UNBAS2
        STMD R40,X14,PTY

        RTN


! ============================================================
! ANGL RUNTIME
!
!       ANGL x,y,w,rx,ry,f
! ============================================================

        BYT 241

ANGL.   SAD
        BIN
        LDMD R14,=UNBAS2

        JSB =ONER
        BIN
        STMD R#,X14,SF

        JSB =ONER
        BIN
        STMD R#,X14,SRY

        JSB =ONER
        BIN
        STMD R#,X14,SRX

        JSB =ONER
        BIN
        STMD R#,X14,SANG

        JSB =ONER
        BIN
        STMD R#,X14,SMY

        JSB =ONER
        BIN
        STMD R#,X14,SMX

        JSB =TRGON

        BIN
        LDMD R14,=UNBAS2
        JSB =ANGPT

        BIN
        LDMD R14,=UNBAS2
        JSB =TRGOFF


! centre -> calculated perimeter point

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,SMX
        STMD R40,X14,LX1
        LDMD R40,X14,SMY
        STMD R40,X14,LY1
        LDMD R40,X14,PTX
        STMD R40,X14,LX2
        LDMD R40,X14,PTY
        STMD R40,X14,LY2
        LDMD R40,X14,SF
        STMD R40,X14,LFLAG

        JSB =SHLINE

        BIN
        PAD
        RTN


! ============================================================
! ARC RUNTIME
!
!       ARC mx,my,ws,we,ww,rx,ry,f
!
! If we < ws, the end angle is treated as a forward wrap through
! 360 degrees (for example 330 -> 30 becomes 330 -> 390).
! ww must be positive; zero/negative step safely produces no arc.
! ============================================================

        BYT 241

ARC.    SAD
        BIN
        LDMD R14,=UNBAS2

        JSB =ONER
        BIN
        STMD R#,X14,SF

        JSB =ONER
        BIN
        STMD R#,X14,SRY

        JSB =ONER
        BIN
        STMD R#,X14,SRX

        JSB =ONER
        BIN
        STMD R#,X14,SWW

        JSB =ONER
        BIN
        STMD R#,X14,SWE

        JSB =ONER
        BIN
        STMD R#,X14,SWS

        JSB =ONER
        BIN
        STMD R#,X14,SMY

        JSB =ONER
        BIN
        STMD R#,X14,SMX

        JSB =TRGON

        BIN
        LDMD R14,=UNBAS2
        JSB =ARCDRW

        BIN
        LDMD R14,=UNBAS2
        JSB =TRGOFF

        BIN
        PAD
        RTN


! ============================================================
! CIRCLE RUNTIME -- v0.08b
!
!       CIRCLE x,y,rx,ry,f[,n]
!
! n omitted:
!       Original Simons' BASIC behaviour: 30 segments / 12 degrees.
!
! n present:
!       Exactly n segments, with nominal angular step 360/n.
!       Valid range is 3..360.  The final endpoint is forced to
!       exactly 360 degrees so accumulated REAL rounding cannot
!       create an extra tiny closing segment.
!
! Optional-parameter detection uses the same TOS/R12 technique as
! HP's documented GCURSOR sample.  Six REAL arguments occupy
! 6*8 = 48 decimal = 060 octal bytes on R12.
! ============================================================

        BYT 241

CIRCL.  SAD
        BIN
        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Default n = 30 decimal = 036 octal.
! ------------------------------------------------------------

        LDM R30,=36,0
        STMD R30,X14,CNSEG


! ------------------------------------------------------------
! Is the optional sixth argument present?
!
! HP GCURSOR pattern:
!       R12 - argument_bytes == TOS  -> that many args present
! ------------------------------------------------------------

        LDM R20,R12
        SBM R20,=60,0
        CMMD R20,=TOS
        JNZ CARGF


! ------------------------------------------------------------
! n -- optional segment count.
! ------------------------------------------------------------

        JSB =ONER
        BIN
        STMD R#,X14,SNSEG

        LDMD R60,X14,SNSEG
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2
        STMD R76,X14,CNSEG


! Require n >= 3.

        LDM R46,R76
        SBM R46,=3,0
        JNG CINVL


! Require n <= 360 decimal = 0550 octal = 0150,0001.

        LDM R46,=150,1
        SBM R46,R76
        JNG CINVL

        JMP CARGF


! Invalid optional segment count.

CINVL   JSB =ERRORP
        BYT 89D


! ------------------------------------------------------------
! Required arguments, reverse order from R12.
! ------------------------------------------------------------

CARGF   LDMD R14,=UNBAS2

        JSB =ONER
        BIN
        STMD R#,X14,SF

        JSB =ONER
        BIN
        STMD R#,X14,SRY

        JSB =ONER
        BIN
        STMD R#,X14,SRX

        JSB =ONER
        BIN
        STMD R#,X14,SMY

        JSB =ONER
        BIN
        STMD R#,X14,SMX


! ------------------------------------------------------------
! Build REAL 360.
! ------------------------------------------------------------

        LDM R36,=150,1
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,S360


! ------------------------------------------------------------
! Convert binary n back to REAL and calculate ww = 360/n.
!
! DIV10 convention used elsewhere in SIMON85:
!       result = R50 / R40
!       result also appears on R12 and must be discarded here.
! ------------------------------------------------------------

        LDMD R36,X14,CNSEG
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,SNSEG

        LDMD R50,X14,S360
        LDMD R40,X14,SNSEG
        JSB =DIV10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,SWW


! ------------------------------------------------------------
! Generate exactly CNSEG chords.
! ------------------------------------------------------------

        JSB =TRGON

        BIN
        LDMD R14,=UNBAS2
        JSB =CIRDRW

        BIN
        LDMD R14,=UNBAS2
        JSB =TRGOFF

        BIN
        PAD
        RTN


! ============================================================
! RINIT / RSTEP / RPOINT -- ARC/CIRCLE incremental trig engine
!
! RINIT input:
!       SANG  = starting angle in degrees
!       SWW   = angular increment in degrees
!
! Persistent recurrence state:
!       RSIN  = sin(current angle)
!       RCOS  = cos(current angle)
!       RDSIN = sin(step)
!       RDCOS = cos(step)
!
! RINIT evaluates the four trig values once and emits the starting PTX/PTY.
! RSTEP advances one full SWW increment without SIN10/COS10 and emits PTX/PTY.
! RPOINT converts the current RSIN/RCOS pair to the ellipse user coordinate.
!
! TRGON must have been called by the owner before RINIT.
! ============================================================

RINIT   BIN

        LDMD R14,=UNBAS2


! sin(start)

        LDMD R40,X14,SANG
        PUMD R40,+R12
        BCD
        JSB =SIN10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,RSIN


! cos(start)

        LDMD R40,X14,SANG
        PUMD R40,+R12
        BCD
        JSB =COS10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,RCOS


! sin(step)

        LDMD R40,X14,SWW
        PUMD R40,+R12
        BCD
        JSB =SIN10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,RDSIN


! cos(step)

        LDMD R40,X14,SWW
        PUMD R40,+R12
        BCD
        JSB =COS10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,RDCOS

        JSB =RPOINT
        RTN


! ------------------------------------------------------------
! RSTEP -- advance current sin/cos by one complete SWW step.
!
! newSin = oldSin*stepCos + oldCos*stepSin
! newCos = oldCos*stepCos - oldSin*stepSin
! ------------------------------------------------------------

RSTEP   BIN

        LDMD R14,=UNBAS2


! RTMP = oldSin * stepCos

        LDMD R40,X14,RSIN
        LDMD R50,X14,RDCOS
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,RTMP


! RNEW = RTMP + oldCos * stepSin

        LDMD R40,X14,RCOS
        LDMD R50,X14,RDSIN
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        LDMD R50,X14,RTMP
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,RNEW


! RTMP = oldCos * stepCos

        LDMD R40,X14,RCOS
        LDMD R50,X14,RDCOS
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,RTMP


! newCos = RTMP - oldSin * stepSin

        LDMD R40,X14,RSIN
        LDMD R50,X14,RDSIN
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        LDMD R50,X14,RTMP
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,RCOS


! Commit newSin only after newCos has consumed oldSin.

        LDMD R40,X14,RNEW
        STMD R40,X14,RSIN

        JSB =RPOINT
        RTN


! ------------------------------------------------------------
! RPOINT -- ellipse point from current recurrence sin/cos state.
!
!       PTX = mx + rx*RSIN
!       PTY = my - ry*RCOS
! ------------------------------------------------------------

RPOINT  BIN

        LDMD R14,=UNBAS2


! X = mx + rx*sin

        LDMD R40,X14,RSIN
        LDMD R50,X14,SRX
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        LDMD R50,X14,SMX
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,PTX


! Y = my - ry*cos

        LDMD R40,X14,RCOS
        LDMD R50,X14,SRY
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        LDMD R50,X14,SMY
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,PTY

        RTN


! ============================================================
! CIRDRW -- counted full-ellipse polyline generator
!
! Uses SMX,SMY,SRX,SRY,SF,SWW,S360,CNSEG.
! TRGON must have been called by the owner.
!
! Unlike ARCDRW, this routine is driven by a binary segment count.
! The last endpoint is explicitly set to 360 degrees.  Therefore exactly n
! chord endpoints are emitted even when 360/n is not exactly representable
! as an HP REAL.  f=1 uses one initial MOVE followed by n DRAW calls.
! ============================================================

CIRDRW  BIN

        LDMD R14,=UNBAS2


! REAL 0 and initial angle.

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,SZERO
        STMD R40,X14,SANG


! First perimeter point at 0 degrees and recurrence setup.
! RINIT also evaluates SIN/COS of SWW once for all ordinary chords.

        JSB =RINIT

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,PTX
        STMD R40,X14,SPX
        LDMD R40,X14,PTY
        STMD R40,X14,SPY


! Cache f once.  For f=1 position ROM360 once at the initial point; all
! following ordinary/final endpoints are streamed with DRAW only.

        JSB =PLMODE

        BIN
        LDMD R14,=UNBAS2
        JSB =PLMOVE

        BIN
        LDMD R14,=UNBAS2


! Remaining segment counter = n.

        LDMD R30,X14,CNSEG
        STMD R30,X14,CREM


! Keep the outer loop deliberately short so every relative branch
! remains comfortably in range.  CIRSTP emits one chord.

CDLOOP  LDMD R14,=UNBAS2
        JSB =CIRSTP

        BIN
        CMB R20,=1
        JZR CDDONE

        JMP CDLOOP

CDDONE  RTN


! ============================================================
! CIRSTP -- generate/draw one counted CIRCLE chord
!
! Return:
!       R20=0  chord drawn, more remain
!       R20=1  final chord drawn
! ============================================================

CIRSTP  BIN

        LDMD R14,=UNBAS2


! Decrement remaining count first.  When it reaches zero this is
! the final chord and its endpoint is forced to exactly 360 degrees.

        LDMD R30,X14,CREM
        DCM R30
        STMD R30,X14,CREM

        TSM R30
        JZR CILAST


! Not the final chord: next = current + step.

        LDMD R40,X14,SANG
        LDMD R50,X14,SWW
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,SNXT

        JMP CINEXT


! Final chord: preserve v0.11c exact-angle closure at 360 degrees.
! This exceptional endpoint still uses ANGPT; normal chords use RSTEP.

CILAST  BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,S360
        STMD R40,X14,SNXT
        STMD R40,X14,SANG

        JSB =ANGPT
        JMP CIDRAW


! Ordinary complete step: keep SANG for end/count semantics, but derive
! the coordinate from the incremental sin/cos recurrence.

CINEXT  LDMD R40,X14,SNXT
        STMD R40,X14,SANG

        JSB =RSTEP


! Draw previous point -> new point using cached composite mode.
! f=1 streams only the new endpoint; f=0/f=2 retain LRAST.

CIDRAW  BIN
        LDMD R14,=UNBAS2
        JSB =PLDRAW


! New point becomes previous point.

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,PTX
        STMD R40,X14,SPX
        LDMD R40,X14,PTY
        STMD R40,X14,SPY


! Signal whether that was the final chord.

        LDMD R30,X14,CREM
        TSM R30
        JZR CIDONE

        LDB R20,=0
        RTN

CIDONE  LDB R20,=1
        RTN


! ============================================================
! ARCDRW -- ARC polyline generator
!
! Uses SMX,SMY,SWS,SWE,SWW,SRX,SRY,SF.
! TRGON must have been called by the owner.
! ============================================================

ARCDRW  BIN

        LDMD R14,=UNBAS2


! REAL 0

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,SZERO


! REAL 360

        LDM R36,=150,1
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,S360


! Require ww > 0.  COMFLT sets E when R40 < R50.

        LDMD R40,X14,SZERO
        LDMD R50,X14,SWW
        JSB =COMFLT
        JEN ADRPOS

        BIN
        RTN

ADRPOS  BIN
        LDMD R14,=UNBAS2


! Effective end = we; if we < ws, wrap end forward by 360.

        LDMD R40,X14,SWE
        STMD R40,X14,SEND

        LDMD R40,X14,SEND
        LDMD R50,X14,SWS
        JSB =COMFLT
        JEN ADRWRP

        BIN
        JMP ADRINI

ADRWRP  BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,SEND
        LDMD R50,X14,S360
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,SEND

ADRINI  BIN
        LDMD R14,=UNBAS2

        LDMD R40,X14,SWS
        STMD R40,X14,SANG

! Initialize sin/cos at the requested start angle and cache sin/cos(ww).

        JSB =RINIT

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,PTX
        STMD R40,X14,SPX
        LDMD R40,X14,PTY
        STMD R40,X14,SPY


! Do not emit an initial MOVE for a zero-length ARC.  Only establish the
! streamed polyline when start < effective end and at least one segment will
! actually be generated.

        LDMD R40,X14,SANG
        LDMD R50,X14,SEND
        JSB =COMFLT
        JEN ADRPLN

        BIN
        RTN

ADRPLN  BIN
        LDMD R14,=UNBAS2
        JSB =PLMODE

        BIN
        LDMD R14,=UNBAS2
        JSB =PLMOVE

        BIN
        LDMD R14,=UNBAS2


! Short outer loop.  ARCSTP performs one segment and returns
! R20=1 when there is no more work.

ADRLOP  LDMD R14,=UNBAS2
        JSB =ARCSTP

        BIN
        CMB R20,=1
        JZR ADRDON

        JMP ADRLOP

ADRDON  RTN


! ============================================================
! ARCSTP -- generate/draw one ARC polyline segment
!
! Return:
!       R20=0  segment drawn, call again
!       R20=1  current angle has reached the effective end
! ============================================================

ARCSTP  BIN

        LDMD R14,=UNBAS2


! If current angle is not less than end, we are done.

        LDMD R40,X14,SANG
        LDMD R50,X14,SEND
        JSB =COMFLT
        JEN ASGO

        BIN
        LDB R20,=1
        RTN

ASGO    BIN
        LDMD R14,=UNBAS2


! next = current + step

        LDMD R40,X14,SANG
        LDMD R50,X14,SWW
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,SNXT


! If end < next, clamp next to end.

        LDMD R40,X14,SEND
        LDMD R50,X14,SNXT
        JSB =COMFLT
        JEN ASCLMP

        BIN
        JMP ASKEEP

ASCLMP  BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,SEND
        STMD R40,X14,SNXT
        STMD R40,X14,SANG

! Residual step shorter than ww: preserve exact v0.11c endpoint semantics.

        JSB =ANGPT
        JMP ASDRAW

ASKEEP  BIN
        LDMD R14,=UNBAS2

        LDMD R40,X14,SNXT
        STMD R40,X14,SANG

! Full ww step: use cached incremental rotation instead of SIN10/COS10.

        JSB =RSTEP


! Draw previous point -> new point using cached composite mode.
! f=1 streams only the new endpoint; f=0/f=2 retain LRAST.

ASDRAW  BIN
        LDMD R14,=UNBAS2
        JSB =PLDRAW


! New point becomes previous point.

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,PTX
        STMD R40,X14,SPX
        LDMD R40,X14,PTY
        STMD R40,X14,SPY

        LDB R20,=0
        RTN


! ============================================================
! PAINT RUNTIME -- v0.09l BIDIRECTIONAL INDEXED-LIST PAINT
!
!       PAINT x,y,f
!
! The seed coordinate is mapped through ROM360 SCALE.  The mapped
! pixel coordinate is retained internally as a 16-bit X/Y pair.
! The HP-85 backend currently accepts only X=0..255, Y=0..191,
! but the PAINT work-stack and internal pixel interface are not
! byte-sized so a wider raster backend can be substituted later.
!
! Fill rule:
!       determine the original seed bit (PSRC)
!       derive target bit PTARG from f
!       scanline-fill the connected 4-neighbour region
!
! f=0 -> target bit 0
! f=1 -> target bit 1
! f=2 -> target bit NOT seed bit (toggle whole connected region)
!
! PAINT is CRT-only; no plotter output is generated.
! ============================================================

        BYT 241

PAINT.  SAD
        BIN
        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Arguments arrive in reverse order from R12: f, y, x.
! ------------------------------------------------------------

        JSB =ONER
        BIN
        STMD R#,X14,PF

        JSB =ONER
        BIN
        STMD R#,X14,PY

        JSB =ONER
        BIN
        STMD R#,X14,PX


! ------------------------------------------------------------
! Convert/validate f.
! ------------------------------------------------------------

        LDMD R60,X14,PF
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2
        STBD R76,X14,PMODE

        CMB R76,=0
        JZR PMOK
        CMB R76,=1
        JZR PMOK
        CMB R76,=2
        JZR PMOK

PINVL   JSB =ERRORP
        BYT 89D


! ------------------------------------------------------------
! Map the seed point using active ROM360 SCALE coefficients.
! ------------------------------------------------------------

PMOK    JSB =READMAP

        BIN
        LDMD R14,=UNBAS2
        LDMD R40,X14,PX
        LDMD R50,X14,PY
        JSB =MAPXY

        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,MX1
        STMD R50,X14,MY1
        STMD R40,X14,MX2
        STMD R50,X14,MY2


! ------------------------------------------------------------
! Build REAL clipping constants and reuse the proven point form
! of LCLIP.  A zero-length segment is accepted iff the point lies
! on-screen.
! ------------------------------------------------------------

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CZERO

        LDM R36,=377,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CXMAX

        LDM R36,=277,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CYMAX

        JSB =LCLIP
        BIN
        CMB R20,=0
        JZR PCVRT

        PAD
        RTN


! ------------------------------------------------------------
! Convert mapped seed to 16-bit logical pixel coordinates.
! The HP-85 backend has already clipped X/Y to 8-bit ranges.
! Take the proven low result byte from CONINT and zero-extend it
! explicitly into PAINT's 16-bit coordinate representation.
! ------------------------------------------------------------

PCVRT   LDMD R14,=UNBAS2

        LDMD R60,X14,MX1
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2

! HP-85 backend range is already clipped to 0..255.
! Preserve the 16-bit PAINT interface, but explicitly zero-extend
! the proven low result byte instead of assuming R77 is defined.

        CLM R46
        LDB R46,R76
        STMD R46,X14,PXC

        LDMD R60,X14,MY1
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2

! Y is already clipped to 0..191, so the same zero-extension is
! correct for the current HP-85 raster backend.

        CLM R46
        LDB R46,R76
        STMD R46,X14,PYC


! ------------------------------------------------------------
! Sample CRT read mode and save caller's CRT byte address.
! ------------------------------------------------------------

        LDB R21,=0
        LDBD R20,=CRTWRS
        LRB R20
        TSB R20
        JEV PCFSA
        LDB R21,=1

PCFSA   LDMD R14,=UNBAS2
        STBD R21,X14,CRTFLG
        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT


! ------------------------------------------------------------
! Read seed row and obtain seed bit.
! ------------------------------------------------------------

        JSB =PRDROW

        BIN
        LDMD R14,=UNBAS2
        JSB =PGET
        STBD R20,X14,PSRC


! ------------------------------------------------------------
! Derive target bit.
! ------------------------------------------------------------

        LDBD R21,X14,PMODE
        CMB R21,=0
        JZR PTZERO
        CMB R21,=1
        JZR PTONE

! XOR: target = 1 - source.

        LDB R22,=1
        LDBD R20,X14,PSRC
        SBB R22,R20
        STBD R22,X14,PTARG
        JMP PTDONE

PTZERO  LDB R22,=0
        STBD R22,X14,PTARG
        JMP PTDONE

PTONE   LDB R22,=1
        STBD R22,X14,PTARG


! ------------------------------------------------------------
! SET/CLEAR are no-ops if the seed already has target state.
! XOR always changes state by construction.
! ------------------------------------------------------------

PTDONE  LDBD R20,X14,PSRC
        LDBD R21,X14,PTARG
        CMB R20,R21
        JNZ PINIT

        LDBD R22,X14,PMODE
        CMB R22,=2
        JZR PINIT

        JSB =PREST
        BIN
        PAD
        RTN


! ------------------------------------------------------------
! v0.09l: BIDIRECTIONAL INDEXED WORK-LIST FILL.
!
! v0.09k physically proved the complete repeated indexed DOWN-list path,
! including branching, rejoining and stale-seed rejection.  v0.09l keeps
! that DOWN implementation unchanged and adds the symmetric indexed UP list.
!
! For every successfully filled scanline:
!
!       1. scan logical row y-1 within [PLFT,PRGT] and queue every
!          contiguous PSRC run on the DOWN list
!       2. scan logical row y+1 within [PLFT,PRGT] and queue every
!          contiguous PSRC run on the UP list
!       3. return to the dispatcher
!
! The dispatcher processes DOWN entries whenever available; if DOWN is
! empty it processes one UP entry.  Processing either direction may queue
! new entries in both lists, so filling ends only when BOTH counts are zero.
!
! PDCNT / PUCNT are one-byte entry counts.  Push/pop always recompute:
!
!       address = UNBAS2 + PDSTK/PUSTK + (index * 4)
!
! Each entry is four bytes: Xlo,Xhi,Ylo,Yhi.  PFSEED remains the proven
! one-row dynamic-span primitive.  PFKACT ensures stale duplicate entries
! do not propagate using old span state.
! ------------------------------------------------------------

PINIT   LDMD R14,=UNBAS2

! Empty both indexed directional lists.

        LDB R20,=0
        STBD R20,X14,PDCNT
        STBD R20,X14,PUCNT
        STBD R20,X14,PFKACT

! Fill the original mapped seed row using the proven PFSEED primitive.

        JSB =PFSEED

! The original seed is known to be a valid source pixel here because the
! SET/CLEAR no-op case was handled before PINIT.  Queue both neighbours.

        JSB =PFLINK


! ============================================================
! PFLLOP -- drain both indexed directional work lists.
!
! DOWN is tried first.  When it is empty, one UP entry is tried.  Any
! successfully filled row may create fresh work in either direction, so
! every completed item returns here rather than draining one list in a
! separate phase.
! ============================================================

PFLLOP  BIN
        LDMD R14,=UNBAS2
        JSB =POPD

        BIN
        CMB R20,=0
        JNZ PFLTRY

! Process one DOWN seed.

        LDMD R14,=UNBAS2
        LDB R20,=0
        STBD R20,X14,PFKACT
        JSB =PFSEED

        BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,PFKACT
        CMB R20,=0
        JZR PFLLOP

        JSB =PFLINK
        JMP PFLLOP


! DOWN empty: try one UP seed.  If UP is also empty, fill is complete.

PFLTRY  BIN
        LDMD R14,=UNBAS2
        JSB =POPU

        BIN
        CMB R20,=0
        JZR PFLUGO

! Both lists empty: restore caller CRT pointer and return.  Keep this epilogue
! local so CAPASM never needs a long relative branch to a distant exit label.

        LDMD R14,=UNBAS2
        JSB =PREST
        BIN
        PAD
        RTN

PFLUGO  LDMD R14,=UNBAS2
        LDB R20,=0
        STBD R20,X14,PFKACT
        JSB =PFSEED

        BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,PFKACT
        CMB R20,=0
        JZR PFLLOP

        JSB =PFLINK
        JMP PFLLOP


! ============================================================
! PFLINK -- queue all adjacent source-colour runs for the scanline most
! recently filled by PFSEED.  PSEEDY and [PLFT,PRGT] describe that row.
! ============================================================

PFLINK  BIN
        LDMD R14,=UNBAS2

! Logical row below: y-1, if present.

        LDMD R46,X14,PSEEDY
        TSM R46
        JZR PFLUP

        DCM R46
        STMD R46,X14,PYC
        JSB =PSCAND


! Logical row above: y+1, if present.

PFLUP   BIN
        LDMD R14,=UNBAS2
        LDMD R46,X14,PSEEDY
        LDM R56,=277,0
        SBM R56,R46
        JZR PFLRST

        ICM R46
        STMD R46,X14,PYC
        JSB =PSCANU


! Restore PYC to the filled row before returning.

PFLRST  BIN
        LDMD R14,=UNBAS2
        LDMD R46,X14,PSEEDY
        STMD R46,X14,PYC
        RTN


! ============================================================
! PFSEED -- process exactly one seed in PXC/PYC.
!
! This remains the hardware-proven one-row primitive:
! re-read row, reject stale seed, expand to the true row boundaries,
! fill/write one complete span, then return.  It deliberately performs
! NO neighbour scanning itself; v0.09l performs that in PFLINK.
!
! PFKACT is set to 1 only after the seed has passed
! PMATCH.  The outer dispatcher uses this to avoid scanning neighbours
! after a stale/duplicate list entry.
! ============================================================

PFSEED  BIN
        LDMD R14,=UNBAS2

! Read the seed row and reject a stale/duplicate seed.

        JSB =PRDROW

        BIN
        LDMD R14,=UNBAS2
        JSB =PMATCH

        BIN
        CMB R20,=0
        JNZ PFSGO
        RTN


! Preserve this seed and initialise its left boundary.

PFSGO   LDMD R14,=UNBAS2

! Mark that this queued seed really represents an unfilled source span.

        LDB R20,=1
        STBD R20,X14,PFKACT

        LDMD R46,X14,PXC
        STMD R46,X14,PSEEDX
        STMD R46,X14,PLFT

        LDMD R46,X14,PYC
        STMD R46,X14,PSEEDY


! ------------------------------------------------------------
! Expand left to X=0 or first non-source pixel.
! ------------------------------------------------------------

PFSLEF  LDMD R46,X14,PLFT
        TSM R46
        JZR PFSRST

        DCM R46
        STMD R46,X14,PXC

        JSB =PMATCH

        BIN
        CMB R20,=0
        JZR PFSRST

        LDMD R14,=UNBAS2
        LDMD R46,X14,PXC
        STMD R46,X14,PLFT
        JMP PFSLEF


! ------------------------------------------------------------
! Expand right from the row seed to X=255 or first non-source pixel.
! ------------------------------------------------------------

PFSRST  LDMD R14,=UNBAS2
        LDMD R46,X14,PSEEDX
        STMD R46,X14,PXC
        STMD R46,X14,PRGT

PFSRGT  LDMD R46,X14,PRGT
        LDM R56,=377,0
        SBM R56,R46
        JZR PFSFIL

        ICM R46
        STMD R46,X14,PXC

        JSB =PMATCH

        BIN
        CMB R20,=0
        JZR PFSFIL

        LDMD R14,=UNBAS2
        LDMD R46,X14,PXC
        STMD R46,X14,PRGT
        JMP PFSRGT


! ------------------------------------------------------------
! Fill the inclusive span [PLFT,PRGT] in ROWBUF.
! ------------------------------------------------------------

PFSFIL  LDMD R14,=UNBAS2
        LDMD R46,X14,PLFT
        STMD R46,X14,PXC

PFSFLP  JSB =PPUT

        BIN
        LDMD R14,=UNBAS2
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PFSWRT

        ICM R46
        STMD R46,X14,PXC
        JMP PFSFLP


! Write this one row and restore PYC to its seed row.

PFSWRT  JSB =PWRROW

        BIN
        LDMD R14,=UNBAS2
        LDMD R46,X14,PSEEDY
        STMD R46,X14,PYC
        RTN


! ============================================================
! PREST -- restore caller's CRT byte pointer after PAINT row reads.
! ============================================================

PREST   BIN
        LDMD R14,=UNBAS2
        LDMD R34,X14,SAVCRT
        JSB =BYTCR!
        JSB =CHKSTS
        BIN
        RTN


! ============================================================
! PRDROW / PWRROW -- HP-85 backend row access for PAINT.
!
! Input PYC is a 16-bit logical pixel Y.  PROWAD converts it to
! the HP-85 physical raster row and returns its CRT nibble address
! in R46/R47.  READROW/WRTROW remain the proven 32-byte primitives.
! ============================================================

PRDROW  BIN
        LDMD R14,=UNBAS2
        JSB =PROWAD
        JSB =READROW
        RTN

PWRROW  BIN
        LDMD R14,=UNBAS2
        JSB =PROWAD
        JSB =WRTROW
        RTN


! ============================================================
! PROWAD -- HP-85-specific row-address backend.
!
! logical Y 0..191 -> physical row 191-Y
! row base = 010000 + physicalRow * 0100 nibble addresses
! ============================================================

PROWAD  BIN
        LDMD R14,=UNBAS2

        LDBD R24,X14,PYC
        LDB R25,=277
        SBB R25,R24

        LDM R46,=0,20
        CMB R25,=0
        JZR PRADY

PROWLP  ADM R46,=100,0
        DCB R25
        JNZ PROWLP

PRADY   RTN


! ============================================================
! PGET -- read current PXC pixel from ROWBUF.
!
! Return R20 = 0 or 1.
! PXC is 16-bit; HP-85 PADDR uses the low byte only after the
! earlier backend range check has guaranteed X<=255.
! ============================================================

PGET    BIN
        LDMD R14,=UNBAS2
        JSB =PADDR

        LDBD R36,R34
        LDB R20,R36
        ORB R20,R23
        CMB R20,R36
        JZR PGSET

        LDB R20,=0
        RTN

PGSET   LDB R20,=1
        RTN


! ============================================================
! PMATCH -- current PXC pixel equals original source bit?
! Return R20=1 yes, 0 no.
! ============================================================

PMATCH  BIN
        LDMD R14,=UNBAS2
        JSB =PGET

        LDMD R14,=UNBAS2
        LDBD R21,X14,PSRC
        CMB R20,R21
        JZR PMYES

        LDB R20,=0
        RTN

PMYES   LDB R20,=1
        RTN


! ============================================================
! PPUT -- write PTARG bit to current PXC in ROWBUF.
! ============================================================

PPUT    BIN
        LDMD R14,=UNBAS2
        JSB =PADDR

        LDBD R36,R34
        LDBD R20,X14,PTARG
        CMB R20,=0
        JZR PPCLR

        ORB R36,R23
        STBD R36,R34
        RTN

PPCLR   ORB R36,R23
        XRB R36,R23
        STBD R36,R34
        RTN


! ============================================================
! PADDR -- locate PXC within 32-byte HP-85 ROWBUF.
!
! Return:
!       R34/R35 -> RAM byte containing pixel
!       R23     -> bit mask (MSB = leftmost)
!
! Uses 16-bit PXC at the interface; the HP-85 backend consumes
! its low byte only because this backend has already limited X
! to 0..255.
! ============================================================

PADDR   BIN
        LDMD R14,=UNBAS2

        LDM R34,=ROWBUF
        ADM R34,R14

        LDBD R20,X14,PXC

! byte index = x >> 3

        LDB R21,R20
        LRB R21
        LRB R21
        LRB R21

! remainder = x - (byte_index << 3)

        LDB R22,R21
        LLB R22
        LLB R22
        LLB R22
        SBB R20,R22

! advance RAM pointer byte_index times

        CMB R21,=0
        JZR PAMASK

PABYLP  ICM R34
        DCB R21
        JNZ PABYLP

! mask = 0x80 >> remainder

PAMASK  LDB R23,=200
        CMB R20,=0
        JZR PARDY

PAMSLP  LRB R23
        DCB R20
        JNZ PAMSLP

PARDY   RTN


! ============================================================
! PSCAND -- scan one neighbouring row within PLFT..PRGT and queue
! one seed for EVERY contiguous PSRC run on the indexed DOWN list.
!
! Input:
!       PYC       = neighbour row to inspect
!       PLFT/PRGT = span on the already-filled parent row
!
! The row is read once and is never modified here.
! ============================================================

PSCAND  BIN
        LDMD R14,=UNBAS2
        JSB =PRDROW

        BIN
        LDMD R14,=UNBAS2
        LDMD R46,X14,PLFT
        STMD R46,X14,PXC


! Scan the inclusive interval.  A matching pixel begins a run;
! only the first pixel of that run is queued.

PDQCHK  JSB =PMATCH

        BIN
        CMB R20,=0
        JNZ PDQRUN

        LDMD R14,=UNBAS2
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PDQRET

        ICM R46
        STMD R46,X14,PXC
        JMP PDQCHK


! Found first pixel of a contiguous source run.

PDQRUN  BIN
        LDMD R14,=UNBAS2
        JSB =PUSHD


! Advance through remainder of this run.

PDQRLP  BIN
        LDMD R14,=UNBAS2
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PDQRET

        ICM R46
        STMD R46,X14,PXC

        JSB =PMATCH

        BIN
        CMB R20,=0
        JNZ PDQRLP
        JMP PDQCHK

PDQRET  RTN


! ============================================================
! PUSHD -- indexed DOWN-list push.
!
! PDCNT is a byte count (0..254 accepted for push).  The current
! PXC/PYC is stored at:
!
!       PDSTK + PDCNT*4
!
! Capacity in this diagnostic is 255 entries.  No mutable RAM pointer
! is retained between operations.
! ============================================================

PUSHD   BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,PDCNT

! count 255 means no further representable byte count.

        CMB R20,=377
        JZR PDOVFL

! R30 = absolute base address of DOWN list.

        LDM R30,=PDSTK
        ADM R30,R14

! Advance by count * 4 bytes, using R21 as disposable loop count.

        LDB R21,R20
        CMB R21,=0
        JZR PDQADR

PDQALP  ADM R30,=4,0
        DCB R21
        JNZ PDQALP

PDQADR  LDMD R46,X14,PXC
        LDB R20,R46
        STBD R20,R30
        ICM R30
        LDB R20,R47
        STBD R20,R30
        ICM R30

        LDMD R46,X14,PYC
        LDB R20,R46
        STBD R20,R30
        ICM R30
        LDB R20,R47
        STBD R20,R30

! Commit count only after all four bytes have been stored.

        LDMD R14,=UNBAS2
        LDBD R20,X14,PDCNT
        ICB R20
        STBD R20,X14,PDCNT
        RTN

PDOVFL  JSB =ERRORP
        BYT 89D


! ============================================================
! POPD -- indexed DOWN-list pop.
!
! Return:
!       R20=0  entry returned in PXC/PYC
!       R20=1  list empty
!
! The count is decremented first; the resulting value is the index of
! the last stored entry.  Its address is recomputed from PDSTK.
! ============================================================

POPD    BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,PDCNT
        CMB R20,=0
        JZR PDEMTY

        DCB R20
        STBD R20,X14,PDCNT

        LDM R30,=PDSTK
        ADM R30,R14

        LDB R21,R20
        CMB R21,=0
        JZR PDQLD

PDQPLP  ADM R30,=4,0
        DCB R21
        JNZ PDQPLP

PDQLD   LDBD R46,R30
        ICM R30
        LDBD R47,R30
        ICM R30
        STMD R46,X14,PXC

        LDBD R46,R30
        ICM R30
        LDBD R47,R30
        STMD R46,X14,PYC

        LDB R20,=0
        RTN

PDEMTY  LDB R20,=1
        RTN


! ============================================================
! PSCANU -- scan one neighbouring row within PLFT..PRGT and queue
! one seed for EVERY contiguous PSRC run on the indexed UP list.
!
! This is the exact UP-list counterpart of the v0.09k-proven PSCAND.
! ============================================================

PSCANU  BIN
        LDMD R14,=UNBAS2
        JSB =PRDROW

        BIN
        LDMD R14,=UNBAS2
        LDMD R46,X14,PLFT
        STMD R46,X14,PXC


! Scan inclusive interval.  Queue only first pixel of each source run.

PUQCHK  JSB =PMATCH

        BIN
        CMB R20,=0
        JNZ PUQRUN

        LDMD R14,=UNBAS2
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PUQRET

        ICM R46
        STMD R46,X14,PXC
        JMP PUQCHK


PUQRUN  BIN
        LDMD R14,=UNBAS2
        JSB =PUSHU


! Advance through remainder of this run.

PUQRLP  BIN
        LDMD R14,=UNBAS2
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PUQRET

        ICM R46
        STMD R46,X14,PXC

        JSB =PMATCH

        BIN
        CMB R20,=0
        JNZ PUQRLP
        JMP PUQCHK

PUQRET  RTN


! ============================================================
! PUSHU -- indexed UP-list push.
!
! PUCNT is a byte count.  Store current PXC/PYC at:
!
!       PUSTK + PUCNT*4
! ============================================================

PUSHU   BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,PUCNT

        CMB R20,=377
        JZR PUOVFL

        LDM R30,=PUSTK
        ADM R30,R14

        LDB R21,R20
        CMB R21,=0
        JZR PUQADR

PUQALP  ADM R30,=4,0
        DCB R21
        JNZ PUQALP

PUQADR  LDMD R46,X14,PXC
        LDB R20,R46
        STBD R20,R30
        ICM R30
        LDB R20,R47
        STBD R20,R30
        ICM R30

        LDMD R46,X14,PYC
        LDB R20,R46
        STBD R20,R30
        ICM R30
        LDB R20,R47
        STBD R20,R30

        LDMD R14,=UNBAS2
        LDBD R20,X14,PUCNT
        ICB R20
        STBD R20,X14,PUCNT
        RTN

PUOVFL  JSB =ERRORP
        BYT 89D


! ============================================================
! POPU -- indexed UP-list pop.
!
! Return:
!       R20=0  entry returned in PXC/PYC
!       R20=1  list empty
! ============================================================

POPU    BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,PUCNT
        CMB R20,=0
        JZR PUEMTY

        DCB R20
        STBD R20,X14,PUCNT

        LDM R30,=PUSTK
        ADM R30,R14

        LDB R21,R20
        CMB R21,=0
        JZR PUQLD

PUQPLP  ADM R30,=4,0
        DCB R21
        JNZ PUQPLP

PUQLD   LDBD R46,R30
        ICM R30
        LDBD R47,R30
        ICM R30
        STMD R46,X14,PXC

        LDBD R46,R30
        ICM R30
        LDBD R47,R30
        STMD R46,X14,PYC

        LDB R20,=0
        RTN

PUEMTY  LDB R20,=1
        RTN


! ============================================================
! PLOTP RUNTIME -- implementation inherited from v0.10a
!
!       PLOTP x,y,f
!
! f=1:
!       Hybrid operation.
!       1. ROM360 MOVE x,y ; DRAW x,y ; MOVE x,y
!          -> CRT/plotter graphics path, ending pen-up at the point.
!       2. Independently map x,y through the active ROM360 SCALE and
!          explicitly SET the corresponding CRT pixel if it lies on-screen.
!          This guarantees the raster result even if a zero-length DRAW is
!          not rendered as a CRT pixel by the ROM360 vector path.
!
! f=0:
!       CRT-only CLEAR of the mapped pixel.  No plotter output.
!
! f=2:
!       CRT-only XOR of the mapped pixel.  No plotter output.
!
! Invalid f values are a no-op, matching LINE semantics.
!
! PLOTP deliberately reuses PAINT's PX/PY/PF, PMODE, PXC/PYC, PTARG and
! ROWBUF helpers.  Commands are not re-entrant, so no additional large
! working area is required.
! ============================================================

        BYT 241

PLTPRT.   SAD
        BIN
        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Arguments arrive in reverse order from R12: f, y, x.
! Reuse PAINT argument locals.
! ------------------------------------------------------------

        JSB =ONER
        BIN
        STMD R#,X14,PF

        JSB =ONER
        BIN
        STMD R#,X14,PY

        JSB =ONER
        BIN
        STMD R#,X14,PX


! ------------------------------------------------------------
! Convert f to the one-byte mode used by the raster helpers.
! ------------------------------------------------------------

        LDMD R60,X14,PF
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2

        STBD R76,X14,PMODE
        LDBD R20,X14,PMODE

        CMB R20,=1
        JZR QSET

        CMB R20,=0
        JZR QRAS

        CMB R20,=2
        JZR QRAS

! Other values: LINE-compatible no-op.

        PAD
        RTN


! ------------------------------------------------------------
! f=1 -- emit the plotter/device-aware point first.
!
! ROM360 uses the raw BASIC user coordinates and its current SCALE/PEN.
! QPDOT ends with a MOVE to the same point so a physical plotter is left
! pen-up after making the point.
! ------------------------------------------------------------

QSET    LDMD R14,=UNBAS2
        JSB =QPDOT

        BIN
        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Common CRT path for f=0,1,2.
! Map one point using the active ROM360 SCALE coefficients.
! ------------------------------------------------------------

QRAS    JSB =READMAP

        BIN
        LDMD R14,=UNBAS2

        LDMD R40,X14,PX
        LDMD R50,X14,PY
        JSB =MAPXY

        BIN
        LDMD R14,=UNBAS2

        STMD R40,X14,MX1
        STMD R50,X14,MY1
        STMD R40,X14,MX2
        STMD R50,X14,MY2


! ------------------------------------------------------------
! Build the standard CRT clipping constants.  Reusing LCLIP with
! identical endpoints is the already-proven point-clipping method.
! If off-screen, f=0/f=2 simply do nothing; for f=1 the ROM360/plotter
! operation has already occurred.
! ------------------------------------------------------------

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CZERO

        LDM R36,=377,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CXMAX

        LDM R36,=277,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CYMAX

        JSB =LCLIP
        BIN
        CMB R20,=0
        JZR QCVRT

        PAD
        RTN


! ------------------------------------------------------------
! Convert clipped mapped point to PAINT's 16-bit pixel coordinates.
! The clipped HP-85 ranges allow the proven R76 low-byte result to be
! explicitly zero-extended.
! ------------------------------------------------------------

QCVRT   LDMD R14,=UNBAS2

        LDMD R60,X14,MX1
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2

        CLM R46
        LDB R46,R76
        STMD R46,X14,PXC

        LDMD R60,X14,MY1
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2

        CLM R46
        LDB R46,R76
        STMD R46,X14,PYC


! ------------------------------------------------------------
! Sample CRT read mode and preserve the current CRT byte address.
! For f=1 this is intentionally done AFTER QPDOT so PREST restores the
! graphics state left by the ROM360 point operation, not an earlier one.
! ------------------------------------------------------------

        LDB R21,=0
        LDBD R20,=CRTWRS
        LRB R20
        TSB R20
        JEV QCFSA
        LDB R21,=1

QCFSA   LDMD R14,=UNBAS2
        STBD R21,X14,CRTFLG
        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT


! ------------------------------------------------------------
! Read the complete raster row.  PGET returns current pixel state.
! ------------------------------------------------------------

        JSB =PRDROW

        BIN
        LDMD R14,=UNBAS2
        JSB =PGET

        BIN
        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Derive resulting pixel state.
! ------------------------------------------------------------

        LDBD R21,X14,PMODE

        CMB R21,=0
        JZR QZERO

        CMB R21,=1
        JZR QONE

! XOR: target = 1 - current pixel.

        LDB R22,=1
        SBB R22,R20
        STBD R22,X14,PTARG
        JMP QWRITE

QZERO   LDB R22,=0
        STBD R22,X14,PTARG
        JMP QWRITE

QONE    LDB R22,=1
        STBD R22,X14,PTARG


! ------------------------------------------------------------
! Modify ROWBUF, write the row, restore caller/ROM360 CRT byte pointer.
! ------------------------------------------------------------

QWRITE  JSB =PPUT
        JSB =PWRROW

        BIN
        LDMD R14,=UNBAS2
        JSB =PREST

        BIN
        PAD
        RTN


! ============================================================
! QPDOT -- ROM360 physical/device point for PLOTP f=1.
!
! Sequence:
!       MOVE x,y     pen up / position
!       DRAW x,y     lower pen at the same coordinate
!       MOVE x,y     raise pen again without displacement
!
! The same raw evaluated REAL x/y values are pushed for every call.
! ============================================================

QPDOT   BIN
        LDMD R14,=UNBAS2

        LDMD R40,X14,PX
        PUMD R40,+R12
        LDMD R40,X14,PY
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPMOVE
        BYT 360
        BIN

        LDMD R14,=UNBAS2
        LDMD R40,X14,PX
        PUMD R40,+R12
        LDMD R40,X14,PY
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPDRAW
        BYT 360
        BIN

        LDMD R14,=UNBAS2
        LDMD R40,X14,PX
        PUMD R40,+R12
        LDMD R40,X14,PY
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPMOVE
        BYT 360
        BIN

        RTN


! ============================================================
! TEST RUNTIME -- v0.10c CRT PIXEL FUNCTION
!
!       TEST(x,y)
!
! HP-83/85 function attributes immediately precede the runtime:
!
!       40 octal = two parameters, both numeric
!       55 octal = numeric system function
!
! The function parser/return mechanism is unchanged from the
! hardware-verified v0.10b diagnostic.
!
! Result:
!       0 = mapped CRT pixel is clear, or mapped point is off-screen
!       1 = mapped CRT pixel is set
!
! TEST is CRT-only; no plotter output is generated.
! ============================================================

        BYT 40,55

TEST.   BIN
        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Function arguments arrive in reverse order on R12: y, x.
! Reuse PAINT/PLOTP's REAL coordinate locals.
! ------------------------------------------------------------

        JSB =ONER
        BIN
        STMD R#,X14,PY

        JSB =ONER
        BIN
        STMD R#,X14,PX


! ------------------------------------------------------------
! Map the user coordinate through the active ROM360 SCALE state.
! READMAP only reads the ROM360 mapping workspace; TEST never calls
! MOVE/DRAW and therefore has no plotter side effect.
! ------------------------------------------------------------

        JSB =READMAP

        BIN
        LDMD R14,=UNBAS2

        LDMD R40,X14,PX
        LDMD R50,X14,PY
        JSB =MAPXY

        BIN
        LDMD R14,=UNBAS2

        STMD R40,X14,MX1
        STMD R50,X14,MY1
        STMD R40,X14,MX2
        STMD R50,X14,MY2


! ------------------------------------------------------------
! Build the standard CRT clipping constants and reuse the proven
! zero-length point form of LCLIP.  Off-screen means pixel state 0.
! ------------------------------------------------------------

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CZERO

        LDM R36,=377,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CXMAX

        LDM R36,=277,0
        JSB =CONBIN
        BIN
        LDMD R14,=UNBAS2
        STMD R40,X14,CYMAX

        JSB =LCLIP
        BIN
        CMB R20,=0
        JZR TCVRT

! Off-screen: return REAL 0 immediately.  Keeping this return local also
! avoids introducing a long relative branch into the function body.

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        PUMD R40,+R12
        RTN


! ------------------------------------------------------------
! Convert the accepted mapped point to PAINT's 16-bit PXC/PYC.
! The clipped HP-85 ranges make explicit zero-extension of R76 safe.
! ------------------------------------------------------------

TCVRT   LDMD R14,=UNBAS2

        LDMD R60,X14,MX1
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2

        CLM R46
        LDB R46,R76
        STMD R46,X14,PXC

        LDMD R60,X14,MY1
        JSB =CONINT
        BIN
        LDMD R14,=UNBAS2

        CLM R46
        LDB R46,R76
        STMD R46,X14,PYC


! ------------------------------------------------------------
! Sample CRT read mode and preserve the caller's CRT byte pointer.
! Same physically-proven rule used by BLOCK, LINE, PLOTP and PAINT:
!
!       CRTWRS bit 1 clear -> INCHR
!       CRTWRS bit 1 set   -> INCHR-
! ------------------------------------------------------------

        LDB R21,=0
        LDBD R20,=CRTWRS
        LRB R20
        TSB R20
        JEV TCFSA
        LDB R21,=1

TCFSA   LDMD R14,=UNBAS2
        STBD R21,X14,CRTFLG

        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT


! ------------------------------------------------------------
! Read exactly one 32-byte raster row and obtain the addressed bit.
! Save the 0/1 result before PREST, since system routines used by
! pointer restoration are free to clobber working registers.
! ------------------------------------------------------------

        JSB =PRDROW

        BIN
        LDMD R14,=UNBAS2
        JSB =PGET

        BIN
        LDMD R14,=UNBAS2
        STBD R20,X14,PFND

        JSB =PREST

        BIN
        LDMD R14,=UNBAS2
        LDBD R20,X14,PFND
        CMB R20,=0
        JZR TRET0


! ------------------------------------------------------------
! Return REAL 1.
! ------------------------------------------------------------

TRET1   LDM R36,=1,0
        JSB =CONBIN
        BIN
        PUMD R40,+R12
        RTN


! ------------------------------------------------------------
! Return REAL 0, including all off-screen mapped coordinates.
! ------------------------------------------------------------

TRET0   LDM R36,=0,0
        JSB =CONBIN
        BIN
        PUMD R40,+R12
        RTN


! ============================================================
! BLOCK RUNTIME
! ============================================================

        BYT 241

BLOCK.  SAD

        BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! f
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,BF


! ------------------------------------------------------------
! y2
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,BY2


! ------------------------------------------------------------
! x2
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,BX2


! ------------------------------------------------------------
! y1
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,BY1


! ------------------------------------------------------------
! x1
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,BX1


! ============================================================
! READ ACTIVE SCALE STATE
! ============================================================

        BIN

        LDMD R14,=UNBAS2

        JSB =READMAP


! ============================================================
! MAP CORNER 1
! ============================================================

        BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,BX1
        LDMD R50,X14,BY1

        JSB =MAPXY

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,MX1
        STMD R50,X14,MY1


! ============================================================
! MAP CORNER 2
! ============================================================

        BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,BX2
        LDMD R50,X14,BY2

        JSB =MAPXY

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,MX2
        STMD R50,X14,MY2


! ============================================================
! BUILD REAL CLIPPING CONSTANTS
! ============================================================


! ------------------------------------------------------------
! 0
! ------------------------------------------------------------

        BIN

        LDM R36,=0,0

        JSB =CONBIN

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,CZERO


! ------------------------------------------------------------
! 255
! ------------------------------------------------------------

        LDM R36,=377,0

        JSB =CONBIN

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,CXMAX


! ------------------------------------------------------------
! 191
! ------------------------------------------------------------

        LDM R36,=277,0

        JSB =CONBIN

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,CYMAX


! ============================================================
! NORMALIZE MAPPED X
! ============================================================

        LDMD R40,X14,MX1
        LDMD R50,X14,MX2

        JSB =COMFLT

        JEN XORDR


! ------------------------------------------------------------
! Swap
! ------------------------------------------------------------

        BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,MX1
        LDMD R50,X14,MX2

        STMD R50,X14,MX1
        STMD R40,X14,MX2

        JMP XORDN


XORDR   BIN

XORDN   LDMD R14,=UNBAS2


! ============================================================
! NORMALIZE MAPPED Y
! ============================================================

        LDMD R40,X14,MY1
        LDMD R50,X14,MY2

        JSB =COMFLT

        JEN YORDR


! ------------------------------------------------------------
! Swap
! ------------------------------------------------------------

        BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,MY1
        LDMD R50,X14,MY2

        STMD R50,X14,MY1
        STMD R40,X14,MY2

        JMP YORDN


YORDR   BIN

YORDN   LDMD R14,=UNBAS2


! ============================================================
! REJECT RECTANGLES COMPLETELY OUTSIDE X
! ============================================================


! ------------------------------------------------------------
! Xmax < 0 ?
! ------------------------------------------------------------

        LDMD R40,X14,MX2
        LDMD R50,X14,CZERO

        JSB =COMFLT

        JEZ RX0OK

        PAD
        RTN


RX0OK   BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Xmin > 255 ?
! ------------------------------------------------------------

        LDMD R40,X14,CXMAX
        LDMD R50,X14,MX1

        JSB =COMFLT

        JEZ RX1OK

        PAD
        RTN


RX1OK   BIN

        LDMD R14,=UNBAS2


! ============================================================
! REJECT RECTANGLES COMPLETELY OUTSIDE Y
! ============================================================


! ------------------------------------------------------------
! Ymax < 0 ?
! ------------------------------------------------------------

        LDMD R40,X14,MY2
        LDMD R50,X14,CZERO

        JSB =COMFLT

        JEZ RY0OK

        PAD
        RTN


RY0OK   BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! Ymin > 191 ?
! ------------------------------------------------------------

        LDMD R40,X14,CYMAX
        LDMD R50,X14,MY1

        JSB =COMFLT

        JEZ RY1OK

        PAD
        RTN


RY1OK   BIN

        LDMD R14,=UNBAS2


! ============================================================
! CLIP X MINIMUM
! ============================================================

        LDMD R40,X14,MX1
        LDMD R50,X14,CZERO

        JSB =COMFLT

        JEN XCL0

        BIN

        JMP XCLHI


XCL0    BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,CZERO

        STMD R40,X14,MX1


! ============================================================
! CLIP X MAXIMUM
! ============================================================

XCLHI   LDMD R14,=UNBAS2

        LDMD R40,X14,CXMAX
        LDMD R50,X14,MX2

        JSB =COMFLT

        JEN XCLMX

        BIN

        JMP YCLLO


XCLMX   BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,CXMAX

        STMD R40,X14,MX2


! ============================================================
! CLIP Y MINIMUM
! ============================================================

YCLLO   LDMD R14,=UNBAS2

        LDMD R40,X14,MY1
        LDMD R50,X14,CZERO

        JSB =COMFLT

        JEN YCL0

        BIN

        JMP YCLHI


YCL0    BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,CZERO

        STMD R40,X14,MY1


! ============================================================
! CLIP Y MAXIMUM
! ============================================================

YCLHI   LDMD R14,=UNBAS2

        LDMD R40,X14,CYMAX
        LDMD R50,X14,MY2

        JSB =COMFLT

        JEN YCLMX

        BIN

        JMP CVCOOR


YCLMX   BIN

        LDMD R14,=UNBAS2

        LDMD R40,X14,CYMAX

        STMD R40,X14,MY2


! ============================================================
! CONVERT CLIPPED COORDINATES
! ============================================================

CVCOOR  BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! X1
! ------------------------------------------------------------

        LDMD R60,X14,MX1

        JSB =CONINT

        BIN

        LDMD R14,=UNBAS2

        STBD R76,X14,IX1


! ------------------------------------------------------------
! Y1
! ------------------------------------------------------------

        LDMD R60,X14,MY1

        JSB =CONINT

        BIN

        LDMD R14,=UNBAS2

        STBD R76,X14,IY1


! ------------------------------------------------------------
! X2
! ------------------------------------------------------------

        LDMD R60,X14,MX2

        JSB =CONINT

        BIN

        LDMD R14,=UNBAS2

        STBD R76,X14,IX2


! ------------------------------------------------------------
! Y2
! ------------------------------------------------------------

        LDMD R60,X14,MY2

        JSB =CONINT

        BIN

        LDMD R14,=UNBAS2

        STBD R76,X14,IY2


! ------------------------------------------------------------
! Mode
! ------------------------------------------------------------

        LDMD R60,X14,BF

        JSB =CONINT

        BIN

        LDMD R14,=UNBAS2

        STBD R76,X14,MODE


! ============================================================
! SAMPLE CRT WIPEOUT STATE
!
! CRTWRS is the RAM mirror of the last value written to CRTSTS.
! Bit 1 = 1 means WIPEOUT, which is HP's documented condition
! for safely using the faster INCHR- entry point.
!
! BASIC CRT OFF was verified on the physical HP-85 as:
!
!       CRT ON  -> CRTWRS = 0
!       CRT OFF -> CRTWRS = 6
!
! Store only a local Boolean so later routines do not have to
! re-read or interpret CRTWRS.
! ============================================================

        LDB R21,=0

        LDBD R20,=CRTWRS

        LRB R20
        TSB R20

        JEV CFSAVE

        LDB R21,=1

CFSAVE  LDMD R14,=UNBAS2

        STBD R21,X14,CRTFLG


! ============================================================
! SAVE CURRENT CRT ADDRESS
! ============================================================

        LDMD R20,=CRTBYT

        LDMD R14,=UNBAS2

        STMD R20,X14,SAVCRT


! ============================================================
! LOGICAL Y -> CRT RASTER ROW
!
!       RTOP = 191 - IY2
!       RBOT = 191 - IY1
! ============================================================

        LDBD R20,X14,IY1
        LDBD R21,X14,IY2


! ------------------------------------------------------------
! Top
! ------------------------------------------------------------

        LDB R22,=277

        SBB R22,R21

        STBD R22,X14,RTOP


! ------------------------------------------------------------
! Bottom
! ------------------------------------------------------------

        LDB R23,=277

        SBB R23,R20

        STBD R23,X14,RBOT


! ============================================================
! CALCULATE FIRST ROW BASE ADDRESS
! ============================================================

        LDM R46,=0,20

        LDBD R24,X14,RTOP

        CMB R24,=0

        JZR ROWRDY


RADDL   ADM R46,=100,0

        DCB R24

        JNZ RADDL


ROWRDY  LDBD R26,X14,RTOP
        LDBD R27,X14,RBOT


! ============================================================
! ROW DISPATCH
!
! SET/CLEAR -> FASTROW
! XOR       -> XORROW
!
! Keeping these as separate local routines makes the scanline
! architecture reusable and keeps the main Y loop short.
! ============================================================

ROWLOOP BIN

        LDMD R14,=UNBAS2

        LDBD R40,X14,MODE

        CMB R40,=2

        JZR DOXOR


! ------------------------------------------------------------
! SET / CLEAR
! ------------------------------------------------------------

        JSB =FASTROW

        JMP ROWNEXT


! ------------------------------------------------------------
! XOR
! ------------------------------------------------------------

DOXOR   LDMD R14,=UNBAS2

        JSB =XORROW


! ============================================================
! NEXT ROW
! ============================================================

ROWNEXT CMB R26,R27

        JZR BDONE

        ICB R26

        ADM R46,=100,0

        JMP ROWLOOP


! ============================================================
! BLOCK COMPLETE
! ============================================================

BDONE   BIN

        LDMD R14,=UNBAS2

        LDMD R34,X14,SAVCRT

        JSB =BYTCR!

        JSB =CHKSTS

        PAD

        RTN


! ============================================================
! FASTROW
!
! v0.05f streaming SET/CLEAR rasterizer.
!
! Input:
!
!       R46/R47 = current raster-row base address
!
! Uses:
!
!       IX1
!       IX2
!       MODE
!
! Hardware CRTBAD is positioned once at the first graphics
! byte and then allowed to auto-increment.
! ============================================================

FASTROW BIN

        LDMD R14,=UNBAS2


! ------------------------------------------------------------
! X limits
! ------------------------------------------------------------

        LDBD R20,X14,IX1
        LDBD R21,X14,IX2


! ------------------------------------------------------------
! Determine first byte column and starting bit.
! ------------------------------------------------------------

        LDB R22,=0
        LDB R23,=200
        LDB R25,=0

        LDB R24,R20

        CMB R24,=0

        JZR FXRDY


FXINIT  LRB R23

        ICB R22

        CMB R22,=10

        JNZ FXIN2

        LDB R22,=0
        LDB R23,=200

        ICB R25


FXIN2   DCB R24

        JNZ FXINIT


! ============================================================
! BUILD ADDRESS OF FIRST GRAPHICS BYTE
! ============================================================

FXRDY   LDB R30,R46
        LDB R31,R47

        LDB R24,R25

        CMB R24,=0

        JZR FXPOS


FXADDL  ADM R30,=2,0

        DCB R24

        JNZ FXADDL


! ============================================================
! POSITION ONCE FOR THIS ROW
! ============================================================

FXPOS   LDMD R14,=UNBAS2

        STMD R30,X14,CURADR

        LDMD R34,X14,CURADR

        JSB =BYTCR!

        BIN

        LDMD R14,=UNBAS2


! ============================================================
! ACCUMULATE CURRENT BYTE MASK
! ============================================================

FNEWBY  LDB R24,=0


FPIXAC  ORB R24,R23


! ------------------------------------------------------------
! Final X?
! ------------------------------------------------------------

        CMB R20,R21

        JZR FLAST


! ------------------------------------------------------------
! Next pixel
! ------------------------------------------------------------

        ICB R20

        LRB R23

        ICB R22


! ------------------------------------------------------------
! Still same byte?
! ------------------------------------------------------------

        CMB R22,=10

        JNZ FPIXAC


! ============================================================
! BYTE COMPLETE
! ============================================================

        LDMD R14,=UNBAS2

        JSB =STRBYT


! ------------------------------------------------------------
! Keep software current-address copy synchronized with the
! CRT controller's automatic +2 increment.
! ------------------------------------------------------------

        BIN

        LDMD R14,=UNBAS2

        LDMD R34,X14,CURADR

        ADM R34,=2,0

        STMD R34,X14,CURADR


! ------------------------------------------------------------
! Next byte begins at its MSB.
! ------------------------------------------------------------

        LDB R22,=0
        LDB R23,=200

        JMP FNEWBY


! ============================================================
! LAST BYTE
! ============================================================

FLAST   LDMD R14,=UNBAS2

        JSB =STRBYT

        RTN


! ============================================================
! XORROW
!
! Buffered XOR scanline.
!
! 1. READROW reads all 32 graphics bytes into ROWBUF.
! 2. Pixels IX1..IX2 are XORed entirely in RAM.
! 3. WRTROW streams ROWBUF back to CRT.
!
! No CRT address repositioning occurs while individual XOR
! pixels are processed.
! ============================================================

XORROW  BIN

        LDMD R14,=UNBAS2

        JSB =READROW


! ============================================================
! PREPARE RAM PIXEL POINTER
! ============================================================

        BIN

        LDMD R14,=UNBAS2

        LDBD R20,X14,IX1
        LDBD R21,X14,IX2


! ------------------------------------------------------------
! Determine byte column / bit mask for IX1.
! ------------------------------------------------------------

        LDB R22,=0
        LDB R23,=200
        LDB R25,=0

        LDB R24,R20

        CMB R24,=0

        JZR XRBPTR


XRXINI  LRB R23

        ICB R22

        CMB R22,=10

        JNZ XRXIN2

        LDB R22,=0
        LDB R23,=200

        ICB R25


XRXIN2  DCB R24

        JNZ XRXINI


! ============================================================
! BUILD POINTER TO ROWBUF BYTE CONTAINING IX1
! ============================================================

XRBPTR  LDM R34,=ROWBUF

        ADMD R34,=UNBAS2

        LDB R24,R25

        CMB R24,=0

        JZR XRMOD


XRBADD  ICM R34

        DCB R24

        JNZ XRBADD


! ============================================================
! XOR PIXELS IN RAM
!
! R34/R35 = current ROWBUF byte
! R23     = one-bit mask
!
! Register-direct memory addressing lets us change the current
! RAM byte without moving the pointer for every individual bit.
! ============================================================

XRMOD   LDBD R36,R34

        XRB R36,R23

        STBD R36,R34


! ------------------------------------------------------------
! Finished?
! ------------------------------------------------------------

        CMB R20,R21

        JZR XRWRITE


! ------------------------------------------------------------
! Next pixel
! ------------------------------------------------------------

        ICB R20

        LRB R23

        ICB R22


! ------------------------------------------------------------
! Still inside same RAM byte?
! ------------------------------------------------------------

        CMB R22,=10

        JNZ XRMOD


! ------------------------------------------------------------
! Move to next ROWBUF byte.
! ------------------------------------------------------------

        LDB R22,=0
        LDB R23,=200

        ICM R34

        JMP XRMOD


! ============================================================
! WRITE MODIFIED SCANLINE
! ============================================================

XRWRITE LDMD R14,=UNBAS2

        JSB =WRTROW

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

        ADMD R34,=UNBAS2


! ------------------------------------------------------------
! 32 decimal bytes = 40 octal.
! ------------------------------------------------------------

        LDB R22,=40


! ------------------------------------------------------------
! Select the read loop once for this scanline.
! ------------------------------------------------------------

        LDMD R14,=UNBAS2

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
! WRTROW
!
! Stream entire ROWBUF to the current physical scanline.
!
!
! Input:
!
!       R46/R47 = row-base CRT nibble address
!
!
! BPLOT-style strategy:
!
!       BYTCR! once
!
!       repeated:
!           CHKSTS
!           fetch RAM byte
!           CRTDAT write
!
! CRTBAD advances automatically after every write.
! ============================================================

WRTROW BIN


! ------------------------------------------------------------
! Position CRT at first byte of row.
! ------------------------------------------------------------

        LDB R34,R46
        LDB R35,R47

        JSB =BYTCR!


! ------------------------------------------------------------
! Reuse R34/R35 as RAM source pointer.
! ------------------------------------------------------------

        BIN

        LDM R34,=ROWBUF

        ADMD R34,=UNBAS2

        LDB R22,=40


WRLOOP  JSB =CHKSTS


! ------------------------------------------------------------
! Fetch next RAM byte and advance source pointer.
! ------------------------------------------------------------

        POBD R32,+R34


! ------------------------------------------------------------
! Write byte. CRTBAD advances automatically.
! ------------------------------------------------------------

        STBD R32,=CRTDAT

        DCB R22

        JNZ WRLOOP

        RTN


! ============================================================
! STRBYT
!
! Streaming byte modifier used by SET/CLEAR path.
!
!
! Entry:
!
!       hardware CRTBAD = CURADR
!       R24             = mask
!
!
! Mode 0:
!
!       full mask -> direct 000 write
!       partial   -> read / clear mask / rewrite
!
! Mode 1:
!
!       full mask -> direct 377 write
!       partial   -> read / set mask / rewrite
!
!
! XOR no longer uses this routine in v0.05h.
! ============================================================

STRBYT  BIN

        LDMD R14,=UNBAS2

        STBD R24,X14,CURMSK

        LDBD R40,X14,MODE


! ============================================================
! CLEAR
! ============================================================

        CMB R40,=0

        JNZ SBSET


! ------------------------------------------------------------
! Full byte?
! ------------------------------------------------------------

        CMB R24,=377

        JNZ SBREAD

        LDB R32,=0

        JMP SBDIR


! ============================================================
! SET
! ============================================================

SBSET   CMB R40,=1

        JNZ SBREAD


! ------------------------------------------------------------
! Full byte?
! ------------------------------------------------------------

        CMB R24,=377

        JNZ SBREAD

        LDB R32,=377

        JMP SBDIR


! ============================================================
! PARTIAL BYTE READ
! ============================================================

SBREAD  LDMD R14,=UNBAS2

        ! R20 is FASTROW's live current-X counter.  Preserve it.
        ! R40 is safe here because MODE is reloaded after the read.

        LDBD R40,X14,CRTFLG

        CMB R40,=0

        JZR SBNORM

        JSB =INCHR-

        JMP SBRDON

SBNORM  JSB =INCHR

SBRDON  BIN

        LDB R36,R32

        LDMD R14,=UNBAS2

        LDBD R23,X14,CURMSK
        LDBD R40,X14,MODE


! ------------------------------------------------------------
! CLEAR?
! ------------------------------------------------------------

        CMB R40,=0

        JNZ SBRSET

        ORB R36,R23
        XRB R36,R23

        JMP SBMOD


! ------------------------------------------------------------
! SET
! ------------------------------------------------------------

SBRSET  ORB R36,R23


! ============================================================
! REWRITE PARTIAL BYTE
! ============================================================

SBMOD   LDMD R14,=UNBAS2

        STBD R36,X14,NEWBYTE


! ------------------------------------------------------------
! INCHR advanced CRTBAD, so reposition to the byte just read.
! ------------------------------------------------------------

        LDMD R34,X14,CURADR

        JSB =BYTCR!

        BIN

        LDMD R14,=UNBAS2

        LDBD R32,X14,NEWBYTE


! ------------------------------------------------------------
! Write and leave hardware positioned at next byte.
! ------------------------------------------------------------

        JSB =CHKSTS

        STBD R32,=CRTDAT

        BIN

        RTN


! ============================================================
! DIRECT FULL-BYTE SET/CLEAR
! ============================================================

SBDIR   JSB =CHKSTS

        STBD R32,=CRTDAT

        BIN

        RTN


! ============================================================
! ROM360 SCALE WORKSPACE OFFSETS
! ============================================================

XOFF    EQU 46
YOFF    EQU 56

XFAC    EQU 66
YFAC    EQU 76


! ============================================================
! READMAP
! ============================================================

READMAP BIN


! ------------------------------------------------------------
! X offset
! ------------------------------------------------------------

        LDMD R14,=SAGBAS

        LDMD R50,X14,XOFF

        LDMD R14,=UNBAS2

        STMD R50,X14,CXOFF


! ------------------------------------------------------------
! Y offset
! ------------------------------------------------------------

        LDMD R14,=SAGBAS

        LDMD R50,X14,YOFF

        LDMD R14,=UNBAS2

        STMD R50,X14,CYOFF


! ------------------------------------------------------------
! X factor
! ------------------------------------------------------------

        LDMD R14,=SAGBAS

        LDMD R50,X14,XFAC

        LDMD R14,=UNBAS2

        STMD R50,X14,CXFAC


! ------------------------------------------------------------
! Y factor
! ------------------------------------------------------------

        LDMD R14,=SAGBAS

        LDMD R50,X14,YFAC

        LDMD R14,=UNBAS2

        STMD R50,X14,CYFAC

        RTN


! ============================================================
! MAPXY
!
!       X' = X * XFACTOR + XOFFSET
!       Y' = Y * YFACTOR + YOFFSET
!
!
! MPY10 and ADD10 each leave an unwanted REAL on R12.
!
! Keep R40 result and discard the stack copy:
!
!       POMD R70,-R12
! ============================================================

MAPXY   BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,MXIN
        STMD R50,X14,MYIN


! ============================================================
! X
! ============================================================

        LDMD R40,X14,MXIN
        LDMD R50,X14,CXFAC

        JSB =MPY10

        POMD R70,-R12

        BIN

        LDMD R14,=UNBAS2

        LDMD R50,X14,CXOFF

        JSB =ADD10

        POMD R70,-R12

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,MXOUT


! ============================================================
! Y
! ============================================================

        LDMD R40,X14,MYIN
        LDMD R50,X14,CYFAC

        JSB =MPY10

        POMD R70,-R12

        BIN

        LDMD R14,=UNBAS2

        LDMD R50,X14,CYOFF

        JSB =ADD10

        POMD R70,-R12

        BIN

        LDMD R14,=UNBAS2

        STMD R40,X14,MYOUT


! ------------------------------------------------------------
! Return mapped coordinates.
! ------------------------------------------------------------

        LDMD R40,X14,MXOUT
        LDMD R50,X14,MYOUT

        RTN


! ============================================================
! ============================================================
! LOCAL DATA
! ============================================================

HMSG    ASC "SIMON85 V0.13A1"



! ------------------------------------------------------------
! BASIC arguments
! ------------------------------------------------------------

BX1      EQU 0
BY1      EQU 10

BX2      EQU 20
BY2      EQU 30

BF       EQU 40


! ------------------------------------------------------------
! LINE arguments
!
! HP REAL = 8 bytes; BSZ 10 octal = 8 decimal bytes.
! ------------------------------------------------------------

LX1      EQU 50
LY1      EQU 60

LX2      EQU 70
LY2      EQU 100

LFLAG       EQU 110
LMODE    EQU 120


! ------------------------------------------------------------
! LINE rasterizer state
!
! LRY1/LRY2 = physical raster rows (191-logicalY)
! LDX/LDY   = positive 16-bit Bresenham deltas
! LERR/LREM = signed error / remaining major-axis steps
! LXDIR/LYDIR: 1=increase, 0=decrease
! LADR/LMASK = current CRT byte address / pixel bit
! ------------------------------------------------------------

LRY1     EQU 121
LRY2     EQU 122

LDX      EQU 123
LDY      EQU 125
LERR     EQU 127
LREM     EQU 131

LXDIR    EQU 133
LYDIR    EQU 134

LADR     EQU 135
LMASK    EQU 137
LNEW     EQU 140


! ------------------------------------------------------------
! LINE clipping state -- v0.07c
! ------------------------------------------------------------

LCOD1    EQU 141
LCOD2    EQU 142
LCOUT    EQU 143
LCODV    EQU 144
LSEL     EQU 145
LCCNT    EQU 146

LCTX     EQU 147
LCTY     EQU 157
LBOUND   EQU 167
LNX      EQU 177
LNY      EQU 207
LTMP1    EQU 217
LTMP2    EQU 227
LTVAL    EQU 237


! ------------------------------------------------------------
! REC arguments / derived opposite corner
! ------------------------------------------------------------

REX      EQU 247
REY      EQU 257
REB      EQU 267
REH      EQU 277
REF      EQU 307
REX2     EQU 317
REY2     EQU 327


! ------------------------------------------------------------
! Shared ARC / CIRCLE / ANGL state
! ------------------------------------------------------------

SMX      EQU 337
SMY      EQU 347
SRX      EQU 357
SRY      EQU 367
SF       EQU 377

SWS      EQU 407
SWE      EQU 417
SWW      EQU 427
SANG     EQU 437
SEND     EQU 447
SNXT     EQU 457

SPX      EQU 467
SPY      EQU 477
PTX      EQU 507
PTY      EQU 517

SZERO    EQU 527
S360     EQU 537
SDRG     EQU 547

! v0.11d ARC/CIRCLE incremental trigonometry state.
RSIN     EQU 550          ! sin(current angle)
RCOS     EQU 560          ! cos(current angle)
RDSIN    EQU 570          ! sin(full angular step)
RDCOS    EQU 600          ! cos(full angular step)
RTMP     EQU 610          ! recurrence arithmetic scratch
RNEW     EQU 620          ! pending new sine while old sine remains live

! CIRCLE v0.08b optional segment-count state.
SNSEG    EQU 630          ! optional n, then REAL copy of binary n
CNSEG    EQU 640           ! validated binary segment count
CREM     EQU 642           ! remaining counted CIRCLE segments


! ------------------------------------------------------------
! PAINT v0.09l arguments and indexed work-list state
! ------------------------------------------------------------

PX       EQU 644          ! BASIC x REAL
PY       EQU 654          ! BASIC y REAL
PF       EQU 664          ! BASIC mode REAL
PMODE    EQU 674

! 16-bit logical physical-pixel coordinates.
PXC      EQU 675
PYC      EQU 677
PSEEDX   EQU 701
PSEEDY   EQU 703
PLFT     EQU 705
PRGT     EQU 707
PORGL    EQU 711           ! retained compatibility/debug state
PORGR    EQU 713           ! retained compatibility/debug state

PSRC     EQU 715           ! original connected-region bit
PTARG    EQU 716           ! requested resulting bit
PFND     EQU 717           ! reserved PAINT diagnostic state
PDIR     EQU 720           ! retained scratch / future directional dispatcher

PDCNT    EQU 721           ! indexed DOWN-list entry count
PUCNT    EQU 722           ! indexed UP-list entry count
PFKACT   EQU 723           ! 1 iff most recent PFSEED actually filled a row
PFRES    EQU 724           ! reserved; preserves established local-data layout

! Two active 256-slot directional list reservations.  Each uses 2000 octal
! bytes (1024 decimal); combined work-list storage remains 2048 decimal bytes.
PDSTK    EQU 726
PDEND    EQU 2726
PUSTK    EQU 2726
PUEND    EQU 4726



! ------------------------------------------------------------
! HIRES foreground / pen parameter
! ------------------------------------------------------------

HPEN     EQU 4726


! ------------------------------------------------------------
! SCALE coefficients
! ------------------------------------------------------------

CXOFF    EQU 4736
CYOFF    EQU 4746

CXFAC    EQU 4756
CYFAC    EQU 4766


! ------------------------------------------------------------
! Mapped coordinates
! ------------------------------------------------------------

MX1      EQU 4776
MY1      EQU 5006

MX2      EQU 5016
MY2      EQU 5026


! ------------------------------------------------------------
! MAPXY scratch
! ------------------------------------------------------------

MXIN     EQU 5036
MYIN     EQU 5046

MXOUT    EQU 5056
MYOUT    EQU 5066


! ------------------------------------------------------------
! REAL clipping constants
! ------------------------------------------------------------

CZERO    EQU 5076
CXMAX    EQU 5106
CYMAX    EQU 5116


! ------------------------------------------------------------
! Clipped integer coordinates
! ------------------------------------------------------------

IX1      EQU 5126
IY1      EQU 5127

IX2      EQU 5130
IY2      EQU 5131


! ------------------------------------------------------------
! Raster rows
! ------------------------------------------------------------

RTOP     EQU 5132
RBOT     EQU 5133


! ------------------------------------------------------------
! Drawing mode
! ------------------------------------------------------------

MODE     EQU 5134


! ------------------------------------------------------------
! CRT read mode
!
! 0 = normal INCHR
! 1 = CRT wiped out; INCHR- is safe
! ------------------------------------------------------------

CRTFLG   EQU 5135


! ------------------------------------------------------------
! Original CRT address
! ------------------------------------------------------------

SAVCRT   EQU 5136


! ------------------------------------------------------------
! SET/CLEAR streaming scratch
! ------------------------------------------------------------

CURADR   EQU 5140
CURMSK   EQU 5142
NEWBYTE  EQU 5143


! ------------------------------------------------------------
! SCANLINE BUFFER
!
! 40 octal = 32 decimal bytes.
!
! This represents exactly one complete HP-85 graphics row:
!
!       32 bytes x 8 pixels = 256 pixels
! ------------------------------------------------------------

ROWBUF   EQU 5144
WORKSZ   EQU 5204       ! end of writable workspace / 2692 decimal bytes


! ============================================================
! ============================================================
! HP-85 SYSTEM SYMBOLS -- all addresses OCTAL
! ============================================================

ROMFL   DAD 101231
FWUSER  DAD 100000
UNBAS2  DAD 102556
SCRAT+  DAD 4344
ROMRTN  DAD 4762

BINTAB  DAD 101233

SAGBAS  DAD 102542

CRTBYT  DAD 100176
CRTWRS  DAD 101016
TOS     DAD 101132
DRG     DAD 100125

SCAN    DAD 11262
NUMVP   DAD 12407
NUMVAL  DAD 12412
GETCM   DAD 13414
ERRORP  DAD 6611

ONER    DAD 56215
MPY10   DAD 52562
ADD10   DAD 52233
SUB10   DAD 52137
DIV10   DAD 51644
COMFLT  DAD 32621
CONBIN  DAD 03572
CONINT  DAD 44321
SIN10   DAD 53546
COS10   DAD 53556
DEG.    DAD 61736

ROMJSB  DAD 4776
PPGCLR  DAD 64557
PPSCAL  DAD 64041
PPPEN   DAD 64241
PPMOVE  DAD 64400
PPDRAW  DAD 64435

BYTCR!  DAD 35422
CHKSTS  DAD 36335
INCHR   DAD 35244
INCHR-  DAD 35220
CRTDAT  DAD 177407

OUTSTR  DAD 35052

        FIN
