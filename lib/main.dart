import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ihc_p3/taskhandler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'tts.dart';
import 'package:shake/shake.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

final jsonheaders = {HttpHeaders.contentTypeHeader: 'application/json'};

final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "flutter_background example app",
    notificationText: "Background notification for keeping the example app running in the background",
    notificationImportance: AndroidNotificationImportance.normal,
    notificationIcon: AndroidResource(name: 'background_icon', defType: 'drawable'),
);

const colores = 
{
  "rojo": [255, 0, 0],
  "azul": [0, 0, 255],
  "verde": [0, 255, 0],
  "blanco": [255, 255, 255],
  "magenta": [255, 0, 255],
  "celeste": [0, 255, 255],
  "amarillo": [255, 255, 0],
  "rosa": [255, 127, 127],
  "naranja": [255, 127, 0],
  "morado": [127, 0, 255],
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterBackground.initialize(androidConfig: androidConfig);
  FlutterForegroundTask.initCommunicationPort();
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
  String status = '';
  int attempts = 0;

  @override
  initState() {
    super.initState();
    tts.init();
    _initSpeech();
    enableBackgroundExecution();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
      _initService();
    });
  }
  
  @pragma('vm:entry-point')
  void startCallback() {
    FlutterForegroundTask.setTaskHandler(MyTaskHandler());
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map<String, dynamic>) {
      final dynamic timestampMillis = data["timestampMillis"];
      if (timestampMillis != null) {
        final DateTime timestamp =
            DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true);
        print('timestamp: ${timestamp.toString()}');
      }
    }
  }

  Future<void> _requestPermissions() async {
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      if (!await FlutterForegroundTask.canScheduleExactAlarms) {
        await FlutterForegroundTask.openAlarmsAndRemindersSettings();
      }
      await FlutterForegroundTask.openSystemAlertWindowSettings();
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Esperando sensor...',
        channelDescription:
            'Agita tu dispositivo con fuerza 3 veces para iniciar.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  void enableBackgroundExecution() async {
    await FlutterBackground.initialize();
    bool success = await FlutterBackground.enableBackgroundExecution();
    print(success);
    _startDetector();
  }

  void _startDetector() {
    print('init detector');
    _detector?.stopListening();
    _detector = ShakeDetector.autoStart(
      onPhoneShake: onPhoneShake,
      minimumShakeCount: 3
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
    FlutterForegroundTask.launchApp();
    doAfterShake();
  }

  void doAfterShake() async {
    status = 'confirmation';
    tts.newVoiceText = 'Quieres realizar algun comando de voz? Di confirmar.';
    await tts.run();
    await _speechToText.listen(
      localeId: "es_ES",
      listenOptions: stt.SpeechListenOptions(partialResults: false, cancelOnError: false),
      onResult: (SpeechRecognitionResult result) async {
        attempts = 0;
        setState(() {_lastWords = result.recognizedWords;});
        print('resultado');
        print(result.recognizedWords);
        if (result.recognizedWords.toLowerCase() == 'confirmar') { listenToOrder(); }
        else { tts.newVoiceText = 'Palabra incorrecta.'; await tts.run(); FlutterForegroundTask.minimizeApp(); }
      }
    );
  }

  void listenToOrder() async {
    status = 'order';
    tts.newVoiceText = 'Dicta tu comando.';
    await tts.run();
    await _speechToText.listen(
      localeId: "es_ES",
      listenOptions: stt.SpeechListenOptions(partialResults: false, cancelOnError: false),
      onResult: (SpeechRecognitionResult result) async {
        attempts = 0;
        setState(() {_lastWords = result.recognizedWords;});
        if (result.recognizedWords.toLowerCase() == 'cancelar') {
          tts.newVoiceText = 'Comando cancelado.';
          await tts.run();
          FlutterForegroundTask.minimizeApp();
          return;
        }
        http.Response response = await http.post(Uri.parse("http://192.168.137.1:5000/api/dialogflow"), body: '{"text": "${result.recognizedWords}"}', headers: jsonheaders);
        Map decoded = jsonDecode(utf8.decode(response.bodyBytes));
        switch (decoded["queryResult"]["action"]) {
          case 'toggle':
            switch (decoded["queryResult"]["parameters"]["lights-status"]) {
              case 'on':
                turnon();
                tts.newVoiceText = 'Se ha encendido la luz';
                break;
              case 'off':
                turnoff();
                tts.newVoiceText = 'Se ha apagado la luz';
                break;
            }
            await tts.run();
            break;
          case 'color':
            List<int>? col = colores[decoded["queryResult"]["parameters"]["color"]];
            if (col != null) {
              color(col[0], col[1], col[2]);
              tts.newVoiceText = 'Se ha cambiado el color a ${decoded["queryResult"]["parameters"]["color"]}';
            } else {
              tts.newVoiceText = 'No se conocen parametros para el color ${decoded["queryResult"]["parameters"]["color"]}.';
            }
            await tts.run();
            break;
          case 'temp':
            switch (decoded["queryResult"]["parameters"]["temp"]) { 
              case 'calido':
                colortemp(0);
                tts.newVoiceText = 'Se ha cambiado la temperatura a cálido.';
                break;
              case 'frio':
                colortemp(100);
                tts.newVoiceText = 'Se ha cambiado la temperatura a frio.';
                break;
            }
            await tts.run();
            break;
          case 'brightness':
            brightness(decoded["queryResult"]["parameters"]["number"].toInt());
            tts.newVoiceText = 'Se ha puesto el brillo al ${decoded["queryResult"]["parameters"]["number"].toInt()} por ciento';
            await tts.run();
            break;
          default:
            tts.newVoiceText = 'No se reconoció ningun comando.';
            await tts.run();
            listenToOrder();
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
    speechEnabled = await _speechToText.initialize(onError: onError);
    setState(() {});
  }

  void onError(SpeechRecognitionError val) async {
    if (val.errorMsg == 'error_no_match' || val.errorMsg == 'error_speech_timeout') {
      attempts++;
      if (attempts >= 3) {
        attempts = 0;
        tts.newVoiceText = 'Comando cancelado.';
        await tts.run();
        FlutterForegroundTask.minimizeApp();
        return;
      }
      tts.newVoiceText = 'No se entendió tu voz.';
      await tts.run();
      if (status == 'confirmation') {
        doAfterShake();
      } else {
        listenToOrder();
      }
    }
  }

  void turnon() async {
    await http.post(Uri.parse("http://192.168.137.1:5000/api/devices/ebffa8b35a6784724fmfrr/on"), body: '{}');
  }

  void turnoff() async {
    await http.post(Uri.parse("http://192.168.137.1:5000/api/devices/ebffa8b35a6784724fmfrr/off"), body: '{}');
  }

  void color(int r, int g, int b) async {
    await http.post(Uri.parse("http://192.168.137.1:5000/api/devices/ebffa8b35a6784724fmfrr/colour"), body: '{"r": $r, "g": $g, "b": $b}', headers: jsonheaders);
  }

  void colortemp(int temp) async {
    await http.post(Uri.parse("http://192.168.137.1:5000/api/devices/ebffa8b35a6784724fmfrr/colourtemp"), body: '{"temp": $temp}', headers: jsonheaders);
  }

  void brightness(int brightness) async {
    await http.post(Uri.parse("http://192.168.137.1:5000/api/devices/ebffa8b35a6784724fmfrr/brightness"), body: '{"brightness": $brightness}', headers: jsonheaders);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _detector?.stopListening();
    tts.stop();
    super.dispose();
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
        onPressed: () {doAfterShake();},
        tooltip: 'Listen',
        child: Icon(Icons.mic),
      )
    );
  }
}