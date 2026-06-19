import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define a class for type safety
class HotkeyOption {
  final String name;
  final PhysicalKeyboardKey key;
  final List<HotKeyModifier> modifiers;
  final String shortcutString;
  final bool isCustom;

  const HotkeyOption({
    required this.name,
    required this.key,
    required this.modifiers,
    required this.shortcutString,
    this.isCustom = false,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'keyValue': key.usbHidUsage, // persist HID usage code
      'modifiers': modifiers.map((m) => m.name).toList(),
      'shortcutString': shortcutString,
      'isCustom': isCustom,
    };
  }

  // Create from JSON
  static HotkeyOption? fromJson(Map<String, dynamic> json) {
    try {
      PhysicalKeyboardKey? key;
      // New format: use HID usage code
      if (json.containsKey('keyValue')) {
        final keyValue = json['keyValue'] as int;
        key = PhysicalKeyboardKey(keyValue);
      } else if (json.containsKey('keyLabel')) {
        // Legacy format: keyLabel
        final keyLabel = json['keyLabel'] as String;
        key = _getPhysicalKeyFromLabel(keyLabel);
      }
      if (key == null) return null;
      final modifierNames = (json['modifiers'] as List).cast<String>();
      final modifiers = modifierNames
          .map((name) => _getModifierFromName(name))
          .where((modifier) => modifier != null)
          .cast<HotKeyModifier>()
          .toList();
      return HotkeyOption(
        name: json['name'] as String,
        key: key,
        modifiers: modifiers,
        shortcutString: json['shortcutString'] as String,
        isCustom: json['isCustom'] as bool? ?? true,
      );
    } catch (e) {
      debugPrint('Error parsing hotkey from JSON: $e');
      return null;
    }
  }

  static PhysicalKeyboardKey? _getPhysicalKeyFromLabel(String label) {
    // Map common key labels to PhysicalKeyboardKey
    final keyMap = {
      'f1': PhysicalKeyboardKey.f1,
      'f2': PhysicalKeyboardKey.f2,
      'f3': PhysicalKeyboardKey.f3,
      'f4': PhysicalKeyboardKey.f4,
      'f5': PhysicalKeyboardKey.f5,
      'f6': PhysicalKeyboardKey.f6,
      'f7': PhysicalKeyboardKey.f7,
      'f8': PhysicalKeyboardKey.f8,
      'f9': PhysicalKeyboardKey.f9,
      'f10': PhysicalKeyboardKey.f10,
      'f11': PhysicalKeyboardKey.f11,
      'f12': PhysicalKeyboardKey.f12,
      'keyA': PhysicalKeyboardKey.keyA,
      'keyB': PhysicalKeyboardKey.keyB,
      'keyC': PhysicalKeyboardKey.keyC,
      'keyD': PhysicalKeyboardKey.keyD,
      'keyE': PhysicalKeyboardKey.keyE,
      'keyF': PhysicalKeyboardKey.keyF,
      'keyG': PhysicalKeyboardKey.keyG,
      'keyH': PhysicalKeyboardKey.keyH,
      'keyI': PhysicalKeyboardKey.keyI,
      'keyJ': PhysicalKeyboardKey.keyJ,
      'keyK': PhysicalKeyboardKey.keyK,
      'keyL': PhysicalKeyboardKey.keyL,
      'keyM': PhysicalKeyboardKey.keyM,
      'keyN': PhysicalKeyboardKey.keyN,
      'keyO': PhysicalKeyboardKey.keyO,
      'keyP': PhysicalKeyboardKey.keyP,
      'keyQ': PhysicalKeyboardKey.keyQ,
      'keyR': PhysicalKeyboardKey.keyR,
      'keyS': PhysicalKeyboardKey.keyS,
      'keyT': PhysicalKeyboardKey.keyT,
      'keyU': PhysicalKeyboardKey.keyU,
      'keyV': PhysicalKeyboardKey.keyV,
      'keyW': PhysicalKeyboardKey.keyW,
      'keyX': PhysicalKeyboardKey.keyX,
      'keyY': PhysicalKeyboardKey.keyY,
      'keyZ': PhysicalKeyboardKey.keyZ,
      'digit1': PhysicalKeyboardKey.digit1,
      'digit2': PhysicalKeyboardKey.digit2,
      'digit3': PhysicalKeyboardKey.digit3,
      'digit4': PhysicalKeyboardKey.digit4,
      'digit5': PhysicalKeyboardKey.digit5,
      'digit6': PhysicalKeyboardKey.digit6,
      'digit7': PhysicalKeyboardKey.digit7,
      'digit8': PhysicalKeyboardKey.digit8,
      'digit9': PhysicalKeyboardKey.digit9,
      'digit0': PhysicalKeyboardKey.digit0,
      'space': PhysicalKeyboardKey.space,
      'enter': PhysicalKeyboardKey.enter,
      'tab': PhysicalKeyboardKey.tab,
      'escape': PhysicalKeyboardKey.escape,
      'backspace': PhysicalKeyboardKey.backspace,
    };
    return keyMap[label.toLowerCase()];
  }

