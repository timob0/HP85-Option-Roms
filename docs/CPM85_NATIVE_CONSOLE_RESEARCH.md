# C2 redesign research — fully integrated HP-85 LOADBIN console, no BASIC program

**Research checkpoint, 2026-10-25.** This is an architecture investigation;
no executable code or new test firmware is introduced by this document.
The last physically accepted console remains C1 (native CPUI renderer,
keyboard pump in a separate BASIC test program). The C2 v0.05b foreground
KEYHIT polling experiment physically crashed; v0.05c quarantines it.
Do **not** rerun v0.05b `CPKTEST`.

## 2026-10-25 — Clock/interrupt versus cooperative print service research

**Finding:** The HP-85 has a millisecond system clock and three
programmable BASIC timers (`ON TIMER# 1..3`). They are useful for
running BASIC programs, but **not a free, source-independent LOADBIN
timer callback**. HP's BASIC documentation says an ON TIMER#
declaration must be within a program, and the Advanced Programming
reference notes that timer branches are local to the declaring program
and do not interrupt other programs. Reserving one of these timers would
also risk interfering with the BASIC application being edited.

Authoritative primary documentation:
- HP Assembler ROM Manual, Section 3, `https://www.akso.de/fileadmin/Series_80/Assembler_ROM_Manual.pdf`.
  This states that clock interrupts invoke the ON TIMER machinery,
  **IRQ20 and IOSP belong to I/O interrupts, not a periodic 20 ms tick**,
  and the firmware executive loop *always* tests CSTAT, tests XCOM,
  and calls RMIDLE.
- HP-85 Owners Manual, timer section,
  `https://www.kaser.com/hp85_series80org/HP85-MainBW.pdf`;
  the ON TIMER# statement must be declared within a program.
- HP-85 Advanced Programming Manual,
  `https://www.series80.org/PDFs/HP85-AdvProg.pdf`,
  documents program-local timer branches.
- CAPASM globals85 and EBTKS headers show `TIMTAB`, `TIMTB2`,
  `TIMTB3`, `CLKSTS`, `CLKDAT`, `IRQ20`, `RMIDLE`.
  The mere existence of a symbol **does not** establish a callable
  periodic extension API.

**Preferred scheduler:** Use *cooperative native idle service through
the existing RMIDLE integration*, rather than a new periodic ISR.
EBTKS AUXROM already owns RMIDLE to inject autostart/batch/Wi-Fi
keyboard events. Its Teensy code `AUXROM_RMIDLE()` dispatches when the
HP EXEC loop reaches the hook. We must preserve/compose with that
implementation, not replace its seven-byte hook.

**Important distinction:** RMIDLE is serviced when the HP executive
loop is reached, **not guaranteed at fixed real-time intervals** or
when the CPU is inside arbitrary long BASIC computation or HP-IB
transaction. Therefore a readiness flag must reflect service
capacity/freshness and buffer credits, not a timer-dependent constant.

### Two-stage, bounded printer service model

1. On every eligible *safe* idle callback, cheaply check console mode,
   guest LST FIFO occupancy and printer/link state without blocking.
   When UI mode active or session detached: set LST not ready and do
   not forward/consume print bytes.
2. In Control mode, request/acknowledge **at most a bounded small
   portion** from the ESP32/Teensy buffer, and use a **verified native
   printer work context** to call HP's printer/HP-IB firmware service
   honoring `PRINTER IS`. Initial design experiments can try
   16–32 bytes per dispatch; this is **an unmeasured starting point**.
   Do not equate bytes received at HP port with bytes delivered to a
   physical printer.
3. Backpressure must propagate from HP printer delivery/credit to the
   ESP32 and CP/M `LISTST`. Dequeue/ack only after the HP printer
   routine has safely accepted/committed the bytes, and distinguish
   acceptance by an HP output routine from delivery by the external
   printer. Programs may call `LIST` without checking `LISTST`; a
   bounded pending buffer plus recoverable error/cancel policy remains
   necessary. UI mode transitions must quiesce in-flight work before
   withdrawing credits.
4. If a single HP printer call can stall indefinitely due to HP-IB
   handshake/offline behavior, chopping a job into chunks **does not
   by itself prevent blocking**. Native HP output timeouts/nonblocking
   status and how to report an offline printer must be examined and
   hardware-verified before enabling live routing.
5. The HP native timer/interrupt path, if identified in more detail
   later, should **at most set a one-byte pending flag**. Never run
   HP-IB transactions, allocate, render CRT, write Teensy SD, or do
   transport handshakes from hardware/clock/keyboard interrupt
   contexts. Avoid reserving one of the user's BASIC timers.

**Concrete next feasibility gate:** instrument the *already-owned*
EBTKS RMIDLE path to count callbacks during an attached CPM console,
including while no keys are pressed. Expose a read-only status
counter only through a safe existing management/status interface;
do not change RMIDLE ownership. Confirm an HP-safe native dispatch
path separately with no printer IO. After that, test a
printer-offline scenario with **ready held false** before attempting
real LST bytes.

