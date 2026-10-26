# PRINTER85 RC1c — CAPD345 paper cutter (hardware test pending)

## Scope
* Source: `src/printer85_rom.asm`; ROM 0241, SII driver 2 (IFD501 / CAPD345).
* Normal PAPER ADVANCE remains one ASCII LF (0x0A) per step, with hold-repeat.
* SHIFT + PAPER ADVANCE issues **one full cut** for SII driver 2 and waits for release; there is no repeat and no page/form feed.
* ThinkJet driver 1 retains SHIFT + PAPER ADVANCE = form feed. COPY, common printer controls and graphics are untouched.
* The PRTKEYS CHIDLE/ROMJSB hook and SHIFT detection are unchanged.

## Command
The SII driver’s existing SIPAGE descriptor slot is reused for its secondary paper action; no descriptor ABI, RAM offsets, CHIDLE logic or key handling is altered.

1. `ESC J 0` = `1B 4A 00`: flush buffered text without additional feed, establishing start-of-line for cutter command.
2. `GS V 65 0` = `1D 56 41 00`: feed to cutting position + zero extra motion units, then full cut.

Assembler octal bytes:
```
SIIJ0   BYT 33,112,0
SIICUT  BYT 35,126,101,0
```
This choice avoids the former SII `ESC d 66` page advance. The CAPD345 has a built-in auto cutter and supports full and partial cuts. The `GS V m n` syntax is documented by Seiko for related printers; IFD501-specific confirmation requires testing on physical hardware.

## Build
From repository root, with the existing CAPASM/CAPROM environment:
```sh
./py311/bin/capasm src/printer85_rom.asm -b build/ROM241.bin -l build/ROM241.lst -r 2 -c -g 85
./py311/bin/caprom build/ROM241.bin -r build/ROM241.rom -s 8
python3 tests/check_printer85_cut.py
```
Check the listing for 0 errors, 0 warnings and confirm an 8 KiB ROM file. This implementation was source-reviewed but not assembled here; these steps and the hardware tests below are pending.

## Hardware smoke test
1. Copy the newly built `ROM241.rom` onto the EBTKS SD card in place of the currently active printer ROM; reboot HP-85 to load it.
2. In BASIC, `PVER` should identify `PRINTER85 0.03B RC1C`.
3. With roll paper loaded correctly and hands clear of the cutter, run `PRTSET <device-selector>,2` using your existing working HP-IB device selector (for example 702 **only if** SC7/address 2 matches your setup), then `PRTKEYS 1`.
4. Tap PAPER ADVANCE once: one line. Hold it: line-by-line repeat. Release: stops.
5. Tap SHIFT + PAPER ADVANCE once: a short feed to cut position, then one full cut. Keep holding: **no repeat cuts**. A full page must not advance.
6. Repeat only after at least 10 mm of paper has been advanced since the last cut, and avoid cutting faster than 30 times/minute (mechanism limits).
7. Confirm COPY/text and graphics hardcopy still work as before. If ThinkJet driver 1 is available, confirm its SHIFT + PAPER still sends FF.
8. To restore original key handling, run `PRTKEYS 0`.

If the cutter does not move, do not repeatedly trigger it: record what the printer did (fed paper, ignored command, error, jam), verify your exact IFD501 board/firmware and check for a cutter enable/function setting.

## References
* Seiko CAPD245/345 product data: https://www.sii.co.jp/sps/eg/product/lowvoltage/capd245.html
* Seiko RP-E10 command manual (similar Seiko command language): https://seiko.manymanuals.com/print-scan/BX-900/specifications-17476/156
