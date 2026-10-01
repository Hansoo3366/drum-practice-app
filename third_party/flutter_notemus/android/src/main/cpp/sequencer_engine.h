// The sequencer and synthesizer behind the native audio bridge, free of
// JNI so it can be built and tested on a desktop as well.
//
// Changed from flutter_notemus 2.8.1: notes are played with a SoundFont when
// one is given (see setSoundFontPaths and setChannelProgram); without one the
// plain waveforms of the original engine are used.
#ifndef FLUTTER_NOTEMUS_SEQUENCER_ENGINE_H_
#define FLUTTER_NOTEMUS_SEQUENCER_ENGINE_H_

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

// SoundFont synthesizer (TinySoundFont, MIT). This header is the one place
// that carries its implementation: include it from a single source file.
#define TSF_IMPLEMENTATION
#include "tsf.h"

namespace {

constexpr double kPi = 3.14159265358979323846;

struct ScheduledNote {
  int midiNote = 60;
  int startTick = 0;
  int durationTicks = 1;
  int velocity = 100;
  int channel = 0;
  bool isTied = false;
};

// A note the SoundFont synthesizer is holding.
struct SoundingNote {
  int endTick = 0;
  int channel = 0;
  int midiNote = 60;
};

struct MetronomeClick {
  int tick = 0;
  bool accent = false;
};

enum class Waveform {
  sine,
  triangle,
  saw,
  square,
};

struct ActiveVoice {
  Waveform waveform = Waveform::sine;
  double phase = 0.0;
  double phaseStep = 0.0;
  double amplitude = 0.0;
  double decay = 1.0;
  int endTick = 0;
  bool isClick = false;
  int remainingSamples = 0;
};

double midiToFrequency(const int midiNote) {
  return 440.0 * std::pow(2.0, (static_cast<double>(midiNote) - 69.0) / 12.0);
}

Waveform waveformForChannel(const int channel) {
  switch (channel & 3) {
    case 0:
      return Waveform::sine;
    case 1:
      return Waveform::triangle;
    case 2:
      return Waveform::saw;
    default:
      return Waveform::square;
  }
}

class NativeSequencerEngine {
 public:
  explicit NativeSequencerEngine(const int sampleRate)
      : sampleRate_(std::max(8000, sampleRate)) {
    recomputeTicksPerSampleLocked();
  }

  ~NativeSequencerEngine() {
    if (synth_ != nullptr) {
      tsf_close(synth_);
    }
  }

  NativeSequencerEngine(const NativeSequencerEngine&) = delete;
  NativeSequencerEngine& operator=(const NativeSequencerEngine&) = delete;

  bool isReady() const { return true; }

  // True when notes are played with the samples of a SoundFont; without one
  // (no path given, or the file could not be read) plain waveforms are used.
  bool hasSoundFont() {
    std::lock_guard<std::mutex> lock(mutex_);
    return synth_ != nullptr;
  }

  void setSoundFontPaths(std::string primaryPath, std::string metronomePath) {
    // Reading the file takes long: do it before taking the audio lock.
    tsf* loaded = nullptr;
    if (!primaryPath.empty()) {
      loaded = tsf_load_filename(primaryPath.c_str());
      if (loaded != nullptr) {
        tsf_set_output(loaded, TSF_MONO, sampleRate_, kSynthGainDb);
        tsf_set_max_voices(loaded, kSynthMaxVoices);
      }
    }
    tsf* previous = nullptr;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      previous = synth_;
      synth_ = loaded;
      sounding_.clear();
      applyProgramsLocked();
      primarySoundFontPath_ = std::move(primaryPath);
      metronomeSoundFontPath_ = std::move(metronomePath);
    }
    if (previous != nullptr) {
      tsf_close(previous);
    }
  }

  // The General MIDI program (0-127) notes on [channel] are played with,
  // and how loud the channel is (1.0 is full).
  void setChannelProgram(const int channel, const int program, const float volume) {
    std::lock_guard<std::mutex> lock(mutex_);
    const int clamped = std::clamp(channel, 0, 15);
    programs_[clamped] = std::clamp(program, 0, 127);
    volumes_[clamped] = std::clamp(volume, 0.0f, 1.0f);
    if (synth_ != nullptr) {
      tsf_channel_set_presetnumber(synth_, clamped, programs_[clamped], 0);
      tsf_channel_set_volume(synth_, clamped, volumes_[clamped]);
    }
  }

