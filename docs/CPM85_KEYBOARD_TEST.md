# CPM85 v0.02a — HP-85 keyboard forwarding experiment

## CPM85 v0.02a — end-to-end hardware validation (2026-10-19)

**PASSED.** The user confirms the complete development setup works on a physical HP-85: `CPM` redirects keystrokes into CP/M, K8 releases the keyboard back to BASIC while CP/M keeps running, and entering `CPM` again reconnects to that existing CP/M session. This extends the previously proven v0.01b keyboard hook/diagnostic tests to real Teensy→ESP32 forwarding. No firmware or ROM `main` branch has been merged; this is a successful functional checkpoint on the development branches.

Open follow-ups include mapping HP-85 special/function/cursor keys, sustained rapid typing, any dropped-key/CRC retries, printer hook coexistence, ESP32 heap and concurrent disk/TFT stress testing. **The first functional test is passed; these broader regressions are not yet claimed.**

## New development-only Teensy/ESP32 bridge

The physically verified v0.01b keyboard capture, K8 release, CPCOUNT and CPLAST behavior are retained in v0.02a. New v0.02a sends each **non-K8 raw KEYHIT code** to EBTKS I/O address **0177741 octal**, sends **1** to control address **0177742** on CPM attach and **0** on K8 or CPOFF detach. These ports only exist on matching Teensy `feature/cpm85-keyboard-forwarding` firmware. K8 remains a local HP release that does not depend on the ESP32.

**DO NOT LOAD the forwarding experiment unless you have deliberately installed the matching development firmware** and saved previous known-good firmware/images. First try the standalone v0.01b version if you need to reconfirm local hook behavior. The v0.01b source is preserved in `src/archive/cpm85_v0.01b.asm`.

Build v0.02a using `build.sh` or the dedicated Actions workflow and load the new CPM85 image. Before `CPM`, boot CP/M and open its console via Telnet or the existing ST7796. Type a few ordinary printable characters on the HP keyboard, press END LINE, and verify that CP/M receives them. Press K8 to detach; BASIC should immediately accept commands, `PRINT CPLAST` should yield 135 and the previously running CP/M session must remain alive. Reenter `CPM` to attach again. Unknown HP special keys are not yet mapped to the CP/M terminal; record their raw codes with `CPMKEYS.bas`.

