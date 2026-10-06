# Product preferences

## Pending

- id: product-scope-20260922
  status: pending
  scope: product-architecture
  signal: user-statement
  confidence: explicit
  source_agent: codex
  recorded_at: 2026-09-22T16:49:00+09:00
  preference: Keep the drum app focused on PDF score viewing, metronome, and related drum practice tools. Keep the piano app shell focused on PDF viewing, MusicXML editing, score conversion, and related piano score workflows. Exclude tap tempo, tempo trainer, setlists, and Jam from the piano shell.

## 2026-10-06T12:27:10+09:00 — piano-menus-and-single-instrument-scores

```omd-meta
id: pref_muw4b0pm_c8565d0b
timestamp: 2026-10-06T12:27:10+09:00
scope: components.navigation
signal: user-correction
confidence: explicit
status: pending
source_agent: codex
source_context: "lib/features/digital_score/presentation/digital_score_screen.dart"
```

Remove the piano app's standalone playback accompaniment menu and automatic accompaniment; generate exactly one instrument's score per request and omit multi-instrument and combined-output choices.
