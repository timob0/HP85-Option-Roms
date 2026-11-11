# CPM85 v0.04d — HP-85 `CPREBOOT` (ESP32-only hardware reset)

Status (2026-10-26): **CPREBOOT physically accepted on the HP-85.** User verified `CPVER` reports `0.04d` and `CPREBOOT` restarts the ESP32 as intended. The matching Teensy change is already merged into existing `feature/cpm-file-transfer-b2c` by PR #5. No ESP32 firmware modification is required. `CPRESET` regression and B2c file-transfer acceptance are separate outstanding checks; none of the three `main` branches has been changed.

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

The HP-85 hardware test has now passed for `CPREBOOT`. The following are
repeatable build/recovery instructions, not a request to reinstall the
already tested code. Preserve current known-good firmware, LOADBIN and
writable disk images.

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
the user's CAPASM source error (`LDB R22,=8`, illegal bare-octal 8) was
corrected to `=10`, and the user subsequently reported the working v0.04d
LOADBIN and `CPREBOOT` on physical hardware. No independent full CI result
has been verified here.

Use the established HP-85 LOADBIN transport to load the newly built
`CPM85.dat`, unloading the previous CPM85 if required. Verify
`CPVER` displays `CPM85 0.04d DISK CONTROL`.

Previously completed physical test (repeat only if needed):
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

**Confirmed by user:** `CPVER` returned `0.04d` and `CPREBOOT` worked
as expected. The initial `0.05c` reading came from an old SD copy of
`CPM85.DAT`; `deploy.sh` now also copies `build/CPM85.dat` to the SD root.
`CPRESET` preserving Wi-Fi still awaits an explicit regression report.

If the old Teensy firmware is accidentally retained, opcode 8 is
unsupported and the HP statement will time out safely; existing
`CPRESET` continues to work.

## Limits

Hardware EN reset is not the same as implementing smarter FRITZ! Mesh
access-point selection. The ESP32 may reconnect to the same distant
repeater. A preferred-BSSID or strongest-BSSID Wi-Fi policy is a separate
future ESP32 experiment, and should not be combined with this recovery
mechanism.
