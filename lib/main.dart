import 'package:flutter/material.dart';
import 'tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() async{
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

  @override
  initState() {
    super.initState();
    tts.init();
    _initSpeech();
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