  static HotKeyModifier? _getModifierFromName(String name) {
    switch (name.toLowerCase()) {
      case 'meta':
        return HotKeyModifier.meta;
      case 'alt':
        return HotKeyModifier.alt;
      case 'shift':
        return HotKeyModifier.shift;
      case 'control':
        return HotKeyModifier.control;
      case 'fn':
        return HotKeyModifier.fn;
      default:
        return null;
    }
  }
}

const List<HotkeyOption> hotkeyOptions = [
  HotkeyOption(
      name: 'F5',
      key: PhysicalKeyboardKey.f5,
      modifiers: <HotKeyModifier>[],
      shortcutString: 'F5'),
  HotkeyOption(
      name: 'Fn + F5',
      key: PhysicalKeyboardKey.f5,
      modifiers: <HotKeyModifier>[HotKeyModifier.fn],
      shortcutString: 'Fn + F5'),
  HotkeyOption(
      name: '⌘ (Command Key) + F5',
      key: PhysicalKeyboardKey.f5,
      modifiers: <HotKeyModifier>[HotKeyModifier.meta],
      shortcutString: '⌘ + F5'),
  // Alt + D
  HotkeyOption(
      name: '⌥ (Option Key) + D',
      key: PhysicalKeyboardKey.keyD,
      modifiers: <HotKeyModifier>[HotKeyModifier.alt],
      shortcutString: '⌥ + D'),
];

// Utility functions for hotkey management
class CustomHotkeyManager {
  static const String _selectedHotkeyKey = 'selected_hotkey';

  // Save the selected hotkey to SharedPreferences
  static Future<void> saveSelectedHotkey(HotkeyOption selectedHotkey) async {
    final prefs = await SharedPreferences.getInstance();
    final json = selectedHotkey.toJson();
    await prefs.setString(_selectedHotkeyKey, jsonEncode(json));
  }

  // Load the selected hotkey from SharedPreferences
  static Future<HotkeyOption> getSelectedHotkey() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_selectedHotkeyKey);
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final option = HotkeyOption.fromJson(json);
        if (option != null) {
          return option;
        }
      } catch (e) {
        debugPrint('Error loading selected hotkey: $e');
      }
    }
    // Return default hotkey if none is saved or loading fails
    return hotkeyOptions[2]; // Default to '⌘ (Command Key) + F5'
  }

  // Format modifier names for display
  static String formatModifierName(HotKeyModifier modifier) {
    switch (modifier) {
      case HotKeyModifier.meta:
        return '⌘';
      case HotKeyModifier.alt:
        return '⌥';
      case HotKeyModifier.shift:
        return '⇧';
      case HotKeyModifier.control:
        return '⌃';
      case HotKeyModifier.fn:
        return 'Fn';
      default:
        return modifier.name;
    }
  }

  // Format key name for display
  static String formatKeyName(PhysicalKeyboardKey key) {
    final keyLabel = key.debugName ?? '';
    if (keyLabel.startsWith('key')) {
      return keyLabel.substring(3).toUpperCase();
    }
    if (keyLabel.startsWith('digit')) {
      return keyLabel.substring(5);
    }
    if (keyLabel.startsWith('f') && keyLabel.length <= 3) {
      return keyLabel.toUpperCase();
    }
    switch (keyLabel.toLowerCase()) {
      case 'space':
        return 'Space';
      case 'enter':
        return 'Enter';
      case 'tab':
        return 'Tab';
      case 'escape':
        return 'Esc';
      case 'backspace':
        return 'Backspace';
      default:
        return keyLabel;
    }
  }
}
