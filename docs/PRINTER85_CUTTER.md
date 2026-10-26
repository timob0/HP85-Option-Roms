# PRINTER85 RC1c — CAPD345 cutter: verified on physical hardware

## Scope
* Source: `src/printer85_rom.asm`; ROM 0241, SII driver 2 (IFD501 / CAPD345).
* Normal PAPER ADVANCE remains one ASCII LF (0x0A) per step, with hold-repeat.
* SHIFT + PAPER ADVANCE issues **one full cut** for SII driver 2 and waits for release; there is no repeat and no page/form feed.
* ThinkJet driver 1 retains SHIFT + PAPER ADVANCE = form feed. COPY, common printer controls and graphics are untouched.
* The PRTKEYS CHIDLE/ROMJSB hook and SHIFT detection are unchanged.

## Command
The SII driver’s existing SIPAGE descriptor slot is reused for its secondary paper action; no descriptor ABI, RAM offsets, CHIDLE logic or key handling is altered.

1. `ESC J 0` = `1B 4A 00`: flush buffered text without additional feed, establishing start-of-line for cutter command.
2. `GS V 65 0` = `1D 56 41 00`: **zero additional feed**, then full cut (subject to IFD501 cutter enable).

Assembler octal bytes:
```
SIIJ0   BYT 33,112,0
SIICUT  BYT 35,126,101,0
```
This choice avoids the former SII `ESC d 66` page advance. **The exact command is explicitly documented for the IFD501** in its Technical Reference, Chapter 8, page 8-77 (PDF page 135). `GS V 65 0` is syntactically valid for an IFD501 and is explicitly described as cutting with `n=0`. No new PRINTER85 assembly patch is necessary to try the cutter after it has been enabled.

## Hardware verification (2026-10-27)

**PASS — physical HP-85 + PRINTER85 0.03b RC1c + IFD501-01UK-E/CAPD345:** The user confirmed `PVER` reports RC1c. Initially, SHIFT+PAPER ADVANCE produced no motion because the IFD501's autocutter option was disabled. The user connected the controller to a Windows machine, enabled the autocutter with the Seiko Windows configuration tool, and left all other software DIP switch settings unchanged. Those settings persisted permanently in the printer controller. Returning to the existing HP-85 setup, SHIFT+PAPER ADVANCE successfully executed a **full paper cut**, without a ROM change. This closes the cutter-command hardware acceptance test. Other PRINTER85 regression checks remain independently scoped.

## Critical hardware precondition: cutter selection

The IFD501 can silently ignore the cutter if **SWDIP1-1 Autocutter Selection** is set to `1` (Disable). `0` means Enable. The factory-default value in the table (Chapter 6, page 6-8 / PDF page 47) is **Disable**.

This also precisely predicts RC1c's observed symptom: the Technical Reference says `GS V 65 n` performs *only* feed when cutting is disabled. Because PRINTER85 transmits `n=0`, neither feed nor cut occurs. The verified RC1c `PVER` reads `PRINTER85 0.03B RC1C`; the first on-device Shift+Paper test produced no motion. **After SWDIP1-1 was enabled, SHIFT+PAPER ADVANCE successfully performed the full cut on the actual CAPD345/IFD501 hardware.**

**Safe setup path (printer attached directly to a compatible Windows PC via IFD501 USB):**
1. Ensure the CAPD345 cutter's FPC cable is connected to **IFD501 connector CN3** (Technical Reference §3.3), with printer power **off** while connecting/disconnecting.
2. Install/select the manufacturer's **SII IFD50x (3inch)** driver for CAPD345 if available. Open printer properties/driver **Function Settings → Setup** while print-ready.
3. Read the existing **General Setting 1 / SWDIP1** and change *only* **SWDIP1-1 Autocutter Selection** from `Disable (1)` to `Enable (0)`; preserve all other settings. Click **Apply** and permit the documented reinitialization.
4. Keep hands clear of the mechanism while enabling: the reference warns cutter movement may occur when enabling and the movable blade is not at home.
5. Reconnect the HP-85 printer setup and retry `SHIFT+PAPER ADVANCE` **without rebuilding the RC1c ROM**.

**Documented raw protocol, for diagnosis (not a blind configuration command):**
- Read function settings: `DC2 'l' 0` = `12 6C 00` (hex); returns 80 bytes, 2 nibble bytes per SWDIP entry.
- Set *one complete SWDIP1 byte* without storing to flash: `DC2 'w' 1 d NUL` = `12 77 01 dd 00` (hex). Persistent version uses function code `81` hex but is **not appropriate until the correct complete byte has been read and checked**.
- This writes **all eight bits of SWDIP1**, not a single bit. Never substitute `dd=00` or any guessed constant; preserve all other active and reserved bits. The ROM currently has no IFD501 status/configuration readback path, and does not change printer settings automatically.

If enabling SWDIP1-1 still produces no cut, confirm CN3 connectivity, the cutter home position, and the IFD501 error/status indications before modifying the ROM or repeatedly attempting cuts.

**Primary references supplied by the project user:**
- *IFD501-01SK-E / IFD501-01UK-E Interface Board Technical Reference*, §3.3 (CN3), §5.4 (autocutter), §6.7/Table 6-9 (SWDIP1-1), §8.4.10 page 8-77 (`GS V`), pages 8-82/83 (`DC2 w` / `DC2 l`).
- *IFD/PTD Series Printer Driver Operations Manual*, §3.3.6 (Windows Function Settings), Appendix A (SII IFD50x 3inch).

## Build
From repository root, with the existing CAPASM/CAPROM environment:
```sh
./py311/bin/capasm src/printer85_rom.asm -b build/ROM241.bin -l build/ROM241.lst -r 2 -c -g 85
./py311/bin/caprom build/ROM241.bin -r build/ROM241.rom -s 8
python3 tests/check_printer85_cut.py
```
Check the listing for 0 errors, 0 warnings and confirm an 8 KiB ROM file. The assistant has not independently run CAPASM; the user has confirmed that the actual RC1c ROM runs and that the cutter works on physical hardware.

## Hardware regression procedure (cutter operation already PASSED)
1. Copy the newly built `ROM241.rom` onto the EBTKS SD card in place of the currently active printer ROM; reboot HP-85 to load it.
2. In BASIC, `PVER` should identify `PRINTER85 0.03B RC1C`.
3. With roll paper loaded correctly and hands clear of the cutter, run `PRTSET <device-selector>,2` using your existing working HP-IB device selector (for example 702 **only if** SC7/address 2 matches your setup), then `PRTKEYS 1`.
4. Tap PAPER ADVANCE once: one line. Hold it: line-by-line repeat. Release: stops.
5. After confirming cutter enabled, tap SHIFT + PAPER ADVANCE once: one full cut with **no programmed extra feed**. Keep holding: **no repeat cuts**. A full page must not advance.
6. Repeat only after at least 10 mm of paper has been advanced since the last cut, and avoid cutting faster than 30 times/minute (mechanism limits).
7. Confirm COPY/text and graphics hardcopy still work as before. If ThinkJet driver 1 is available, confirm its SHIFT + PAPER still sends FF.
8. To restore original key handling, run `PRTKEYS 0`.

If the cutter does not move, do not repeatedly trigger it: record what the printer did (fed paper, ignored command, error, jam), verify your exact IFD501 board/firmware and check for a cutter enable/function setting.

## References
* Seiko CAPD245/345 product data: https://www.sii.co.jp/sps/eg/product/lowvoltage/capd245.html
* Seiko RP-E10 command manual (similar Seiko command language): https://seiko.manymanuals.com/print-scan/BX-900/specifications-17476/156