  void setTempo(const int bpm) {
    std::lock_guard<std::mutex> lock(mutex_);
    tempoBpm_ = std::clamp(bpm, 20, 400);
    recomputeTicksPerSampleLocked();
  }

  void setTicksPerQuarter(const int ticksPerQuarter) {
    std::lock_guard<std::mutex> lock(mutex_);
    ticksPerQuarter_ = std::clamp(ticksPerQuarter, 24, 9600);
    recomputeTicksPerSampleLocked();
  }

  void setTimeSignature(const int numerator, const int denominator) {
    std::lock_guard<std::mutex> lock(mutex_);
    timeSigNumerator_ = std::max(1, numerator);
    timeSigDenominator_ = std::max(1, denominator);
  }

  void clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    notes_.clear();
    clicks_.clear();
    activeVoices_.clear();
    silenceSynthLocked();
    nextNoteIndex_ = 0;
    nextClickIndex_ = 0;
    playbackStartTick_ = 0;
    sequenceTotalTicks_ = 0;
    currentTick_ = 0.0;
    playing_ = false;
  }

  void addNote(const ScheduledNote note) {
    std::lock_guard<std::mutex> lock(mutex_);
    ScheduledNote sanitized = note;
    sanitized.midiNote = std::clamp(sanitized.midiNote, 0, 127);
    sanitized.startTick = std::max(0, sanitized.startTick);
    sanitized.durationTicks = std::max(1, sanitized.durationTicks);
    sanitized.velocity = std::clamp(sanitized.velocity, 1, 127);
    sanitized.channel = std::clamp(sanitized.channel, 0, 15);
    notes_.push_back(sanitized);
  }

  void addMetronome(const int totalTicks, const int countInBeats) {
    std::lock_guard<std::mutex> lock(mutex_);
    const int beatTicks = std::max(1, (ticksPerQuarter_ * 4) / timeSigDenominator_);
    const int clampedCountIn = std::max(0, countInBeats);

    sequenceTotalTicks_ = std::max(0, totalTicks);
    playbackStartTick_ = -clampedCountIn * beatTicks;

    clicks_.clear();
    const int effectiveNumerator = std::max(1, timeSigNumerator_);
    int beatIndex = -clampedCountIn;

    for (int tick = playbackStartTick_; tick <= sequenceTotalTicks_;
         tick += beatTicks, ++beatIndex) {
      int measureBeat = beatIndex % effectiveNumerator;
      if (measureBeat < 0) {
        measureBeat += effectiveNumerator;
      }
      MetronomeClick click;
      click.tick = tick;
      click.accent = (measureBeat == 0);
      clicks_.push_back(click);
    }

    if (clicks_.empty()) {
      MetronomeClick click;
      click.tick = playbackStartTick_;
      click.accent = true;
      clicks_.push_back(click);
    }
  }

  void processTies() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (notes_.size() < 2) {
      return;
    }

    std::sort(notes_.begin(), notes_.end(),
              [](const ScheduledNote& lhs, const ScheduledNote& rhs) {
                if (lhs.channel != rhs.channel) {
                  return lhs.channel < rhs.channel;
                }
                if (lhs.midiNote != rhs.midiNote) {
                  return lhs.midiNote < rhs.midiNote;
                }
                if (lhs.startTick != rhs.startTick) {
                  return lhs.startTick < rhs.startTick;
                }
                return lhs.durationTicks < rhs.durationTicks;
              });

    std::vector<ScheduledNote> merged;
    merged.reserve(notes_.size());

    for (const ScheduledNote& note : notes_) {
      if (merged.empty()) {
        merged.push_back(note);
        continue;
      }

      ScheduledNote& previous = merged.back();
      const bool samePitch = previous.channel == note.channel && previous.midiNote == note.midiNote;
      const int previousEnd = previous.startTick + previous.durationTicks;
      const bool contiguous = note.startTick <= (previousEnd + 1);
      const bool tieRelated = previous.isTied || note.isTied;

      if (samePitch && contiguous && tieRelated) {
        const int noteEnd = note.startTick + note.durationTicks;
        previous.durationTicks = std::max(previousEnd, noteEnd) - previous.startTick;
        previous.velocity = std::max(previous.velocity, note.velocity);
        previous.isTied = true;
      } else {
        merged.push_back(note);
      }
    }

    notes_.swap(merged);
  }

  void start() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::sort(notes_.begin(), notes_.end(),
              [](const ScheduledNote& lhs, const ScheduledNote& rhs) {
                if (lhs.startTick != rhs.startTick) {
                  return lhs.startTick < rhs.startTick;
                }
                if (lhs.channel != rhs.channel) {
                  return lhs.channel < rhs.channel;
                }
                return lhs.midiNote < rhs.midiNote;
              });

    std::sort(clicks_.begin(), clicks_.end(),
              [](const MetronomeClick& lhs, const MetronomeClick& rhs) {
                return lhs.tick < rhs.tick;
              });

    activeVoices_.clear();
    silenceSynthLocked();
    nextNoteIndex_ = 0;
    nextClickIndex_ = 0;
    currentTick_ = static_cast<double>(playbackStartTick_);
    playing_ = true;
  }

  void stop() {
    std::lock_guard<std::mutex> lock(mutex_);
    playing_ = false;
    activeVoices_.clear();
    silenceSynthLocked();
  }

  void render(int16_t* output, const int frames, const int channels) {
    if (output == nullptr || frames <= 0 || channels <= 0) {
      return;
    }

    std::fill(output, output + (frames * channels), static_cast<int16_t>(0));

    std::lock_guard<std::mutex> lock(mutex_);
    if (!playing_) {
      return;
    }

    const int renderEndTick = renderEndTickLocked();
    const double ticksPerSample = ticksPerSample_;

    if (synth_ != nullptr) {
      renderWithSynthLocked(output, frames, channels, renderEndTick);
      return;
    }

    for (int frame = 0; frame < frames; ++frame) {
      while (nextNoteIndex_ < notes_.size() &&
             notes_[nextNoteIndex_].startTick <= currentTick_ + 1e-9) {
        spawnNoteVoiceLocked(notes_[nextNoteIndex_]);
        ++nextNoteIndex_;
      }

      while (nextClickIndex_ < clicks_.size() &&
             clicks_[nextClickIndex_].tick <= currentTick_ + 1e-9) {
        spawnClickVoiceLocked(clicks_[nextClickIndex_]);
        ++nextClickIndex_;
      }

      double mixed = 0.0;
      for (size_t index = 0; index < activeVoices_.size();) {
        ActiveVoice& voice = activeVoices_[index];
        const bool noteFinished = !voice.isClick && currentTick_ >= voice.endTick;
        const bool clickFinished = voice.isClick && voice.remainingSamples <= 0;
        const bool silent = voice.amplitude < 0.00015;

        if (noteFinished || clickFinished || silent) {
          activeVoices_.erase(activeVoices_.begin() + static_cast<long>(index));
          continue;
        }

        mixed += renderVoiceSampleLocked(voice);
        if (voice.isClick) {
          --voice.remainingSamples;
        }
        ++index;
      }

      mixed = std::clamp(mixed, -1.0, 1.0);
      const auto sample = static_cast<int16_t>(mixed * 32767.0);
      for (int channel = 0; channel < channels; ++channel) {
        output[(frame * channels) + channel] = sample;
      }

      currentTick_ += ticksPerSample;

      const bool sequenceFinished = currentTick_ > renderEndTick &&
                                    nextNoteIndex_ >= notes_.size() &&
                                    nextClickIndex_ >= clicks_.size() &&
                                    activeVoices_.empty();
      if (sequenceFinished) {
        playing_ = false;
        break;
      }
    }
  }

 private:
  // Notes are started and released at the start of each block: 64 frames
  // are 1.3 ms at 48 kHz.
  static constexpr int kSynthBlockFrames = 64;
  static constexpr int kSynthMaxVoices = 128;
  // Headroom for several parts playing full chords; what still goes over
  // is rounded off by softLimit.
  static constexpr float kSynthGainDb = -8.0f;

  // Leaves the signal alone up to 0.8 of full scale and bends what is above
  // towards 1.0, so loud passages saturate softly rather than clip.
  static double softLimit(const double sample) {
    constexpr double knee = 0.8;
    const double magnitude = std::fabs(sample);
    if (magnitude <= knee) {
      return sample;
    }
    const double bent = knee + (1.0 - knee) * std::tanh((magnitude - knee) / (1.0 - knee));
    return sample < 0.0 ? -bent : bent;
  }

  void applyProgramsLocked() {
    if (synth_ == nullptr) {
      return;
    }
    for (int channel = 0; channel < 16; ++channel) {
      tsf_channel_set_presetnumber(synth_, channel, programs_[channel], 0);
      tsf_channel_set_volume(synth_, channel, volumes_[channel]);
    }
  }

  // Stops every note at once. The reset also clears the channels' presets.
  void silenceSynthLocked() {
    sounding_.clear();
    if (synth_ != nullptr) {
      tsf_reset(synth_);
      applyProgramsLocked();
    }
  }

  void renderWithSynthLocked(int16_t* output,
                             const int frames,
                             const int channels,
                             const int renderEndTick) {
    // Let the last notes ring out for a moment after the last tick.
    const double tailTicks = 1.5 * static_cast<double>(sampleRate_) * ticksPerSample_;
    int frame = 0;
    while (frame < frames) {
      for (size_t index = 0; index < sounding_.size();) {
        if (currentTick_ >= sounding_[index].endTick) {
          tsf_channel_note_off(synth_, sounding_[index].channel, sounding_[index].midiNote);
          sounding_.erase(sounding_.begin() + static_cast<long>(index));
        } else {
          ++index;
        }
      }

      while (nextNoteIndex_ < notes_.size() &&
             notes_[nextNoteIndex_].startTick <= currentTick_ + 1e-9) {
        const ScheduledNote& note = notes_[nextNoteIndex_];
        // The same key struck again: release the note still sounding, so
        // its end does not cut the new one short.
        for (size_t index = 0; index < sounding_.size();) {
          if (sounding_[index].channel == note.channel &&
              sounding_[index].midiNote == note.midiNote) {
            tsf_channel_note_off(synth_, note.channel, note.midiNote);
            sounding_.erase(sounding_.begin() + static_cast<long>(index));
          } else {
            ++index;
          }
        }
        tsf_channel_note_on(synth_, note.channel, note.midiNote,
                            static_cast<float>(note.velocity) / 127.0f);
        SoundingNote sounding;
        sounding.endTick = note.startTick + note.durationTicks;
        sounding.channel = note.channel;
        sounding.midiNote = note.midiNote;
        sounding_.push_back(sounding);
        ++nextNoteIndex_;
      }

      while (nextClickIndex_ < clicks_.size() &&
             clicks_[nextClickIndex_].tick <= currentTick_ + 1e-9) {
        spawnClickVoiceLocked(clicks_[nextClickIndex_]);
        ++nextClickIndex_;
      }

      const int block = std::min(frames - frame, kSynthBlockFrames);
      tsf_render_float(synth_, synthBlock_, block, 0);
      for (int offset = 0; offset < block; ++offset) {
        double mixed = softLimit(static_cast<double>(synthBlock_[offset]));
        // Only metronome clicks are voices here.
        for (size_t index = 0; index < activeVoices_.size();) {
          ActiveVoice& voice = activeVoices_[index];
          if (voice.remainingSamples <= 0 || voice.amplitude < 0.00015) {
            activeVoices_.erase(activeVoices_.begin() + static_cast<long>(index));
            continue;
          }
          mixed += renderVoiceSampleLocked(voice);
          --voice.remainingSamples;
          ++index;
        }
        mixed = std::clamp(mixed, -1.0, 1.0);
        const auto sample = static_cast<int16_t>(mixed * 32767.0);
        for (int channel = 0; channel < channels; ++channel) {
          output[((frame + offset) * channels) + channel] = sample;
        }
      }
      frame += block;
      currentTick_ += static_cast<double>(block) * ticksPerSample_;

      const bool sequenceFinished = currentTick_ > renderEndTick + tailTicks &&
                                    nextNoteIndex_ >= notes_.size() &&
                                    nextClickIndex_ >= clicks_.size() &&
                                    activeVoices_.empty() &&
                                    sounding_.empty();
      if (sequenceFinished) {
        tsf_reset(synth_);
        applyProgramsLocked();
        playing_ = false;
        break;
      }
    }
  }

  void recomputeTicksPerSampleLocked() {
    ticksPerSample_ =
        (static_cast<double>(tempoBpm_) * static_cast<double>(ticksPerQuarter_)) /
        (60.0 * static_cast<double>(sampleRate_));
  }

  int maxNoteEndTickLocked() const {
    int endTick = 0;
    for (const auto& note : notes_) {
      endTick = std::max(endTick, note.startTick + note.durationTicks);
    }
    return endTick;
  }

  int renderEndTickLocked() const {
    const int beatTicks = std::max(1, (ticksPerQuarter_ * 4) / timeSigDenominator_);
    const int notesEnd = maxNoteEndTickLocked();
    const int clicksEnd = clicks_.empty() ? sequenceTotalTicks_ : clicks_.back().tick + beatTicks;
    return std::max(sequenceTotalTicks_, std::max(notesEnd, clicksEnd));
  }

  void spawnNoteVoiceLocked(const ScheduledNote& note) {
    ActiveVoice voice;
    voice.waveform = waveformForChannel(note.channel);
    voice.phase = 0.0;
    voice.phaseStep = midiToFrequency(note.midiNote) / static_cast<double>(sampleRate_);
    voice.amplitude = (static_cast<double>(note.velocity) / 127.0) * 0.22;
    voice.decay = 0.99998;
    voice.endTick = note.startTick + note.durationTicks;
    voice.isClick = false;
    voice.remainingSamples = 0;
    activeVoices_.push_back(voice);
  }

  void spawnClickVoiceLocked(const MetronomeClick& click) {
    ActiveVoice voice;
    voice.waveform = click.accent ? Waveform::square : Waveform::triangle;
    const double frequency = click.accent ? 1760.0 : 1320.0;
    voice.phase = 0.0;
    voice.phaseStep = frequency / static_cast<double>(sampleRate_);
    voice.amplitude = click.accent ? 0.65 : 0.45;
    voice.decay = 0.995;
    voice.endTick = click.tick + std::max(1, ticksPerQuarter_ / 8);
    voice.isClick = true;
    voice.remainingSamples = std::max(1, sampleRate_ / 35);
    activeVoices_.push_back(voice);
  }

  double renderVoiceSampleLocked(ActiveVoice& voice) const {
    double raw = 0.0;
    switch (voice.waveform) {
      case Waveform::sine:
        raw = std::sin(2.0 * kPi * voice.phase);
        break;
      case Waveform::triangle:
        raw = 1.0 - 4.0 * std::fabs(voice.phase - 0.5);
        break;
      case Waveform::saw:
        raw = (2.0 * voice.phase) - 1.0;
        break;
      case Waveform::square:
        raw = (voice.phase < 0.5) ? 1.0 : -1.0;
        break;
    }

    const double sample = raw * voice.amplitude;
    voice.phase += voice.phaseStep;
    if (voice.phase >= 1.0) {
      voice.phase -= std::floor(voice.phase);
    }
    voice.amplitude *= voice.decay;
    return sample;
  }

  mutable std::mutex mutex_;

  int sampleRate_ = 48000;
  int tempoBpm_ = 120;
  int ticksPerQuarter_ = 960;
  int timeSigNumerator_ = 4;
  int timeSigDenominator_ = 4;
  double ticksPerSample_ = 0.0;

  int sequenceTotalTicks_ = 0;
  int playbackStartTick_ = 0;
  double currentTick_ = 0.0;
  bool playing_ = false;

  std::string primarySoundFontPath_;
  std::string metronomeSoundFontPath_;

  std::vector<ScheduledNote> notes_;
  std::vector<MetronomeClick> clicks_;
  std::vector<ActiveVoice> activeVoices_;

  tsf* synth_ = nullptr;
  int programs_[16] = {0};
  float volumes_[16] = {1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f,
                        1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f};
  std::vector<SoundingNote> sounding_;
  float synthBlock_[kSynthBlockFrames] = {0.0f};

  size_t nextNoteIndex_ = 0;
  size_t nextClickIndex_ = 0;
};

}  // namespace

#endif  // FLUTTER_NOTEMUS_SEQUENCER_ENGINE_H_
