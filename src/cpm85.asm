! ======================================================================
! CPM85 v0.06a -- C2a RMIDLE console test, C2 unsafe poll remains disabled
!
! v0.01b HP-85 capture/release + CPCOUNT/CPLAST proven on hardware.
! v0.02a adds only two EBTKS write-only I/O ports:
!   0177741 (0341 EBTKS offset): key data (raw KEYHIT byte)
!   0177742 (0342 EBTKS offset): attach=1, detach=0
! Keycode translation and forwarding to CP/M are on the ESP32.
! K8 stays local; it must NEVER be forwarded to CP/M.
! For use ONLY with matching Teensy/ESP32 DEVELOPMENT firmware.
! User-facing:
!       LOADBIN "CPM85"
!       CPM            ! capture HP keyboard; K8 (SHIFT+K4) detaches
!       CPOFF         ! manual detach, if an alternative input is available
!       CPVER         ! display this test module's version
!       CPCOUNT       ! number of captured keystrokes, modulo 256
!       CPLAST        ! last captured RAW HP keycode, including K8
!       CPSTATUS      ! active / pending drive assignments
!       CPDMNT "B:","WORK.DSK"  ! pending mount, relative to /cpm/disks
!       CPDUMNT "B:" ! pending unmount
!       CPRESET       ! activate desired mounts by Z80-only reset
!       CPDIMGS      ! list .DSK images in /cpm/disks
!       CPDMK "WORK.DSK" ! create fresh 8 MiB disk on Teensy SD
!       CPDCAT "A:"     ! read-only native BDOS directory catalog
!       CPUI 0          ! native C1 console state + CRT, BASIC key pump
!       CPUI K          ! deliver raw keyboard code from KBDKEY (C1 probe)
!       C85MENU         ! C2a source-free RMIDLE status console + K1-K4 / K8
!       CPKTEST         ! DISABLED safe return after C2 hardware crash
!       CPKCOUNT        ! compatibility diagnostic (0 in quarantined C2)
!       CPKLAST         ! compatibility diagnostic (0 in quarantined C2)
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
! v0.01b VERIFIED on HP-85: CPCOUNT=9, CPLAST=135 (K8).
! v0.02a I/O keyboard forwarding is NOT YET tested on hardware.
! The prior CHIDLE control flow, K8 decode and functions are unchanged.
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
        DEF NOPARS    ! CPSTATUS
        DEF TWOSTR    ! CPDMNT
        DEF ONESTR    ! CPDUMNT
        DEF NOPARS    ! CPRESET
        DEF NOPARS    ! CPDIMGS
        DEF ONESTR    ! CPDMK
        DEF ONESTR    ! CPDCAT
        DEF UIKPAR    ! CPUI - numeric raw keyboard code
        DEF NOPARS    ! CPKTEST bounded native input probe
        DEF NOPARS    ! CPKCOUNT numeric diagnostic
        DEF NOPARS    ! CPKLAST numeric diagnostic
        DEF NOPARS    ! C85MENU source-free console experiment

RUNTIM  BYT 0,0
        DEF CPMRUN
        DEF OFFRUN
        DEF VERRUN
        DEF CNTFUN
        DEF LSTFUN
        DEF CPSTAT
        DEF CPDMNT
        DEF CPUMNT
        DEF CPRESE
        DEF CPIMGS
        DEF CPMAKE
        DEF CPCAT
        DEF UIRUN
        DEF K2RUN
        DEF K2CNT
        DEF K2LST
        DEF MNRUN
        BYT 377,377

ASCIIS  ASP "CPM"
        ASP "CPOFF"
        ASP "CPVER"
        ASP "CPCOUNT"
        ASP "CPLAST"
        ASP "CPSTATUS"
        ASP "CPDMNT"
        ASP "CPDUMNT"
        ASP "CPRESET"
        ASP "CPDIMGS"
        ASP "CPDMK"
        ASP "CPDCAT"
        ASP "CPUI"
        ASP "CPKTEST"
        ASP "CPKCOUNT"
        ASP "CPKLAST"
        ASP "C85MENU"

ERMSG   BYT 377

! No-argument statement parser: identical to proven PVERP in PRINTER85.
NOPARS  LDB R47,R43
        LDB R45,=371
        PUMD R45,+R12
        JSB =SCAN
        RTN

