! ============================================================
! SIMON85 v0.11d ARC/CIRCLE INCREMENTAL TRIG OPTIMIZATION (based on frozen v0.11c baseline)
!
! HIRES + BLOCK + LINE + SHAPES + PAINT + PLOT + TEST + PRINTSCREEN + PRTSET + PRTKEYS
!
! Commands:
!
!       VERSION
!       BLOCK x1,y1,x2,y2,f
!       HIRES j,k
!       LINE x1,y1,x2,y2,f
!       REC x,y,b,h,f
!       ARC mx,my,ws,we,ww,rx,ry,f
!       CIRCLE x,y,rx,ry,f[,n]
!       ANGL x,y,w,rx,ry,f
!       PAINT x,y,f
!       PLOT x,y,f
!       TEST(x,y)        ! returns CRT pixel state 0 or 1
!       PRINTSCREEN device,driver[,zoom[,orientation]]   ! 1=ThinkJet, 2=SII/IFD501
!       PRTSET device,driver[,zoom[,orientation]]          ! keyboard hardcopy profile
!       PRTKEYS mode     ! 0=restore CHIDLE, 1=install SIMON85 COPY/PAPER keys
!
! f:
!
!       0 = CLEAR
!       1 = SET
!       2 = XOR
!
!
! v0.05i strategy
! ----------------
!
! SET / CLEAR:
!
!       retain proven v0.05f streaming rasterizer
!
! XOR:
!
!       READROW
!           position once at scanline start
!           sequentially read 32 bytes -> ROWBUF
!
!       modify requested X range entirely in RAM
!
!       WRTROW
!           position once at scanline start
!           sequentially stream 32 bytes -> CRT
!
!
! ROWBUF is 32 bytes:
!
!       256 pixels / 8 pixels per byte = 32 bytes
!
!
! This establishes reusable scanline primitives for:
!
!       XOR
!       future flood fill
!       bitmap manipulation
!       sprites / patterns
!
!
! v0.05h adds CRT-state-aware reads:
!
!       CRTWRS bit 1 clear -> INCHR
!       CRTWRS bit 1 set   -> INCHR-
!
! BASIC CRT OFF was physically verified to leave CRTWRS = 6
! in alpha mode: wipeout + power-down.  BLOCK never changes
! CRT state itself; CRT OFF / CRT ON remains under user control.
!
! The wipeout state is sampled once per BLOCK and stored in
! CRTFLG for use by READROW and partial-byte SET/CLEAR reads.
!
!
! v0.05i bug fix:
!
!       SBREAD must preserve R20 because FASTROW uses R20 as the
!       live current-X counter across calls to STRBYT.  v0.05h
!       temporarily used R20 to inspect CRTFLG, corrupting X after
!       a partial-byte read.  R40 is used instead; MODE is reloaded
!       immediately after the read, so R40 is safe to clobber here.
!
!
! v0.06a adds HIRES j,k:
!
!       equivalent to:
!
!           GCLEAR
!           SCALE 0,320,200,0
!           PEN j
!
!       k is parsed/evaluated for Simons' BASIC compatibility but
!       otherwise ignored on the HP-85.  j is preserved unchanged;
!       SIMON85 performs no range check or clamping.
!
!       This first implementation invokes the documented HP-85 CRT
!       GCLEAR/SCALE/PEN runtimes.  The Plotter/Printer ROM 360 state
!       used by BLOCK remains the hardware test point for SCALE; the
!       original j REAL is retained in HPEN for later plotter dispatch.
!
!
! v0.06c correction:
!
!       SCALE. and PEN. are system-ROM routines marked ROMJSB=Y for
!       callers executing from an external ROM.  SIMON85 is a RAM
!       binary program, not an external ROM.  HP's own binary-program
!       examples call such system routines directly; only the ROM
!       versions use ROMJSB.  Therefore HIRES now calls SCALE. and
!       PEN. directly.  No other HIRES logic is changed.
!
!
! v0.06d diagnostic:
!
!       HIRES parser is unchanged.  Runtime does ONLY:
!
!           consume k with ONER
!           consume/store j with ONER
!           return
!
!       No GCLEAR, SCALE or PEN routine is called.  This isolates
!       parameter parsing/evaluation from the graphics runtimes.
!
!
! v0.06e diagnostic:
!
!       v0.06d physically proved that HIRES parsing, expression
!       evaluation and ONER retrieval of j,k are correct.
!
!       This build adds ONLY GCLEAR after consuming the two HIRES
!       arguments.  SCALE and PEN remain absent.  TOS is handled
!       exactly as documented by HP for a no-parameter GCLR. call:
!       save TOS on R6, set TOS = R12, call GCLR., restore TOS.
!
!
! v0.06f diagnostic:
!
!       v0.06e physically proved the GCLEAR call and documented
!       TOS handling.  Adding the system CRT SCALE. routine with
!       SCALE 0,320,200,0 produces ERROR 89 INVALID PARAM.
!
!
! v0.06g diagnostic:
!
!       Native BASIC with Printer/Plotter ROM 360 accepts the
!       reflected Y scale SCALE 0,320,200,0, but HP's base CRT
!       SCALE statement documentation requires increasing minima/
!       maxima.  This build therefore changes ONLY the SCALE.
!       arguments to the non-reflected:
!
!           SCALE 0,320,0,200
!
!       PEN remains absent.  If this succeeds, the failure in
!       v0.06f is specifically the reflected Y axis through the
!       bare system CRT SCALE. entry point rather than our stack.
!
!
! v0.06h diagnostic:
!
!       Inspection/disassembly of the actual EBTKS ROM 360 image
!       identifies token 8, SCALE, with runtime entry 064041 octal.
!       The ROM entry itself loads AGLBAS and consumes the four
!       SCALE parameters from R12.
!
!       This build restores the desired reflected scale:
!
!           SCALE 0,320,200,0
!
!       but invokes ROM 360 entry 064041 through ROMJSB.
!       GCLEAR remains the physically-proven system GCLR. path and
!       PEN is still absent, isolating the ROM360 SCALE call.
!
!
! v0.06i:
!
!       v0.06h was physically verified: HIRES clears the graphics
!       screen and ROM360 SCALE 0,320,200,0 correctly updates the
!       coefficients used by BLOCK.
!
!       This build completes HIRES by adding PEN j through the
!       Printer/Plotter ROM 360 PEN runtime at 064241 octal.  The
!       evaluated j value is passed unchanged to ROM360; SIMON85
!       performs no range check or clamping.  k remains ignored.
!
!
! v0.06j:
!
!       HIRES now uses the Printer/Plotter ROM 360 GCLEAR runtime
!       at 064557 octal as well.  This keeps GCLEAR, SCALE and PEN
!       on the same device-aware ROM360 graphics path and removes
!       the special TOS handling previously needed by system GCLR.
!
!
! v0.07a:
!
!       Adds Simons' BASIC compatible:
!
!           LINE x1,y1,x2,y2,f
!
!       f=1 through ROM360 MOVE/DRAW was physically verified.
!       The attempted f=0 implementation (temporary ROM360 PEN 0)
!       correctly suppressed drawing but did NOT erase an existing
!       CRT line.  This established that ROM360 PEN 0 is a no-draw
!       state rather than Simons' BASIC CLEAR semantics.
!
!
! v0.07b:
!
!       Keeps the physically-proven f=1 ROM360 path unchanged and
!       adds an integer Bresenham CRT rasterizer for:
!
!           f=0 -> CLEAR one CRT bit per Bresenham pixel
!           f=2 -> XOR   one CRT bit per Bresenham pixel
!
!       f=0 and f=2 deliberately produce no plotter output.
!       The direct CRT path uses the active ROM360 SCALE mapping,
!       the proven CRT-state-aware INCHR/INCHR- read rule, and
!       restores the caller's CRT byte address before returning.
!
!       v0.07b is intentionally an on-screen-endpoints build:
!       both mapped endpoints must lie inside 0..255 / 0..191.
!       Proper clipping of partially visible lines is deferred.
!
!       ROM360 vector entries used by f=1:
!
!           MOVE = 064400 octal
!           DRAW = 064435 octal
!
!
! v0.07c:
!
!       v0.07b was physically verified for all three LINE modes:
!
!           f=1 -> ROM360 vector draw
!           f=0 -> direct CRT Bresenham CLEAR
!           f=2 -> direct CRT Bresenham XOR
!
!       This build changes ONLY the direct CRT f=0/f=2 path by
!       adding Cohen-Sutherland clipping in mapped REAL graphics
!       coordinates before conversion to integer CRT pixels.
!
!       Partly visible lines are clipped to the 0..255 / 0..191
!       logical CRT rectangle.  Completely invisible lines are
!       rejected without touching the CRT.  The proven Bresenham
!       and pixel read/modify/write code is otherwise unchanged.
!

