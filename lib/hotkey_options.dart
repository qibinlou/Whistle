import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

// Define a class for type safety
class HotkeyOption {
  final String name;
  final PhysicalKeyboardKey key;
  final List<HotKeyModifier> modifiers;
  final String shortcutString;

  const HotkeyOption({
    required this.name,
    required this.key,
    required this.modifiers,
    required this.shortcutString,
  });
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
