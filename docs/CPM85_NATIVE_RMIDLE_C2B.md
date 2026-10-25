# HARDWARE-REJECTED — C2b native RMIDLE experiment

**Physical HP-85 result (2026-10-25): FAIL. DO NOT BUILD OR RUN
CPM85 v0.06b `CMENU` again.** The user reports no visible counter,
machine freeze with no response to K8, and recovery after pressing
RESET (warm boot). This overrides the earlier CAPASM/CAPLIF and source
regression success: successful compilation is not evidence that an
HP firmware hook or native CRT write is safe on hardware.

**Recovery committed:** on `timob0/HP85-Option-Roms`
`feature/cpm85-hpib-output`, restored `src/cpm85.asm`,
keyword tests and CI from the pre-C2b commit
`72d389ae33a77c6b239ca09116a609a2942a1ddb`, corresponding
to experimental v0.05c with failed C2 foreground polling disabled
and C1 `CPUI` preserved. Removed the misleading C2b-specific
regression that asserted the failed hook implementation was present.
No EBTKS Teensy or ESP32 firmware changes. All `main` branches
remain untouched.

**Last physically accepted console:** C1 v0.05a, commit
`13655f2d8bd0889b91aa4d0a47c8936bcb429d0c`.
Use this previously tested source/image for ordinary HP operation.
v0.05c is a source rollback baseline, not independently physically
accepted. Following RESET, reloading the accepted C1 LOADBIN is
recommended before further testing; do not retry experimental CMENU.

## Technical postmortem (hypotheses, not confirmed root cause)

The C2b implementation modified **two live HP RAM hook vectors**.
On CMENU entry it installed a resident CHIDLE keyboard intercept and
a new RMIDLE trampoline intended to call existing AUXROM ROM361
handler. RMHOOK also attempted **direct CRTBUSY/CRTBAD/CRTDAT
display writes inside the RMIDLE callback**. Because RMDIRTY
started at 1, the first callback was supposed to execute the CRT
drawing path immediately, before the first counter appeared.

The complete absence of a visible counter **does not show that
RMIDLE never ran**: execution may have frozen in the hook wrapper,
the very first CRT operation, the original ROMJSB call, or the
hook return/stack path. The user-visible failure does not
distinguish these possibilities.

The first design flaw was conflating three uncertain mechanisms in
one hardware test: new hook chaining/return semantics, potentially
sensitive native CRT I/O during EXEC RMIDLE, and hook cleanup upon
K8. Even bounded display status polls do not prove they are
safe or nonintrusive inside the HP firmware's EXEC callback.
The static test guarded byte patterns and source operations but
did not model ROMJSB stack/register/condition behavior, callback
reentrancy, or CRT controller timing. There is no basis to conclude
that only a particular instruction caused the freeze.

**Revised investigation gate:** no new binary should install RMIDLE
and draw the CRT in the same initial experiment. Obtain or inspect
the exact HP-85 ROMJSB/EXEC hook calling convention and, ideally,
reproduce in an HP-85 emulator or disassembler first. If still
attempted on hardware, a *counter-only*, no-screen, no-HP-IB
hook probe with a direct K8/RESET recovery path must pass on its
own, with the value read after K8 from BASIC. Screen rendering
would be a separate stage after the hook lifecycle is demonstrated.
Avoid overwriting the EBTKS AUXROM RMIDLE slot if its original handler
cannot be faithfully preserved and chained.

---

## Retired v0.06b instructions — historical only; DO NOT RUN

# CPM85 C2b — first all-HP-native RMIDLE counter and modal keyboard console

**Status: experimental, native CAPASM/CAPLIF CI passing; physical HP-85
acceptance PENDING.** Source: HP Option ROMs
`feature/cpm85-hpib-output`, CPM85 **v0.06b**.
**No Teensy or ESP32 firmware changes. No BASIC source file required.**

This replaces the rejected Teensy-rendered C2a design and never uses
its optional `screenEmu` setting. Unlike the crashed original C2,
there is **no native KEYHIT busy loop**. Execution returns promptly
from the LOADBIN command, then HP's normal EXEC/keyboard machinery
drives two resident RAM intercepts.

## Precisely established prerequisite

The user's physical HP-85 reported the following seven bytes at
RMIDLE decimal 34076–34082 (octal 102434–102442):

```
decimal: 206 254   9  51 103 241 158
octal:   316 376 011 063 147 361 236
```

This is the exact 7-byte HP Option-ROM hook:
`JSB =ROMJSB; DEF 063463; BYT 361; RTN`.
That is AUXROM 361 and **must keep being invoked** to preserve
EBTKS normal autostart, batch and keyboard-injection services.

The experimental `CMENU` runtime:
- checks that `CHIDLE` begins with its idle opcode 0236 and that
  **all seven RMIDLE bytes exactly match the above signature**;
  refuses unexpected hook ownership with BASIC error 89 *before*
  modifying either intercept
- saves all seven RMIDLE bytes and seven CHIDLE bytes in private
  LOADBIN RAM and installs the known 4-byte `JSB <RAM>; RTN`
  redirect at each entry; no Teensy display, mailbox or I/O change
- returns immediately to HP's editor/EXEC context, without loading
  or modifying the BASIC source program