!
! v0.08a:
!
!       v0.07c was physically verified for LINE SET/CLEAR/XOR and
!       Cohen-Sutherland clipping.  This build adds four composite
!       Simons' BASIC graphics primitives on top of that proven LINE
!       infrastructure:
!
!           REC x,y,b,h,f
!           ARC mx,my,ws,we,ww,rx,ry,f
!           CIRCLE x,y,rx,ry,f
!           ANGL x,y,w,rx,ry,f
!
!       Every generated segment is routed through the same LINE policy:
!
!           f=1 -> ROM360 MOVE/DRAW (CRT + active plotter)
!           f=0 -> clipped direct-CRT CLEAR
!           f=2 -> clipped direct-CRT XOR
!
!       ARC/ANGL use Simons' degree convention: 0 degrees is vertically
!       above the centre, 90 degrees is to the right.  CIRCLE is the
!       Simons ARC special case 0..360 with 12-degree step.  The HP-85
!       trig mode is temporarily changed to DEG and its DRG byte restored
!       afterwards.
!
!
! v0.08b:
!
!       v0.08a was physically verified for REC, ARC, CIRCLE and ANGL.
!       CIRCLE now accepts one optional sixth numeric parameter:
!
!           CIRCLE x,y,rx,ry,f[,n]
!
!       If n is omitted, the original Simons' BASIC behaviour is
!       preserved: 30 line segments (12 degrees per segment).
!       If n is present, exactly n line segments are generated and
!       the angular increment is 360/n degrees.  The final segment
!       is forced to end at exactly 360 degrees, avoiding accumulated
!       floating-point error and guaranteeing exact closure.
!
!       Valid n range: 3..360.  Other values report ERROR 89.
!       ARC is unchanged and continues to use its explicit ww angle
!       increment parameter.
!
!
! v0.09a:
!
!       Adds PAINT x,y,f using an iterative scanline flood fill.
!       The seed point is mapped through the active ROM360 SCALE.
!       Physical pixel coordinates used by the new PAINT engine are
!       stored as 16-bit values even though the HP-85 backend is
!       currently 256 x 192.  This deliberately avoids baking an
!       8-bit X-coordinate assumption into the new raster API.
!
!       PAINT operates on the CRT only:
!
!           f=0  clear connected seed-colour region
!           f=1  set connected seed-colour region
!           f=2  toggle connected seed-colour region
!
!       The implementation reuses the physically-proven READROW /
!       WRTROW scanline primitives and a bounded internal seed stack.
!
! v0.09b:
!
!       First hardware bug-fix build after v0.09a locked up before
!       painting the first visible span.  The PAINT coordinate
!       conversion no longer assumes that CONINT's companion byte
!       R77 is defined for the clipped HP-85 pixel range.  X and Y
!       are clipped as REALs first (0..255 / 0..191), then the proven
!       low result byte R76 is explicitly zero-extended into the
!       16-bit PAINT coordinate variables.  The 16-bit PAINT stack
!       and internal interfaces are retained unchanged.
!
!       This specifically prevents a stray high byte from turning an
!       on-screen seed into a large 16-bit X value and making the
!       right-span expansion loop run until 16-bit wraparound before
!       the first row is written.
!
! v0.10a:
!
!       Adds PLOT x,y,f as the direct single-pixel primitive.
!
!       f=1 is hybrid, matching the established LINE policy:
!           - CRT: mapped pixel is explicitly SET through the direct
!             raster/ROWBUF path, guaranteeing a visible CRT pixel.
!           - ROM360: MOVE x,y ; DRAW x,y ; MOVE x,y.  On an attached
!             plotter this moves pen-up to the point, lowers the pen
!             at that point, then raises it again.
!
!       f=0 and f=2 are CRT-only:
!           f=0 -> CLEAR the mapped pixel
!           f=2 -> XOR the mapped pixel
!       No plotter operation occurs for these modes.
!
!       Raw BASIC coordinates are passed unchanged to ROM360 for f=1.
!       CRT mapping uses the active ROM360 SCALE coefficients and clips
!       independently to the 256 x 192 CRT.  Thus an f=1 point may still
!       be meaningful to a plotter even when its mapped CRT point lies
!       outside the display.
!
!       Invalid f values follow LINE semantics and are a no-op.
!
!
! v0.10b:
!
!       Adds the first SIMON85 numeric-function keyword:
!
!           TEST(x,y)
!
!       This diagnostic build deliberately does NOT read the CRT yet.
!       It proves only HP BASIC numeric-function integration.
!
!       The HP-83/85 Assembler manual specifies attributes 40,55
!       (octal) for a numeric system function with two numeric parameters.
!       BASIC therefore parses both expressions automatically; no custom
!       TEST parse routine is required.  The corresponding PARSE-table
!       entry is a two-byte dummy slot.
!
!       At runtime TEST consumes y and x with ONER, then pushes a REAL 1
!       onto the R12 operating stack.  Thus every valid TEST(x,y) returns
!       exactly 1 in v0.10b, independent of its arguments.
!
!       Once this function-return path is hardware-verified, v0.10c can
!       replace only the constant-result body with SCALE mapping plus the
!       proven raster pixel-read path.
!
!
! v0.10c:
!
!       v0.10b was physically verified on the HP-85: TEST(x,y) parses as
!       a two-parameter numeric function, arbitrary numeric expressions are
!       accepted, ONER consumes the arguments correctly, and a REAL result
!       can be returned safely on the R12 operating stack.
!
!       This build keeps that proven function shell and replaces only the
!       constant-result diagnostic body with the real CRT pixel lookup:
!
!           TEST(x,y)
!               -> active ROM360 SCALE mapping
!               -> zero-length LCLIP point test
!               -> PXC/PYC conversion
!               -> CRT-state-aware PRDROW
!               -> PGET
!               -> REAL 0 or 1 returned on R12
!
!       TEST is raster-only.  It performs no MOVE, DRAW, PEN or other
!       plotter operation.  A mapped point outside the 256 x 192 CRT returns
!       0 without reading the CRT.
!
!
!
! v0.10d:
!
!       Parser-only diagnostic for PRINTSCREEN.  Hardware verification
!       established that the 11-character keyword coexists correctly with
!       the built-in PRINT statement.
!
!
! v0.10e:
!
!       First HP-IB transport diagnostic:
!
!           PRINTSCREEN device,driver
!
!       Example:
!
!           PRINTSCREEN 702,1
!
!       device is currently restricted to HP-IB interface select code 7
!       with primary addresses 00..30, i.e. BASIC device selectors
!       700..730.  driver must be 1 or 2; the driver value is validated but
!       is otherwise deliberately unused in this transport-only build.
!
!       The runtime performs the HP low-level sequence documented in the
!       Assembly Language I/O Reference Manual:
!
!           - translator CCR/PSR = 177530 octal (select code 7)
!           - translator OB/IB   = 177531 octal
!           - write control register 16 = 0 to suppress automatic EOL
!           - HP-IB UNLISTEN
!           - Send My Talk Address
!           - send listener address 40 octal + primary address
!           - simple-output protocol 240 octal
!           - send the explicit byte stream "SIMON85 HPIB OK" + CR/LF
!           - UNLISTEN the peripheral
!           - restore control register 16 to 2 (CR/LF default)
!
!       There is intentionally no screen read and no ThinkJet/SII graphics
!       protocol yet.  This build proves only parsing, address derivation,
!       direct HP-IB addressing, EOL suppression and simple byte output.
!       It follows the same CR16 0 -> 2 convention as the working BASIC
!       hardcopy programs; preservation of a non-default pre-existing CR16
!       value is deferred until the transport itself is hardware-proven.
!
!       No timeout/recovery path is present yet.  Execute this diagnostic
!       only with the selected HP-IB device online and listening.
!
!
! v0.10f:
!
!       First real PRINTSCREEN printer driver.  Driver 1 targets the
!       HP ThinkJet 2225A and is a direct assembly implementation of the
!       physically working PCOPY.BAS protocol specification.
!
!           PRINTSCREEN 702,1
!
!       sends, with automatic interface EOL suppressed:
!
!           ESC * r 192 S
!           ESC * r A
!           192 times:
!               ESC * b 32 W
!               32 raw HP-85 CRT raster bytes
!           ESC * r B
!
!       The HP-85 raster is read directly from physical row 0 through 191.
!       Existing READROW / ROWBUF are reused unchanged.  PRINTSCREEN samples
!       the CRT read state and preserves/restores the caller's CRT byte pointer.
!       No scaling, rotation or pixel conversion is performed in this build.
!
!       Driver 2 remains reserved for the SII/IFD501 implementation and returns
!       ERROR 89 in v0.10f rather than sending a misleading diagnostic stream.
!
!       v0.10e fix1 is the physically verified HP-IB transport baseline and its
!       low-level HPIB7/HPDIR/HPSNDC/HPCTRL/HPADRO/HPOUT routines are unchanged.
!
!
! v0.10g:
!
!       Extends the physically verified ThinkJet driver with software zoom
!       and 90-degree clockwise landscape rotation:
!
!           PRINTSCREEN device,driver[,zoom[,orientation]]
!
!       zoom:        1 = normal (default), 2 = 2x, 4 = 4x
!       orientation: 0 = portrait/direct raster (default), 1 = 90-degree CW
!
!       The ThinkJet remains in its 192 x 96 dpi graphics mode selected by
!       ESC*r192S.  Zoom is therefore implemented solely by pixel/row
!       duplication: 32-byte portrait rows become 64 or 128 bytes and are
!       transmitted 2 or 4 times.  At 4x the 1024-dot portrait width remains
!       within the ThinkJet's 1280-dot high-density print region.
!
!       Landscape uses a 192-byte eight-row band buffer; each source CRT byte
!       is read only once per band and its eight pixels are scattered into
!       eight rotated 24-byte output rows.  Rotated rows expand to 48 or 96
!       bytes at 2x/4x.  Driver 2 remains reserved for SII/IFD501.
!
!
! v0.10h:
!
!       Adds driver 2 for the Seiko Instruments IFD501-01UK-E with
!       CAPD345A print mechanism.  This first SII build deliberately uses the
!       same standard-mode GS v 0 raster path as the physically working
!       SIIDUMP.BAS reference rather than page mode:
!
!           PRINTSCREEN device,2[,zoom[,orientation]]
!
!       The CAPD345A has 576 printable dots.  Driver 2 therefore supports:
!
!           zoom 1: portrait 256x192, landscape 192x256
!           zoom 2: printer-native double width+height (GS v 0 m=3),
!                   portrait 512x384, landscape 384x512
!
!       zoom 4 is rejected for driver 2 because it would require 1024 dots
!       in portrait or 768 dots in landscape, both wider than the 576-dot
!       CAPD345A mechanism.  ThinkJet driver 1 retains zoom 1/2/4 unchanged.
!
!       Portrait sends one GS v 0 header for 32 bytes x 192 rows followed by
!       the existing 192 ROWBUF scanlines.  Landscape reuses the verified
!       v0.10g clockwise transpose engine and sends 24 bytes x 256 rows.
!       Pixel polarity is unchanged: HP-85 set pixels are sent as 1 bits.
!
!       After the raster payload, ESC d 4 advances four printer lines, matching
!       the practical paper-advance intent of the original SIIDUMP.BAS test.
!       Page mode remains deferred until this direct raster path is proven.
!
!
! v0.10h1:
!
!       Fixes HP-IB device-selector decoding without changing the verified
!       ThinkJet driver code or its raster/zoom/landscape implementation.
!
!       PRINTSCREEN now decodes the normal HP BASIC device selector:
!
!           selector = 100 * select_code + primary_address
!
!       and accepts select codes 3..10 with primary addresses 0..30.
!       Examples:
!
!           311 -> select code 3, primary address 11
!           702 -> select code 7, primary address 2
!
!       The legacy HPIB7 entry label is retained so the physically verified
!       ThinkJet code remains source-identical.  HPIB7 now derives the
!       correct CCR/PSR and OB/IB pair from PSCODE:
!
!           SC3  -> 177520 / 177521
!           ...
!           SC7  -> 177530 / 177531
!           ...
!           SC10 -> 177536 / 177537
!
!       SII/IFD501 raster formatting is otherwise unchanged from v0.10h.
!
!
! v0.10h3:
!
!       Replaces the failed long-lived SII HP-IB streaming experiment with
!       self-contained one-row GS v 0 raster commands.  No HP-IB output
!       transaction remains active while CRT memory is accessed.
!
!       Portrait:  192 commands, each 8-byte GS v 0 header + 32-byte row.
!       Landscape: 256 commands, each 8-byte GS v 0 header + 24-byte row.
!
!       The existing 64-byte TJSBUF is reused as the temporary row-packet
!       buffer, so no 6144-byte framebuffer is allocated.  Driver 1, the
!       v0.10h1 HP-IB selector decoding, HPIB7 and HPOUT are unchanged.
!
!       SII zoom 1 uses m=0; zoom 2 uses m=3 (printer-native double width
!       and double height).  Zoom 4 remains rejected for driver 2.
!
!
! v0.10h4:
!
!       Hardware testing proved the v0.10h3 row-packet raster path for SII
!       portrait, zoom and landscape.  The remaining fault was HP-IB CR16
!       cleanup: after some PRINTSCREEN calls, subsequent BASIC OUTPUT lost
!       its automatic CR/LF and later PRINTSCREEN calls could misbehave.
!
!       BASIC CONTROL <select-code>,16;2 immediately and repeatedly repaired
!       the condition, proving CR16 restoration is sufficient.
!
!       Driver 2 now takes its own cleanup path after SIIDRV:
!
!           HPIB7             -> selects translator from PSCODE
!           HPCTRL CR16 = 2  -> restores normal CR/LF EOL handling
!
!       PSCODE is decoded from PRINTSCREEN's first parameter, so this is NOT
!       hardcoded to SC3 or SC7.  Examples:
!
!           PRINTSCREEN 311,... -> cleanup uses select code 3
!           PRINTSCREEN 702,... -> cleanup uses select code 7
!
!       The SII cleanup deliberately omits the previous explicit UNLISTEN
!       command (077 octal), which was observed appearing as a printed '?' in
!       failing cases before CR16 restoration.
!
!       Driver 1 (ThinkJet), SII raster generation, generic selector decoding,
!       HPIB7, HPCTRL and HPOUT are otherwise unchanged from v0.10h3.
!
!
! v0.10h5:
!
!       Adds a short CPU-only settling delay before the SII CR16=2 cleanup.
!       Physical testing showed this makes repeated output substantially more
!       reliable through the EBTKS virtual HP-IB interface.
!
!
! v0.10i:
!
!       SII performance build based on the verified v0.10h5 baseline.
!       Eight raster rows are batched into each GS v 0 command while retaining
!       the rule that no HP-IB transaction spans CRT access.
!
!       Portrait:  192 one-row transactions -> 24 eight-row transactions.
!       Landscape: 256 one-row transactions -> 32 eight-row transactions.
!
!       A 264-byte SIIPKT workspace is added.  ThinkJet code, generic HP-IB
!       routing and the v0.10h5 EBTKS CR16 settling delay remain unchanged.
!
!
! v0.10i2:
!
!       Keeps the verified v0.10i1 eight-row batching unchanged and hardens
!       only the SII/EBTKS CR16 cleanup: the initial CPU-only delay is doubled,
!       CR16=2 is written twice through generic HPIB7/HPCTRL, and a short
!       CPU-only settling delay separates the writes and precedes BASIC return.
!       PSCODE remains derived from PRINTSCREEN's first device parameter.
!
!
! v0.10j:
!
!       Adds automatic SII-only CRT wipeout/power-down around PRINTSCREEN.
!       If the caller's CRT is active, driver 2 calls CRTPOF before HP-IB output,
!       forces CRTFLG=1 so READROW/TJLBD use the fast INCHR- path, and records
!       PSAUTO=1.  After the unchanged v0.10i2 CR16 cleanup, CRTPUP is called
!       only when PSAUTO=1.  If the CRT was already wiped/off, its state is
!       preserved and no automatic power-up occurs.  ThinkJet is unchanged.
!
!
! v0.11e:
!
!       ARC/CIRCLE polyline dispatch optimization on top of v0.11d.
!       The v0.11d incremental trigonometry is unchanged.
!
!       For f=1 the generated ellipse/arc is now sent to ROM360 as one
!       continuous polyline: one MOVE to the initial perimeter point followed
!       by one DRAW for each generated endpoint.  v0.11d previously routed
!       every chord through SHLINE/LNDRAW, causing a redundant MOVE before
!       every DRAW and two ROM360 vector calls per chord.
!
!       The composite mode SF is converted to LMODE once at primitive setup.
!       For f=0/f=2 the existing direct CRT LRAST path is retained, but it
!       also reuses that cached mode instead of repeating CONINT for every
!       chord.  REC, ANGL and standalone LINE remain unchanged.
!
!       ARC preserves the no-segment case: no initial ROM360 MOVE is emitted
!       unless start < effective end, so a zero-length ARC remains a no-op.
!
!
! v0.11d:
!
!       ARC/CIRCLE performance build based directly on the frozen v0.11c
!       baseline.  All printer, keyboard, raster, parser and ROM360 routing
!       code is unchanged.
!
!       The expensive per-point SIN10/COS10 evaluation is removed from the
!       normal ARC/CIRCLE segment loop.  At primitive setup RINIT evaluates
!       SIN/COS for the starting angle and for the angular step once, then
!       each ordinary point advances with the first-order rotation recurrence:
!
!           sin(a+d) = sin(a)*cos(d) + cos(a)*sin(d)
!           cos(a+d) = cos(a)*cos(d) - sin(a)*sin(d)
!
!       RPOINT applies the existing rx/ry scaling and centre translation,
!       so generated coordinates remain HP REAL user coordinates and the
!       established SHLINE/ROM360 plotter-aware path is unchanged.
!
!       Exact-end behaviour is deliberately retained:
!           - CIRCLE's final endpoint is still evaluated at exactly 360 deg.
!           - ARC still evaluates a clamped residual endpoint explicitly when
!             the requested span is not an exact multiple of ww.
!       ANGL continues to use ANGPT/SIN10/COS10 unchanged.
!
!       Physical BASIC drift testing over 360 one-degree recurrence steps
!       measured maximum sin/cos errors around 1E-9, far below CRT or plotter
!       coordinate resolution.
!
!
! v0.11c:
!
!       Cleanup-only branch from the frozen, hardware-verified v0.11b1
!       baseline.  Printer protocols, graphics algorithms, CHIDLE takeover,
!       PRTSET semantics and the verified v0.10j SII landscape path remain
!       unchanged.
!
!       Changes:
!
!           - remove development-only BASIC diagnostics:
!                 KEYCODE, KEYCOUNT, RAWKEY, KEYSTATUS
!
!           - remove their private capture state and KEYCOD sampling;
!             retain only one private KSHIFT byte containing KEYSTS bit 3
!             sampled before EOJ2 for PAPER vs SHIFT+PAPER dispatch
!
!           - rename public HELLO command to VERSION
!
!           - PRINTSCREEN returns silently after a successful hardcopy;
!             remove the "PRINTSCREEN SENT" string and OUTSTR call
!
!           - remove obsolete PSKEY state left over from the pre-v0.11b1
!             PRINTSCREEN/COPY return-path experiment
!
!       VERSION is intended as the new public version-report command.  The
!       available HP-85 project documentation did not identify VERSION as a
!       built-in keyword; physical parser testing remains the final check.
!
!
! v0.11b1:
!
!       CAPASM branch-range correction only.  v0.11b assembled far enough to
!       prove four new relative transfers exceeded the Capricorn JMP/Jcc range:
!
!           KHCREL -> KHEOJ
!           KGRAPH -> PSSTRT
!           TXTCOPY row loop -> TXROW
!           PRNSCR -> PSSTRT
!
!       Corrections:
!
!           - handled CHIDLE exits are kept local instead of jumping to a
!             distant common KHEOJ label;
!           - PSSTRT is now a true internal subroutine.  PRINTSCREEN and
!             keyboard graphics COPY both JSB X14,PSSTRT;
!           - the BASIC PRINTSCREEN confirmation/PAD wrapper lives in PRNSCR.;
!           - TXTCOPY uses a tiny outer row loop calling TXT1ROW, so its JNZ
!             stays comfortably inside relative-branch range.
!
!       No printer protocol, raster algorithm, PRTSET semantics, keyboard
!       keycode logic or v0.10j SII landscape code is changed.
!
!
! v0.11b:
!
!       First functional external-printer keyboard build, deliberately based
!       on the verified v0.10j graphics/printer path plus the hardware-proven
!       v0.11a2 CHIDLE takeover.  No v0.10k fast-transpose code is included.
!
!       New BASIC configuration:
!
!           PRTSET device,driver[,zoom[,orientation]]
!           PRTKEYS 1
!           PRTKEYS 0
!
!       PRTSET validates exactly the same selector / driver / zoom /
!       orientation rules as PRINTSCREEN but stores an independent keyboard
!       hardcopy profile.  PRINTSCREEN does not alter that profile.
!
!       COPY (KEYHIT 0211 octal / 137 decimal):
!
!           CRTWRS bit 7 = 0  -> copy currently visible 16x32 alpha display
!           CRTWRS bit 7 = 1  -> invoke the existing v0.10j graphics hardcopy
!                               using the stored PRTSET profile
!
!       Alpha COPY starts at CRTRAM (the current display/home address), reads
!       exactly 16 visible rows x 32 characters, masks CRT underline/cursor
!       bit 7, appends CR/LF to each row, and sends normal printer text.
!       Alpha address wrap at 010000 octal is handled explicitly.
!
!       PAPER ADVANCE (KEYHIT 0212 octal / 138 decimal):
!
!           KEYSTS bit 3 clear -> LF; holding the key repeats after a delay
!           KEYSTS bit 3 set   -> one page advance; no repeat
!
!       KEYSTS bit 3 is based on physical HP-85A measurements:
!
!           normal PAPER ADVANCE : KEYSTS = 247 decimal / 0367 octal
!           SHIFT+PAPER ADVANCE   : KEYSTS = 255 decimal / 0377 octal
!
!       This SHIFT interpretation is therefore a SIMON85 hardware-verified
!       observation, not a documented HP KEYSTS bit definition.
!
!       Driver-specific paper controls:
!
!           ThinkJet: LF = ASCII 0Ah, page advance = FF 0Ch
!           SII:      LF = ASCII 0Ah, page advance = ESC d 66
!
!       v0.11a2 proved that CLE + EOJ2 followed by discarding two R6 returns
!       completely suppresses the native internal-printer COPY/PAPER action.
!       That takeover sequence is retained.
!
!       (Historical v0.11b note: diagnostic keyboard functions were retained
!       in that development build; v0.11c removes them.)
!
!
! HP-85 graphics geometry:
!
!       resolution       = 256 x 192
!       graphics base    = 010000 octal
!       row stride       = 0100 octal nibble addresses
!       byte stride      = 2 nibble addresses
!       8 pixels / byte
!       MSB = leftmost pixel
!
!
! Requires Printer/Plotter ROM 360 for SCALE mapping.
! ============================================================


        NAM SIMON

        DEF RUNTIM
        DEF ASCIIS
        DEF PARSE
        DEF ERMSG
        DEF INIT


