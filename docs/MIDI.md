# Controlling the Akai S900 over MIDI

This is the developer guide for controlling an Akai S900 running
SuperOS-900 5.0.1 from your own software. It covers everything a host can do
through the MIDI IN and MIDI OUT jacks: play the sampler, move its
parameters with controllers, press its panel keys, read its display, and
read and write its RAM.

The S900 is an open machine. Three SysEx messages built into its operating
system let any computer with a MIDI interface read any byte of the running
sampler's memory, write any byte, and start code at any address. They are
Akai's own service messages, present in the factory OS; superOS keeps all
three and keeps them working while a take is armed. Nothing is installed on
the sampler.

Status legend, used throughout: **HW** = used on a real S900 running 5.0 (HW and EMU tags were earned on 5.0; section 7 addresses were rechecked in the 5.0.1 build)
through a USB MIDI interface (an automated rig that armed and triggered 44
recordings over MIDI with no hang), **EMU** = proven against the 5.0
firmware running in an emulator, **CODE** = read from the firmware code.

Contents:

1. [Setup: cables and channel](#1-setup-cables-and-channel)
2. [Playing and parameters (channel messages)](#2-playing-and-parameters-channel-messages)
3. [The service ops: PEEK 0E, POKE 0C, CALL 0D](#3-the-service-ops-peek-0e-poke-0c-call-0d)
4. [Timing](#4-timing)
5. [A standalone Python example](#5-a-standalone-python-example)
6. [Pressing panel keys](#6-pressing-panel-keys)
7. [Useful addresses](#7-useful-addresses)
8. [Recording over MIDI](#8-recording-over-midi)
9. [Safety](#9-safety)

## 1. Setup: cables and channel

- Connect **both** directions: your interface's MIDI OUT to the S900's
  MIDI IN (everything you send), and the S900's MIDI OUT to your
  interface's MIDI IN (PEEK replies). A POKE works with the first cable
  alone, but then nothing can be confirmed.
- Do not build a MIDI loop (the S900's OUT merged or thru'd back into its
  IN). A PEEK reply is framed as op 0C (section 3), so a looped reply
  arrives as a POKE.
- **Channel.** The `<ch>` byte of every service op must equal the S900's
  basic MIDI channel minus one, as set on MIDI `*01`: channel 1 is `00`,
  channel 16 is `0F`. With omni on, any value is accepted. superOS ships
  omni off on channel 1, so the value is `00` unless you have changed it;
  loading settings from disk restores whatever they carry. If PEEK gets no
  answer, try each value 0 to 15.

## 2. Playing and parameters (channel messages)

Status: from the SuperOS-900 5.0 manual, except CC 89, which is CODE (read from the 5.0.1 firmware, not in the manual).

- **Notes:** note on and off with velocity, on the basic channel and the
  keygroups' channel offsets.
- **Scope:** a controller writes every keygroup on the receiving channel
  and takes effect immediately. Values above a parameter's range clamp to
  it. The panel pages show the new values the next time the page is drawn.

### Fixed controllers (always on, nothing to assign)

| CC | parameter | range |
|---|---|---|
| 1 | transwave window position (mod wheel), per channel | 0-127 |
| 72 | amplitude envelope release | 0-99 |
| 73 | amplitude envelope attack | 0-99 |
| 74 | filter cutoff, live on sounding notes | 0-99 |
| 75 | amplitude envelope decay | 0-99 |
| 76 | LFO rate | 0-99 |
| 77 | LFO depth | 0-99 |
| 78 | LFO delay | 0-99 |
| 79 | amplitude envelope sustain | 0-99 |
| 80 | filter envelope attack | 0-99 |
| 81 | filter envelope decay | 0-99 |
| 82 | filter envelope sustain | 0-99 |
| 83 | filter envelope release | 0-99 |
| 84 | transwave depth (EDIT PROGRAM `*13` EndLFO) | 0-99 |
| 85 | filter envelope amount | 0-100 = -50..+50 |
| 86 | LFO desync | 64 and up = ON |
| 89 | transwave wheel mode (per keygroup, saved with the program). CODE | 64 and up = S950 wheel model: the mod wheel is centred on the loop, scaled by the transwave depth, no LFO; below 64 = the 5.0 model (default) |

### Assignable controllers (UTILITY `*01` and `*02`)

Defaults below. They reset to these at every power-on and are not saved to
disk. Setting a number to 0 switches that feature off. CC 1, 7, 64 and 123
are handled by the stock OS first, so do not assign them.

| default CC | name | parameter |
|---|---|---|
| 13 (fine: 45) | StartCC | keygroup start point, 16,384 steps from the sample's own start to its own end; read at note on |
| 14 | EndCC | keygroup end point, same scale; on a looped sample it drags the loop through the sample |
| 5 | PortaCC | portamento time, per keygroup, 0 = off |
| 11 | LoudCC | keygroup loudness offset, 0-100 = -50..+50, live on sounding notes |
| 12 | PitchCC | keygroup transpose, 64 = centre |
| 16 | AAcapCC | anti-aliasing cap: 0-31 = 0, 32-63 = 1, 64-95 = 2, 96-127 = 3 |

StartCC is the coarse half of a standard 14-bit pair; its fine half is
StartCC + 32. Sending the coarse controller alone behaves like a plain
128-step controller, because a coarse message clears the held fine value.
A StartCC above 95 has no legal fine partner and the fine half switches
itself off.

UTILITY `*02` FiltKnob ON makes panel edits of Filter and Loudness transmit
as CC 74 and LoudCC on the basic channel, so knob moves record into a
sequencer.

## 3. The service ops: PEEK 0E, POKE 0C, CALL 0D

| op | name | what it does | status |
|---|---|---|---|
| 0E | Read (peek) | Sends back a range of memory on MIDI OUT. | HW |
| 0C | Write (poke) | Writes the message's bytes into memory from an address upward. No reply. | HW |
| 0D | Call | Jumps to an address. No reply. | EMU |

Addresses are 16-bit, in the operating system's own 64 KB of memory, where
every address in this guide lives. Sample audio lives above it and moves
with the S900's own MIDI sample dump (a pre-standard Akai format, not MIDI
SDS).

### The frame

```
F0 47 <ch> <op> 40 00 00 <payload, 7-bit encoded> <checksum> F7
```

| byte | meaning |
|---|---|
| `F0` | SysEx start |
| `47` | Akai |
| `<ch>` | basic channel minus one (section 1) |
| `<op>` | `0E` read, `0C` write, `0D` call |
| `40` | fixed; anything else and the message is ignored |
| `00` | stored by the parser and unused by these three ops; send `00` |
| `00` | fixed; the op's handler starts on the next byte |
| payload | every raw byte `b` is sent as two bytes: `b & 0x7F`, then `b >> 7` (0 or 1). Two-byte numbers are low byte first |
| checksum | XOR of every payload byte as sent, after the split into pairs |
| `F7` | SysEx end |

This is the same frame as superOS for the S950. What differs between the
two machines is the channel byte and every memory address, so a program
written for one does not work on the other unchanged.

### Worked example: read the section lamps

Read one byte at `0x9571`, the lamp of the section that is running
(section 7). The raw payload is the address and the length, low byte
first: `71 95 01 00`. Split into pairs it becomes
`71 00 15 01 01 00 00 00` (`95` is `15` with the top bit set). The XOR of
those eight bytes is `64`.

```
send   F0 47 00 0E 40 00 00  71 00 15 01  01 00 00 00  64 F7
                             addr 9571    length 1     cksum
reply  F0 47 00 0C 40 00 00  71 00 15 01  01 00 00 00  08 00  6C F7
                             addr 9571    length 1     08     cksum
```

The reply carries the data byte `08`: bit 3, the PLAY lamp.

### 0E Read (PEEK)

Payload: `addr_lo addr_hi len_lo len_hi`. The machine answers on MIDI OUT
with `F0 47 xx 0C 40 00 00`, then pairs holding the address (2 bytes) and
length (2 bytes) you asked for, then the memory, then a checksum and `F7`.

- The reply's op byte is `0C`, not `0E`, and its third byte is not your
  channel: it comes from another setting and is `00` by default. Match
  replies on `47`, `0C` and the echoed address.
- Read up to 64 bytes per message. A 64-byte reply is 145 bytes on the
  wire, about 46 ms at MIDI speed.
- **Never ask for length 0**: the machine sends all 65,536 bytes.
- A request with a wrong checksum gets no reply.
- **Liveness probe:** read 14 bytes at `0x58AE`. The answer is
  `00 01 02 03 04 05 06 07 08 09 0A 0C 0D 0E`, the table of service ops.
  An answer means the cable, the channel byte and the service all work.

### 0C Write (POKE)

Payload: `addr_lo addr_hi 00 00 data...`. The two zero bytes are read and
ignored; every byte after them is written from the address upward until
`F7`. There is no reply: read the bytes back to confirm.

- Bytes are stored as they arrive and the checksum is checked only at the
  end, so **a wrong checksum does not stop a write**. Build frames with
  code, not by hand.
- **Write at most 16 data bytes per message** and split longer writes. The
  whole message has to fit the machine's 64-byte MIDI receive buffer,
  which has no overflow guard; 16 leaves a margin.

Example, start an armed recording (section 8): write `FF` to `0x957C`.

```
F0 47 00 0C 40 00 00  7C 00 15 01  00 00 00 00  7F 01  16 F7
                      addr 957C    00 00        FF     cksum
```

### 0D Call

Payload: `addr_lo addr_hi`. The machine jumps to that address from inside
its MIDI service. There is no reply, and the code there runs with the
machine exactly as it is: interrupts, voices and the receive buffer all
live. It must already be in memory (written with 0C), be 8086 code written
for this OS, and leave everything it touches as it found it. A mistake
crashes the machine; a power cycle recovers it. The emulator proves the
jump reaches the address asked for; nothing has been run this way on
hardware. **Everything in this guide needs only read and write.**

## 4. Timing

- **One message at a time, sent whole.** The handler collects its bytes
  with a busy loop and a short timeout. Send each message as one SysEx in
  one burst, which is what any MIDI interface does with a single send; do
  not pace it out byte by byte or interleave another message.
- **Wait for replies.** After a read, wait for its reply before sending
  anything else. Allow 1 s and try up to three times.
- **Leave a gap after a write.** There is no reply; wait 50 ms, then read
  back.
- **Key presses need the page to catch up.** Allow about 0.3 s between keys
  and about 1 s after a section key.
- **The machine's own work comes first.** While it records a take,
  messages wait in the receive buffer and are answered afterwards. A
  message that gets no answer means: wait, then try again.

## 5. A standalone Python example

Python 3 with `mido` and `python-rtmidi`. This is the whole protocol in
about forty lines; port it to any language that can send SysEx.

```python
import time
import mido

PEEK, POKE = 0x0E, 0x0C

def frame(op, payload, ch=0):
    enc = []
    for b in payload:
        enc += [b & 0x7F, b >> 7]
    ck = 0
    for b in enc:
        ck ^= b
    return [0xF0, 0x47, ch, op, 0x40, 0x00, 0x00] + enc + [ck, 0xF7]

def send(out, msg):
    out.send(mido.Message('sysex', data=msg[1:-1]))   # mido adds F0/F7

def peek(out, inp, addr, n, ch=0):                    # n = 1..64
    for _ in inp.iter_pending():                      # drop stale input
        pass
    send(out, frame(PEEK, [addr & 0xFF, addr >> 8, n & 0xFF, n >> 8], ch))
    end = time.time() + 1.0
    while time.time() < end:
        for m in inp.iter_pending():
            d = list(m.data) if m.type == 'sysex' else []
            if d[:1] == [0x47] and d[2:3] == [0x0C]:
                body = d[6:-1]                        # pairs, no checksum
                v = [body[i] | body[i + 1] << 7
                     for i in range(0, len(body) - 1, 2)]
                if v[0] | v[1] << 8 == addr:
                    return bytes(v[4:4 + n])
        time.sleep(0.005)
    raise TimeoutError(f'no reply for {addr:#06x}')

def poke(out, addr, data, ch=0):
    data = bytes(data)
    for i in range(0, len(data), 16):                 # 16 bytes per message
        a = addr + i
        send(out, frame(POKE, [a & 0xFF, a >> 8, 0, 0] + list(data[i:i + 16]), ch))
        time.sleep(0.05)

print(mido.get_output_names())                        # pick your interface
out = mido.open_output('UX16 Port 1')                 # example names
inp = mido.open_input('UX16 Port 1')
print(peek(out, inp, 0x58AE, 14).hex(' '))            # 00 01 02 ... 0c 0d 0e
poke(out, 0x9562, [0x93])                             # press EDIT PROGRAM
time.sleep(1.0)
print(peek(out, inp, 0x9571, 1))                      # b'\x01': EDIT PROGRAM lamp
```

## 6. Pressing panel keys

Write a key code to the key cell `0x9562` and the OS takes it as a panel
press. One write is one press. The panel's own key scan can overwrite the
cell before the OS reads it, so a robust client confirms each press by
reading the display or the lamps (section 7) and writes again if nothing
changed. A key that changes nothing on screen (ON/+ at the top of its
range) cannot be confirmed this way.

| key | code | key | code |
|---|---|---|---|
| PLAY | `0x90` | PAGE up / down | `0x10` / `0x11` |
| REC | `0x91` | CURSOR left / right | `0x08` / `0x09` |
| EDIT SAMPLE | `0x92` | digits 0 to 9 | `0x30` to `0x39` |
| EDIT PROGRAM | `0x93` | ON/+ and OFF/- | `0x2B` and `0x2D` |
| DISK | `0x94` | ENT | `0x0D` |
| MIDI | `0x95` | page/field mode | `0x20` |
| UTILITY | `0x96` | letters on a name field | their ASCII codes |

Section keys, PAGE, cursor right, digits, ENT and names typed as ASCII are
HW; the rest come from the same key table. Digits typed into a number
field overwrite it from its first position; finish with ENT.

**Be careful with ENT.** On DISK `*01` it clears sample memory and loads
the disk. Read the display before you send it.

## 7. Useful addresses

SuperOS-900 5.0.1. Every address below was checked against the 5.0.1 build (`bceba4c`, `57b4330`) and is unchanged from 5.0. Other versions differ.

| address | what it is | status |
|---|---|---|
| `0x58AE`, 14 | service op table, reads `00` to `0A`, `0C`, `0D`, `0E` (no `0B`): the liveness probe | EMU |
| `0x9562`, 1 | key cell (section 6) | HW |
| `0x9571`, 1 | section lamps, one bit per running section: bit 0 EDIT PROGRAM, 1 EDIT SAMPLE, 2 REC, 3 PLAY, 4 MIDI, 5 UTILITY, 6 DISK. Read only | HW |
| `0x9590`, 2 | the current page's field record. Each page has its own value: read it once on each page you drive and use it to tell where you are | HW |
| `0x7CEC`, `0x7CE8`, `0x7CEA` | display text. Line 1 is 40 ASCII characters at `[0x7CEC] + [0x7CE8]`, line 2 at `[0x7CEC] + [0x7CEA]` (read the three 2-byte values first) | HW |
| `0x9E4C`, 68 | directory, one byte per slot: `P` program, `K` keygroup, `S` sample, `0` free | HW |
| `0xA0CA + 0x46 * slot` | the 70-byte record of that slot. A sample's record starts with its name | HW |
| `0x7CD6`, 2 | address of the current program's record. Its `+0x12` is the address of its first keygroup record | EMU |
| `0x7C7F`, 1 | basic MIDI channel minus one; bit 7 set = omni on. Change it on MIDI `*01`, not by writing | CODE |
| `0x957C`, 1 | record trigger. `FF` starts an armed take (section 8) | HW |
| `0x7CEE`, 4 | scratch the service ops collect their address into. Every message overwrites it | CODE |
| `0x7D52` upward | recording scratch: a take overwrites it. Keep nothing there | EMU |
| `0xB316` to `0xB355` | the 64-byte MIDI receive buffer. Never write | CODE |

### Keygroup record (a `K` slot), HW

| offset | field | may write? |
|---|---|---|
| `+0x00`, `+0x01` | high key, low key | yes |
| `+0x02` | velocity switch point | yes |
| `+0x03` to `+0x06` | amplitude envelope attack, decay, sustain, release | yes |
| `+0x14` | MIDI channel offset | yes |
| `+0x17` | filter envelope amount. **Keep it inside -50 to +50**: a value outside halts the machine with a divide fault | yes, in range |
| `+0x22` to `+0x25` | filter envelope attack, decay, sustain, release | yes |
| `+0x2C`, `+0x2D` | filter and loudness, soft sample | yes |
| `+0x42`, `+0x43` | filter and loudness, loud sample | yes |
| `+0x18` / `+0x2E` | soft / loud sample name, 10 characters | read only |
| `+0x28` / `+0x3E` | soft / loud sample header address | **never** |
| `+0x44` | address of the next keygroup of the program (EMU) | **never** |

### Sample header (the first `0x3C` bytes of an `S` slot), CODE unless marked

| offset | field |
|---|---|
| `+0x00` | name, 10 characters |
| `+0x14` | sample rate in Hz, 2 bytes: the rate the pitch is computed from at note on (HW) |
| `+0x16` | pitch |
| `+0x18` | loudness |
| `+0x1A` | replay mode, one character |
| `+0x1C`, `+0x20`, `+0x24` | end point, start point, loop length, 4 bytes each, in sample words. Read freely; change them from the panel, which also rebuilds what depends on them |
| `+0x28` | chain of the notes playing this sample. **Never write** |
| `+0x36` | address of the sample's audio. **Never write** |

To learn how a field is stored, read it, change it on the panel, and read
it again.

## 8. Recording over MIDI

Arm a take as usual on the REC pages. From then until the take starts, the
machine keeps answering MIDI, so a program can arm the S900, start the
sound it wants recorded, and fire the take at the right moment:

1. Drive the REC pages with key presses and arm the take.
2. Write `FF` to `0x957C`. The take starts, whatever START WITH mode is
   set.
3. Send nothing while the take runs. Messages that arrive then wait in the
   receive buffer and are answered after it ends.
4. When the take is over, read the display or the directory to confirm it,
   and fetch the audio with the sample dump.

**While a take is armed or running, send only 0E read, 0C write and the
trigger write.** Bulk program or sample messages and a sample dump stop the
recording's transfer or reset the MIDI port.

If an OOPS or SYSTEM ERROR message comes up, the machine stops servicing
MIDI until a section key is pressed on the panel. A program that stops
getting replies should say so and leave the next step to the person at the
machine.

## 9. Safety

**Reading is always safe. Writing is where care is needed.** The rule:
write value fields that a page or a controller also writes, inside the
range the page allows. Never write structural pointers. Before writing a
byte, ask which firmware routine normally writes it and what else that
routine updates. If it also rebuilds a list or re-links something, use the
real path instead: key presses, or a controller.

| safe to write | never write |
|---|---|
| the key cell `0x9562` and the record trigger `0x957C` | sample header addresses in a keygroup (`+0x28`, `+0x3E`) and the next-keygroup link (`+0x44`) |
| keygroup value fields (section 7), inside their page ranges | a sample's note chain (`+0x28`) and audio address (`+0x36`) |
| a sample's rate (`+0x14`) | the receive buffer `0xB316` to `0xB355`, its pointers `0x7CE2` / `0x7CE4`, and the operating system's code |

- **A power cycle recovers everything.** Everything these messages touch is
  memory. If a write hangs the machine, switch it off and on: superOS
  loads fresh from the boot disk.
- **Nothing is saved unless you save.** Nothing reaches a floppy unless you
  save it on the DISK pages, so your disks are safe from anything sent over
  MIDI until you choose to save.
- The stock Akai bulk program and sample messages (ops 07 to 0A) are not
  needed for anything here; on a test rig a program load hung the machine.
  Write keygroup fields and move audio with the sample dump.