- on native RMIDLE invocations, saves R10–R47 scratch registers,
  increments three ASCII digits in HP RAM, optionally refreshes a
  32-character **native HP CRT alpha row** using direct CRTBAD/
  CRTDAT registers with bounded busy waits (every 256 callbacks,
  or after a K1–K4 event), then restores saved registers
- **calls the original ROMJSB descriptor LAST** using precisely
  `JSB =ROMJSB; BYT 063,147,361; RTN` after the register restores;
  this preserves the original AUXROM hook's responsibility for its
  resulting return/condition state
- retains the hardware-proven `CHIDLE` capture/K8 handling:
  K1=Drives, K2=Devices, K3=System, K4 toggles simulated
  Management/CP-M Control; **no keyboard codes forwarded to ESP32**
  in this probe
- on K8 or CPOFF/unload, restores the saved RMIDLE bytes only if
  the 4-byte currently installed RMIDLE trampoline still points to
  ours, then restores the original CHIDLE bytes
- leaves PRINTER IS / LST / LISTST and HP-IB untouched.

## Display

Example native CRT row (32 columns, ASCII digits):

```
RMIDLE:000 PAGE:1 MODE:0 K8 EXIT
```

The **digits count actual RMIDLE invocations modulo 1000**, updating
in private RAM at each callback. The CRT row is redrawn only after
256 callbacks, or a key change, to limit interference and workload.
The displayed number may wrap from 999 to 000 and could appear to
jump if the callback is frequent. Page 1/2/3 and mode 0/1 show
only the controls' internal HP-native state; no real CP/M Control
forwarding occurs in this test.

The overlay uses CRT hardware and *does not* use `OUTSTR` inside
RMIDLE, redirection through PRINT, Teensy CRT DMA, or `screenEmu`.
The current CRT byte pointer is restored after each draw. **Full
screen restoration is not yet implemented**: the row's characters
may remain visible after K8 until the HP firmware next redraws it.
Your BASIC program in memory should be untouched.

## Build and physical test

Only build the HP Option-ROM module from
`timob0/HP85-Option-Roms`:

```bash
git fetch origin
git switch feature/cpm85-hpib-output
git pull --ff-only
./py311/bin/capasm src/cpm85.asm -b build/CPM85.bin -l build/CPM85.lst -r 2 -c
./py311/bin/caplif build/CPM85.bin -l build/CPM85.dat -f CPM85
```

The CI workflow uses `capasm==1.0.1` and `caplif`, and also
tests the exact ROM361 RMIDLE hook bytes and cleanup paths.
**Assembly/CI cannot guarantee safety on the physical HP-85**,
particularly for direct CRT writing from an EXEC callback.
This is the first physical test of the new hook, so begin with
a **disposable/basic-safe session** and preserve a copy of any
important edited BASIC program.

1. Exit prior CPM capture with K8, issue `PRTKEYS 0` if PRINTER85
   is active and select `CRT IS 1` (alpha mode). Keep the
   physically accepted C1 v0.05a `CPM85.dat` available to revert.
2. Reload experimental CPM85 v0.06b, then `CPVER` should show
   `CPM85 0.06b NATIVE RMIDLE`.
3. Optionally verify the current RMIDLE seven bytes still equal
   the signature above using `PEEK(34076)` through `PEEK(34082)`.
4. Enter **`CMENU`** as a single immediate BASIC statement.
   It prints an activation heading and returns to the HP's
   normal event processing. No separate BASIC source is involved.
5. **First let it run without touching any keys.** Look for
   the native `RMIDLE:### PAGE:# MODE:#` line to appear and its
   three digits to change over time.
6. If stable, press **K2, K3, K1, K4, K4**. Observe updates of
   page/mode and whether the counter keeps moving.
7. Press **K8**; verify immediate return to standard BASIC typing
   and that your BASIC program is intact. Screen overlay may remain
   until refreshed; that by itself does not mean the hook persists.
8. Optionally re-run the *read-only* seven `PEEK`s after K8.
   They must return the original ROM361 signature, proving cleanup.
   Finally regress the original `CPM`/K8 keyboard forwarding.

**If CMENU errors 89:** do not retry until you check the RMIDLE
bytes and hook ownership. This is expected when another module
has modified either intercept.

**If the HP hangs, resets unexpectedly, or K8 fails:** stop,
power-cycle/reset as needed, then restore the last accepted C1
image. Report which output appeared, whether the counter advanced
and what K8 did. Do **not** rerun the old `CPKTEST` tight loop.

## Remaining uncertainties and next acceptance gates

- ROMJSB chaining and scratch-register conventions have been
  source-reviewed and compiled but **not validated on hardware**.
- Calling native CRT hardware from RMIDLE is experimental and
  needs physical timing/stability validation. Any HPIB printing
  work must wait for this to be verified and must not occur
  inside a sensitive interrupt/hook context.
- Although each CRT busy poll is bounded, no real-time guarantee
  exists for the HP EXEC callback frequency.
- It remains to be established whether `RMIDLE` continues to
  run during long HP BASIC programs (it may not).
- Screen/editor restoration should be improved after acceptance,
  without requiring another BASIC source program.

**Repository policy:** all `main` branches untouched.