! ============================================================
! TABLES
! ============================================================

PARSE   BYT 0,0
        DEF VERSNP
        DEF BLOCKP
        DEF HIRESP
        DEF BLOCKP      ! LINE:   five numeric parameters
        DEF BLOCKP      ! REC:    five numeric parameters
        DEF ARCP        ! ARC:    eight numeric parameters
        DEF CIRCLP      ! CIRCLE: five + optional sixth numeric parameter
        DEF ANGLP       ! ANGL:   six numeric parameters
        DEF PAINTP      ! PAINT:  three numeric parameters
        DEF PAINTP      ! PLOT:   three numeric parameters
        DEF PRNSCP      ! PRINTSCREEN: device,driver[,zoom[,orientation]]
        DEF PRNSCP      ! PRTSET: same argument syntax / validation
        DEF PKEYSP      ! PRTKEYS mode
        BSZ 2           ! TEST:     implied function parser from attributes

RUNTIM  BYT 0,0
        DEF VERSN.
        DEF BLOCK.
        DEF HIRES.
        DEF LINE.
        DEF REC.
        DEF ARC.
        DEF CIRCL.
        DEF ANGL.
        DEF PAINT.
        DEF PLOT.
        DEF PRNSCR.
        DEF PSET.
        DEF PKEYS.
        DEF TEST.
        BYT 377,377

ASCIIS  ASP "VERSION"
        ASP "BLOCK"
        ASP "HIRES"
        ASP "LINE"
        ASP "REC"
        ASP "ARC"
        ASP "CIRCLE"
        ASP "ANGL"
        ASP "PAINT"
        ASP "PLOT"
        ASP "PRINTSCREEN"
        ASP "PRTSET"
        ASP "PRTKEYS"
        ASP "TEST"

ERMSG   BYT 377


! ============================================================
! INIT -- keyboard-hook de-initialization only
!
! v0.11d, like v0.11c, never installs CHIDLE automatically.  On LOADBIN (ROMFL=3)
! initialise only our private flags.  If the resident binary is removed by
! SCRATCH (2) or LOAD (5), restore the exact seven bytes saved by PRTKEYS 1.
!
! Per the HP Assembler manual INIT uses only registers >=R20 after ROMFL has
! been established not to be one of the token-allocation callbacks 10..12.
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
! VERSION PARSER
! ============================================================

