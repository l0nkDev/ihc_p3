import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:shake/shake.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "flutter_background example app",
    notificationText: "Background notification for keeping the example app running in the background",
    notificationImportance: AndroidNotificationImportance.normal,
    notificationIcon: AndroidResource(name: 'background_icon', defType: 'drawable'), // Default is ic_launcher from folder mipmap
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterBackground.initialize(androidConfig: androidConfig);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: MyHomePage(),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Tts tts = Tts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool speechEnabled = false;
  String _lastWords = 'Testeo';
  ShakeDetector? _detector;
  Timer? _timer;
  int _timerTotalSeconds = 0;

  @override
  initState() {
    super.initState();
    tts.init();
    _initSpeech();
    enableBackgroundExecution();
  } 

  void enableBackgroundExecution() async {
    bool success = await FlutterBackground.enableBackgroundExecution();
    print(success);
    _startDetector();
  }

  void _startDetector() {
    print('init detector');
    _detector?.stopListening();
    _detector = ShakeDetector.autoStart(
      onPhoneShake: onPhoneShake
    );
    count();
  }

  void count() async {
    _timer = Timer(const Duration(seconds: 1), () {
              _timerTotalSeconds += _timer!.tick;
              final seconds = _timerTotalSeconds;
              print('Background service alive ${seconds}s');
              count();
            });
  }

  void onPhoneShake(ShakeEvent event) async {
          print('shaken!');
          await LaunchApp.isAppInstalled(
            androidPackageName: 'com.example.ihc_p3'
          );
          tts.newVoiceText = 'Quieres realizar algun comando de voz? Di confirmar.';
          await tts.run();
          await _speechToText.listen(
            localeId: "es_ES",
            listenOptions: stt.SpeechListenOptions(partialResults: false, cancelOnError: false),
            onResult: (SpeechRecognitionResult result) {
              print('Resultado: ${result.recognizedWords}');
              if (result.recognizedWords.toLowerCase() == 'confirmar') { listenToOrder(); }
              else { tts.newVoiceText = 'Comando cancelado.'; tts.run(); }
            }
          );
  }

  void listenToOrder() async {
          tts.newVoiceText = 'Dicta tu comando.';
          await tts.run();
          await _speechToText.listen(
            localeId: "es_ES",
            listenOptions: stt.SpeechListenOptions(partialResults: false, cancelOnError: false),
            onResult: (SpeechRecognitionResult result) async {
              http.Response response = await http.post(Uri.parse("https://dialogflow.googleapis.com/v2/projects/newagent-tded/agent/sessions/62297da6-4429-cbe6-df0b-9d16f28a2dc8:detectIntent"), 
              body: '''
                    {
                      "queryInput": 
                      {
                        "text":
                        {
                          "text": "${result.recognizedWords}",
                          "languageCode": "es"
                        }
                      }
                    }
                    ''',
              headers: {HttpHeaders.authorizationHeader: "Bearer ", HttpHeaders.contentTypeHeader: 'application/json'});
              Map decoded = jsonDecode(utf8.decode(response.bodyBytes));
              if (decoded["queryResult"]["action"] != 'toggle') {
                tts.newVoiceText = 'DialogFlow no puede reconocer el comando: ${result.recognizedWords}';
                await tts.run();
              } else {
                tts.newVoiceText = 'DialogFlow ha reconocido el item: "${decoded["queryResult"]["parameters"]["item"]}" y la acción: "${decoded["queryResult"]["parameters"]["lights-status"]}"';
                await tts.run();
              }
            }
          );
  }

  void changedLanguageDropDownItem(String? selectedType) {
    setState(() {
      tts.language = selectedType;
      tts.setLanguage(tts.language!);
      if (tts.isAndroid) {
        tts
            .isLanguageInstalled(tts.language!)
            .then((value) => tts.isCurrentLanguageInstalled = (value as bool));
      }
    });
  }

  void _initSpeech() async {
    speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

    void _startListening() async {
    await _speechToText.listen(
      onResult: _onSpeechResult, 
      localeId: "es_ES",
      listenOptions: stt.SpeechListenOptions(partialResults: false, cancelOnError: false)
    );
    setState(() {});
  }

    void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

    void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
    tts.newVoiceText = _lastWords;
    changedLanguageDropDownItem("es_ES");
    tts.run();
  }

  @override
  void dispose() {
    super.dispose();
    _detector?.stopListening();
    tts.stop();
  }


  @override
  Widget build(BuildContext context) {
final theme = Theme.of(context);
final style = theme.textTheme.displaySmall!.copyWith(
  color: theme.colorScheme.onPrimary
);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: 
                  [
                    Card(
                      color: theme.colorScheme.primary,
                      child: 
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(_lastWords, style: style,),
                        )
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        onPressed:
            _speechToText.isNotListening ? _startListening : _stopListening,
        tooltip: 'Listen',
        child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
      )
    );
  }
}