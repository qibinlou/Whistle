import 'package:flutter/services.dart';

class MacOSKeyboardController {
  static const platform =
      MethodChannel('com.normadit.whistle/keyboardController');

  static Future<void> insertText(String text) async {
    try {
      await platform.invokeMethod('insertText', {"text": text});
    } on PlatformException catch (e) {
      print("Failed to insert text: '${e.message}'.");
    }
  }
}