VERSNP  LDB R47,R43

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
! BLOCK PARSER
!
!       BLOCK x1,y1,x2,y2,f
! ============================================================

BLOCKP  PUBD R43,+R6

        JSB =NUMVP
        JEN B1OK
        JMP BERR

B1OK    JSB =GETCM
        JSB =NUMVAL
        JEZ BERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ BERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ BERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ BERR

        POBD R47,-R6

        LDB R45,=371
        PUMD R45,+R12

        RTN


BERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! HIRES PARSER
!
!       HIRES j,k
! ============================================================

HIRESP  PUBD R43,+R6

        JSB =NUMVP
        JEN H1OK
        JMP HERR

H1OK    JSB =GETCM
        JSB =NUMVAL
        JEZ HERR

        POBD R47,-R6

        LDB R45,=371
        PUMD R45,+R12

        RTN


HERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! PRINTSCREEN PARSER -- v0.10g
!
!       PRINTSCREEN device,driver[,zoom[,orientation]]
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

        JSB =NUMVP
        JEN C1OK
        JMP CERR

C1OK    JSB =GETCM
        JSB =NUMVAL
        JEZ CERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ CERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ CERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ CERR


! Optional sixth numeric parameter?  054 octal is comma.

        CMB R14,=54
        JNZ CDONE

        JSB =NUMVP
        JEZ CERR

CDONE   POBD R47,-R6

        LDB R45,=371
        PUMD R45,+R12

        RTN

CERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! ANGL PARSER
!
!       ANGL x,y,w,rx,ry,f
! ============================================================

ANGLP   PUBD R43,+R6

        JSB =NUMVP
        JEN A1OK
        JMP AERR

A1OK    JSB =GETCM
        JSB =NUMVAL
        JEZ AERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ AERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ AERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ AERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ AERR

        POBD R47,-R6

        LDB R45,=371
        PUMD R45,+R12

        RTN

AERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! ARC PARSER
!
!       ARC mx,my,ws,we,ww,rx,ry,f
! ============================================================

ARCP    PUBD R43,+R6

        JSB =NUMVP
        JEN G1OK
        JMP GERR

G1OK    JSB =GETCM
        JSB =NUMVAL
        JEZ GERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ GERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ GERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ GERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ GERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ GERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ GERR

        POBD R47,-R6

        LDB R45,=371
        PUMD R45,+R12

        RTN

GERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! PAINT PARSER
!
!       PAINT x,y,f
! ============================================================

PAINTP  PUBD R43,+R6

        JSB =NUMVP
        JEN P1OK
        JMP PERR

P1OK    JSB =GETCM
        JSB =NUMVAL
        JEZ PERR

        JSB =GETCM
        JSB =NUMVAL
        JEZ PERR

        POBD R47,-R6

        LDB R45,=371
        PUMD R45,+R12

        RTN

PERR    POBD R47,-R6

        JSB =ERRORP
        BYT 81D


! ============================================================
! VERSION RUNTIME
! ============================================================

        BYT 241

VERSN.  LDM R26,=HMSG
        ADMD R26,=BINTAB

        LDM R36,=14D,0

        JSB =OUTSTR

        RTN


! ============================================================
! PRTKEYS RUNTIME -- v0.11b keyboard takeover control
!
!       PRTKEYS 1    install SIMON85 COPY/PAPER CHIDLE hook
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


! PRTKEYS 1 is idempotent.  If SIMON85 already owns CHIDLE, return without
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


! PRTKEYS 0: restore the saved seven bytes only when SIMON85 installed them.

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
! Uses the same PSARGS validation as PRINTSCREEN, then copies the validated
! byte values into a persistent profile used only by physical COPY/PAPER.
! PRINTSCREEN never modifies the stored HC* profile.
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

! Graphics COPY uses the existing v0.10j PRINTSCREEN execution path with the
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
! HCLOAD -- copy stored PRTSET profile to the existing PRINTSCREEN PS* state.
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
! graphics COPY and the BASIC PRINTSCREEN wrapper.
! ------------------------------------------------------------

KGRAPH  BIN
        LDMD R14,=BINTAB

! PSSTRT is a shared internal subroutine.  Physical graphics COPY and the
! BASIC PRINTSCREEN wrapper both call the same verified hardcopy executor.

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
! rule used elsewhere in SIMON85 when a worker body exceeds relative range.

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
! PRINTSCREEN RUNTIME -- v0.10h1 generic HP-IB selector + ThinkJet/SII
!
!       PRINTSCREEN device,driver[,zoom[,orientation]]
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

! Successful PRINTSCREEN remains deliberately silent in v0.11d.

        PAD
        RTN


! ------------------------------------------------------------
! PSARGS -- common PRINTSCREEN / PRTSET argument extraction and validation.
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
! reliably repairs every observed post-PRINTSCREEN failure.  Therefore restore
! CR16 directly and immediately after the final SII HPOUT has completed.
!
! IMPORTANT: HPIB7 is generic.  It derives the translator register pair from
! PSCODE, which was decoded from the first PRINTSCREEN argument.  No select
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
! HPCTRL so the translator always comes from PSCODE decoded from PRINTSCREEN's
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

! v0.10j: restore the CRT only if this PRINTSCREEN call blanked it.
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
! HPIB7 remains generic and uses PSCODE decoded from PRINTSCREEN device.
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

        LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB


! ------------------------------------------------------------
! f
! ------------------------------------------------------------

        JSB =ONER
        BIN

        STMD R#,X14,LF


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

        LDMD R60,X14,LF

        JSB =CONINT

        BIN

        LDMD R14,=BINTAB

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

LSET    LDMD R14,=BINTAB
        JSB X14,LNDRAW

        BIN
        PAD
        RTN


! ------------------------------------------------------------
! f=0 / f=2 -- direct CRT raster path.
! ------------------------------------------------------------

LRAS    LDMD R14,=BINTAB
        JSB X14,LRAST

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

        LDMD R14,=BINTAB

        LDMD R40,X14,LX1
        PUMD R40,+R12

        LDMD R40,X14,LY1
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPMOVE
        BYT 360
        BIN

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

        JSB X14,READMAP


! ------------------------------------------------------------
! Map endpoint 1.
! ------------------------------------------------------------

        BIN

        LDMD R14,=BINTAB

        LDMD R40,X14,LX1
        LDMD R50,X14,LY1

        JSB X14,MAPXY

        BIN

        LDMD R14,=BINTAB

        STMD R40,X14,MX1
        STMD R50,X14,MY1


! ------------------------------------------------------------
! Map endpoint 2.
! ------------------------------------------------------------

        LDMD R40,X14,LX2
        LDMD R50,X14,LY2

        JSB X14,MAPXY

        BIN

        LDMD R14,=BINTAB

        STMD R40,X14,MX2
        STMD R50,X14,MY2


! ------------------------------------------------------------
! Build REAL constants 0, 255, 191.
! ------------------------------------------------------------

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,CZERO

        LDM R36,=377,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,CXMAX

        LDM R36,=277,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB
        JSB X14,LCLIP

        BIN

        CMB R20,=0
        JZR LCVRT

        RTN


! ============================================================
! Convert mapped REAL endpoints to integer logical coordinates.
! ============================================================

LCVRT   BIN

        LDMD R14,=BINTAB

        LDMD R60,X14,MX1
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB
        STBD R76,X14,IX1

        LDMD R60,X14,MY1
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB
        STBD R76,X14,IY1

        LDMD R60,X14,MX2
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB
        STBD R76,X14,IX2

        LDMD R60,X14,MY2
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB
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

LCFSA   LDMD R14,=BINTAB
        STBD R21,X14,CRTFLG

        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT


! ------------------------------------------------------------
! Initialize current CRT byte address and bit mask from endpoint 1.
! ------------------------------------------------------------

        JSB X14,LINIT


! ------------------------------------------------------------
! Compute dx, dy and X/Y directions.
! ------------------------------------------------------------

        BIN

        LDMD R14,=BINTAB

        JSB X14,LDELT


! ============================================================
! Select major axis.  dx and dy are positive 16-bit values.
! ============================================================

        BIN

        LDMD R14,=BINTAB

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

        JSB X14,LBRESX

        JMP LRFIN


! ------------------------------------------------------------
! Y-major: REM=dy, ERR=dy/2.
! ------------------------------------------------------------

LYMJR   STMD R56,X14,LREM

        LDM R36,R56
        LRM R37
        STMD R36,X14,LERR

        JSB X14,LBRESY


! ============================================================
! Restore caller's CRT byte address.
! ============================================================

LRFIN   BIN

        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB


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

LISAVE  LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB


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

LBXDRV  LDMD R14,=BINTAB
        JSB X14,LBXIT

        BIN

        CMB R20,=0
        JZR LBXDRV

        RTN


! ============================================================
! LBXIT -- one X-major Bresenham iteration
! ============================================================

LBXIT   BIN

        LDMD R14,=BINTAB
        JSB X14,LPIX

        BIN

        LDMD R14,=BINTAB

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

        JSB X14,LSTPX

        BIN

        LDMD R14,=BINTAB


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

        JSB X14,LSTPY

        BIN

        LDMD R14,=BINTAB

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

LBYDRV  LDMD R14,=BINTAB
        JSB X14,LBYIT

        BIN

        CMB R20,=0
        JZR LBYDRV

        RTN


! ============================================================
! LBYIT -- one Y-major Bresenham iteration
! ============================================================

LBYIT   BIN

        LDMD R14,=BINTAB
        JSB X14,LPIX

        BIN

        LDMD R14,=BINTAB

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

        JSB X14,LSTPY

        BIN

        LDMD R14,=BINTAB


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

        JSB X14,LSTPX

        BIN

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

        LDMD R34,X14,LADR
        JSB =BYTCR!

        BIN

        LDMD R14,=BINTAB

        LDBD R40,X14,CRTFLG

        CMB R40,=0
        JZR LPNORM

        JSB =INCHR-
        JMP LPRDON

LPNORM  JSB =INCHR

LPRDON  BIN

        LDB R36,R32

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB

        LDB R20,=10D
        STBD R20,X14,LCCNT

LCLP0   LDMD R14,=BINTAB
        JSB X14,LCLCHK

        BIN

        CMB R20,=0
        JNZ LCLNAC

        RTN

LCLNAC  CMB R20,=1
        JNZ LCLSTP

        RTN

LCLSTP  LDMD R14,=BINTAB
        JSB X14,LCLONE

        BIN

        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB

        LDMD R40,X14,MX1
        LDMD R50,X14,MY1
        JSB X14,LCODE

        BIN
        LDMD R14,=BINTAB
        STBD R20,X14,LCOD1

        LDMD R40,X14,MX2
        LDMD R50,X14,MY2
        JSB X14,LCODE

        BIN
        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB

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
        LDMD R14,=BINTAB
        LDBD R20,X14,LCODV
        ADB R20,=1
        STBD R20,X14,LCODV


! ------------------------------------------------------------
! RIGHT: x > 255  <=> 255 < x
! ------------------------------------------------------------

LCDRCK  BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,CXMAX
        LDMD R50,X14,LCTX
        JSB =COMFLT
        JEN LCDRGT

        BIN
        JMP LCDBCK

LCDRGT  BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,LCODV
        ADB R20,=2
        STBD R20,X14,LCODV


