import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:whistle/hotkey_options.dart';

class ShortcutsSettingsScreen extends StatefulWidget {
  final Function? onHotkeyChanged;

  ShortcutsSettingsScreen({this.onHotkeyChanged});

  @override
  _ShortcutsSettingsScreenState createState() =>
      _ShortcutsSettingsScreenState();
}

class _ShortcutsSettingsScreenState extends State<ShortcutsSettingsScreen> {
  bool _enableDictation = false;
  int _selectedHotkeyIndex = 2; // Default to F5 (index 2)
  String _activationMode = 'Push to Talk';
  bool _playDictationSounds = true;
  bool _pauseMusicDuringDictation = true;
  bool _isCheckingShortcut = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableDictation = prefs.getBool('enableDictation') ?? false;
      _selectedHotkeyIndex = prefs.getInt('hotkey_option_index') ?? 2;
      _activationMode = prefs.getString('activationMode') ?? 'Push to Talk';
      _playDictationSounds = prefs.getBool('playDictationSounds') ?? true;
      _pauseMusicDuringDictation =
          prefs.getBool('pauseMusicDuringDictation') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableDictation', _enableDictation);
    await prefs.setInt('hotkey_option_index', _selectedHotkeyIndex);
    await prefs.setString('activationMode', _activationMode);
    await prefs.setBool('playDictationSounds', _playDictationSounds);
    await prefs.setBool(
        'pauseMusicDuringDictation', _pauseMusicDuringDictation);

    // Call the callback if it exists to update the hotkey immediately
    if (widget.onHotkeyChanged != null) {
      widget.onHotkeyChanged!();
    }
  }

  Future<bool> _isShortcutAvailable(int optionIndex) async {
    setState(() {
      _isCheckingShortcut = true;
    });

    try {
      bool isAvailable = true;
      try {
        final option = hotkeyOptions[optionIndex];
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
    final result = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Keyboard Shortcut'),
        children: List.generate(
            hotkeyOptions.length,
            (index) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, index),
                  child: Text(hotkeyOptions[index].name),
                )),
      ),
    );

    if (result != null && result != _selectedHotkeyIndex) {
      final isAvailable = await _isShortcutAvailable(result);

      if (!isAvailable) {
        // Show warning that the shortcut is in use
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Shortcut Conflict'),
            content: Text(
                'The shortcut "${hotkeyOptions[result].name}" appears to be in use by another application. Please select a different shortcut.'),
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
        setState(() {
          _selectedHotkeyIndex = result;
        });
        await _saveSettings();
      }
    }
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
              subtitle: Text(hotkeyOptions[_selectedHotkeyIndex].name),
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