! Parse HP BASIC string expressions; HP assembler manual 7-20 and 8-2:
! STREX+ scans then STREXP, GETCMA demands a comma and scans.
! At runtime each string occupies [length (2 bytes), address (2 bytes)]
! on R12, last expression first. No arbitrary token/string peeking.
ONESTR  PUBD R43,+R6
        JSB =STREX+
        JEZ CSERR
        JMP CSOK

TWOSTR  PUBD R43,+R6
        JSB =STREX+
        JEZ CSERR
        JSB =GETCMA
        JSB =STREXP
        JEZ CSERR
CSOK    POBD R47,-R6
        LDB R45,=371
        PUMD R45,+R12
        RTN
CSERR   POBD R47,-R6
        JSB =ERRORP
        BYT 81D

! CPUI: C1 experimental numeric raw-keycode receiver.
! Parser and ONER/CONINT runtime follow the proven PRINTER85 PRTKEYS
! LOADBIN path. No undocumented native key polling is attempted yet.
UIKPAR  PUBD R43,+R6
        JSB =NUMVP
        JEN UIKOK
        JMP UIKERR
UIKOK   POBD R47,-R6
        LDB R45,=371
        PUMD R45,+R12
        RTN
UIKERR  POBD R47,-R6
        JSB =ERRORP
        BYT 81D

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
        STBD R20,X14,UIACT
        STBD R20,X14,UIMODE
        STBD R20,X14,UIPAGE
        STBD R20,X14,K2COUNT
        STBD R20,X14,K2LAST
        RTN

INRESET LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,KHACT
        STBD R20,X14,UIACT
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
        JNZ CPALRD

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
! Tell Teensy the HP keyboard has been attached. This port is private
! to the matching EBTKS development firmware; a missing Teensy
! handler must never prevent local K8 release.
        STBD R20,=CPCTL
        JMP CPMRET

! Even if CPM is invoked while already attached, terminate the BASIC
! statement on a clean line. No keyboard hook or transport state changes.
CPALRD  LDM R26,=ALRMSG
        ADMD R26,=BINTAB
        LDM R36,=24D,0
        JSB =OUTSTR
        JMP CPMRET

CPBUSY  LDM R26,=BSYMSG
        ADMD R26,=BINTAB
        LDM R36,=38D,0
        JSB =OUTSTR

CPMRET  BIN
        PAD
        RTN

! ---------------------------------------------------------------
! C85MENU: C2a opt-in, source-free resident native console probe.
! Uses the same physically proven CHIDLE trampoline / EOJ2 and
! K8 detach as CPM. DOES NOT run any CPU-spinning HP loop.
!
! Control value 2 tells development Teensy to count REAL RMIDLE
! callbacks and draw a throttled CRT counter from its main loop.
! The standard CP/M key forwarder remains detached (value!=1).
! Any K1-K4 key is sent through CPKEY but the Teensy probe only
! updates local page/mode flags; it forwards nothing to the ESP32.
! An old Teensy ignores value 2; K8 exit still works locally.
! ---------------------------------------------------------------
        BYT 241
MNRUN   SAD
        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,KHACT
        CMB R20,=0
        JZR MNFREE
        JSB =ERRORP
        BYT 89D
MNFREE  LDBD R20,=CHIDLE
        CMB R20,=236
        JZR MNOK
        JSB =ERRORP
        BYT 89D
MNOK    LDM R26,=MNMSG
        ADMD R26,=BINTAB
        LDM R36,=30D,0
        JSB =OUTSTR
        BIN
        LDMD R14,=BINTAB
        LDM R34,=CHIDLE
        LDM R36,=KHSAVE
        ADM R36,R14
        LDB R20,=7
MNSAVE  POBD R22,+R34
        PUBD R22,+R36
        DCB R20
        JNZ MNSAVE

! Same validated 4-byte CHIDLE stub as CPMRUN: JSB <KHOOK>, RTN.
        LDMD R14,=BINTAB
        LDM R46,=KHOOK
        ADM R46,R14
        STM R46,R45
        LDB R47,=236
        LDB R44,=316
        STMD R44,=CHIDLE
        LDB R20,=2
        STBD R20,X14,KHACT
        STBD R20,=CPCTL
        BIN
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
        LDM R36,=24D,0
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

