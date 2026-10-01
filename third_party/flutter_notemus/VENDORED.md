# Vendored flutter_notemus 2.8.1

Copied from pub.dev (Apache-2.0, see `LICENSE`) without `example/`, `doc/`,
`test/` and the README screenshots. The app depends on this copy through
`dependency_overrides` in the root `pubspec.yaml`.

## Changes from upstream

- `android/src/main/cpp/sequencer_engine.h` (new): the sequencer class moved
  out of `native_audio_engine.cpp`, free of JNI. Notes are played with a
  SoundFont through TinySoundFont when `primarySoundFontPath` names a readable
  `.sf2`; otherwise the original waveforms are used. Each MIDI channel has a
  General MIDI program and a volume. Output goes through a soft limiter.
- `android/src/main/cpp/tsf.h` (new): TinySoundFont v0.9, MIT licence, see the
  header of the file.
- `native_audio_engine.cpp`: JNI entry points `nativeSetChannelProgram` and
  `nativeHasSoundFont`.
- `FlutterNotemusPlugin.kt`: method channel calls `nativeSequencerSetProgram`
  and `nativeHasSoundFont`.
- `lib/src/midi/method_channel_native_backend.dart`: `setChannelProgram` and
  `hasSoundFont`.
- `pubspec.yaml`: the `screenshots` section removed with the screenshots.

To update: copy the new upstream version over this directory and apply the
changes above again.