! ------------------------------------------------------------
! BOTTOM: y < 0
! ------------------------------------------------------------

LCDBCK  BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,LCTY
        LDMD R50,X14,CZERO
        JSB =COMFLT
        JEN LCDBOT

        BIN
        JMP LCDTCK

LCDBOT  BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,LCODV
        ADB R20,=4
        STBD R20,X14,LCODV


! ------------------------------------------------------------
! TOP: y > 191  <=> 191 < y
! ------------------------------------------------------------

LCDTCK  BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,CYMAX
        LDMD R50,X14,LCTY
        JSB =COMFLT
        JEN LCDTOP

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,LCODV
        RTN

LCDTOP  BIN
        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB


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

        JSB X14,LINTY

        BIN
        LDMD R14,=BINTAB
        JSB X14,LCREPL
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

        JSB X14,LINTY

        BIN
        LDMD R14,=BINTAB
        JSB X14,LCREPL
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

        JSB X14,LINTX

        BIN
        LDMD R14,=BINTAB
        JSB X14,LCREPL
        RTN


! ------------------------------------------------------------
! LEFT is the only remaining possible bit.
! ------------------------------------------------------------

LCOLFT  LDMD R40,X14,CZERO
        STMD R40,X14,LBOUND

        JSB X14,LINTX

        BIN
        LDMD R14,=BINTAB
        JSB X14,LCREPL
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

        LDMD R14,=BINTAB


! numerator = boundary - y1

        LDMD R50,X14,LBOUND
        LDMD R40,X14,MY1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,LTMP1


! denominator = y2 - y1

        LDMD R50,X14,MY2
        LDMD R40,X14,MY1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,LTMP2


! t = numerator / denominator

        LDMD R50,X14,LTMP1
        LDMD R40,X14,LTMP2
        JSB =DIV10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,LTVAL


! dx = x2 - x1

        LDMD R50,X14,MX2
        LDMD R40,X14,MX1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB


! dx * t

        LDMD R50,X14,LTVAL
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB


! x = x1 + dx*t

        LDMD R50,X14,MX1
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB


! numerator = boundary - x1

        LDMD R50,X14,LBOUND
        LDMD R40,X14,MX1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,LTMP1


! denominator = x2 - x1

        LDMD R50,X14,MX2
        LDMD R40,X14,MX1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,LTMP2


! t = numerator / denominator

        LDMD R50,X14,LTMP1
        LDMD R40,X14,LTMP2
        JSB =DIV10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,LTVAL


! dy = y2 - y1

        LDMD R50,X14,MY2
        LDMD R40,X14,MY1
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB


! dy * t

        LDMD R50,X14,LTVAL
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB


! y = y1 + dy*t

        LDMD R50,X14,MY1
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB

        STMD R40,X14,LNY

        LDMD R40,X14,LBOUND
        STMD R40,X14,LNX

        RTN


! ============================================================
! LCREPL -- replace endpoint selected by LSEL with LNX/LNY
! ============================================================

LCREPL  BIN

        LDMD R14,=BINTAB

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
!       LX1,LY1,LX2,LY2,LF
!
! This deliberately duplicates LINE.'s mode dispatch rather than
! changing the physically-proven LINE runtime itself.
! ============================================================

SHLINE  BIN

        LDMD R14,=BINTAB
        LDMD R60,X14,LF

        JSB =CONINT

        BIN
        LDMD R14,=BINTAB

        STBD R76,X14,LMODE
        LDBD R20,X14,LMODE

        CMB R20,=1
        JZR SHSET

        CMB R20,=0
        JZR SHRAS

        CMB R20,=2
        JZR SHRAS

        RTN

SHSET   LDMD R14,=BINTAB
        JSB X14,LNDRAW
        BIN
        RTN

SHRAS   LDMD R14,=BINTAB
        JSB X14,LRAST
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

        LDMD R14,=BINTAB
        LDMD R60,X14,SF
        JSB =CONINT

        BIN
        LDMD R14,=BINTAB
        STBD R76,X14,LMODE
        RTN


! Initial polyline position: only vector SET mode has a ROM360 current point.

PLMOVE  BIN

        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB
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

PLDRAS  LDMD R14,=BINTAB

        LDMD R40,X14,SPX
        STMD R40,X14,LX1
        LDMD R40,X14,SPY
        STMD R40,X14,LY1
        LDMD R40,X14,PTX
        STMD R40,X14,LX2
        LDMD R40,X14,PTY
        STMD R40,X14,LY2

        JSB X14,LRAST
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
        LDMD R14,=BINTAB

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
        LDMD R14,=BINTAB
        STMD R40,X14,REX2


! y2 = y + h

        LDMD R40,X14,REY
        LDMD R50,X14,REH
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
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
        STMD R40,X14,LF
        JSB X14,SHLINE


! right: (x2,y) -> (x2,y2)

        BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,REX2
        STMD R40,X14,LX1
        LDMD R40,X14,REY
        STMD R40,X14,LY1
        LDMD R40,X14,REX2
        STMD R40,X14,LX2
        LDMD R40,X14,REY2
        STMD R40,X14,LY2
        LDMD R40,X14,REF
        STMD R40,X14,LF
        JSB X14,SHLINE


! bottom: (x2,y2) -> (x,y2)

        BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,REX2
        STMD R40,X14,LX1
        LDMD R40,X14,REY2
        STMD R40,X14,LY1
        LDMD R40,X14,REX
        STMD R40,X14,LX2
        LDMD R40,X14,REY2
        STMD R40,X14,LY2
        LDMD R40,X14,REF
        STMD R40,X14,LF
        JSB X14,SHLINE


! left: (x,y2) -> (x,y)

        BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,REX
        STMD R40,X14,LX1
        LDMD R40,X14,REY2
        STMD R40,X14,LY1
        LDMD R40,X14,REX
        STMD R40,X14,LX2
        LDMD R40,X14,REY
        STMD R40,X14,LY2
        LDMD R40,X14,REF
        STMD R40,X14,LF
        JSB X14,SHLINE

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
        LDMD R14,=BINTAB
        STBD R20,X14,SDRG

        JSB =DEG.
        BIN
        RTN

TRGOFF  BIN

        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB


! X = mx + rx*sin(angle)

        LDMD R40,X14,SANG
        PUMD R40,+R12
        BCD
        JSB =SIN10
        POMD R70,-R12
        BIN

        LDMD R14,=BINTAB
        LDMD R50,X14,SRX
        JSB =MPY10
        POMD R70,-R12
        BIN

        LDMD R14,=BINTAB
        LDMD R50,X14,SMX
        JSB =ADD10
        POMD R70,-R12
        BIN

        LDMD R14,=BINTAB
        STMD R40,X14,PTX


! Y = my - ry*cos(angle)

        LDMD R40,X14,SANG
        PUMD R40,+R12
        BCD
        JSB =COS10
        POMD R70,-R12
        BIN

        LDMD R14,=BINTAB
        LDMD R50,X14,SRY
        JSB =MPY10
        POMD R70,-R12
        BIN

        LDMD R14,=BINTAB
        LDMD R50,X14,SMY
        JSB =SUB10
        POMD R70,-R12
        BIN

        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB

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

        JSB X14,TRGON

        BIN
        LDMD R14,=BINTAB
        JSB X14,ANGPT

        BIN
        LDMD R14,=BINTAB
        JSB X14,TRGOFF


! centre -> calculated perimeter point

        BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,SMX
        STMD R40,X14,LX1
        LDMD R40,X14,SMY
        STMD R40,X14,LY1
        LDMD R40,X14,PTX
        STMD R40,X14,LX2
        LDMD R40,X14,PTY
        STMD R40,X14,LY2
        LDMD R40,X14,SF
        STMD R40,X14,LF

        JSB X14,SHLINE

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
        LDMD R14,=BINTAB

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

        JSB X14,TRGON

        BIN
        LDMD R14,=BINTAB
        JSB X14,ARCDRW

        BIN
        LDMD R14,=BINTAB
        JSB X14,TRGOFF

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
        LDMD R14,=BINTAB


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
        LDMD R14,=BINTAB
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

CARGF   LDMD R14,=BINTAB

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
        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB
        STMD R40,X14,SNSEG

        LDMD R50,X14,S360
        LDMD R40,X14,SNSEG
        JSB =DIV10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,SWW


! ------------------------------------------------------------
! Generate exactly CNSEG chords.
! ------------------------------------------------------------

        JSB X14,TRGON

        BIN
        LDMD R14,=BINTAB
        JSB X14,CIRDRW

        BIN
        LDMD R14,=BINTAB
        JSB X14,TRGOFF

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

        LDMD R14,=BINTAB


! sin(start)

        LDMD R40,X14,SANG
        PUMD R40,+R12
        BCD
        JSB =SIN10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,RSIN


! cos(start)

        LDMD R40,X14,SANG
        PUMD R40,+R12
        BCD
        JSB =COS10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,RCOS


! sin(step)

        LDMD R40,X14,SWW
        PUMD R40,+R12
        BCD
        JSB =SIN10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,RDSIN


! cos(step)

        LDMD R40,X14,SWW
        PUMD R40,+R12
        BCD
        JSB =COS10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,RDCOS

        JSB X14,RPOINT
        RTN


! ------------------------------------------------------------
! RSTEP -- advance current sin/cos by one complete SWW step.
!
! newSin = oldSin*stepCos + oldCos*stepSin
! newCos = oldCos*stepCos - oldSin*stepSin
! ------------------------------------------------------------

RSTEP   BIN

        LDMD R14,=BINTAB


! RTMP = oldSin * stepCos

        LDMD R40,X14,RSIN
        LDMD R50,X14,RDCOS
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,RTMP


! RNEW = RTMP + oldCos * stepSin

        LDMD R40,X14,RCOS
        LDMD R50,X14,RDSIN
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        LDMD R50,X14,RTMP
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,RNEW


! RTMP = oldCos * stepCos

        LDMD R40,X14,RCOS
        LDMD R50,X14,RDCOS
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,RTMP


! newCos = RTMP - oldSin * stepSin

        LDMD R40,X14,RSIN
        LDMD R50,X14,RDSIN
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        LDMD R50,X14,RTMP
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,RCOS


! Commit newSin only after newCos has consumed oldSin.

        LDMD R40,X14,RNEW
        STMD R40,X14,RSIN

        JSB X14,RPOINT
        RTN


! ------------------------------------------------------------
! RPOINT -- ellipse point from current recurrence sin/cos state.
!
!       PTX = mx + rx*RSIN
!       PTY = my - ry*RCOS
! ------------------------------------------------------------

RPOINT  BIN

        LDMD R14,=BINTAB


! X = mx + rx*sin

        LDMD R40,X14,RSIN
        LDMD R50,X14,SRX
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        LDMD R50,X14,SMX
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,PTX


! Y = my - ry*cos

        LDMD R40,X14,RCOS
        LDMD R50,X14,SRY
        JSB =MPY10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        LDMD R50,X14,SMY
        JSB =SUB10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB


! REAL 0 and initial angle.

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,SZERO
        STMD R40,X14,SANG


! First perimeter point at 0 degrees and recurrence setup.
! RINIT also evaluates SIN/COS of SWW once for all ordinary chords.

        JSB X14,RINIT

        BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,PTX
        STMD R40,X14,SPX
        LDMD R40,X14,PTY
        STMD R40,X14,SPY


