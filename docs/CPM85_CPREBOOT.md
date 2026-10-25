# CPM85 v0.04d — HP-85 `CPREBOOT` (ESP32-only hardware reset)

Status: **implemented on the existing Teensy B2c branch and HP CPM85
LOADBIN feature branch; full firmware/HP assembly builds and physical tests pending**. No ESP32 source or firmware change is required.

## Motivation

On an HP-85 with EBTKS, Wi-Fi sometimes remains associated with a distant
FRITZ!Repeater. CP/M and the HP BASIC EBTKS functions still run, but the
ESP32 Web UI/updater is unreachable and MODEM dials return NO CARRIER.
Cycling HP-85 power is undesirable; an ESP32-only restart is useful.

It does **not** guarantee selecting a different FRITZ! Mesh access point.
The new command simply cold-reboots the ESP32; Wi-Fi association policy
remains unchanged.

## Implementation

`CPRESET` is unchanged: it requests a **Z80-only reset** via the
Teensy-to-ESP32 UART control mailbox, preserving ESP32 Wi-Fi/web services.

New zero-argument statement:

```text
CPREBOOT
```

- HP-85 CPM85 v0.04d writes opcode **8** to existing EBTKS port 0177744
  (octal), and reads the reply via 0177745/0177746 as usual.
- The Teensy `Cpm85Drive` mailbox consumes opcode 8 **locally**. It
  never relays this request to the ESP32 and never requires Wi-Fi or
  functioning ESP32 UART.
- In the Teensy's **ordinary main loop**, the local service publishes
  `ESP32 REBOOT QUEUED - CP/M AND WIFI WILL RESTART`, state 2.
  No reset is performed in the HP-bus ISR.
- The Teensy waits for HP BASIC to consume the full reply, including
  its terminating NUL, then gives the CRT renderer a 1.5-second grace
  period before calling the **existing hardware-proven `ESP_Reset()`**.
  This sets BOOT high for normal firmware, pulses ESP32 EN low for
  10 ms, and releases it.
- If HP BASIC times out or sends opcode 0 to abort *before consuming
  the entire reply*, no hardware reset is armed. Extra commands during
  the grace interval do not schedule another reboot.
- HP-85 CPU, BASIC workspace, keyboard, Teensy, SD files and EBTKS
  hardware interfaces are **not themselves reset**. ESP32 RAM,
  Z80/CP/M state, Wi-Fi association, web and TFT terminal sessions ARE
  lost/restarted. Mounted media is reactivated on ESP32 startup.
- Do not issue `CPREBOOT` while CP/M is writing disk data, using MODEM,
  during an OTA update, or running a file copy. First exit CP/M keyboard
  capture with K8 and ensure the Z80 is idle at `A>`; save HP/CPM work.

## Development branches

- `timob0/HP85-Option-Roms`:
  **`feature/cpm85-esp-reboot`** (CPM85 v0.04d LOADBIN)
- `timob0/ebtks-alt-firmware`:
  **`feature/cpm-file-transfer-b2c`** (CPREBOOT merged from the
  temporary feature branch in [PR #5](https://github.com/timob0/ebtks-alt-firmware/pull/5),
  merge commit `3fb5e73e`). The temporary branch is now redundant but
  has not been deleted.
- `timob0/EBTKS-Z80-Emulator`: **unchanged**. Use the accepted
  ESP32 build already installed.
- All `main` branches are unchanged.

## Build / installation checklist

**Do not flash until the Teensy native test, Teensy firmware build and
HP CAPASM/CAPLIF validation pass.** Preserve current known-good firmware,
loadbin file and writable disk images.

Teensy:

```bash
git fetch origin
git switch feature/cpm-file-transfer-b2c
git pull --ff-only
pio run -e teensy41
```

The corresponding GitHub Actions workflow also compiles native
`test/cpm85_esp_reboot_native.cpp` and all previous B2c tests.

HP85-Option-Roms:

```bash
git fetch origin
git switch feature/cpm85-esp-reboot
git pull --ff-only
python3 tests/check_cpm85_keywords.py
mkdir -p build
./py311/bin/capasm src/cpm85.asm -b build/CPM85.bin -l build/CPM85.lst -r 2 -c
./py311/bin/caplif build/CPM85.bin -l build/CPM85.dat -f CPM85
```

The isolated CPREBOOT mailbox native harness compiled successfully with
`g++ -std=c++17 -Wall -Wextra -Werror -pedantic` during this review;
full PlatformIO and CAPASM/CAPLIF builds still require validation.

Use the established HP-85 LOADBIN transport to load the newly built
`CPM85.dat`, unloading the previous CPM85 if required. Verify
`CPVER` displays `CPM85 0.04d DISK CONTROL`.

First physical test:
1. Safely stop any CP/M file I/O; verify `A>`; detach HP keyboard via
   K8 so BASIC accepts commands.
2. At HP BASIC: `CPREBOOT`.
3. Confirm the HP display prints the queued-restart notice and returns
   to a new BASIC input line. Roughly 1.5 seconds after the notice is
   fully received, only ESP32 should reboot.
4. Confirm HP BASIC is still responsive; watch TFT and CP/M restart.
5. Recheck Web updater, CP/M DIR, HP CPDCAT, modem, and /api/system/health
   if Wi-Fi comes back.
6. Re-test `CPRESET` separately: it must *not* restart Wi-Fi/Web.

If the old Teensy firmware is accidentally retained, opcode 8 is
unsupported and the HP statement will time out safely; existing
`CPRESET` continues to work.

## Limits

Hardware EN reset is not the same as implementing smarter FRITZ! Mesh
access-point selection. The ESP32 may reconnect to the same distant
repeater. A preferred-BSSID or strongest-BSSID Wi-Fi policy is a separate
future ESP32 experiment, and should not be combined with this recovery
mechanism.
