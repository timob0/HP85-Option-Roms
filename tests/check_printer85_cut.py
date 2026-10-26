#!/usr/bin/env python3
"""Source-level regression guard for PRINTER85 RC1c paper cutting."""
from pathlib import Path

source = Path("src/printer85_rom.asm").read_text()
assert 'HMSG    ASC "PRINTER85 0.03B RC1C"' in source
assert 'SIDESC  BYT 2' in source
assert 'DEF SIPAGE             ! SHIFT+PAPER: SII autocutter' in source

# SII uses only a feed-to-cutter full cut; ESC d 66 page advance is gone.
assert "SIICUT  BYT 35,126,101,0" in source
assert "SIIPG   BYT" not in source
sii_paper = source.split("SIPAGE  LDM R30,=3D,0", 1)[1].split("SITCLS", 1)[0]
assert "LDM R32,=SIIJ0" in sii_paper
assert "LDM R32,=SIICUT" in sii_paper
assert "LDM R32,=SIIPG" not in sii_paper

# Preserve physical key repeat/release, standard LF and ThinkJet FF.
assert "KHPREP  JSB =HCLINE" in source
assert "KHPPAG  JSB =HCPAGE" in source
assert "JSB =KHREL" in source.split("KHPPAG  JSB =HCPAGE", 1)[1].split("KHPCLS", 1)[0]
assert "SILINE  LDM R30,=1,0" in source
assert "TJPAGE  LDM R30,=1,0" in source
assert "HCLF    BYT 12" in source
assert "HCFF    BYT 14" in source
print("PASS: PRINTER85 RC1c SII cutter source-level invariants")