! Cache f once.  For f=1 position ROM360 once at the initial point; all
! following ordinary/final endpoints are streamed with DRAW only.

        JSB X14,PLMODE

        BIN
        LDMD R14,=BINTAB
        JSB X14,PLMOVE

        BIN
        LDMD R14,=BINTAB


! Remaining segment counter = n.

        LDMD R30,X14,CNSEG
        STMD R30,X14,CREM


! Keep the outer loop deliberately short so every relative branch
! remains comfortably in range.  CIRSTP emits one chord.

CDLOOP  LDMD R14,=BINTAB
        JSB X14,CIRSTP

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

        LDMD R14,=BINTAB


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
        LDMD R14,=BINTAB
        STMD R40,X14,SNXT

        JMP CINEXT


! Final chord: preserve v0.11c exact-angle closure at 360 degrees.
! This exceptional endpoint still uses ANGPT; normal chords use RSTEP.

CILAST  BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,S360
        STMD R40,X14,SNXT
        STMD R40,X14,SANG

        JSB X14,ANGPT
        JMP CIDRAW


! Ordinary complete step: keep SANG for end/count semantics, but derive
! the coordinate from the incremental sin/cos recurrence.

CINEXT  LDMD R40,X14,SNXT
        STMD R40,X14,SANG

        JSB X14,RSTEP


! Draw previous point -> new point using cached composite mode.
! f=1 streams only the new endpoint; f=0/f=2 retain LRAST.

CIDRAW  BIN
        LDMD R14,=BINTAB
        JSB X14,PLDRAW


! New point becomes previous point.

        BIN
        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB


! REAL 0

        LDM R36,=0,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,SZERO


! REAL 360

        LDM R36,=150,1
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,S360


! Require ww > 0.  COMFLT sets E when R40 < R50.

        LDMD R40,X14,SZERO
        LDMD R50,X14,SWW
        JSB =COMFLT
        JEN ADRPOS

        BIN
        RTN

ADRPOS  BIN
        LDMD R14,=BINTAB


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
        LDMD R14,=BINTAB
        LDMD R40,X14,SEND
        LDMD R50,X14,S360
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,SEND

ADRINI  BIN
        LDMD R14,=BINTAB

        LDMD R40,X14,SWS
        STMD R40,X14,SANG

! Initialize sin/cos at the requested start angle and cache sin/cos(ww).

        JSB X14,RINIT

        BIN
        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB
        JSB X14,PLMODE

        BIN
        LDMD R14,=BINTAB
        JSB X14,PLMOVE

        BIN
        LDMD R14,=BINTAB


! Short outer loop.  ARCSTP performs one segment and returns
! R20=1 when there is no more work.

ADRLOP  LDMD R14,=BINTAB
        JSB X14,ARCSTP

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

        LDMD R14,=BINTAB


! If current angle is not less than end, we are done.

        LDMD R40,X14,SANG
        LDMD R50,X14,SEND
        JSB =COMFLT
        JEN ASGO

        BIN
        LDB R20,=1
        RTN

ASGO    BIN
        LDMD R14,=BINTAB


! next = current + step

        LDMD R40,X14,SANG
        LDMD R50,X14,SWW
        JSB =ADD10
        POMD R70,-R12
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,SNXT


! If end < next, clamp next to end.

        LDMD R40,X14,SEND
        LDMD R50,X14,SNXT
        JSB =COMFLT
        JEN ASCLMP

        BIN
        JMP ASKEEP

ASCLMP  BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,SEND
        STMD R40,X14,SNXT
        STMD R40,X14,SANG

! Residual step shorter than ww: preserve exact v0.11c endpoint semantics.

        JSB X14,ANGPT
        JMP ASDRAW

ASKEEP  BIN
        LDMD R14,=BINTAB

        LDMD R40,X14,SNXT
        STMD R40,X14,SANG

! Full ww step: use cached incremental rotation instead of SIN10/COS10.

        JSB X14,RSTEP


! Draw previous point -> new point using cached composite mode.
! f=1 streams only the new endpoint; f=0/f=2 retain LRAST.

ASDRAW  BIN
        LDMD R14,=BINTAB
        JSB X14,PLDRAW


! New point becomes previous point.

        BIN
        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB


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
        LDMD R14,=BINTAB
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

PMOK    JSB X14,READMAP

        BIN
        LDMD R14,=BINTAB
        LDMD R40,X14,PX
        LDMD R50,X14,PY
        JSB X14,MAPXY

        BIN
        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB
        STMD R40,X14,CZERO

        LDM R36,=377,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,CXMAX

        LDM R36,=277,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,CYMAX

        JSB X14,LCLIP
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

PCVRT   LDMD R14,=BINTAB

        LDMD R60,X14,MX1
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB

! HP-85 backend range is already clipped to 0..255.
! Preserve the 16-bit PAINT interface, but explicitly zero-extend
! the proven low result byte instead of assuming R77 is defined.

        CLM R46
        LDB R46,R76
        STMD R46,X14,PXC

        LDMD R60,X14,MY1
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB

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

PCFSA   LDMD R14,=BINTAB
        STBD R21,X14,CRTFLG
        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT


! ------------------------------------------------------------
! Read seed row and obtain seed bit.
! ------------------------------------------------------------

        JSB X14,PRDROW

        BIN
        LDMD R14,=BINTAB
        JSB X14,PGET
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

        JSB X14,PREST
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
!       address = BINTAB + PDSTK/PUSTK + (index * 4)
!
! Each entry is four bytes: Xlo,Xhi,Ylo,Yhi.  PFSEED remains the proven
! one-row dynamic-span primitive.  PFKACT ensures stale duplicate entries
! do not propagate using old span state.
! ------------------------------------------------------------

PINIT   LDMD R14,=BINTAB

! Empty both indexed directional lists.

        LDB R20,=0
        STBD R20,X14,PDCNT
        STBD R20,X14,PUCNT
        STBD R20,X14,PFKACT

! Fill the original mapped seed row using the proven PFSEED primitive.

        JSB X14,PFSEED

! The original seed is known to be a valid source pixel here because the
! SET/CLEAR no-op case was handled before PINIT.  Queue both neighbours.

        JSB X14,PFLINK


! ============================================================
! PFLLOP -- drain both indexed directional work lists.
!
! DOWN is tried first.  When it is empty, one UP entry is tried.  Any
! successfully filled row may create fresh work in either direction, so
! every completed item returns here rather than draining one list in a
! separate phase.
! ============================================================

PFLLOP  BIN
        LDMD R14,=BINTAB
        JSB X14,POPD

        BIN
        CMB R20,=0
        JNZ PFLTRY

! Process one DOWN seed.

        LDMD R14,=BINTAB
        LDB R20,=0
        STBD R20,X14,PFKACT
        JSB X14,PFSEED

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PFKACT
        CMB R20,=0
        JZR PFLLOP

        JSB X14,PFLINK
        JMP PFLLOP


! DOWN empty: try one UP seed.  If UP is also empty, fill is complete.

PFLTRY  BIN
        LDMD R14,=BINTAB
        JSB X14,POPU

        BIN
        CMB R20,=0
        JZR PFLUGO

! Both lists empty: restore caller CRT pointer and return.  Keep this epilogue
! local so CAPASM never needs a long relative branch to a distant exit label.

        LDMD R14,=BINTAB
        JSB X14,PREST
        BIN
        PAD
        RTN

PFLUGO  LDMD R14,=BINTAB
        LDB R20,=0
        STBD R20,X14,PFKACT
        JSB X14,PFSEED

        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,PFKACT
        CMB R20,=0
        JZR PFLLOP

        JSB X14,PFLINK
        JMP PFLLOP


! ============================================================
! PFLINK -- queue all adjacent source-colour runs for the scanline most
! recently filled by PFSEED.  PSEEDY and [PLFT,PRGT] describe that row.
! ============================================================

PFLINK  BIN
        LDMD R14,=BINTAB

! Logical row below: y-1, if present.

        LDMD R46,X14,PSEEDY
        TSM R46
        JZR PFLUP

        DCM R46
        STMD R46,X14,PYC
        JSB X14,PSCAND


! Logical row above: y+1, if present.

PFLUP   BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PSEEDY
        LDM R56,=277,0
        SBM R56,R46
        JZR PFLRST

        ICM R46
        STMD R46,X14,PYC
        JSB X14,PSCANU


! Restore PYC to the filled row before returning.

PFLRST  BIN
        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB

! Read the seed row and reject a stale/duplicate seed.

        JSB X14,PRDROW

        BIN
        LDMD R14,=BINTAB
        JSB X14,PMATCH

        BIN
        CMB R20,=0
        JNZ PFSGO
        RTN


! Preserve this seed and initialise its left boundary.

PFSGO   LDMD R14,=BINTAB

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

        JSB X14,PMATCH

        BIN
        CMB R20,=0
        JZR PFSRST

        LDMD R14,=BINTAB
        LDMD R46,X14,PXC
        STMD R46,X14,PLFT
        JMP PFSLEF


! ------------------------------------------------------------
! Expand right from the row seed to X=255 or first non-source pixel.
! ------------------------------------------------------------

PFSRST  LDMD R14,=BINTAB
        LDMD R46,X14,PSEEDX
        STMD R46,X14,PXC
        STMD R46,X14,PRGT

PFSRGT  LDMD R46,X14,PRGT
        LDM R56,=377,0
        SBM R56,R46
        JZR PFSFIL

        ICM R46
        STMD R46,X14,PXC

        JSB X14,PMATCH

        BIN
        CMB R20,=0
        JZR PFSFIL

        LDMD R14,=BINTAB
        LDMD R46,X14,PXC
        STMD R46,X14,PRGT
        JMP PFSRGT


! ------------------------------------------------------------
! Fill the inclusive span [PLFT,PRGT] in ROWBUF.
! ------------------------------------------------------------

PFSFIL  LDMD R14,=BINTAB
        LDMD R46,X14,PLFT
        STMD R46,X14,PXC

PFSFLP  JSB X14,PPUT

        BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PFSWRT

        ICM R46
        STMD R46,X14,PXC
        JMP PFSFLP


! Write this one row and restore PYC to its seed row.

PFSWRT  JSB X14,PWRROW

        BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PSEEDY
        STMD R46,X14,PYC
        RTN


! ============================================================
! PREST -- restore caller's CRT byte pointer after PAINT row reads.
! ============================================================

PREST   BIN
        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB
        JSB X14,PROWAD
        JSB X14,READROW
        RTN

PWRROW  BIN
        LDMD R14,=BINTAB
        JSB X14,PROWAD
        JSB X14,WRTROW
        RTN


! ============================================================
! PROWAD -- HP-85-specific row-address backend.
!
! logical Y 0..191 -> physical row 191-Y
! row base = 010000 + physicalRow * 0100 nibble addresses
! ============================================================

PROWAD  BIN
        LDMD R14,=BINTAB

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
        LDMD R14,=BINTAB
        JSB X14,PADDR

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
        LDMD R14,=BINTAB
        JSB X14,PGET

        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB
        JSB X14,PADDR

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
        LDMD R14,=BINTAB

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
        LDMD R14,=BINTAB
        JSB X14,PRDROW

        BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PLFT
        STMD R46,X14,PXC


! Scan the inclusive interval.  A matching pixel begins a run;
! only the first pixel of that run is queued.

PDQCHK  JSB X14,PMATCH

        BIN
        CMB R20,=0
        JNZ PDQRUN

        LDMD R14,=BINTAB
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PDQRET

        ICM R46
        STMD R46,X14,PXC
        JMP PDQCHK