! ----------------------------------------------------------------------
! HP BASIC disk control. No keyboard hook, SD, UART, JSON, or HP bus ISR
! callbacks are added here. Each command writes bounded short ASCII to
! four EBTKS I/O ports and waits for a reply. K8 keyboard hook unchanged.
! The matching Teensy and ESP32 firmware are both REQUIRED.
!
! CPSTATUS: no arguments
! CPRESET: explicitly resets ONLY Z80 (operator must be at CP/M prompt).
! CPDMNT / CPDUMNT / CPDMK: BASIC string expressions, not numeric parameters.
! ----------------------------------------------------------------------

        BYT 241
CPSTAT  BIN
        LDMD R14,=BINTAB
        JSB X14,CPCLR
        LDB R22,=1
        JSB X14,CPGO
        RTN

        BYT 241
CPRESE  BIN
        LDMD R14,=BINTAB
        JSB X14,CPCLR
        LDB R22,=4
        JSB X14,CPGO
        RTN

        BYT 241
CPUMNT  BIN
        LDMD R14,=BINTAB
        JSB X14,CPCLR
        ! Each string contributes a 2-byte ADDRESS then 2-byte LENGTH
        ! when popped from BASIC R12. R30/R32 end on 2-byte boundaries.
        ! R40 and R42 do NOT: POMD R40 pops 8 bytes, corrupting R12.
        POMD R30,-R12     ! drive string address (2 bytes)
        POMD R32,-R12     ! drive string length  (2 bytes)
        JSB X14,CPWRDR
        LDB R22,=3
        JSB X14,CPGO
        RTN

        BYT 241
CPDMNT  BIN
        LDMD R14,=BINTAB
        JSB X14,CPCLR
        ! Runtime strings are stacked in argument order, so last first.
        ! Keep filename in R26 (address) / R24 (length) while emitting
        ! the first argument from R30 (address) / R32 (length).
        POMD R26,-R12     ! image filename address (2 bytes)
        POMD R24,-R12     ! image filename length  (2 bytes)
        POMD R30,-R12     ! drive string address   (2 bytes)
        POMD R32,-R12     ! drive string length    (2 bytes)
        JSB X14,CPWRDR
        LDB R20,=174      ! ASCII pipe separator, octal 0174
        STBD R20,=CPARG
        LDM R30,R26       ! exactly 2 bytes; no overlapping R40..R47
        LDM R32,R24       ! exactly 2 bytes
        JSB X14,CPWRIM
        LDB R22,=2
        JSB X14,CPGO
        RTN

! CPDIMGS and CPDMK reuse the proven command mailbox with opcodes 5/6.
! CPDMK waits longer for the Teensy to finish writing its SD image.
        BYT 241
CPIMGS  BIN
        LDMD R14,=BINTAB
        JSB X14,CPCLR
        LDB R22,=5
        JSB X14,CPGO
        RTN

        BYT 241
CPMAKE  BIN
        LDMD R14,=BINTAB
        JSB X14,CPCLR
        POMD R30,-R12     ! file-name string address, exactly 2 bytes
        POMD R32,-R12     ! file-name length, exactly 2 bytes
        ! Preserve the user's string before CPWRIM consumes its pointer/len.
        STMD R30,X14,CPNMADR
        STMD R32,X14,CPNMLEN
        JSB X14,CPWRIM
        ! Only normal BASIC runtime displays progress, never CHIDLE/ISR.
        JSB X14,CPBANN
        LDB R22,=6
        JSB X14,CPGO
        RTN

! CPDCAT "A:" uses the established HP->Teensy->ESP mailbox.
! The ESP32 safely finishes BDOS 10 with a synthetic blank Return
! only while the native CCP command line is verified empty; HP never
! injects a keyboard key. This command requires Teensy/ESP opcode 7.
        BYT 241
CPCAT   BIN
        LDMD R14,=BINTAB
        JSB X14,CPCLR
        POMD R30,-R12     ! drive expression character address
        POMD R32,-R12     ! drive expression character length
        JSB X14,CPWRDR
        LDB R22,=7
        JSB X14,CPGO
        RTN

