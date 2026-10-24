# CPM85 management console — Stage C0 hardware input/UI probe

**Status (2026-10-24): STAGE C0 PHYSICAL HP-85 ACCEPTANCE PASSED.**
User tested `tests/CPMCONSOLE.bas` on the physical machine and confirmed
**"yes, that works."** The foreground BASIC loop, display-only menu,
K1-K3 page controls, K4 UI/simulated-Control mode toggle, and K8
return/keyboard cleanup are accepted as a group. CI passed on the
HP feature branch. This validation is limited to the standalone BASIC
prototype: there is **no native LOADBIN foreground loop, printer
receiver, LST: interception, or live keyboard forwarding in this test**.
The previously validated CPM85 v0.04c LOADBIN remains untouched.

## Why a standalone BASIC skeleton first

The intended end product is a **foreground CPM85 management console** with
its own input loop, local drive/device menus, and a CP/M Control mode in
which HP-85 keyboard forwarding and printer reception both run.
Switching back to UI mode must pause BOTH services, withdraw printer
readiness, and leave the parallel Z80 running.

The existing HP CPM85 v0.04c LOADBIN implements keyboard capture by
installing the CHIDLE hook and returning to BASIC; this is physically
accepted. A foreground assembly loop cannot safely assume that CHIDLE
continues to run in the BASIC editor, so we need to establish a proven
key-input contract **before** replacing that command.

The project's existing `tests/CPMKEYS.bas` has physically exercised
`KBDBUFFER 1`, `KBDISKEY`, and `KBDKEY` **inside a running BASIC program**.
C0 uses those same APIs to verify an HP-side foreground loop and modal
keyboard ownership. This does not establish how to invoke them from a
LOADBIN entry; that remains a separate implementation investigation.

## C0 behavior and explicit limitations

- Run as a separate BASIC program; it does **not** call or replace the
  installed `CPM` LOADBIN command and does not alter CHIDLE.
- Input is polled in the BASIC loop. K1 (128), K2 (129), K3 (130)
  select Drives / Devices / System placeholder pages; K4 (131) switches
  Management <-> simulated CP/M Control; K8 (135) exits from either mode.
- Uses `DISP`, **not `PRINT`**: HP-85 BASIC `PRINT` honors `PRINTER IS`
  and might unexpectedly send menu text to the internal printer or HP-IB.
  For this hardware test, leave `CRT IS 1` (the internal CRT) selected.
- The test-only UI is confined to one display line to avoid invoking
  `PRINTER IS`. The eventual assembly console will have a proper
  multi-line CRT renderer that preserves the existing printer setting.
- No EBTKS I/O writes; no ESP32/Teensy changes; no CP/M keys forwarded;
  no LST bytes received; printer ready stays conceptually **false**.
  **Do not mistake simulated Control mode for an active CP/M session.**
- `KBDBUFFER 0` is executed on the normal K8 exit. A BASIC STOP,
  runtime error or RESET can interrupt the program before cleanup.
  Test with expendable unsaved BASIC data and plan to reinitialize
  the keyboard if an emergency interruption occurs.

## Physical test procedure

1. Confirm CP/M and TFT/Web terminal are running normally, but **exit the
   existing CPM85 keyboard capture with K8** before starting this test.
   Disable any PRINTER85 keyboard panel first (enter `PRTKEYS 0`).
2. With `CRT IS 1`, load or type `tests/CPMCONSOLE.bas` as an ordinary
   HP-85 BASIC program. It is source text, not a LOADBIN artifact.
3. `RUN`; expect `DRIVES: K1-3 PG K4 CPM K8 END` on the display.
4. Press K2 and K3; the displayed page should change. K1 restores
   Drives. Press K4; expect `CP/M DEMO: K4 MENU K8 EXIT`.
5. Press ordinary letters while in simulated Control; **they are NOT
   forwarded**. K4 returns to the selected management page.
6. Press K8 from Management, then RUN again and press K8 directly from
   Control. Both should exit back to BASIC, execute `KBDBUFFER 0`,
   and display the exit message.
7. Verify keyboard works normally after both exits. Then use the
   *unchanged* firmware's `CPM` command, type in CP/M on TFT/Web, K8
   detach, and check CP/M `DIR`. That is the preservation regression.

If a key produces an unexpected function-key code on the user's
hardware, collect the decimal code using the existing tested
`tests/CPMKEYS.bas` and revise C0 mapping before integrating.

## C1 plan after C0 physical acceptance

- Determine a safe native HP-85 foreground keyboard API (rather than
  assuming CHIDLE), and a CRT output routine independent of `PRINTER IS`.
- Implement this foreground loop as a new **experimental LOADBIN command**
  separate from existing `CPM` until keyboard UX and clean exit are
  physically verified.
- Only then connect the per-mode HP->Teensy keyboard forwarding and
  ESP32->Teensy->HP printer byte service, with session generation, ACK,
  credits, and CP/M LISTST nonready while UI active.

**No merge, firmware flash or normal printer-output testing for C0.**