! Found first pixel of a contiguous source run.

PDQRUN  BIN
        LDMD R14,=BINTAB
        JSB X14,PUSHD


! Advance through remainder of this run.

PDQRLP  BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PDQRET

        ICM R46
        STMD R46,X14,PXC

        JSB X14,PMATCH

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
        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB
        JSB X14,PRDROW

        BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PLFT
        STMD R46,X14,PXC


! Scan inclusive interval.  Queue only first pixel of each source run.

PUQCHK  JSB X14,PMATCH

        BIN
        CMB R20,=0
        JNZ PUQRUN

        LDMD R14,=BINTAB
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PUQRET

        ICM R46
        STMD R46,X14,PXC
        JMP PUQCHK


PUQRUN  BIN
        LDMD R14,=BINTAB
        JSB X14,PUSHU


! Advance through remainder of this run.

PUQRLP  BIN
        LDMD R14,=BINTAB
        LDMD R46,X14,PXC
        LDMD R56,X14,PRGT
        SBM R56,R46
        JZR PUQRET

        ICM R46
        STMD R46,X14,PXC

        JSB X14,PMATCH

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
        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB
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
! PLOT RUNTIME -- v0.10a
!
!       PLOT x,y,f
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
! PLOT deliberately reuses PAINT's PX/PY/PF, PMODE, PXC/PYC, PTARG and
! ROWBUF helpers.  Commands are not re-entrant, so no additional large
! working area is required.
! ============================================================

        BYT 241

PLOT.   SAD
        BIN
        LDMD R14,=BINTAB


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
        LDMD R14,=BINTAB

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

QSET    LDMD R14,=BINTAB
        JSB X14,QPDOT

        BIN
        LDMD R14,=BINTAB


! ------------------------------------------------------------
! Common CRT path for f=0,1,2.
! Map one point using the active ROM360 SCALE coefficients.
! ------------------------------------------------------------

QRAS    JSB X14,READMAP

        BIN
        LDMD R14,=BINTAB

        LDMD R40,X14,PX
        LDMD R50,X14,PY
        JSB X14,MAPXY

        BIN
        LDMD R14,=BINTAB

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
        LDMD R14,=BINTAB
        STMD R40,X14,CZERO

        LDM R36,=377,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,CXMAX

        LDM R36,=277,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,CYMAX

        JSB X14,LCLIP
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

QCVRT   LDMD R14,=BINTAB

        LDMD R60,X14,MX1
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB

        CLM R46
        LDB R46,R76
        STMD R46,X14,PXC

        LDMD R60,X14,MY1
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB

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

QCFSA   LDMD R14,=BINTAB
        STBD R21,X14,CRTFLG
        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT


! ------------------------------------------------------------
! Read the complete raster row.  PGET returns current pixel state.
! ------------------------------------------------------------

        JSB X14,PRDROW

        BIN
        LDMD R14,=BINTAB
        JSB X14,PGET

        BIN
        LDMD R14,=BINTAB


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

QWRITE  JSB X14,PPUT
        JSB X14,PWRROW

        BIN
        LDMD R14,=BINTAB
        JSB X14,PREST

        BIN
        PAD
        RTN


! ============================================================
! QPDOT -- ROM360 physical/device point for PLOT f=1.
!
! Sequence:
!       MOVE x,y     pen up / position
!       DRAW x,y     lower pen at the same coordinate
!       MOVE x,y     raise pen again without displacement
!
! The same raw evaluated REAL x/y values are pushed for every call.
! ============================================================

QPDOT   BIN
        LDMD R14,=BINTAB

        LDMD R40,X14,PX
        PUMD R40,+R12
        LDMD R40,X14,PY
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPMOVE
        BYT 360
        BIN

        LDMD R14,=BINTAB
        LDMD R40,X14,PX
        PUMD R40,+R12
        LDMD R40,X14,PY
        PUMD R40,+R12

        JSB =ROMJSB
        DEF PPDRAW
        BYT 360
        BIN

        LDMD R14,=BINTAB
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
        LDMD R14,=BINTAB


! ------------------------------------------------------------
! Function arguments arrive in reverse order on R12: y, x.
! Reuse PAINT/PLOT's REAL coordinate locals.
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

        JSB X14,READMAP

        BIN
        LDMD R14,=BINTAB

        LDMD R40,X14,PX
        LDMD R50,X14,PY
        JSB X14,MAPXY

        BIN
        LDMD R14,=BINTAB

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
        LDMD R14,=BINTAB
        STMD R40,X14,CZERO

        LDM R36,=377,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,CXMAX

        LDM R36,=277,0
        JSB =CONBIN
        BIN
        LDMD R14,=BINTAB
        STMD R40,X14,CYMAX

        JSB X14,LCLIP
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

TCVRT   LDMD R14,=BINTAB

        LDMD R60,X14,MX1
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB

        CLM R46
        LDB R46,R76
        STMD R46,X14,PXC

        LDMD R60,X14,MY1
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB

        CLM R46
        LDB R46,R76
        STMD R46,X14,PYC


! ------------------------------------------------------------
! Sample CRT read mode and preserve the caller's CRT byte pointer.
! Same physically-proven rule used by BLOCK, LINE, PLOT and PAINT:
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

TCFSA   LDMD R14,=BINTAB
        STBD R21,X14,CRTFLG

        LDMD R20,=CRTBYT
        STMD R20,X14,SAVCRT


! ------------------------------------------------------------
! Read exactly one 32-byte raster row and obtain the addressed bit.
! Save the 0/1 result before PREST, since system routines used by
! pointer restoration are free to clobber working registers.
! ------------------------------------------------------------

        JSB X14,PRDROW

        BIN
        LDMD R14,=BINTAB
        JSB X14,PGET

        BIN
        LDMD R14,=BINTAB
        STBD R20,X14,PFND

        JSB X14,PREST

        BIN
        LDMD R14,=BINTAB
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

        LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB

        JSB X14,READMAP


! ============================================================
! MAP CORNER 1
! ============================================================

        BIN

        LDMD R14,=BINTAB

        LDMD R40,X14,BX1
        LDMD R50,X14,BY1

        JSB X14,MAPXY

        BIN

        LDMD R14,=BINTAB

        STMD R40,X14,MX1
        STMD R50,X14,MY1


! ============================================================
! MAP CORNER 2
! ============================================================

        BIN

        LDMD R14,=BINTAB

        LDMD R40,X14,BX2
        LDMD R50,X14,BY2

        JSB X14,MAPXY

        BIN

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

        STMD R40,X14,CZERO


! ------------------------------------------------------------
! 255
! ------------------------------------------------------------

        LDM R36,=377,0

        JSB =CONBIN

        BIN

        LDMD R14,=BINTAB

        STMD R40,X14,CXMAX


! ------------------------------------------------------------
! 191
! ------------------------------------------------------------

        LDM R36,=277,0

        JSB =CONBIN

        BIN

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

        LDMD R40,X14,MX1
        LDMD R50,X14,MX2

        STMD R50,X14,MX1
        STMD R40,X14,MX2

        JMP XORDN


XORDR   BIN

XORDN   LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB

        LDMD R40,X14,MY1
        LDMD R50,X14,MY2

        STMD R50,X14,MY1
        STMD R40,X14,MY2

        JMP YORDN


YORDR   BIN

YORDN   LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB

        LDMD R40,X14,CZERO

        STMD R40,X14,MX1


! ============================================================
! CLIP X MAXIMUM
! ============================================================

XCLHI   LDMD R14,=BINTAB

        LDMD R40,X14,CXMAX
        LDMD R50,X14,MX2

        JSB =COMFLT

        JEN XCLMX

        BIN

        JMP YCLLO


XCLMX   BIN

        LDMD R14,=BINTAB

        LDMD R40,X14,CXMAX

        STMD R40,X14,MX2


! ============================================================
! CLIP Y MINIMUM
! ============================================================

YCLLO   LDMD R14,=BINTAB

        LDMD R40,X14,MY1
        LDMD R50,X14,CZERO

        JSB =COMFLT

        JEN YCL0

        BIN

        JMP YCLHI


YCL0    BIN

        LDMD R14,=BINTAB

        LDMD R40,X14,CZERO

        STMD R40,X14,MY1


! ============================================================
! CLIP Y MAXIMUM
! ============================================================

YCLHI   LDMD R14,=BINTAB

        LDMD R40,X14,CYMAX
        LDMD R50,X14,MY2

        JSB =COMFLT

        JEN YCLMX

        BIN

        JMP CVCOOR


YCLMX   BIN

        LDMD R14,=BINTAB

        LDMD R40,X14,CYMAX

        STMD R40,X14,MY2


! ============================================================
! CONVERT CLIPPED COORDINATES
! ============================================================

CVCOOR  BIN

        LDMD R14,=BINTAB


! ------------------------------------------------------------
! X1
! ------------------------------------------------------------

        LDMD R60,X14,MX1

        JSB =CONINT

        BIN

        LDMD R14,=BINTAB

        STBD R76,X14,IX1


! ------------------------------------------------------------
! Y1
! ------------------------------------------------------------

        LDMD R60,X14,MY1

        JSB =CONINT

        BIN

        LDMD R14,=BINTAB

        STBD R76,X14,IY1


! ------------------------------------------------------------
! X2
! ------------------------------------------------------------

        LDMD R60,X14,MX2

        JSB =CONINT

        BIN

        LDMD R14,=BINTAB

        STBD R76,X14,IX2


! ------------------------------------------------------------
! Y2
! ------------------------------------------------------------

        LDMD R60,X14,MY2

        JSB =CONINT

        BIN

        LDMD R14,=BINTAB

        STBD R76,X14,IY2


! ------------------------------------------------------------
! Mode
! ------------------------------------------------------------

        LDMD R60,X14,BF

        JSB =CONINT

        BIN

        LDMD R14,=BINTAB

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

CFSAVE  LDMD R14,=BINTAB

        STBD R21,X14,CRTFLG


! ============================================================
! SAVE CURRENT CRT ADDRESS
! ============================================================

        LDMD R20,=CRTBYT

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

        LDBD R40,X14,MODE

        CMB R40,=2

        JZR DOXOR


! ------------------------------------------------------------
! SET / CLEAR
! ------------------------------------------------------------

        JSB X14,FASTROW

        JMP ROWNEXT


! ------------------------------------------------------------
! XOR
! ------------------------------------------------------------

DOXOR   LDMD R14,=BINTAB

        JSB X14,XORROW


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

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB


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

FXPOS   LDMD R14,=BINTAB

        STMD R30,X14,CURADR

        LDMD R34,X14,CURADR

        JSB =BYTCR!

        BIN

        LDMD R14,=BINTAB


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

        LDMD R14,=BINTAB

        JSB X14,STRBYT


! ------------------------------------------------------------
! Keep software current-address copy synchronized with the
! CRT controller's automatic +2 increment.
! ------------------------------------------------------------

        BIN

        LDMD R14,=BINTAB

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

FLAST   LDMD R14,=BINTAB

        JSB X14,STRBYT

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

        LDMD R14,=BINTAB

        JSB X14,READROW


! ============================================================
! PREPARE RAM PIXEL POINTER
! ============================================================

        BIN

        LDMD R14,=BINTAB

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

        ADMD R34,=BINTAB

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

XRWRITE LDMD R14,=BINTAB

        JSB X14,WRTROW

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

        ADMD R34,=BINTAB

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

        LDMD R14,=BINTAB

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