! CPDMK start banner: compose CREATING <name>... in a bounded HP
! LOADBIN buffer and print once through native OUTSTR. OUTSTR finishes
! the CRT line, so the name is visible before the long CPDMK wait.
! CPWRIM has already limited this name to 79 bytes; 9+79+3 < 96.
CPBANN  BIN
        LDMD R14,=BINTAB
        LDM R30,=CPMKPFX
        ADM R30,R14
        LDM R26,=CPMKBUF
        ADM R26,R14
        LDB R20,=9D        ! length of "CREATING "
CPBPF   POBD R22,+R30
        PUBD R22,+R26
        DCB R20
        JNZ CPBPF
        LDMD R30,X14,CPNMADR
        LDMD R32,X14,CPNMLEN
        LDM R36,=12D,0   ! 9 prefix + 3 dots
        ADM R36,R32       ! plus validated filename length
CPBNAM  POBD R22,+R30
        PUBD R22,+R26
        DCM R32
        JNZ CPBNAM
        LDB R22,=56      ! octal ASCII period '.'
        PUBD R22,+R26
        PUBD R22,+R26
        PUBD R22,+R26
        LDM R26,=CPMKBUF
        ADM R26,R14
        JSB =OUTSTR       ! native CRT output, including newline
        RTN

! A fresh BASIC statement always starts with an empty command mailbox.
! 0 resets a previous timed-out or rejected partial command.
CPCLR   CLB R20
        STBD R20,=CPOPC
        RTN

! Check and stream a drive operand (one character or letter + colon).
! Input: R30-R31 = character address, R32-R33 = 16-bit length.
CPWRDR  BIN
        CMM R32,=1,0
        JNC CPBAD
        CMM R32,=3,0
        JCY CPBAD
CPDRLP  POBD R20,+R30
        STBD R20,=CPARG
        DCM R32
        JNZ CPDRLP
        RTN

! Check image length. Teensy request buffer is bounded to 92 chars.
! Input: R30-R31 = character address, R32-R33 = 16-bit length.
CPWRIM  BIN
        CMM R32,=1,0
        JNC CPBAD
        CMM R32,=80D,0
        JCY CPBAD
CPIMLP  POBD R20,+R30
        STBD R20,=CPARG
        DCM R32
        JNZ CPIMLP
        RTN

! This is an invalid argument in the HP BASIC statement. ERROR+ never
! returns to our routine, matching the original numeric parsers.
CPBAD   JSB =ERRORP
        BYT 89D

! Submit one request, poll the I/O status, and display its reply.
! Bounded nested software timeout prevents a hung HP BASIC if the ESP32
! or Teensy has old firmware. No delays or waits run inside Teensy ISR.
! Reply input has a separate hard byte limit, including if an unhandled
! HP bus read keeps supplying the same non-NUL character forever.
CPGO    BIN
        STBD R22,=CPOPC
        LDM R36,=8D,0
        CMB R22,=6
        JZR CPLONG
        CMB R22,=7
        JNZ CPWTOP
CPLONG  LDM R36,=250D,0  ! CPDMK and CPDCAT are bounded async services
CPWTOP  LDM R56,=177,377  ! 16-bit polling counter, not 64-bit R50
CPWAIT  LDBD R20,=CPSTATE
        CMB R20,=2
        JZR CPREAD
        CMB R20,=3
        JZR CPREAD
        DCM R56
        JNZ CPWAIT
        DCM R36
        JNZ CPWTOP
        CLB R20
        STBD R20,=CPOPC     ! Abort stale mailbox after timeout
        LDM R26,=CPTOUT
        ADMD R26,=BINTAB
        LDM R36,=19D,0
        JSB =OUTSTR
        RTN

! CPM85 v0.03d status output: use the previously hardware-tested
! byte-by-byte OUTCHR path for printable ASCII. The HP firmware OUTCHR
! renders ASCII control codes as glyphs, so neither LF nor CR should be
! passed through it. Instead, use OUTSTR with one blank character: that
! native CRT routine performs a real carriage return and fills the line.
! Incoming LF is ASCII 10D (octal 12), CR is 13D (octal 15).
! Never use 12D/15D here: the D suffix explicitly denotes decimal.
!
! HP-85 multi-byte instructions extend to the next 2/8-byte register
! boundary. R56-R57 is EXACTLY two bytes; R50-R57 is EIGHT bytes.
! =0,3 loads 0x0300 = 768, not =3,0 which loads 3.
! Save only this 2-byte register pair across OUTSTR.
CPREAD  LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,CPENDNL
        LDM R56,=0,3       ! exactly 768 reply bytes maximum
