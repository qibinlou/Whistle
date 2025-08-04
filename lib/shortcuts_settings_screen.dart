import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:whistle/hotkey_options.dart';
import 'package:whistle/custom_hotkey_recorder.dart';

class ShortcutsSettingsScreen extends StatefulWidget {
  final Function? onHotkeyChanged;

  ShortcutsSettingsScreen({this.onHotkeyChanged});

  @override
  _ShortcutsSettingsScreenState createState() =>
      _ShortcutsSettingsScreenState();
}

class _ShortcutsSettingsScreenState extends State<ShortcutsSettingsScreen> {
  bool _enableDictation = false;
  String _activationMode = 'Push to Talk';
  bool _playDictationSounds = true;
  bool _pauseMusicDuringDictation = true;
  bool _isCheckingShortcut = false;
  HotkeyOption? _selectedHotkey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedHotkey = await CustomHotkeyManager.getSelectedHotkey();

    setState(() {
      _enableDictation = prefs.getBool('enableDictation') ?? false;
      _activationMode = prefs.getString('activationMode') ?? 'Push to Talk';
      _playDictationSounds = prefs.getBool('playDictationSounds') ?? true;
      _pauseMusicDuringDictation =
          prefs.getBool('pauseMusicDuringDictation') ?? true;
      _selectedHotkey = selectedHotkey;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableDictation', _enableDictation);
    await prefs.setString('activationMode', _activationMode);
    await prefs.setBool('playDictationSounds', _playDictationSounds);
    await prefs.setBool(
        'pauseMusicDuringDictation', _pauseMusicDuringDictation);

    // Call the callback if it exists to update the hotkey immediately
    if (widget.onHotkeyChanged != null) {
      widget.onHotkeyChanged!();
    }
  }

  Future<bool> _isShortcutAvailable(HotkeyOption option) async {
    setState(() {
      _isCheckingShortcut = true;
    });

    try {
      bool isAvailable = true;
      try {
        final hotKey = HotKey(
          key: option.key,
          modifiers: option.modifiers,
          scope: HotKeyScope.system,
        );

        await hotKeyManager.register(
          hotKey,
          keyDownHandler: (_) {},
        );

        // If we get here, the hotkey is available
        await hotKeyManager.unregister(hotKey);
      } catch (e) {
        print('Error checking hotkey: $e');
        isAvailable = false;
      }

      return isAvailable;
    } finally {
      setState(() {
        _isCheckingShortcut = false;
      });
    }
  }

  Future<void> _selectShortcut() async {
    // Get the currently saved option
    final savedOption = _selectedHotkey;
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Keyboard Shortcut'),
        children: [
          // Predefined hotkeys
          for (final option in hotkeyOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Text(option.name),
            ),
          // Show existing custom hotkey if one is saved
          if (savedOption != null && savedOption.isCustom)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, savedOption),
              child: Row(
                children: [
                  Icon(Icons.star, size: 20, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(child: Text(savedOption.name)),
                  IconButton(
                    icon: Icon(Icons.delete, size: 16, color: Colors.red),
                    onPressed: () {
                      Navigator.pop(context, 'deleteCustom');
                    },
                  ),
                ],
              ),
            ),
          // Record new custom hotkey
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'custom'),
            child: Row(
              children: [
                Icon(Icons.add, size: 20),
                SizedBox(width: 8),
                Text('Record Custom Hotkey'),
              ],
            ),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result == 'custom') {
      await _recordCustomHotkey();
    } else if (result == 'deleteCustom') {
      // Delete and reset
      await CustomHotkeyManager.saveSelectedHotkey(hotkeyOptions[2]);
      setState(() { _selectedHotkey = hotkeyOptions[2]; });
      await _saveSettings();
    } else if (result is HotkeyOption) {
      await _selectHotkey(result);
    }
  }

  Future<void> _selectHotkey(HotkeyOption option) async {
    // Check if this is the same as currently selected
    if (_selectedHotkey?.shortcutString == option.shortcutString) return;

    final isAvailable = await _isShortcutAvailable(option);

    if (!isAvailable) {
      // Show warning that the shortcut is in use
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Shortcut Conflict'),
          content: Text(
              'The shortcut "${option.name}" appears to be in use by another application. Please select a different shortcut.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Save the selected hotkey
      await CustomHotkeyManager.saveSelectedHotkey(option);
      setState(() {
        _selectedHotkey = option;
      });
      await _saveSettings();
    }
  }

  Future<void> _recordCustomHotkey() async {
    await showDialog(
      context: context,
      builder: (context) => CustomHotkeyRecorder(
        onHotkeyRecorded: (hotkeyOption) async {
          print('Recording custom hotkey: ${hotkeyOption.shortcutString}');

          // Save the custom hotkey as the selected hotkey
          await CustomHotkeyManager.saveSelectedHotkey(hotkeyOption);

          setState(() {
            _selectedHotkey = hotkeyOption;
          });

          await _saveSettings();
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Custom hotkey saved: ${hotkeyOption.shortcutString}')),
          );
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  String _getSelectedHotkeyName() {
    if (_selectedHotkey == null) {
      return 'Loading...';
    }
    return _selectedHotkey!.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dictation Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SwitchListTile(
              title: Text('Enable Dictation'),
              value: _enableDictation,
              onChanged: (value) {
                setState(() {
                  _enableDictation = value;
                });
                _saveSettings();
              },
            ),
            ListTile(
              title: Text('Dictation Keyboard Shortcut'),
              subtitle: Text(_getSelectedHotkeyName()),
              trailing: _isCheckingShortcut
                  ? CircularProgressIndicator(strokeWidth: 2)
                  : Icon(Icons.keyboard),
              onTap: _selectShortcut,
            ),
            // ListTile(
            //   title: Text('Activation Mode'),
            //   subtitle: Text(_activationMode),
            //   onTap: () async {
            //     final result = await showDialog<String>(
            //       context: context,
            //       builder: (context) => SimpleDialog(
            //         title: Text('Select Activation Mode'),
            //         children: [
            //           SimpleDialogOption(
            //             onPressed: () => Navigator.pop(context, 'Push to Talk'),
            //             child: Text('Push to Talk'),
            //           ),
            //           SimpleDialogOption(
            //             onPressed: () => Navigator.pop(context, 'Toggle'),
            //             child: Text('Toggle'),
            //           ),
            //         ],
            //       ),
            //     );
            //     if (result != null) {
            //       setState(() {
            //         _activationMode = result;
            //       });
            //       _saveSettings();
            //     }
            //   },
            // ),
            SwitchListTile(
              title: Text('Play Dictation Sounds'),
              value: _playDictationSounds,
              onChanged: (value) {
                setState(() {
                  _playDictationSounds = value;
                });
                _saveSettings();
              },
            ),
            SwitchListTile(
              title: Text('Pause Music During Dictation'),
              value: _pauseMusicDuringDictation,
              onChanged: (value) {
                setState(() {
                  _pauseMusicDuringDictation = value;
                });
                _saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}
