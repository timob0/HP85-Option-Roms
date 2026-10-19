# CPM85 v0.01a — keyboard-only HP-85 experiment

Development branch: `feature/cpm85-keyboard-capture`. **Experimental. Do not deploy as a finished CP/M keyboard integration.** No Teensy or ESP32 firmware changes are required. No option-ROM IDs or SIMON85/PRINTER85 source files are changed.

## Hardware test order (important)

**Test 1 — EBTKS AUXROM keyboard buffer using BASIC.** This checks the officially documented `KBDBUFFER 1`, `KBDISKEY` and `KBDKEY` statements/functions **inside a running BASIC program**. They are explicitly invalid in calculator mode, so a standalone machine-code call is not assumed to work. Type or import `tests/CPMKEYS.bas` as an ordinary numbered BASIC program, ideally on an HP-85 with EBTKS's standard AUXROMs enabled. If PRINTER85's key-panel is currently installed, issue `PRTKEYS 0` first. Save any important BASIC program/data before beginning.

```basic
RUN
```

Press letters, shifted keys and cursor/navigation keys and note the printed **decimal** keycode. Press **K8 (SHIFT + physical K4)** to release keyboard capture. For HP-85 we currently expect K8 = **207 octal = 135 decimal**, but **verify** this with the machine. The test should finish with `KEYBOARD RELEASED` and normal BASIC keyboard operation. EBTKS reports the AUXROM buffer as 16 keys. If this fails, **do not proceed to Test 2**.

**Test 2 — isolated LOADBIN `CPM` command and CHIDLE hook.** This is an alternative keyboard-path experiment using the **same CHIDLE hook pattern as the tested standalone PRINTER85**. It intentionally does **not** call AUXROM `KBDBUFFER`: the documented AUXROM keywords are restricted to a running BASIC program, and the low-level AUXROM entry-point contract has not yet been established for a LOADBIN runtime. Therefore the two tests exercise **different input hooks**; passing Test 1 does not establish Test 2 will work.

Build with CAPASM 1.0.1 and CAPLIF:

```bash
capasm src/cpm85.asm -b build/CPM85.bin -l build/CPM85.lst -r 2 -c
caplif build/CPM85.bin -l build/CPM85.dat -f CPM85
```

A dedicated GitHub Actions workflow also builds and uploads `CPM85.dat` as a downloadable artifact. The repository's standard `build.sh` uses its pre-existing `./py311/bin/capasm` tools and now includes CPM85.

Load `CPM85.dat` with the existing HP-85 `LOADBIN` procedure (`LOADBIN "CPM85"`). Keep the original `PRTKEYS 1` panel disabled (`PRTKEYS 0`) for this standalone test; CPM refuses to overwrite an occupied CHIDLE intercept rather than chaining it. Before attachment, you can invoke `C85VER`.

The LOADBIN registers these **non-overlapping** keywords:

| Keyword | Purpose |
| --- | --- |
| `CPM` | Install the temporary CHIDLE keyboard-capture hook. No input is sent to Z80 yet. |
| `C85OFF` | Explicitly restore CHIDLE (normally only useful from an alternative input source). |
| `C85VER` | Print module/version. |
| `C85COUNT` | Numeric function: captured key count modulo 256. |
| `C85LAST` | Numeric function: last raw HP keyboard code captured. |

The `C85*` names deliberately do **not** begin with `CPM` to avoid the HP BASIC shortest-match keyword collision previously encountered with `PLOT`/`PLOTTER`.

Suggested sequence:

```text
LOADBIN "CPM85"
C85VER
CPM
[Press a few ordinary keys — BASIC must not echo them]
[Press SHIFT+K4 (K8) to detach]
PRINT C85COUNT
PRINT C85LAST
[Normal BASIC editor should now accept typing]
```

For the K8 detachment to work, the *captured* `KEYHIT` must be octal 207. The HP-85 CHIDLE handler recognizes that code locally and restores **all seven original hook bytes**, using the proven `EOJ2` + R6 handled-key return sequence from PRINTER85. For this first experiment the saved hook must initially be idle (`CHIDLE` begins with `RTN`, octal 236). We intentionally **do not chain** PRINTER85's or another ROM's intercept.

## Recovery and limitations

- This is experimental machine code, **not hardware validated**. Build success only checks assembly, not interactions with the live HP BASIC interpreter or OS hook.
- When the keyboard is captured, K8 is the intended release. A RESET may be required if the HP keyboard is unavailable or the hook misbehaves. This would interrupt HP BASIC; use sacrificial/noncritical data for these tests.
- The LOADBIN's INIT follows the established standalone PRINTER85 pattern for LOAD, SCRATCH and RESET hook lifecycle. If RESET resets the HP interpreter hook, the module drops its ownership flag.
- `C85COUNT` rolls over after 255 events, and `C85LAST` includes K8 as the final code.
- No key remapping, key-repeat rate control, CP/M data transport, ESP32 changes, Teensy mailbox usage or disk traffic is included in this version.
- `KBDBUFFER` and CHIDLE may interact with existing key hooks differently; test separately, not concurrently. Do not leave a capture mode active while changing the loaded binary or installing other CHIDLE consumers.
- If a key is erroneously ignored or K8 has a different raw code, collect the numeric codes from **Test 1** before changing the hook.
- Only after both tests are verified should we add a Teensy FIFO and serialized ESP32 `consoleRxEnqueue` forwarding; avoid sending unsolicited bytes on the storage UART.

## Sources

- Existing tested standalone PRINTER85 key-hook lifecycle: `src/printer85.asm` (this repository).
- EBTKS AUXROM source: [EBTKS_AUXROM_SD_Services.cpp](https://github.com/timob0/ebtks-alt-firmware/blob/main/src/EBTKS_AUXROM_SD_Services.cpp) (documented RMIDLE ownership codes 2 and 3 are not implemented on the Teensy).
- [EBTKS AUXROM reference](https://www.fliptronics.com/EBTKS/AUXROM_Keywords.html) — keyboard buffer documented only for running BASIC programs.