CPRLOOP LDBD R32,=CPRPLY
        CMB R32,=0
        JZR CPDONE
        CMB R32,=10D      ! ASCII LF
        JZR CPNEWLN
        CMB R32,=13D      ! ASCII CR, ignored
        JZR CPNEXT
        JSB =OUTCHR       ! Proven v0.03b printable-character path
        LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,CPENDNL
        JMP CPNEXT

CPNEWLN LDMD R14,=BINTAB
        STMD R56,X14,CPRBUD
        LDM R26,=CPSPACE
        ADM R26,R14
        LDM R36,=1D,0
        JSB =OUTSTR       ! One trailing space plus native CRT newline
        LDMD R14,=BINTAB
        LDB R20,=1
        STBD R20,X14,CPENDNL
        LDMD R56,X14,CPRBUD
CPNEXT  DCM R56
        JNZ CPRLOOP
        CLB R20
        STBD R20,=CPOPC  ! Abort if a reply never terminates
        LDM R26,=CPRLONG
        ADMD R26,=BINTAB
        LDM R36,=18D,0
        JSB =OUTSTR       ! native newline already printed
        RTN
! Some result strings end with LF and others do not. Leave exactly
! one fresh BASIC input line after a reply, not an extra blank line.
CPDONE  LDMD R14,=BINTAB
        LDBD R20,X14,CPENDNL
        CMB R20,=1
        JZR CPFIN
        LDM R26,=CPSPACE
        ADM R26,R14
        LDM R36,=1D,0
        JSB =OUTSTR       ! native HP-85 CRT newline
CPFIN   RTN

CPTOUT  ASP "CPM85 DRIVE TIMEOUT"
CPRLONG ASP "CPM85 REPLY LIMIT"
CPSPACE BYT 40         ! octal ASCII space, one byte for OUTSTR newline
CPMKPFX ASP "CREATING "

! ---------------------------------------------------------------
! CPUI key -- C1 experimental native state machine and CRT renderer.
! Executed only from normal HP BASIC statements, NEVER from CHIDLE.
! A small BASIC program owns KBDBUFFER/KBDKEY foreground polling.
! All CPUI output uses HP-native OUTSTR (not PRINT or HP-IB).
! This stage DOES NOT attach keyboard, emit EBTKS keys or receive LST.
! ---------------------------------------------------------------
        BYT 241
UIRUN   SAD
        BIN
        LDMD R14,=BINTAB
        JSB =ONER
        BIN
        LDMD R14,=BINTAB
        STMD R#,X14,UIREAL
        LDMD R60,X14,UIREAL
        JSB =CONINT
        BIN
        LDMD R14,=BINTAB
        LDB R20,R77
        JZR UIARGOK
        JSB =ERRORP
        BYT 89D
UIARGOK LDB R22,R76
        CMB R22,=0
        JNZ UIEVENT
        JMP UIINIT

UIEVENT LDBD R20,X14,UIACT
        CMB R20,=1
        JZR UIACTOK
        JSB =ERRORP
        BYT 89D
UIACTOK CMB R22,=207
        JNZ UICHECK
        JMP UIEXIT
UICHECK CMB R22,=203
        JNZ UIMENK
        JMP UISWCH
UIMENK  LDBD R20,X14,UIMODE
        CMB R20,=0
        JZR UIMKEY
        BIN
        PAD
        RTN
UIMKEY  CMB R22,=200
        JNZ UICHK2
        LDB R20,=1
        JMP UISTPG
UICHK2  CMB R22,=201
        JNZ UICHK3
        LDB R20,=2
        JMP UISTPG
UICHK3  CMB R22,=202
        JZR UISET3
        BIN
        PAD
        RTN
UISET3  LDB R20,=3
UISTPG  STBD R20,X14,UIPAGE
        JMP UIDRAW

