import 'dart:io' show Platform;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

  enum TtsState { playing, stopped, paused, continued }
  class Tts extends FlutterTts {
    String? language;
    String? engine;
    double volume = 0.5;
    double pitch = 1.0;
    double rate = 0.5;
    bool isCurrentLanguageInstalled = false;  
    String? newVoiceText;
    int? inputLength;

    TtsState ttsState = TtsState.stopped;

    bool get isPlaying => ttsState == TtsState.playing;
    bool get isStopped => ttsState == TtsState.stopped;
    bool get isPaused => ttsState == TtsState.paused;
    bool get isContinued => ttsState == TtsState.continued;

    bool get isIOS => !kIsWeb && Platform.isIOS;
    bool get isAndroid => !kIsWeb && Platform.isAndroid;
    bool get isWindows => !kIsWeb && Platform.isWindows;
    bool get isWeb => kIsWeb;

    dynamic init() {

      _setAwaitOptions();

      if (isAndroid) {
        _getDefaultEngine();
        _getDefaultVoice();
      }
    }

    //Future<dynamic> _getLanguages() async => await getLanguages;

    //Future<dynamic> _getEngines() async => await getEngines;

    Future<void> _getDefaultEngine() async {
      var engine = await getDefaultEngine;
      if (engine != null) {
        print(engine);
      }
    }

    Future<void> _getDefaultVoice() async {
      var voice = await getDefaultVoice;
      if (voice != null) {
        print(voice);
      }
    }

    Future<void> run() async {
      await setVolume(volume);
      await setSpeechRate(rate);
      await setPitch(pitch);
      await setLanguage('es-ES');

      if (newVoiceText != null) {
        if (newVoiceText!.isNotEmpty) {
          await speak(newVoiceText!);
        }
      }
    }

    Future<void> _setAwaitOptions() async {
      await awaitSpeakCompletion(true);
    }
  }