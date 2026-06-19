import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whistle/services/app_settings.dart';
import 'package:whistle/services/dictation_controller.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String supportPath;
  FakePathProviderPlatform(this.supportPath);

  @override
  Future<String?> getApplicationSupportPath() async {
    return supportPath;
  }
}

class FakeAudioRecorder extends Fake implements AudioRecorder {
  bool hasPermissionResult = true;
  String? startedPath;
  bool isStarted = false;
  bool isStopped = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => hasPermissionResult;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startedPath = path;
    isStarted = true;
  }

  @override
  Future<String?> stop() async {
    isStopped = true;
    return startedPath;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String mockSupportPath;
  late Directory tempDir;
  late FakeAudioRecorder fakeRecorder;
  late DictationController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppSettings.kPlaySounds: false,
      AppSettings.kPauseMusic: false,
    });
    tempDir = Directory.systemTemp.createTempSync('whistle_test_support');
    mockSupportPath = tempDir.path;
    fakeRecorder = FakeAudioRecorder();
    controller = DictationController(recorder: fakeRecorder);

    // Mock Path Provider
    PathProviderPlatform.instance = FakePathProviderPlatform(mockSupportPath);

    // Mock Hotkey Manager
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('hotkey_manager'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    // Mock Status Bar Controller
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.normadit.whistle/StatusBarController'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    // Mock Media Center Channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.normadit.whistle/MediaCenter'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    // Mock Window Manager
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    // Mock Audioplayers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async {
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('hotkey_manager'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.normadit.whistle/StatusBarController'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.normadit.whistle/MediaCenter'),
      null,
    );
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('DictationController starts recording using Application Support directory', () async {
    expect(controller.status, DictationStatus.idle);

    // Trigger toggle (starts recording)
    await controller.toggle();

    expect(controller.status, DictationStatus.recording);
    expect(fakeRecorder.isStarted, isTrue);
    expect(fakeRecorder.startedPath, startsWith(mockSupportPath));
    expect(fakeRecorder.startedPath, endsWith('.wav'));
  });

  test('DictationController deletes the recorded file after transcription attempt', () async {
    // Start recording
    await controller.toggle();
    final path = fakeRecorder.startedPath;
    expect(path, isNotNull);

    // Create a dummy file on the filesystem to simulate the recorder output
    final file = File(path!);
    await file.create(recursive: true);
    expect(await file.exists(), isTrue);

    // Stop and transcribe (API key is not set, so it will fail and clean up)
    await controller.toggle();

    // Verify the controller finished and cleaned up the file
    expect(controller.status, DictationStatus.idle);
    expect(await file.exists(), isFalse);
  });
}
