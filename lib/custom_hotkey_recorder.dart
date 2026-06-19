import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:whistle/hotkey_options.dart';

class CustomHotkeyRecorder extends StatefulWidget {
  final Function(HotkeyOption) onHotkeyRecorded;
  final Function() onCancel;

  const CustomHotkeyRecorder({
    super.key,
    required this.onHotkeyRecorded,
    required this.onCancel,
  });

  @override
  State<CustomHotkeyRecorder> createState() => _CustomHotkeyRecorderState();
}

class _CustomHotkeyRecorderState extends State<CustomHotkeyRecorder> {
  bool _isRecording = false;
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final Set<HotKeyModifier> _pressedModifiers = {};
  PhysicalKeyboardKey? _lastMainKey;
  String _displayText =
      'Click "Start Recording" and press your desired key combination';

  final Map<LogicalKeyboardKey, HotKeyModifier> _modifierMap = {
    LogicalKeyboardKey.metaLeft: HotKeyModifier.meta,
    LogicalKeyboardKey.metaRight: HotKeyModifier.meta,
    LogicalKeyboardKey.altLeft: HotKeyModifier.alt,
    LogicalKeyboardKey.altRight: HotKeyModifier.alt,
    LogicalKeyboardKey.shiftLeft: HotKeyModifier.shift,
    LogicalKeyboardKey.shiftRight: HotKeyModifier.shift,
    LogicalKeyboardKey.controlLeft: HotKeyModifier.control,
    LogicalKeyboardKey.controlRight: HotKeyModifier.control,
    LogicalKeyboardKey.fn: HotKeyModifier.fn,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Record Custom Hotkey'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: _isRecording ? Colors.red.shade50 : Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  Icon(
                    _isRecording ? Icons.radio_button_checked : Icons.keyboard,
                    size: 48,
                    color: _isRecording ? Colors.red : Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text(
                    _displayText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (_isRecording)
              Focus(
                autofocus: true,
                onKeyEvent: _handleKeyEvent,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      'Press your key combination...',
                      style: TextStyle(
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
            if (_pressedKeys.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Current combination: ${_getCurrentCombinationText()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text('Cancel'),
        ),
        if (!_isRecording)
          ElevatedButton(
            onPressed: _startRecording,
            child: Text('Start Recording'),
          ),
        if (_isRecording)
          ElevatedButton(
            onPressed: _stopRecording,
            child: Text('Stop Recording'),
          ),
        if (_lastMainKey != null && _pressedModifiers.isNotEmpty)
          ElevatedButton(
            onPressed: _saveHotkey,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('Save Hotkey'),
          ),
      ],
    );
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _pressedKeys.clear();
      _pressedModifiers.clear();
      _lastMainKey = null;
      _displayText = 'Recording... Press your key combination';
    });
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      if (_lastMainKey != null && _pressedModifiers.isNotEmpty) {
        _displayText = 'Hotkey recorded: ${_getCurrentCombinationText()}';
      } else {
        _displayText = 'Please record a valid key combination (modifier + key)';
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isRecording) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      final logicalKey = event.logicalKey;
      final physicalKey = event.physicalKey;

      setState(() {
        _pressedKeys.add(logicalKey);

        // Check if it's a modifier key
        if (_modifierMap.containsKey(logicalKey)) {
          _pressedModifiers.add(_modifierMap[logicalKey]!);
        } else {
          // It's a main key
          _lastMainKey = physicalKey;
        }

        _displayText = 'Current: ${_getCurrentCombinationText()}';
      });
    } else if (event is KeyUpEvent) {
      final logicalKey = event.logicalKey;

      setState(() {
        _pressedKeys.remove(logicalKey);

        // Remove modifier if released
        if (_modifierMap.containsKey(logicalKey)) {
          _pressedModifiers.remove(_modifierMap[logicalKey]!);
        }
      });
    }

    return KeyEventResult.handled;
  }

  String _getCurrentCombinationText() {
    if (_lastMainKey == null) return 'No key pressed';

    final modifierText = _pressedModifiers
        .map((m) => CustomHotkeyManager.formatModifierName(m))
        .join(' + ');

    final keyText = CustomHotkeyManager.formatKeyName(_lastMainKey!);

    if (modifierText.isEmpty) {
      return keyText;
    } else {
      return '$modifierText + $keyText';
    }
  }

  void _saveHotkey() {
    if (_lastMainKey == null) return;

    final combinationText = _getCurrentCombinationText();
    final hotkeyOption = HotkeyOption(
      name: 'Custom: $combinationText',
      key: _lastMainKey!,
      modifiers: _pressedModifiers.toList(),
      shortcutString: combinationText,
      isCustom: true,
    );

    widget.onHotkeyRecorded(hotkeyOption);
  }
}
