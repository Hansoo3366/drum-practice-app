#include <jni.h>

#include <string>

#include "sequencer_engine.h"

namespace {

NativeSequencerEngine* engineFromHandle(const jlong handle) {
  return reinterpret_cast<NativeSequencerEngine*>(handle);
}

std::string jstringToString(JNIEnv* env, jstring value) {
  if (value == nullptr) {
    return {};
  }
  const char* raw = env->GetStringUTFChars(value, nullptr);
  if (raw == nullptr) {
    return {};
  }
  std::string result(raw);
  env->ReleaseStringUTFChars(value, raw);
  return result;
}

}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeCreateEngine(
    JNIEnv*,
    jobject,
    jint sampleRate) {
  auto* engine = new NativeSequencerEngine(sampleRate);
  return reinterpret_cast<jlong>(engine);
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeDestroyEngine(
    JNIEnv*,
    jobject,
    jlong handle) {
  delete engineFromHandle(handle);
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetSoundFontPaths(
    JNIEnv* env,
    jobject,
    jlong handle,
    jstring primaryPath,
    jstring metronomePath) {
  auto* engine = engineFromHandle(handle);
  if (engine == nullptr) {
    return;
  }
  engine->setSoundFontPaths(jstringToString(env, primaryPath),
                            jstringToString(env, metronomePath));
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetChannelProgram(
    JNIEnv*,
    jobject,
    jlong handle,
    jint channel,
    jint program,
    jfloat volume) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->setChannelProgram(channel, program, volume);
  }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeHasSoundFont(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  return engine != nullptr && engine->hasSoundFont() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetTempo(
    JNIEnv*,
    jobject,
    jlong handle,
    jint bpm) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->setTempo(bpm);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetTicksPerQuarter(
    JNIEnv*,
    jobject,
    jlong handle,
    jint ticksPerQuarter) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->setTicksPerQuarter(ticksPerQuarter);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeSetTimeSignature(
    JNIEnv*,
    jobject,
    jlong handle,
    jint numerator,
    jint denominator) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->setTimeSignature(numerator, denominator);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeClear(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->clear();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeAddNote(
    JNIEnv*,
    jobject,
    jlong handle,
    jint midiNote,
    jint startTick,
    jint durationTicks,
    jint velocity,
    jint channel,
    jboolean isTied) {
  auto* engine = engineFromHandle(handle);
  if (engine == nullptr) {
    return;
  }
  ScheduledNote note;
  note.midiNote = static_cast<int>(midiNote);
  note.startTick = static_cast<int>(startTick);
  note.durationTicks = static_cast<int>(durationTicks);
  note.velocity = static_cast<int>(velocity);
  note.channel = static_cast<int>(channel);
  note.isTied = static_cast<bool>(isTied);
  engine->addNote(note);
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeAddMetronome(
    JNIEnv*,
    jobject,
    jlong handle,
    jint totalTicks,
    jint countInBeats) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->addMetronome(totalTicks, countInBeats);
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeProcessTies(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->processTies();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeStart(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->start();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeStop(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine != nullptr) {
    engine->stop();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeRender(
    JNIEnv* env,
    jobject,
    jlong handle,
    jshortArray output,
    jint frames,
    jint channels) {
  auto* engine = engineFromHandle(handle);
  if (engine == nullptr || output == nullptr) {
    return;
  }

  const int expectedSamples = std::max(0, static_cast<int>(frames) * static_cast<int>(channels));
  if (expectedSamples == 0) {
    return;
  }

  const jsize length = env->GetArrayLength(output);
  if (length < expectedSamples) {
    return;
  }

  jshort* samples = env->GetShortArrayElements(output, nullptr);
  if (samples == nullptr) {
    return;
  }

  engine->render(reinterpret_cast<int16_t*>(samples), frames, channels);
  env->ReleaseShortArrayElements(output, samples, 0);
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_alessonqueiroz_flutternotemus_FlutterNotemusPlugin_nativeIsReady(
    JNIEnv*,
    jobject,
    jlong handle) {
  auto* engine = engineFromHandle(handle);
  if (engine == nullptr) {
    return JNI_FALSE;
  }
  return engine->isReady() ? JNI_TRUE : JNI_FALSE;
}
