# Verify: s900-midi-api

Documentation-only repo. There is nothing to build or run, and no hardware,
live site, email or Stripe is involved. "Running the product" means checking
that the guide's frame rules and worked examples are true, offline, with
Python 3 standard library only (no `mido`, no MIDI port).

## Run it

From the repo root, run this with `python3 -I -` (paste it on stdin):

```python
import re
def frame(op, payload, ch=0):
    enc = []
    for b in payload:
        enc += [b & 0x7F, b >> 7]
    ck = 0
    for b in enc:
        ck ^= b
    return [0xF0, 0x47, ch, op, 0x40, 0, 0] + enc + [ck, 0xF7]

def hexs(m): return ' '.join('%02X' % b for b in m)

peek = frame(0x0E, [0x71, 0x95, 0x01, 0x00])
print(hexs(peek))
poke = frame(0x0C, [0x7C, 0x95, 0, 0, 0xFF])
print(hexs(poke))

doc = open('docs/MIDI.md').read().replace('  ', ' ')
for m in (peek,):
    want = hexs(m).replace('  ', ' ')
    print('peek example in doc:', want in re.sub(r' +', ' ', doc))
```

## What you should see

- First line: `F0 47 00 0E 40 00 00 71 00 15 01 01 00 00 00 64 F7`, the same bytes as
  "Worked example: read the section lamps" in `docs/MIDI.md` section 3
  (checksum `64`).
- Second line: `F0 47 00 0C 40 00 00 7C 00 15 01 00 00 00 00 7F 01 16 F7`, the
  POKE of `FF` to `0x957C` in section 3, `0C Write` (single spaces here, the
  guide pads groups with two).
- Last line: `peek example in doc: True`.

Any mismatch between the printed bytes and the guide is a docs bug: report
the line of `docs/MIDI.md` and the bytes you computed.

## Driving one feature and recording what you saw

Feature: the PEEK frame builder (section 3 and section 5).

1. Run the snippet above.
2. Record: the command, the printed lines, and whether each matched the guide.
3. Also check the facts the guide states: payload bytes are sent as
   `b & 0x7F` then `b >> 7`; checksum is the XOR of the pairs; the channel byte
   is the basic channel minus one. Change `ch` to 2 and confirm only byte 3 of
   the frame changes.

## Not verifiable here

Anything marked HW or EMU in the guide (replies from a real S900 or the
emulator) needs hardware. Do not claim them. The Python example in section 5
needs `mido`, `python-rtmidi` and a MIDI interface: do not run it.
