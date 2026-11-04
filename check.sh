#!/bin/sh
# Docs check: every file and link that README.md, KNOWLEDGE.md and docs/MIDI.md name still exists.
# Local only: no network, no hardware, no keys.
cd "$(dirname "$0")" || exit 1
fail=0
bad() { echo "FAIL: $*"; fail=1; }

for f in README.md KNOWLEDGE.md LICENSE docs/MIDI.md; do
  [ -s "$f" ] || bad "missing or empty: $f"
done

# Relative markdown links (not http, not #anchor) must point at an existing file.
for f in README.md KNOWLEDGE.md docs/MIDI.md; do
  [ -f "$f" ] || continue
  dir=$(dirname "$f")
  grep -oE '\]\([^)#]+(#[^)]*)?\)' "$f" | sed -E 's/^\]\(//; s/\)$//; s/#.*//' | sort -u |
  while read -r t; do
    case "$t" in http*|mailto:*|"") continue ;; esac
    [ -e "$dir/$t" ] || echo "FAIL: $f links to missing $t"
  done
done > .check.out
# Backticked file paths named in KNOWLEDGE.md (README.md, docs/MIDI.md, LICENSE ...).
grep -oE '`[A-Za-z0-9_./-]+\.(md|sh|py|txt|png)`|`LICENSE`' KNOWLEDGE.md | tr -d '`' | sort -u |
while read -r t; do
  [ -e "$t" ] || echo "FAIL: KNOWLEDGE.md names missing $t"
done >> .check.out

# In-page anchors in docs/MIDI.md must match a heading (GitHub slug rules).
if [ -f docs/MIDI.md ]; then
  grep -E '^#{1,6} ' docs/MIDI.md | sed -E 's/^#+ //' | tr 'A-Z' 'a-z' |
    sed -E 's/[^a-z0-9 _-]//g; s/ /-/g' | sort -u > .check.slugs
  grep -oE '\]\(#[^)]+\)' docs/MIDI.md | sed -E 's/^\]\(#//; s/\)$//' | sort -u |
  while read -r a; do
    grep -qx -- "$a" .check.slugs || echo "FAIL: docs/MIDI.md anchor #$a has no heading"
  done >> .check.out
  rm -f .check.slugs
fi

if grep -q FAIL .check.out; then cat .check.out; fail=1; fi
rm -f .check.out
echo "SKIP: live GitHub remote links and the Python example in MIDI.md section 5 (need network, mido and hardware)"
[ "$fail" = 0 ] && echo "OK"
exit $fail