## Requirement clarified by user

The finished `CPM` command must launch a complete management console
from a previously installed `LOADBIN "CPM85"` module, **without loading
any BASIC source**. The user's current HP BASIC program and editing
context must remain available on returning from the console. The
console provides Drives, Devices and System management pages and
two exclusive modes:

- **Management:** HP keyboard owned locally, no keys forwarded and CP/M
  `LST:` not ready.
- **CP/M Control:** HP keyboard forwarded except reserved console keys;
  incoming `LST:` stream may be drained to the HP-native `PRINTER IS`
  target if available, with bounded acknowledgements/backpressure.
- K4 toggles management/control in initial design, K8 always returns
  control to normal HP BASIC immediately. The Z80 continues running.
  Printer device override `CPM 705` is deferred.

A literal CPU-spinning foreground loop is **not** a requirement.
Instead, a resident event-driven LOADBIN console can behave modally
while allowing native firmware to keep driving the keyboard. This is
the same user-visible execution model as the already proven `CPM`
keyboard capture, only with much richer state/display functions.

## Specific HP-85 entry points located

CAPASM HP-85 symbol table
`https://github.com/bug400/capasm/blob/master/symbols/globals85.txt`
and upstream EBTKS header
`https://github.com/Fliptron/T41_EBTKS_FW_1.0/blob/master/include/EBTKS.h`
agree on these OCTAL system addresses:

| Name | Octal address | Known/labelled use |
| --- | --- | --- |
| `CHIDLE` | `102416` | Character editor intercept; current CPM85 `CHIDLE` keyboard capture **physically proven** |
| `KYIDLE` | `102425` | Keyboard intercept; an HP assembler manual describes it as polled when a key is pressed (requires HP-85-specific hook ABI validation) |
| `RMIDLE` | `102434` | EXEC/interpreter idle intercept; **already used by EBTKS AUXROM**, not free for commandeering |
| `KEYHIT` | `100671` | Last-key-related RAM; **not a standalone event queue**; direct foreground polling failed on real hardware |
| `KEYSRV` | `34555` | Symbol-labelled native keyboard service; exact entry ABI/side effects UNVERIFIED |
| `COUNTK` | `34664` | Symbol-labelled key-count service; ABI UNVERIFIED |
| `KEYSTS` | `177402` | Keyboard status I/O; not suitable for naive polling without validating firmware ownership |
| `KEYCOD` | `177403` | Keyboard-code/EOJ hardware register; do not read opportunistically |
| `EOJ2` | `34772` | Existing keyboard-hook completion helper used by proven CPM85/PRINTER85 paths |

The *HP-85/87 assembler reference manual* available via
`https://www.akso.de/fileadmin/Series_80/Assembler_ROM_Manual.pdf`
describes `KYIDLE` as a keyboard intercept called when a key is pressed.
The HP-85 addresses are independently corroborated by the above
tables. A matching documented `KYIDLE` calling and stack contract
still must be located before installation on physical hardware.

## Evidence from existing working modules

1. **CPM85 v0.04c keyboard attach/detach** (`src/cpm85.asm`)
   installs a relocatable RAM `CHIDLE` trampoline, returns from the
   BASIC command and forwards subsequent `KEYHIT` key events via the
   EBTKS port `0177741`. K8 detaches via `KREL`. The user verified this
   on actual HP-85 hardware. This already proves that *a resident,
   source-free keyboard-ownership session* is viable.
2. **PRINTER85** (`src/printer85_rom.asm`) uses `CHIDLE` and
   `EOJ2`, native KEY LABEL save/restore, and invokes significant
   printer operations from keyboard handling. Its ROM trampoline
   unwinds the ROM-switching frame before the local stack correction.
   This is evidence that native event handlers can render/dispatch;
   it is **not** proof that arbitrary printer operations are safe in
   a periodic or time-sensitive context.
3. **EBTKS AUXROM / Teensy firmware**
   (`timob0/ebtks-alt-firmware/src/EBTKS_AUXROM_SD_Services.cpp`
   around `AUXROM_RMIDLE`): comments explicitly say RMIDLE is
   called when the HP's EXEC loop reaches the hook; usage code
   `0` = no character, `1` = injected character, `2` = take
   ownership of the keyboard, `3` = release keyboard ownership.
   Codes `2` and `3` are **supported by AUXROM but explicitly
   labelled untested in the Teensy**. Source points to ROM361 listing
   label `RHNOTKEY` and ROM364 `KBDISR`. We must obtain those
   ROM listings or study their equivalent before relying on 2/3.
   EBTKS already relies on RMIDLE to inject autostart/batch input,
   so replacing it blindly would regress existing functionality.

## Leading architecture: resident native event dispatch

A `CPM` (or experimental `CPMENU`) LOADBIN statement:

1. Verify hook ownership, register/init session state, save HP CRT /
   KEY LABEL / editor context needed for eventual restoration.