UIINIT  LDBD R20,X14,KHACT
        CMB R20,=0
        JNZ UIBAD
        LDBD R20,=CHIDLE
        CMB R20,=236
        JNZ UIBAD
        LDB R20,=1
        STBD R20,X14,UIACT
        STBD R20,X14,UIPAGE
        CLB R20
        STBD R20,X14,UIMODE
        JMP UIDRAW

UISWCH  LDBD R20,X14,UIMODE
        CMB R20,=0
        JNZ UISWUI
        LDB R20,=1
        STBD R20,X14,UIMODE
        JMP UIDRAW
UISWUI  CLB R20
        STBD R20,X14,UIMODE
        JMP UIDRAW

UIEXIT  CLB R20
        STBD R20,X14,UIACT
        STBD R20,X14,UIMODE
        LDM R26,=UIBYE
        ADMD R26,=BINTAB
        LDM R36,=18D,0
        JSB =OUTSTR
        BIN
        PAD
        RTN
UIBAD   JSB =ERRORP
        BYT 89D

! All output goes through native CRT OUTSTR, never BASIC PRINT.
! Each call emits one native CRT line; this first native renderer
! scrolls rather than clearing the CRT so previous BASIC text survives.
UIDRAW  LDM R26,=UITITLE
        ADMD R26,=BINTAB
        LDM R36,=25D,0
        JSB =OUTSTR
        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,UIMODE
        CMB R20,=0
        JZR UIDRUI
        JMP UIDRCT

UIDRUI  LDM R26,=UIMENU
        ADMD R26,=BINTAB
        LDM R36,=25D,0
        JSB =OUTSTR
        BIN
        LDMD R14,=BINTAB
        LDBD R20,X14,UIPAGE
        CMB R20,=1
        JZR UIDR1
        CMB R20,=2
        JZR UIDR2
        JMP UIDR3
UIDR1   LDM R26,=UIDRIVE
        ADMD R26,=BINTAB
        LDM R36,=26D,0
        JSB =OUTSTR
        BIN
        PAD
        RTN
UIDR2   LDM R26,=UIDEVIC
        ADMD R26,=BINTAB
        LDM R36,=27D,0
        JSB =OUTSTR
        BIN
        PAD
        RTN
UIDR3   LDM R26,=UISYSTM
        ADMD R26,=BINTAB
        LDM R36,=26D,0
        JSB =OUTSTR
        BIN
        PAD
        RTN

UIDRCT  LDM R26,=UICTRL
        ADMD R26,=BINTAB
        LDM R36,=28D,0
        JSB =OUTSTR
        LDM R26,=UIPAUSE
        ADMD R26,=BINTAB
        LDM R36,=25D,0
        JSB =OUTSTR

UIRET   BIN
        PAD
        RTN

! ----------------------------------------------------------------------
! Stage C2 unsafe input experiment QUARANTINED after hardware crash.
!
! 2026-10-24: physical HP-85 crashed when CPKTEST was invoked.
! Original C2 probe is preserved in Git history (commit 7c7d9cd3);
! do not run it. Its local JSB =K2KEY was an invalid relocatable
! routine call (should use JSB X14,K2KEY). More fundamentally,
! the KEYHIT-only busy loop was never proven to get keyboard events
! while normal HP BASIC execution was suspended.
!
! CPKTEST now returns immediately after an OUTSTR notice. No native
! foreground loop, KEYHIT read, CHIDLE changes or EBTKS I/O.
! Retain only the zero-argument numeric diagnostics for source ABI
! compatibility: both remain zero after initial LOADBIN/CPKTEST.
! The validated C1 CPUI + BASIC key-pump path stays untouched.
! ----------------------------------------------------------------------
        BYT 241
K2RUN   SAD
        BIN
        LDMD R14,=BINTAB
        CLB R20
        STBD R20,X14,K2COUNT
        STBD R20,X14,K2LAST
        LDM R26,=K2STOP
        ADMD R26,=BINTAB
        LDM R36,=29D,0
        JSB =OUTSTR
        BIN
        PAD
        RTN

        BYT 0,55
K2CNT   BIN
        LDMD R14,=BINTAB
        LDM R36,=0,0
        LDBD R36,X14,K2COUNT
        JSB =CONBIN
        BIN
        PUMD R40,+R12
        RTN

        BYT 0,55
