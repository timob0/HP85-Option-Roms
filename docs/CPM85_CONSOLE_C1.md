# CPM85 Stage C1 — native HP-85 CRT/mode command with BASIC key pump

**Status:** experimental, not yet accepted on physical HP-85. Feature
branch `feature/cpm85-hpib-output`. No ESP32 or Teensy firmware change.

## Why the C1 input path is deliberately hybrid

C0, the standalone `tests/CPMCONSOLE.bas`, passed physical testing.
It proves that in a running HP BASIC program, EBTKS AUXROM's
`KBDBUFFER`, `KBDISKEY` and `KBDKEY` supply physical key events and
K8=135 releases that program.

No documented, hardware-proven **native LOADBIN foreground key scanner**
has yet been identified. The already accepted CPM85 `CHIDLE` keyboard
hook only runs reliably after the `CPM` command returns to the BASIC
editor, so it cannot simply be assumed to run inside a new blocking
machine-code console loop.

**C1 therefore implements actual console-state transition and multiline
CRT rendering in CPM85 native assembly** through a new `CPUI key`
statement. The tiny `tests/CPMCONSOLE_C1.bas` foreground BASIC loop
continues to poll the *verified* keyboard-buffer interface and passes
keycodes to `CPUI`. This is an honest intermediate step, not yet an
entirely native polling loop.

## New experimental HP BASIC command (v0.05a)

- `CPUI 0`: initialize independent native mode/page state and draw the
  menu. Guard against an active legacy `CPM` or `PRTKEYS` CHIDLE hook.
- `CPUI 128` / `129` / `130` (K1/K2/K3): select placeholder Drives,
  Devices, or System page, **only** in Management mode.
- `CPUI 131` (K4): switch Management <-> simulated CP/M Control.
- `CPUI 135` (K8): disable native C1 console state, render exit,
  and let the BASIC key-pump execute `KBDBUFFER 0`.
- Other codes are ignored by the native UI. No keys are sent to CP/M,
  no printer bytes received, and no printer readiness is advertised.

The `CPUI` parser uses numeric `NUMVP` and the hardware-proven
`ONER`/`CONINT` register/stack convention from PRINTER85. No new
undocumented numeric BASIC-stack operations. The new command is appended
to the existing keyword/parser/runtime tables, preserving the index and
behavior of all accepted commands including `CPM`, `CPDCAT` and
`CPDMK`. String output uses HP-native `OUTSTR` only, never BASIC
`PRINT` or direct HP-IB. Lines are <=32 CRT columns. The first native
renderer **scrolls**, rather than clearing and redrawing the full CRT.

No new EBTKS registers, no CHIDLE modifications, no file writes and no
runtime change on ESP32/Teensy.

## Build and physical test

On the Mac in `timob0/HP85-Option-Roms`:

```bash
git fetch origin
git switch feature/cpm85-hpib-output
git pull --ff-only
./py311/bin/capasm src/cpm85.asm -b build/CPM85.bin -l build/CPM85.lst -r 2 -c
./py311/bin/caplif build/CPM85.bin -l build/CPM85.dat -f CPM85
```

If using GitHub Actions instead, take the `CPM85.dat` artifact from the
successful **feature-branch** CAPASM workflow.

1. Use expendable BASIC data; exit an existing `CPM` session with K8,
   and disable the PRINTER85 keyboard panel with `PRTKEYS 0`.
   Set `CRT IS 1` for the CRT.
2. Reload the new `CPM85.dat` in the usual way with
   `LOADBIN "CPM85"`; ensure no old CPM85 binary is still active.
   `CPVER` should show `CPM85 0.05a CONSOLE PROBE`.
3. First type `CPUI 0` at the BASIC prompt: you should see the native
   console heading plus Drives page. This isolates the LOADBIN parser
   and CRT renderer *before* entering the key-pump loop.
4. Run `tests/CPMCONSOLE_C1.bas` as a **BASIC program** (not LOADBIN).
   It starts the keyboard buffer, calls native `CPUI 0`, then forwards
   every keycode using `CPUI K`.
5. K2 -> Devices; K3 -> System; K1 -> Drives; K4 -> simulated CP/M
   Control page; ordinary letters -> no redraw; K4 -> Management;
   K8 -> return to BASIC.
6. Run again and K8 exit straight from simulated Control. Verify that
   ordinary BASIC keyboard input works after exit in both cases.
7. Verify `CPM` still forwards keyboard input to the already running
   CP/M TFT/Web terminal, K8 still detaches, and `CPDCAT "A:"`,
   `DIR`, Multiplan and Media Manager remain unaffected.

**Safety:** `CPMCONSOLE_C1.bas` performs `KBDBUFFER 0` on normal K8
exit. STOP, RESET, assembly error or interruption can bypass that line;
use only scratch sessions and restore keyboard state if necessary.
Do not install PRINTER85's CHIDLE panel and legacy CPM hook together.
The native C1 page switch *does not* advertise LST readiness.

## Remaining gate after C1

Choose a verified HP native **foreground keyboard scanner / runtime
entry point** before moving `KBDBUFFER` polling entirely into machine
code. Next introduce a safe display/page abstraction and only then
HP/Teensy mode signaling, key forwarding and LST reception. Do not
pretend this hybrid key-pump already satisfies the final architecture.
