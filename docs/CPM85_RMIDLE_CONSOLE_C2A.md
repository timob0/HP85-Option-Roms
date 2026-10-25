# RETIRED C2a — incorrect Teensy-rendered RMIDLE probe

**Retired on 2026-10-25. DO NOT follow the build/flash/test instructions
below.** The user correctly rejected this implementation as violating
the intended architecture: the HP-85 itself must count RMIDLE callbacks
and render the native CRT. EBTKS's `screenEmu` controls a separate
optional CRT-mirroring implementation, not the native HP-85 console.

**Observed hardware result:** `CMENU` gave no counter and K1-K4 appeared
ineffective; K8 exited cleanly and the user's BASIC program was intact.
The Teensy probe had been gated behind `get_screenEmu()` and did
not display anything when `screenEmu` was false. This observation
does not establish the HP's native RMIDLE callback frequency.

**Repository recovery:** All new C2a Teensy CRT/RMIDLE files were
deleted, and the modified Teensy code restored identically to
`main` on `feature/cpm85-hpib-output`. The HP repo's
Teensy-dependent `CMENU` command was withdrawn, reverting CPM85
`src/cpm85.asm` to the quarantined v0.05c/C1 source.
No user hardware update needed now; the current flashed v0.06a
`CMENU` image remains an obsolete experiment. Prefer the
physically accepted C1 v0.05a LOADBIN for ongoing use.

**Replacement design requirement:** entirely HP-native keyboard/UI
handling and count/display, with **correct chaining of the existing
EBTKS AUXROM RMIDLE hook**. Do not overwrite that hook. The
HP Assembler ROM documentation describes 7-byte RMIDLE hook forms,
but exact save/execute/restore handling and an appropriate
CRT-coordinate/overlay service need to be verified before generating
another hardware binary. Printer output remains disabled. See
`docs/CPM85_NATIVE_CONSOLE_RESEARCH.md`.

---

## Historical (retracted) instructions — do not execute

# C2a native HP-85 RMIDLE console probe — joint HP LOADBIN + Teensy test

**Status:** compiled / CI checked, PHYSICAL HP-85 TEST PENDING.
**Build pair:** HP Option ROM `feature/cpm85-hpib-output` CPM85
v0.06a and EBTKS Teensy `feature/cpm85-hpib-output` with
`EBTKS_CPM85_RMIDLE_PROBE_ENABLE=1` on the feature branch.
ESP32 firmware does **not** change.

## Why this is *not* the crashed native C2 experiment

The C2 `CPKTEST` foreground tight-poll experiment crashed the
physical HP-85 and remains **permanently disabled**. Do not run old
v0.05b firmware. This design does **not** spin in HP native code or
read `KEYHIT` from a foreground loop. It reuses the user-accepted
CPM85 `CHIDLE` keyboard interception and returns from the LOADBIN
`CMENU` statement to the firmware editor, just as existing `CPM`
does. K8 always restores `CHIDLE`, even if the Teensy has not yet
been reflashed or the counter never updates.

The source-free native command `CMENU` uses only:
- HP-side `CHIDLE` for key events. It saves the existing hook, installs
  the known four-byte stub, and sends control byte `2` to the
  existing `CPCTL=0177742` EBTKS port. The first menu interaction
  is **Management**. K1-K3 select pages, K4 toggles the *simulated*
  Control mode, and K8 detaches. Key events use the known
  `CPKEY=0177741` port, but on this experimental mode the
  Teensy **never** forwards them to the ESP32 Z80.
- Existing EBTKS AUXROM `AUXROM_RMIDLE()` increments a 32-bit
  count, and then continues **all the previous mailbox processing
  unchanged** (CONFIG.TXT, batch, Wi-Fi injection, etc).
- Existing Teensy main task `loop()` checks at most every 250 ms
  and uses EBTKS's already-implemented `Write_on_CRT_Alpha`
  DMA routine to redraw the HP CRT status. This is **not**
  called in the Teensy bus ISR, keyboard hook, or AUXROM_RMIDLE
  handler. The selected page and mode are read from ISR-written
  byte flags.
- The visual counter shows the raw number of RMIDLE callbacks
  since `CMENU` opened. It labels the callback stream `STALLED`
  after two seconds without a new value; independent Teensy uptime
  does not make the count advance. This distinguishes HP's
  RMIDLE activity from an unrelated free-running timer.
- On **normal K8**, Teensy uses its existing CRT capture/restore
  primitives to restore the prior alpha screen snapshot; the HP
  key hook is restored on the HP side, separately. On physical
  **RESET** the experimental HP module issues special value `4`
  so the Teensy stops without replaying a stale pre-reset screen.
  This is best-effort, not yet physically verified.