K2LST   BIN
        LDMD R14,=BINTAB
        LDM R36,=0,0
        LDBD R36,X14,K2LAST
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
! Detach from Teensy without consulting/awaiting the ESP32.
        CLB R22
        STBD R22,=CPCTL
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
! One short, write-only 8-bit I/O cycle; the Teensy ISR only queues
! the byte, never does storage/UART work in the HP keyboard hook.
        STBD R22,=CPKEY

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
CPRBUD  BSZ 2           ! exactly R56-R57, survives CRT calls
CPENDNL BSZ 1           ! was last output byte an HP-native newline?
CPNMADR BSZ 2           ! CPDMK original HP string pointer (2 bytes)
CPNMLEN BSZ 2           ! CPDMK original HP string length  (2 bytes)
CPMKBUF BSZ 96D         ! 9+79+3 maximum, decimal; assembler defaults octal
UIREAL  BSZ 8D          ! temporary BASIC real, ONER/CONINT conversion
UIACT   BSZ 1           ! native C1 console initialized
UIMODE  BSZ 1           ! 0=management,1=simulated CP/M control
UIPAGE  BSZ 1           ! 1=drives,2=devices,3=system
K2COUNT BSZ 1           ! quarantined probe count, 0
K2LAST  BSZ 1           ! quarantined probe last code, 0


! Message bytes (ASCII subset).  Lengths are decimal, not null-terminated.
K2STOP  ASP "CPKTEST DISABLED - SEE C2 DOC"
UITITLE ASP "CPM85 CONSOLE C1 (NATIVE)"
UIMENU  ASP "K1-3 PAGES K4 CPM K8 EXIT"
UIDRIVE ASP "DRIVES: NOT CONNECTED (C1)"
UIDEVIC ASP "DEVICES: NOT CONNECTED (C1)"
UISYSTM ASP "SYSTEM: NOT CONNECTED (C1)"
UICTRL  ASP "CP/M CONTROL: DEMO MODE ONLY"
UIPAUSE ASP "KEYS/LST PAUSED (C1 DEMO)"
UIBYE   ASP "CPM85 CONSOLE EXIT"
ONMSG   ASP "CPM85 KEY CAPTURE ON - K8 RETURNS TO BASIC"
BSYMSG   ASP "CPM85: KEYBOARD HOOK BUSY (PRTKEYS 0?)"
OFFMSG   ASP "CPM85 KEY CAPTURE OFF"
ALRMSG  ASP "CPM85 KEY CAPTURE ACTIVE"
MNMSG    ASP "C85MENU RMIDLE TEST - K8 EXITS"
VERMSG   ASP "CPM85 0.06a RMIDLE PROBE"
ONLEN   EQU 42D
BSYLEN  EQU 38D
OFFLEN  EQU 21D
VERLEN  EQU 24D

! HP-85 addresses, all OCTAL (copied from tested PRINTER85 LOADBIN).
BINTAB  DAD 101233
ROMFL   DAD 101231
CHIDLE  DAD 102416
KEYHIT  DAD 100671
EOJ2    DAD 34772
CPKEY   DAD 177741     ! EBTKS keyboard data I/O port
CPCTL   DAD 177742     ! EBTKS keyboard attach/detach I/O port
CPARG   DAD 177743     ! Drive-control ASCII argument stream, W
CPOPC   DAD 177744     ! Drive-control opcode, W
CPSTATE DAD 177745     ! Drive-control status, R
CPRPLY  DAD 177746     ! Drive-control result char, R
STREX+  DAD 13623      ! SCAN + parse string expression
STREXP  DAD 13626      ! Parse subsequent string expression
GETCMA  DAD 13414      ! Demand comma and SCAN
ERRORP  DAD 6611       ! Standard HP BASIC error
OUTCHR  DAD 35114      ! Output one character to HP CRT
SCAN    DAD 11262
OUTSTR  DAD 35052
CONBIN  DAD 03572
NUMVP   DAD 12407      ! numeric parser, PRINTER85 tested
ONER    DAD 56215      ! pop BASIC REAL into R#
CONINT  DAD 44321      ! REAL -> binary integer R76/R77

        FIN