See [the bridge integration guide in the ESP32 repository](https://github.com/timob0/EBTKS-Z80-Emulator/blob/feature/cpm85-keyboard-forwarding/CPM85_KEYBOARD_BRIDGE.md) for required firmware branches, flash order and caveats. **All v0.02a forwarding is untested on real hardware until the user runs this test.**

---

## Historical v0.01b keyboard-only hardware tests

## Physical HP-85 checkpoint

**v0.01b hardware-confirmed (2026-10-19):** On the physical HP-85, the user loaded CPM85 v0.01b, captured nine key events, detached successfully with K8, and reported `PRINT CPCOUNT` = **9** and `PRINT CPLAST` = **135** decimal (**207 octal**, K8). These observations validate the corrected `0,55` zero-argument numeric function descriptors and their integration with the keyboard hook. The LOADBIN keyboard capture, K8 release and both numeric diagnostics are now **hardware tested**. The module still does **not** forward keystrokes to CP/M; Teensy/ESP32 transport is future work. No option-ROM merge or other firmware change was made for this test.

**v0.01a hardware-confirmed:** The user reports `tests/CPMKEYS.bas` captures and displays raw keycodes and releases cleanly with K8. The standalone `CPM85` LOADBIN also loads, the `CPM` command captures normal keyboard input, and K8 successfully returns to BASIC. Thus, **keyboard ownership and K8 release are proven**. The diagnostic functions `C85COUNT` and `C85LAST` produced `Error 89 INVALID PARM` on the physical HP-85. Code inspection found that both functions mistakenly used the **SIMON85 `TEST(x,y)` two-argument function descriptor `40,55` (octal)** instead of the **zero-argument numeric function descriptor `0,55`**. Because the runtime accepted no parameters, the wrong descriptor is a direct and sufficient explanation of the error; embedded digits were also removed from the new names to avoid any separate lexer ambiguity.

**v0.01b correction (now hardware verified):** Keep the **same proven CHIDLE capture/release implementation** and numeric-function bodies. Fix both descriptor bytes from `40,55` to `0,55` (octal), and change diagnostic keyword names to all-letters with distinguishable three-character prefixes: `CPOFF`, `CPVER`, `CPCOUNT` and `CPLAST`. None extends the `CPM` keyword. The zero-argument descriptor is corroborated by the CAPASM assembler repository's `lex75/hpilcmd.asm` (`BYT 0,55 ! numeric, no arguments`); the new `CPCOUNT` and `CPLAST` functions have now been verified on an HP-85 (9 captured keys, last code 135). Reassemble/reload v0.01b to test the correction; assembly passing is not enough. Use `PRINT CPCOUNT` and `PRINT CPLAST` **without arguments or parentheses** after K8; the count should include the K8 keystroke and the last code should be decimal 135.



Development branch: `feature/cpm85-keyboard-capture`. **Experimental. Do not deploy as a finished CP/M keyboard integration.** No Teensy or ESP32 firmware changes are required. No option-ROM IDs or SIMON85/PRINTER85 source files are changed.

## Hardware test order (important)

**Test 1 — EBTKS AUXROM keyboard buffer using BASIC (PASSED on physical HP-85).** This checks the officially documented `KBDBUFFER 1`, `KBDISKEY` and `KBDKEY` statements/functions **inside a running BASIC program**. They are explicitly invalid in calculator mode, so a standalone machine-code call is not assumed to work. Type or import `tests/CPMKEYS.bas` as an ordinary numbered BASIC program, ideally on an HP-85 with EBTKS's standard AUXROMs enabled. If PRINTER85's key-panel is currently installed, issue `PRTKEYS 0` first. Save any important BASIC program/data before beginning.

```basic
RUN
```

Press letters, shifted keys and cursor/navigation keys and note the printed **decimal** keycode. Press **K8 (SHIFT + physical K4)** to release keyboard capture. For HP-85 we currently expect K8 = **207 octal = 135 decimal**, but **verify** this with the machine. The test should finish with `KEYBOARD RELEASED` and normal BASIC keyboard operation. EBTKS reports the AUXROM buffer as 16 keys. If this fails, **do not proceed to Test 2**.

**Test 2 — isolated LOADBIN `CPM` command and CHIDLE hook (CPM/K8 PASSED on physical HP-85; numeric diagnostics pending v0.01b).** This is an alternative keyboard-path experiment using the **same CHIDLE hook pattern as the tested standalone PRINTER85**. It intentionally does **not** call AUXROM `KBDBUFFER`: the documented AUXROM keywords are restricted to a running BASIC program, and the low-level AUXROM entry-point contract has not yet been established for a LOADBIN runtime. Therefore the two tests exercise **different input hooks**; passing Test 1 does not establish Test 2 will work.

Build with CAPASM 1.0.1 and CAPLIF:

```bash
capasm src/cpm85.asm -b build/CPM85.bin -l build/CPM85.lst -r 2 -c
caplif build/CPM85.bin -l build/CPM85.dat -f CPM85
```

A dedicated GitHub Actions workflow also builds and uploads `CPM85.dat` as a downloadable artifact. The repository's standard `build.sh` uses its pre-existing `./py311/bin/capasm` tools and now includes CPM85.

Load `CPM85.dat` with the existing HP-85 `LOADBIN` procedure (`LOADBIN "CPM85"`). Keep the original `PRTKEYS 1` panel disabled (`PRTKEYS 0`) for this standalone test; CPM refuses to overwrite an occupied CHIDLE intercept rather than chaining it. Before attachment, you can invoke `CPVER`.

The LOADBIN registers these **non-overlapping** keywords:

| Keyword | Purpose |
| --- | --- |
| `CPM` | Install the temporary CHIDLE keyboard-capture hook. No input is sent to Z80 yet. |
| `CPOFF` | Explicitly restore CHIDLE (normally only useful from an alternative input source). |
| `CPVER` | Print module/version. |
| `CPCOUNT` | Numeric function: captured key count modulo 256. |
| `CPLAST` | Numeric function: last raw HP keyboard code captured. |

All five keyword names use only letters and diverge by character three; none extends the `CPM` prefix. The old `C85*` names were replaced following physical HP-85 Error 89 reports.

Suggested sequence:

```text
LOADBIN "CPM85"
CPVER
CPM
[Press a few ordinary keys — BASIC must not echo them]
[Press SHIFT+K4 (K8) to detach]
PRINT CPCOUNT
PRINT CPLAST
[Normal BASIC editor should now accept typing]
```

For the K8 detachment to work, the *captured* `KEYHIT` must be octal 207. The HP-85 CHIDLE handler recognizes that code locally and restores **all seven original hook bytes**, using the proven `EOJ2` + R6 handled-key return sequence from PRINTER85. For this first experiment the saved hook must initially be idle (`CHIDLE` begins with `RTN`, octal 236). We intentionally **do not chain** PRINTER85's or another ROM's intercept.

## Recovery and limitations

- The core capture/K8 release machine code passed physical HP-85 testing in v0.01a; the newly renamed v0.01b diagnostics are **hardware validated**. Build success only checks assembly, not interactions with the live HP BASIC interpreter or OS hook.
- When the keyboard is captured, K8 is the intended release. A RESET may be required if the HP keyboard is unavailable or the hook misbehaves. This would interrupt HP BASIC; use sacrificial/noncritical data for these tests.
- The LOADBIN's INIT follows the established standalone PRINTER85 pattern for LOAD, SCRATCH and RESET hook lifecycle. If RESET resets the HP interpreter hook, the module drops its ownership flag.
- `CPCOUNT` rolls over after 255 events, and `CPLAST` includes K8 as the final code.
- No key remapping, key-repeat rate control, CP/M data transport, ESP32 changes, Teensy mailbox usage or disk traffic is included in this version.
- `KBDBUFFER` and CHIDLE may interact with existing key hooks differently; test separately, not concurrently. Do not leave a capture mode active while changing the loaded binary or installing other CHIDLE consumers.
- If a key is erroneously ignored or K8 has a different raw code, collect the numeric codes from **Test 1** before changing the hook.
- Only after both tests are verified should we add a Teensy FIFO and serialized ESP32 `consoleRxEnqueue` forwarding; avoid sending unsolicited bytes on the storage UART.

## Sources

- Existing tested standalone PRINTER85 key-hook lifecycle: `src/printer85.asm` (this repository).
- EBTKS AUXROM source: [EBTKS_AUXROM_SD_Services.cpp](https://github.com/timob0/ebtks-alt-firmware/blob/main/src/EBTKS_AUXROM_SD_Services.cpp) (documented RMIDLE ownership codes 2 and 3 are not implemented on the Teensy).
- [EBTKS AUXROM reference](https://www.fliptronics.com/EBTKS/AUXROM_Keywords.html) — keyboard buffer documented only for running BASIC programs.