SBREAD  LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

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

SBMOD   LDMD R14,=BINTAB

        STBD R36,X14,NEWBYTE


! ------------------------------------------------------------
! INCHR advanced CRTBAD, so reposition to the byte just read.
! ------------------------------------------------------------

        LDMD R34,X14,CURADR

        JSB =BYTCR!

        BIN

        LDMD R14,=BINTAB

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

        LDMD R14,=AGLBAS

        LDMD R50,X14,XOFF

        LDMD R14,=BINTAB

        STMD R50,X14,CXOFF


! ------------------------------------------------------------
! Y offset
! ------------------------------------------------------------

        LDMD R14,=AGLBAS

        LDMD R50,X14,YOFF

        LDMD R14,=BINTAB

        STMD R50,X14,CYOFF


! ------------------------------------------------------------
! X factor
! ------------------------------------------------------------

        LDMD R14,=AGLBAS

        LDMD R50,X14,XFAC

        LDMD R14,=BINTAB

        STMD R50,X14,CXFAC


! ------------------------------------------------------------
! Y factor
! ------------------------------------------------------------

        LDMD R14,=AGLBAS

        LDMD R50,X14,YFAC

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

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

        LDMD R14,=BINTAB

        LDMD R50,X14,CXOFF

        JSB =ADD10

        POMD R70,-R12

        BIN

        LDMD R14,=BINTAB

        STMD R40,X14,MXOUT


! ============================================================
! Y
! ============================================================

        LDMD R40,X14,MYIN
        LDMD R50,X14,CYFAC

        JSB =MPY10

        POMD R70,-R12

        BIN

        LDMD R14,=BINTAB

        LDMD R50,X14,CYOFF

        JSB =ADD10

        POMD R70,-R12

        BIN

        LDMD R14,=BINTAB

        STMD R40,X14,MYOUT


! ------------------------------------------------------------
! Return mapped coordinates.
! ------------------------------------------------------------

        LDMD R40,X14,MXOUT
        LDMD R50,X14,MYOUT

        RTN


! ============================================================
! LOCAL DATA
! ============================================================

HMSG    ASC "SIMON85 V0.11E"

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
! BASIC arguments
! ------------------------------------------------------------

BX1     BSZ 10
BY1     BSZ 10

BX2     BSZ 10
BY2     BSZ 10

BF      BSZ 10


! ------------------------------------------------------------
! LINE arguments
!
! HP REAL = 8 bytes; BSZ 10 octal = 8 decimal bytes.
! ------------------------------------------------------------

LX1     BSZ 10
LY1     BSZ 10

LX2     BSZ 10
LY2     BSZ 10

LF      BSZ 10
LMODE   BSZ 1


! ------------------------------------------------------------
! LINE rasterizer state
!
! LRY1/LRY2 = physical raster rows (191-logicalY)
! LDX/LDY   = positive 16-bit Bresenham deltas
! LERR/LREM = signed error / remaining major-axis steps
! LXDIR/LYDIR: 1=increase, 0=decrease
! LADR/LMASK = current CRT byte address / pixel bit
! ------------------------------------------------------------

LRY1    BSZ 1
LRY2    BSZ 1

LDX     BSZ 2
LDY     BSZ 2
LERR    BSZ 2
LREM    BSZ 2

LXDIR   BSZ 1
LYDIR   BSZ 1

LADR    BSZ 2
LMASK   BSZ 1
LNEW    BSZ 1


! ------------------------------------------------------------
! LINE clipping state -- v0.07c
! ------------------------------------------------------------

LCOD1   BSZ 1
LCOD2   BSZ 1
LCOUT   BSZ 1
LCODV   BSZ 1
LSEL    BSZ 1
LCCNT   BSZ 1

LCTX    BSZ 10
LCTY    BSZ 10
LBOUND  BSZ 10
LNX     BSZ 10
LNY     BSZ 10
LTMP1   BSZ 10
LTMP2   BSZ 10
LTVAL   BSZ 10


! ------------------------------------------------------------
! REC arguments / derived opposite corner
! ------------------------------------------------------------

REX     BSZ 10
REY     BSZ 10
REB     BSZ 10
REH     BSZ 10
REF     BSZ 10
REX2    BSZ 10
REY2    BSZ 10


! ------------------------------------------------------------
! Shared ARC / CIRCLE / ANGL state
! ------------------------------------------------------------

SMX     BSZ 10
SMY     BSZ 10
SRX     BSZ 10
SRY     BSZ 10
SF      BSZ 10

SWS     BSZ 10
SWE     BSZ 10
SWW     BSZ 10
SANG    BSZ 10
SEND    BSZ 10
SNXT    BSZ 10

SPX     BSZ 10
SPY     BSZ 10
PTX     BSZ 10
PTY     BSZ 10

SZERO   BSZ 10
S360    BSZ 10
SDRG    BSZ 1

! v0.11d ARC/CIRCLE incremental trigonometry state.
RSIN    BSZ 10          ! sin(current angle)
RCOS    BSZ 10          ! cos(current angle)
RDSIN   BSZ 10          ! sin(full angular step)
RDCOS   BSZ 10          ! cos(full angular step)
RTMP    BSZ 10          ! recurrence arithmetic scratch
RNEW    BSZ 10          ! pending new sine while old sine remains live

! CIRCLE v0.08b optional segment-count state.
SNSEG   BSZ 10          ! optional n, then REAL copy of binary n
CNSEG   BSZ 2           ! validated binary segment count
CREM    BSZ 2           ! remaining counted CIRCLE segments


! ------------------------------------------------------------
! PAINT v0.09l arguments and indexed work-list state
! ------------------------------------------------------------

PX      BSZ 10          ! BASIC x REAL
PY      BSZ 10          ! BASIC y REAL
PF      BSZ 10          ! BASIC mode REAL
PMODE   BSZ 1

! 16-bit logical physical-pixel coordinates.
PXC     BSZ 2
PYC     BSZ 2
PSEEDX  BSZ 2
PSEEDY  BSZ 2
PLFT    BSZ 2
PRGT    BSZ 2
PORGL   BSZ 2           ! retained compatibility/debug state
PORGR   BSZ 2           ! retained compatibility/debug state

PSRC    BSZ 1           ! original connected-region bit
PTARG   BSZ 1           ! requested resulting bit
PFND    BSZ 1           ! reserved PAINT diagnostic state
PDIR    BSZ 1           ! retained scratch / future directional dispatcher

PDCNT   BSZ 1           ! indexed DOWN-list entry count
PUCNT   BSZ 1           ! indexed UP-list entry count
PFKACT  BSZ 1           ! 1 iff most recent PFSEED actually filled a row
PFRES   BSZ 2           ! reserved; preserves established local-data layout

! Two active 256-slot directional list reservations.  Each uses 2000 octal
! bytes (1024 decimal); combined work-list storage remains 2048 decimal bytes.
PDSTK   BSZ 2000
PDEND   BSZ 0
PUSTK   BSZ 2000
PUEND   BSZ 0


! ------------------------------------------------------------
! v0.11d inherited keyboard hardcopy / CHIDLE state
! ------------------------------------------------------------

PKMODE  BSZ 10          ! PRTKEYS BASIC mode parameter as HP REAL
KHACT   BSZ 1           ! 1 iff SIMON85 installed the current CHIDLE stub
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
! PRINTSCREEN / HP-IB transport state
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
PSAUTO  BSZ 1           ! 1 iff SII PRINTSCREEN itself called CRTPOF
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


! ------------------------------------------------------------
! HIRES foreground / pen parameter
! ------------------------------------------------------------

HPEN    BSZ 10


! ------------------------------------------------------------
! SCALE coefficients
! ------------------------------------------------------------

CXOFF   BSZ 10
CYOFF   BSZ 10

CXFAC   BSZ 10
CYFAC   BSZ 10


! ------------------------------------------------------------
! Mapped coordinates
! ------------------------------------------------------------

MX1     BSZ 10
MY1     BSZ 10

MX2     BSZ 10
MY2     BSZ 10


! ------------------------------------------------------------
! MAPXY scratch
! ------------------------------------------------------------

MXIN    BSZ 10
MYIN    BSZ 10

MXOUT   BSZ 10
MYOUT   BSZ 10


! ------------------------------------------------------------
! REAL clipping constants
! ------------------------------------------------------------

CZERO   BSZ 10
CXMAX   BSZ 10
CYMAX   BSZ 10


! ------------------------------------------------------------
! Clipped integer coordinates
! ------------------------------------------------------------

IX1     BSZ 1
IY1     BSZ 1

IX2     BSZ 1
IY2     BSZ 1


! ------------------------------------------------------------
! Raster rows
! ------------------------------------------------------------

RTOP    BSZ 1
RBOT    BSZ 1


! ------------------------------------------------------------
! Drawing mode
! ------------------------------------------------------------

MODE    BSZ 1


! ------------------------------------------------------------
! CRT read mode
!
! 0 = normal INCHR
! 1 = CRT wiped out; INCHR- is safe
! ------------------------------------------------------------

CRTFLG  BSZ 1


! ------------------------------------------------------------
! Original CRT address
! ------------------------------------------------------------

SAVCRT  BSZ 2


! ------------------------------------------------------------
! SET/CLEAR streaming scratch
! ------------------------------------------------------------

CURADR  BSZ 2
CURMSK  BSZ 1
NEWBYTE BSZ 1


! ------------------------------------------------------------
! SCANLINE BUFFER
!
! 40 octal = 32 decimal bytes.
!
! This represents exactly one complete HP-85 graphics row:
!
!       32 bytes x 8 pixels = 256 pixels
! ------------------------------------------------------------

ROWBUF  BSZ 40


! ============================================================
! HP-85 SYSTEM SYMBOLS
!
! All addresses OCTAL.
! ============================================================

BINTAB  DAD 101233
ROMFL   DAD 101231
CHIDLE  DAD 102416
KEYHIT  DAD 100671
KEYSTS  DAD 177402
EOJ2    DAD 34772

AGLBAS  DAD 102542

CRTBYT  DAD 100176
CRTRAM  DAD 100200
CRTWRS  DAD 101016
TOS     DAD 101132
DRG     DAD 100125


! ------------------------------------------------------------
! Parser
! ------------------------------------------------------------

SCAN    DAD 11262

NUMVP   DAD 12407
NUMVAL  DAD 12412
GETCM   DAD 13414

ERRORP  DAD 6611


! ------------------------------------------------------------
! Runtime numeric
! ------------------------------------------------------------

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


! ------------------------------------------------------------
! Graphics statement runtimes / ROM switching
! ------------------------------------------------------------

GCLR.   DAD 36013
SCALE.  DAD 66247
PEN.    DAD 66416

ROMJSB  DAD 4776

! Printer/Plotter ROM 360 runtime entries identified from the
! actual ROM image supplied from EBTKS.
PPGCLR  DAD 64557
PPSCAL  DAD 64041
PPPEN   DAD 64241
PPMOVE  DAD 64400
PPDRAW  DAD 64435


! ------------------------------------------------------------
! CRT
! ------------------------------------------------------------

BYTCR!  DAD 35422
CHKSTS  DAD 36335
INCHR   DAD 35244
INCHR-  DAD 35220
CRTPOF  DAD 35703
CRTPUP  DAD 35716

CRTDAT  DAD 177407


! ------------------------------------------------------------
! Output
! ------------------------------------------------------------

OUTSTR  DAD 35052


        FIN
