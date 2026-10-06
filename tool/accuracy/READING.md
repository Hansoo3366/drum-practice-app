# Reading the original score lines (ground truth)

You are transcribing printed lead sheets (Korean worship songs) by eye, one staff system
per PNG, so that a machine conversion can be scored against your reading later. You will
not see the machine's output, and you must not run OCR or any recognition tool: look at
each image with the Read tool and write down what is printed. If something is too small,
crop and enlarge that part with Python/PIL into your own folder and Read the enlargement.

Images: `lines/<song>/pP-sNN.png` (page P, system NN, top to bottom). Read them in order.
Each image shows one staff, the chord symbols above it and the lyric lines below it. The
top or bottom edge may show a sliver of the neighbouring system: ignore it.

## What counts

Only what is PRINTED in black as part of the score. Ignore everything added by a player:
coloured handwriting or typed notes (blue/red/purple/green text such as "Intro-ABB",
"도돌이O", "B1", "tag", "2절 들어갈 때 간주 1마디"), highlighter strokes, circles, crosses,
red alternative chords written above the printed ones, watermarks, URLs, copyright lines.
Instrument cues in boxes ("P, HiHat only", "+ Synth, AG, EG", "D fill-in") are not chords
or lyrics: leave them out.

## Output

Write one file per song: `truth/<song>.json`, UTF-8, exactly this shape:

```json
{
  "song": "s02_weak",
  "systems": [
    {
      "file": "p1-s01.png",
      "key": "1b",
      "time": "4/4",
      "bars": [
        {
          "chords": ["F", "Gm7", "F/A", "Bb", "C/Bb"],
          "lyrics": [["나","의","약","함","은","나","의","자","랑","이","요"],
                     ["나","가","난","함","은","나","의","상","급","이","요"]],
          "onsets": 11,
          "signs": ["repeat-start"],
          "mark": "VERSE",
          "unsure": []
        }
      ]
    }
  ]
}
```

- `bars`: one entry per bar of the system, left to right. Bars are separated by barlines.
  A bar that holds only a pickup (anacrusis) still counts as a bar. Do not merge or skip
  bars, even empty ones.
- `key`: the key signature at the start of the system as a count: "3#", "2b", "0".
  `time`: the time signature only if one is printed in this system, else null.
- `chords`: the chord symbols printed above this bar, left to right, in plain ASCII as
  printed: sharp "#", flat "b", superscripts on the line ("Dmaj7", "F#m7", "Csus4",
  "D(sus4)", "F#7(b9)", "Bm7(b5)", "Cadd2", "Gdim", "C#o7" for a small circle). Keep
  slash chords as printed, including a bare bass such as "/D". Keep parentheses printed
  around a whole chord, e.g. "(D7)". "N.C." is written "N.C.". No chord: `[]`.
- `lyrics`: one list per printed lyric line under the staff (verse 1 first), each a list
  of the syllables that fall in this bar, one printed syllable per item, in order. Leave
  out extension dashes and lines ("-", "—", "_"), verse numbers ("1.", "2.") and
  punctuation. A syllable belongs to the bar of the note it is printed under. English
  words: one item per printed syllable/word chunk. A lyric line with nothing in this bar
  is `[]`; if the system has no lyrics at all, `"lyrics": []`.
- `onsets`: how many notes start in the bar: count each stem/notehead position once (the
  notes of a two-note chord struck together count as one), count a note tied from the
  previous note as its own onset, do not count rests or grace notes. Slash/rhythm
  notation counts the same way. A bar with only rests is 0.
- `signs`: any of "repeat-start", "repeat-end", "ending-1", "ending-2", "ending-3"
  (the bracket covers this bar; a bracket "1.2." gives both "ending-1","ending-2"),
  "segno", "coda", "to-coda", "ds" (any D.S. text), "dc" (any D.C. text), "fine",
  "double-bar" (thin double barline at the END of this bar), "final-bar". Else `[]`.
- `mark`: a printed rehearsal/section label at this bar (boxed or bold text such as
  "VERSE", "Chorus", "A", "B2", "Intro", "Pre-chorus"), as printed, else null.
- `unsure`: short notes on anything you could not read with confidence, e.g.
  "chord 2 could be Am7 or Am9", "verse 2 syllable 3 illegible". Do not guess silently:
  write your best reading in the field and say so here.

Accuracy matters far more than speed: this is the answer key. Korean lyric syllables are
small; enlarge when unsure. Count bars carefully; a system usually has 3 to 6.

When done, reply with only: the songs you wrote, the number of systems and bars per song,
and how many `unsure` notes you left. Do not paste the transcription into the reply.