2. Draw initial Management page using native HP CRT output (reuse
   C1 state machine/renderer; **do not** call the BASIC `CPUI`
   keyword implementation directly from a key hook, because its
   `ONER`/BASIC stack and `PAD` semantics are not a keyboard hook ABI).
3. Install a **single** proven keyboard event dispatch hook and
   **return to the BASIC runtime**. The CPU now runs the normal
   firmware editor/EXEC path; no other BASIC program is loaded.
4. In the event handler: capture real key event, distinguish
   K1–K3 (page), K4 (mode toggle), K8 (always local detach), and
   ordinary CP/M keys. Dispatch only small, verified native operations
   and return through the proven `EOJ2`/stack path.
5. Provide a separate, cooperative **no-key-required service** to
   handle incoming printer data while Control is active. Study
   `RMIDLE` and EBTKS AUXROM coexistence first; do NOT overwrite
   a live EBTKS hook. The service must be non-blocking, bounded,
   respect HP native printer readiness, and never run in the Teensy
   HP-bus ISR. If no safe periodic HP call exists yet, leave
   `LISTST` not ready and postpone printer drain.
6. On K8/CPOFF/RESET/LOAD/SCRATCH: revoke LST readiness before
   detaching, restore **exact** previous hook bytes and HP
   display/editor/key-label state, discard stale sessions and return
   to the already resident BASIC program.

The exact placement of the idle service is OPEN:
- Prefer cooperating with the existing EBTKS AUXROM RMIDLE implementation
  (extension/known callback) if its execution and callback ABI can be
  validated and hook ownership is manageable.
- Alternatively, chain an existing HP firmware idle intercept only
  after proving the original handler executes and is safely preserved.
- If neither can be validated, explore native `KEYSRV`/
  `KYIDLE` separately in documentation/emulator, but do not revive
  the rejected `KEYHIT` busy spin.

**Important nuance:** An idle hook may not run during long HP BASIC
calculations or binary code execution. Printer ready must follow
actual receiver service capacity / freshness, not merely a stored
`CPM` active flag. Never set `LISTST` to ready until the no-key
service path is proven.

## Safe hardware validation gates (no unnecessary firmware flashing)

**C2a - resident UI hook only; HP Option ROMs only**
- Add a separate experimental command (not replace accepted `CPM`).
- Reuse the *verified existing CHIDLE* capture mechanism and use C1
  native render/page state in a callback-safe routine.
- No `KEYHIT` spin, no EBTKS/ESP change, no printer operations.
- Physical test: from the BASIC editor with an unsaved BASIC program,
  enter console, navigate K1–K4, K8 exit; previous BASIC program and
  editor remain intact. Regression for PRINTER85/CHIDLE conflict.
- Preserve a guaranteed local K8 detach even when external firmware
  or menus malfunction.

**C2b - true background/no-key servicing proof**
- Inspect native EBTKS AUXROM ROM361/ROM364 `RMIDLE` ownership/calling
  contract and decide composition. First implement a side-effect-free
  counter that increments in verified safe idle service callbacks
  and can be read by a normal BASIC function *after* console exit.
- Verify count grows while **no key is pressed**; check no lost
  EBTKS autostart/batch/keyboard activity and no dependence on
  UI repaint side effects. No printer/HP-IB transport yet.

**C2c - gated mode/session state**
- Mode switch is local and atomically disables forwarding/receive
  before changing ownership. Add Teensy/ESP mode state/heartbeats
  only after C2a/C2b.
- `LST:` stays NOT READY until capacity, printer availability
  and safe backpressure have been demonstrated.

**C2d - HP native printer service**
- Reuse HP's own configured `PRINTER IS` destination; optional
  `CPM 705` is session-local. No new ESP32 IEEE-488 handling.
- Use bounded payloads and acknowledgements. Never print from a
  bus ISR or claim success on buffer reception without verified
  delivery. Offline target must not trap the UI.

## Research still needed

- Determine exact *HP-85* `KYIDLE` call frequency, register/stack
  contract, execution context and install/uninstall lifecycle. It
  may be preferable to `CHIDLE` if compatible with PRINTER85.
- Obtain EBTKS ROM361/ROM364 listings for `RHNOTKEY` and
  `KBDISR`; inspect how `RMIDLE` and keyboard ownership work.
- Determine whether a safe `RMIDLE` callback or different native
  interpreter service can execute without key events and coexist
  with EBTKS. Do not assume idle equals periodic real-time scheduling.
- Save/restore the HP CRT *and current BASIC editing line* when
  entering/leaving modal console. This must be physically tested
  while a nonempty BASIC program is present; C1 `OUTSTR` scrolling
  is not yet sufficient.
- Look into the HP assembler/system monitor manual for `KEYSRV`
  calling contract, but consider it lower priority than the
  physically proven event-driven keyboard hook.

## Explicit exclusions

No additional BASIC source program, no foreground `KEYHIT` polling,
no overwriting EBTKS/PRINTER85-owned hooks, no uncontrolled HP
interrupt masking, no edits to `main`, no premature CP/M LST ready.
