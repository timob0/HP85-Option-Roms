# CPM85 Stage C2 — bounded all-native KEYHIT input feasibility probe

**Status (2026-10-24): native test source implemented; HP-85 hardware
validation PENDING.** Existing C1 hybrid `CPUI` and accepted legacy
`CPM` commands remain intact; no ESP32/Teensy firmware changes.
Development branch: `feature/cpm85-hpib-output`.
This is **not yet** a production keyboard replacement or CP/M control mode.

## Motivation and critical uncertainty

C0 proved an HP BASIC foreground loop using EBTKS AUXROM's documented
`KBDBUFFER/KBDISKEY/KBDKEY`. C1 moved menu/page/mode handling and
CRT rendering to HP native Capricorn assembly through `CPUI key`,
but still relied on a small BASIC foreground event-polling program.

C2 must prove whether a **native LOADBIN runtime that remains busy in a
foreground loop** can receive physical keypresses without returning to
BASIC's editor or calling BASIC AUXROM keyboard functions.

In the existing, hardware-accepted keyboard hook, HP firmware updates
`KEYHIT` (RAM, octal address `100671`) before invoking `CHIDLE`.
**We do not know whether KEYHIT changes while a normal LOADBIN statement
continues executing**, so trying to use it as a reliable event queue
would be speculative. Stage C2 measures precisely that. Static tests
and CAPASM success do not prove event delivery.

## New isolated test in experimental CPM85 v0.05b

- `CPKTEST`: bounded native foreground input-and-menu probe. It saves
  the initial `KEYHIT` value, observes changes, and renders a small
  Drives/Devices/System view using native `OUTSTR`. It starts with
  printer readiness **off** and never writes the EBTKS keyboard
  attach/forwarding I/O ports. The Z80 and TFT keep running independently.
- `CPKCOUNT`: numeric function giving count of distinct observed
  KEYHIT values, modulo 256; does not affect the existing `CPCOUNT`.
- `CPKLAST`: numeric function returning most recently observed
  KEYHIT value; does not affect `CPLAST`.
- Input candidates: K1/K2/K3 (128/129/130 decimal) select pages; K4
  (131) toggles Management versus **simulated** Control; K8
  (135 decimal = `207` octal) exits the native loop immediately *if*
  KEYHIT is actually updated. Other distinct codes increase the count
  but are not forwarded. Identical consecutive codes cannot be
  distinguished by this **change-detection** strategy.
- If the native KEYHIT register does not update, the loop exits with
  `C2 TIMEOUT - BACK TO BASIC` after three 16-bit polling spans.
  The inactivity count restarts when any new KEYHIT value is detected;
  stop typing to ensure a timeout even if the hardware is noisy.
- Active legacy `CPM` keyboard hook, PRINTER85 `PRTKEYS` hook, or
  unfinished C1 `CPUI` session causes a refusal rather than sharing
  resources.

## Build

In `timob0/HP85-Option-Roms`:

```bash
git fetch origin
git switch feature/cpm85-hpib-output
git pull --ff-only
./py311/bin/capasm src/cpm85.asm -b build/CPM85.bin -l build/CPM85.lst -r 2 -c
./py311/bin/caplif build/CPM85.bin -l build/CPM85.dat -f CPM85
```

Only the HP-85 LOADBIN needs reloading: there is **no ESP32 or Teensy
flashing** for C2. Do not deploy the experimental LOADBIN outside a
scratch HP BASIC session until hardware tests pass.

## Physical keyboard experiment

1. Exit an existing legacy `CPM` keyboard session with K8, and exit
   any C1 `CPUI` session with `CPUI 135` if one was started manually.
   Issue `PRTKEYS 0` if the printer control panel is installed.
2. Use `CRT IS 1` and freshly load `CPM85.dat` from the feature
   branch. `CPVER` should read `CPM85 0.05b NATIVE KEY PROBE`.
3. At the HP BASIC prompt, enter `CPKTEST`. Expect the native
   `C2 RAW KEYHIT PROBE ACTIVE` heading and Drives page.
4. Press K2 (Devices), K3 (System), K1 (Drives), then K4 (simulated
   Control) and K4 again (Management). Observe whether CRT output
   changes **without any running BASIC keyboard event-pump program**.
5. Press K8. If this input strategy works, `CPKTEST` exits immediately
   and emits `C2 K8 - BACK BASIC`. If it does not detect native keys,
   it will return on its own with a **timeout** instead.
6. After return, use the safe CRT destination to inspect diagnostics:
   `DISP CPKCOUNT`, then `DISP CPKLAST`. They should show at
   least one event, and last code 135, **only if K8 was detected**.
   Report both diagnostics and whether pages changed or timeout occurred.
7. Verify ordinary HP BASIC keyboard works after test. Then regress
   the unchanged `CPM` K8 attach/release and the accepted
   `CPMCONSOLE_C1.bas` menu as a separate follow-up.

**Never infer that this mechanism works solely because `CPKTEST`
assembled or displayed its initial banner.** If KEYHIT does not change
in a busy native loop, C2 has successfully ruled out this shortcut.
The next approach would require a documented callable native keyboard
scan/queue service or a dedicated, explicitly versioned Teensy/HP
event mailbox, not another speculative busy spin.

## Acceptance gate

Pass requires: correct K1-K4 navigation, a K8 exit without waiting for
timeout, accurate diagnostic codes (particularly last=135), normal
BASIC keyboard after exit, then successful legacy CPM C1 regressions.
This C2 experimental input has **no CP/M keyboard forwarding, no
HP-IB output, no LIST/LISTST routing and no printer ready state**.
