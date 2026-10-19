#!/bin/bash
# CAPASM github: https://github.com/bug400/capasm
./py311/bin/capasm src/simon85.asm -b build/SIMON.bin -l build/SIMON.lst -r 2 -c
./py311/bin/caplif build/SIMON.bin -l build/SIMON.dat -f SIMON

./py311/bin/capasm src/printer85.asm -b build/PRINTER.bin -l build/PRINTER.lst -r 2 -c
./py311/bin/caplif build/PRINTER.bin -l build/PRINTER.dat -f PRINTER

# Make the option roms
./py311/bin/capasm src/printer85_rom.asm -b build/ROM241.bin -l build/ROM241.lst -r 2 -c -g 85
./py311/bin/caprom build/ROM241.bin -r build/ROM241.rom -s 8

./py311/bin/capasm src/simon85_rom.asm -b build/ROM102.bin -l build/ROM102.lst -r 2 -c -g 85
./py311/bin/caprom build/ROM102.bin -r build/ROM102.rom -s 8

# CPM85 keyboard-only LOADBIN experiment (no Teensy/ESP32 changes).
./py311/bin/capasm src/cpm85.asm -b build/CPM85.bin -l build/CPM85.lst -r 2 -c
./py311/bin/caplif build/CPM85.bin -l build/CPM85.dat -f CPM85
