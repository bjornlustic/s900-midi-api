# Akai S900 MIDI API

How to control an Akai S900 running **SuperOS-900 5.0** from your own
software over a MIDI cable: play it, move its parameters, press its panel
keys, read its display, and read and write its memory while it runs.

This repo is documentation only. It explains the protocol and the memory
map so you can build your own editor, librarian, controller mapping, test
rig or automation, in any language that can send SysEx. No firmware, ROM,
OS image or tool ships here.

**The guide: [docs/MIDI.md](docs/MIDI.md).**

## Requirements

- An Akai S900 running SuperOS-900 5.0, from <https://superos303.com>.
  Addresses in the guide are for 5.0; other versions differ.
- A MIDI interface cabled both ways: your OUT to the S900's MIDI IN, the
  S900's MIDI OUT to your IN. Replies come back on the S900's OUT.

## Two ways in

| you want to | use | guide section |
|---|---|---|
| play notes, move filter, envelopes, LFO, start and end points, transwave | MIDI notes and controllers | 2 |
| read the display, the lamps, the directory, any RAM | SysEx op `0E` (peek) | 3, 7 |
| write RAM | SysEx op `0C` (poke) | 3, 9 |
| press panel keys, change pages, type values | a poke of the key cell | 6 |
| arm and fire a recording from a computer | key presses plus the record trigger | 8 |

## The protocol in one line

```
F0 47 <ch> <op> 40 00 00 <payload as (b & 7F, b >> 7) pairs> <XOR of the pairs> F7
```

`<ch>` is the S900's basic MIDI channel minus one (`00` by default);
`<op>` is `0E` read, `0C` write, `0D` call. Everything else, including
worked examples you can check your framing against byte for byte, timing
rules, a forty-line Python example, key codes, addresses and what is safe
to write, is in [docs/MIDI.md](docs/MIDI.md).

## Safety in one paragraph

Reading is always safe. Write only value fields that a page or a
controller also writes, inside the range the page allows, and never write
structural pointers. Nothing reaches a floppy unless you save it on the
DISK pages, and a power cycle recovers the machine from any bad write.

## Licence

MIT, see [LICENSE](LICENSE). Akai and S900 are trademarks of their
respective owners, used only to identify compatibility. This project is
not affiliated with or endorsed by Akai.
