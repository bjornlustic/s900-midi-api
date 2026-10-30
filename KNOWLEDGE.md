# s900-midi-api: knowledge

Consolidated 2026-10-13 from the repo contents and git history.

## What this is

Public, documentation-only repo (MIT) describing how a host controls an Akai S900 running SuperOS-900 5.0 over MIDI: channel messages and CCs, the stock Akai SysEx service ops (PEEK 0E, POKE 0C, CALL 0D), panel key codes, a RAM address table and safety rules. No firmware or tools ship here. Remote: github.com/bjornlustic/s900-midi-api (branch main).

## Current status

- One commit: `61eb640` (2026-09-24), pushed (main == origin/main). No activity since.
- The guide targets SuperOS-900 5.0. SuperOS-900 5.0.1 shipped 2026-10-01 (see ../KNOWLEDGE.md) and is not reflected here.

## Layout

- `README.md`: summary, frame format, safety paragraph.
- `docs/MIDI.md`: the full developer guide (setup, CC tables, frame, worked examples, timing, 40-line Python example, key codes, address table, keygroup and sample header offsets, recording over MIDI, safety).
- `LICENSE`: MIT.

## Build / run / test

None. Documentation only. The Python example in `docs/MIDI.md` section 5 needs `mido` and `python-rtmidi`.

## Key technical facts (all from `docs/MIDI.md`)

- Frame: `F0 47 <ch> <op> 40 00 00 <payload as (b & 7F, b >> 7) pairs> <XOR of the pairs> F7`. `<ch>` = basic channel minus one. Same frame as SuperOS-950; addresses differ per machine.
- PEEK reply comes back framed as op `0C`; a MIDI loop therefore turns replies into POKEs. Never request length 0 (sends 64 KB). Max 64 bytes per read, 16 data bytes per write (64-byte RX buffer at `0xB316..0xB355`, no overflow guard).
- Liveness probe: PEEK 14 bytes at `0x58AE` returns `00..0E` (service op table).
- Key cell `0x9562` (write a key code = one panel press), lamps `0x9571`, record trigger `0x957C` (`FF` fires an armed take), directory `0x9E4C`, slot records `0xA0CA + 0x46*slot`.
- Fixed CCs 72..86 and CC 1 (transwave window); assignable StartCC 13 (fine 45), EndCC 14, PortaCC 5, LoudCC 11, PitchCC 12, AAcapCC 16. Defaults reset at power-on, not saved.
- Keygroup `+0x17` filter envelope amount outside -50..+50 halts the machine (divide fault).
- Status tags in the guide: HW (verified on a real S900 over USB MIDI), EMU, CODE. CALL 0D is EMU only.

## Decisions and why

- Docs only, no firmware or tools, so the repo can be public without redistributing Akai or SuperOS code (`README.md`).

## Known issues

- Not updated for 5.0.1. SuperOS-900 5.0.1 added CC 89 (wheel mode, kg+0x12 bit 7, >= 64 selects the S950 wheel model) per `AkaiS900/superos900` commit `bceba4c`; `docs/MIDI.md` does not list it.

## Open questions for Bjorn

1. Are the RAM addresses in `docs/MIDI.md` section 7 (`0x58AE`, `0x9562`, `0x9571`, `0x957C`, `0x7CEC`, ...) unchanged in SuperOS-900 5.0.1? Not verified here; most are stock-OS RAM and probably unchanged, but no 5.0.1 check is recorded.
2. Should the guide be bumped to 5.0.1 and document CC 89?
