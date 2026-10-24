#!/usr/bin/env python3
"""Guard the first, deliberately isolated HP-85 foreground console prototype.

This tests source consistency only. Real keyboard dispatch, page redraw,
KBDBUFFER cleanup, and timing must be accepted on the physical HP-85.
"""
from pathlib import Path
import re

p = Path(__file__).with_name("CPMCONSOLE.bas")
src = p.read_text()
lines = src.splitlines()
numbered = [re.fullmatch(r"(\d+)\s+(.+)", x) for x in lines]
assert all(numbered), "Every HP BASIC statement needs a line number"
numbers = [int(m.group(1)) for m in numbered]
assert sorted(set(numbers)) == numbers, "Line numbers must be strictly increasing"
index = {int(m.group(1)): m.group(2) for m in numbered}

for line, statement in index.items():
    for target in re.findall(r"\b(?:GOTO|GOSUB|THEN)\s+(\d+)(?:\s|$)", statement):
        assert int(target) in index, (line, statement, target)

# 8-bit code values were verified by PRINTER85, where K1..K8 are 0200..0207.
for k in range(128, 132):
    assert f"K={k}" in src
assert "K=135" in src, "K8 exit must remain available in both modes"

assert "KBDBUFFER 1" in src and "KBDBUFFER 0" in src
assert index[400] == "KBDBUFFER 0"
assert index[420] == "END"
assert index[130] == "IF K=135 THEN 400"
assert index[140] == "IF K=131 THEN 300"
assert index[150] == "IF M=1 THEN 110"
assert "GOSUB 500" in src
assert "LST: NOT READY" in src
assert "KEYS ARE NOT FORWARDED" in src
# Future transport must be implemented only after physical console validation.
assert not re.search(r"\b(?:CPM\s*$|CPCTL|CPKEY|POKE|OUTPUT|PRINT\s+#)\b", src, re.M)

# No 32-column alpha row should wrap (unconditional PRINT of static text).
for line, statement in index.items():
    m = re.fullmatch(r'PRINT "([^"]*)"', statement)
    if m:
        assert len(m.group(1)) <= 30, (line, len(m.group(1)), m.group(1))

print("PASS: CPM85 foreground BASIC skeleton, modes, key routing guard, cleanup and 30-col CRT")
