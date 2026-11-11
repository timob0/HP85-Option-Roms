# HP85 Option ROMs

This repository contains three independent extensions for the HP-85:

- **SIMON85** (ROM 0102, octal) adds graphics primitives, flood fill and pixel operations.
- **PRINTER85** (ROM 0241, octal) provides external-printer hardcopy, printer settings, and optional COPY/PAPER key handling.
- **CPM85** (LOAD BIN) connects HP BASIC to the native Z80 CP/M system, including disk-image management and bidirectional file transfers with the Teensy SD card. CPM85 requires matching Teensy and ESP32 firmware.

## Pocket guides

The editable, vintage-format LaTeX reference manuals are maintained with the source:

- [SIMON85 Pocket Guide](manuals/SIMON85-pocket-guide.tex)
- [PRINTER85 Pocket Guide](manuals/PRINTER85-pocket-guide.tex)
- [CPM85 Pocket Guide](manuals/CPM85-pocket-guide.tex)
- [Manual build and maintenance instructions](manuals/README.md)

Each guide starts with EBTKS installation/configuration, then covers every public BASIC command with an explanation and example. CI checks the guides' command coverage and source version strings; render PDFs locally using a LaTeX distribution.

## Setup

Place the SIMON85 and PRINTER85 option-ROM binaries in the Teensy SD card's `/roms85` directory, enable them in your existing EBTKS `CONFIG.TXT`, and reboot to load them. SIMON85 requires the HP Printer/Plotter ROM 0360 (octal). PRINTER85 requires a supported external printer connected by HP-IB.

For CPM85, load the binary under HP BASIC and run matching B2d or later firmware on both the ESP32 and Teensy; see [the CP/M guide](manuals/CPM85-pocket-guide.tex) and the [ESP32 emulator setup](https://github.com/timob0/EBTKS-Z80-Emulator/blob/main/GETTING_STARTED.md).
