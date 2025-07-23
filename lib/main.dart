import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whistle/hotkey_options.dart';
import 'package:whistle/sound_controller.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './keyboard_controller.dart';
import 'chinese_utils.dart';
import 'api_key_settings_screen.dart';
import 'shortcuts_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await hotKeyManager.unregisterAll();
  // await dotenv.load(fileName: ".env");

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager before running the app.
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whistle',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Whistle'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with WidgetsBindingObserver, WindowListener {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  List<String> _transcriptionHistory = []; // Store transcription history

  static const _statusBarChannel =
      MethodChannel('com.normadit.whistle/StatusBarController');

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this); // Add observer
    _setupHotkey();
    _setupMenuBarChannel();
  }

  void _setupHotkey() async {
    await hotKeyManager.unregisterAll();

    final prefs = await SharedPreferences.getInstance();

    // Get the stored hotkey option index with default to F5 (index 0)
    final hotkeyIndex = prefs.getInt('hotkey_option_index') ?? 0;

    // Get the selected hotkey option (with bounds checking)
    final selectedIndex = hotkeyIndex >= 0 && hotkeyIndex < hotkeyOptions.length
        ? hotkeyIndex
        : 0; // Default to F5

    final selectedOption = hotkeyOptions[selectedIndex];

    // Register the hotkey, noted hotKeyManager is quite buggy in my own testing
    try {
      await hotKeyManager.register(
        HotKey(
          key: selectedOption.key,
          modifiers: selectedOption.modifiers,
          scope: HotKeyScope.system,
        ),
        keyDownHandler: (_) => _toggleVoiceInput(),
      );
    } catch (e) {
      print('Error registering hotkey: $e');
    }
  }

  void _setupMenuBarChannel() {
    _statusBarChannel.setMethodCallHandler((call) async {
      if (call.method == 'toggleVoiceInput') {
        await _toggleVoiceInput();
      }
    });
  }

  Future<void> _toggleVoiceInput() async {
    if (!_isRecording) {
      print("start recording...");
      await _startRecording();
    } else {
      print("stop recording...");
      await _stopRecording();
      if (_recordingPath != null) {
        final transcription = await _transcribeAudio(_recordingPath!);
        await _insertTextAtCursor(postProcessTranscription(transcription));
      }
    }
    _updateStatusBarIcon();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final prefs = await SharedPreferences.getInstance();
        final playDictationSounds =
            prefs.getBool('playDictationSounds') ?? true;
        if (playDictationSounds) {
          SoundController.playStartSound();
        }

        // pause music playing
        final pauseMusicDuringDictation =
            prefs.getBool('pauseMusicDuringDictation') ?? true;

        if (pauseMusicDuringDictation) {
          try {
            await _statusBarChannel.invokeMethod('playPause');
            print('Media paused via StatusBarController');
          } catch (e) {
            print('Failed to pause media: $e');
          }
        }

        final tempDir = await getTemporaryDirectory();
        final randomSuffix =
            Random().nextInt(1000000).toString().padLeft(6, '0');
        _recordingPath = '${tempDir.path}/voice_input_$randomSuffix.wav';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: _recordingPath!,
        );
        setState(() => _isRecording = true);
        _updateStatusBarIcon();
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      final prefs = await SharedPreferences.getInstance();
      final playDictationSounds = prefs.getBool('playDictationSounds') ?? true;
      if (playDictationSounds) {
        SoundController.playStopSound();
      }

      // Resume other audio playback
      final pauseMusicDuringDictation =
          prefs.getBool('pauseMusicDuringDictation') ?? true;
      if (pauseMusicDuringDictation) {
        try {
          // Use StatusBarController's exposed API to resume media
          await _statusBarChannel.invokeMethod('playPause');
          print('Media resumed via StatusBarController');
        } catch (e) {
          print('Failed to resume media: $e');
        }
      }

      setState(() => _isRecording = false);
      _updateStatusBarIcon();
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<String> _transcribeAudio(String filePath) async {
    print('Transcribing audio input: $filePath');
    
    // Temporarily disabled for debugging - remove this line to enable transcription
    // return "Debugging... This is a dummy transcription for local dev.";

    // Load the OpenAI API key from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final openAiApiKey = prefs.getString('OPENAI_API_KEY');

    if (openAiApiKey == null || openAiApiKey.isEmpty) {
      // Make sure the window is visible and focused before showing the dialog
      await windowManager.show();
      await windowManager.focus();

      // Show a warning dialog if the API key is not set
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('API Key Missing'),
          content: Text(
            'The OpenAI API key is not set. Please configure it in the settings screen.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                ); // Navigate to the settings screen
              },
              child: Text('Go to Settings'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: Text('Cancel'),
            ),
          ],
        ),
      );
      throw Exception('OpenAI API key is not set.');
    }

    // return 'This is a dummy transcription for local dev.';

    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', url)
      ..fields['model'] = 'gpt-4o-transcribe'
      ..fields['prompt'] =
          'Ensure that grammar is corrected where necessary and punctuation is added to create a clean and polished transcript.'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    // Use the loaded API key
    request.headers['Authorization'] = 'Bearer $openAiApiKey';

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      return postProcessTranscription(jsonDecode(responseBody)['text']);
    } else {
      print(
          'Error transcribing audio: ${response.statusCode} ${response.reasonPhrase}');
      throw Exception('Failed to transcribe audio from $filePath');
    }
  }

  String postProcessTranscription(String transcription) {
    if (containsChineseCharacters(transcription)) {
      return transcription
          .replaceAll(',', '，')
          .replaceAll('.', '。')
          .replaceAll('?', '？')
          .replaceAll('!', '！')
          .replaceAll(';', '；')
          .replaceAll(':', '：');
    }
    return transcription;
  }

  Future<void> _insertTextAtCursor(String text) async {
    print('Inserting text at current cursor: $text');
    await MacOSKeyboardController.insertText(text);
    _transcriptionHistory.add(text); // Add transcription to history
    setState(() {}); // Update UI
  }

  void _updateStatusBarIcon() {
    _statusBarChannel.invokeMethod('updateStatusBarIcon', _isRecording);
  }

  Future<String> _getCurrentShortcut() async {
    final prefs = await SharedPreferences.getInstance();
    // Get the stored hotkey option index with default to 0
    final hotkeyIndex = prefs.getInt('hotkey_option_index') ?? 0;

    // Get the selected hotkey option (with bounds checking)
    final selectedIndex = hotkeyIndex >= 0 && hotkeyIndex < hotkeyOptions.length
        ? hotkeyIndex
        : 0; // Default to first option

    // Return the shortcutString from the selected option
    return hotkeyOptions[selectedIndex].shortcutString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.keyboard),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ShortcutsSettingsScreen(
                          onHotkeyChanged: _setupHotkey,
                        )),
              );
              // Reload hotkey setup when returning from settings
              _setupHotkey();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FutureBuilder<String>(
              future: _getCurrentShortcut(),
              builder: (context, snapshot) {
                final shortcut = snapshot.data ?? 'your configured shortcut';
                return Text(
                  _isRecording
                      ? 'Recording...'
                      : 'Press $shortcut to start voice input mode 🎙️',
                  style: Theme.of(context).textTheme.headlineMedium,
                );
              },
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _transcriptionHistory.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: MouseRegion(
                      onEnter: (_) {
                        // Optional: Change cursor to pointer on hover
                        SystemMouseCursors.click;
                      },
                      child: GestureDetector(
                        onTap: () => _copyToClipboard(_transcriptionHistory[
                            index]), // Reuse action handler
                        onDoubleTap: () => _copyToClipboard(
                            _transcriptionHistory[
                                index]), // Reuse action handler
                        child: SelectableText(_transcriptionHistory[
                            index]), // Wrap SelectableText
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _audioRecorder.dispose();
    hotKeyManager.unregisterAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // SystemNavigator.pop(); // Minimize the app to the dock
      await windowManager.hide();
    } else if (state == AppLifecycleState.resumed) {
      // Bring back the home page view when the dock icon is clicked
      await windowManager.show();
      await windowManager.focus();
    }
  }
}