**No printer/HP-IB/CP/M `LST:` handling, ready flag or credit is
enabled.** Existing legacy `CPM` value 1 attach/0 detach is preserved.

## Build

On the Mac, first build/flash Teensy from
`timob0/ebtks-alt-firmware`:

```bash
git fetch origin
git switch feature/cpm85-hpib-output
git pull --ff-only
pio run -e teensy41
pio run -e teensy41 -t upload
```

Feature-branch `platformio.ini` includes
`-DEBTKS_CPM85_RMIDLE_PROBE_ENABLE=1`. Do not deploy this
experimental firmware as a general baseline. Use a working
Teensy firmware backup for recovery if required. No ESP32 flash
is necessary.

Then build/LOADBIN the HP module from
`timob0/HP85-Option-Roms`:

```bash
git fetch origin
git switch feature/cpm85-hpib-output
git pull --ff-only
./py311/bin/capasm src/cpm85.asm -b build/CPM85.bin -l build/CPM85.lst -r 2 -c
./py311/bin/caplif build/CPM85.bin -l build/CPM85.dat -f CPM85
```

Load `CPM85.dat` by your standard HP-85 LIF/LOADBIN workflow.
`CPVER` must report `CPM85 0.06a RMIDLE PROBE`.

## Physical test procedure

1. Use a disposable HP BASIC edit session initially and preserve a
   known-good C1 image; **do not run CPKTEST**. Turn off the PRINTER85
   keyboard panel with `PRTKEYS 0`, leave any original `CPM`
   capture with K8, use alpha `CRT IS 1`, and verify normal HP
   keyboard works.
2. Enter **`CMENU`** as an immediate BASIC statement. Do not load,
   scratch or run any BASIC source. The HP prints a short notice and
   returns to its standard editor event cycle, but the keyboard is
   retained by the modal console until K8.
3. EBTKS should overlay a compact menu on the **physical HP CRT**:
   a page label, Management mode, `RMIDLE: ########## ACTIVE`,
   and K1-K4/K8 instructions. Watch for several seconds **without
   pressing any key**. The counter should rise if HP calls RMIDLE
   while the editor is waiting.
4. Press K2, K3 and K1. The **PAGE** line should switch to
   Devices, System and Drives while RMIDLE count continues to rise.
   Press K4 to switch to **CP/M CONTROL (NO KEYS)** and K4 to
   return to Management. Neither mode forwards any keys.
5. Press **K8**. The `CHIDLE` hook should restore immediately
   without waiting for Teensy redraw. Teensy then attempts to
   restore the prior CRT image. Verify ordinary HP BASIC typing,
   the current BASIC program source and cursor/editing behavior.
6. Finally retest the **unchanged `CPM`** keyboard capture, K8
   release, and the Z80/TFT/Web terminal. If the counter does not
   rise, **report the displayed number, STALLED/ACTIVE, and
   whether function keys/K8 still worked**.

## Interpretation / safety caveats

- **Counter advances without keys + K1–K4 and K8 respond:** promising
  evidence that EBTKS RMIDLE can host future cooperative service
  while the native modal console is present. It does **not** prove
  printer output would be safe from that context.
- **Counter remains zero/STALLED but keys work:** existing RMIDLE
  path is not being serviced as expected (or AUXROM not active).
  Do not attach printer processing; console hook can still be useful.
- **Counter advances only with keys:** RMIDLE is not an independent
  idle service under the tested conditions. Printer needs an
  alternative scheduler or explicit readiness deferral.
- **K8 doesn't exit or the HP resets:** hardware test failed;
  stop testing, recover with last accepted C1 firmware and report
  screen behavior. Do not rerun the crashed C2 polling firmware.
- This test uses the existing EBTKS CRT DMA capability for a visual
  counter. CRT capture/restore is **experimental in this modal use**
  and may not fully preserve a currently edited input line or
  another feature using the shared capture buffer. Start with
  expendable BASIC data, not an unsaved important program.
- `Write_on_CRT_Alpha` only paints in alpha mode; do not test
  in graphics mode. The experiment intentionally excludes HP-86/87.
  EBTKS `get_screenEmu()` must be enabled for the overlay.
- RMIDLE runs only when the HP EXEC loop reaches it. No fixed-rate
  timer or guarantee during arbitrary HP BASIC calculations is
  implied.

All `main` branches stay unchanged until physical tests pass.
