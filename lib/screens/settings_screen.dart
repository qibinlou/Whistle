import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../hotkey_options.dart';
import '../providers/provider_registry.dart';
import '../providers/transcription_provider.dart';
import '../services/app_settings.dart';
import '../services/dictation_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';

/// Unified, sectioned settings: AI providers (keys + models + active choice)
/// and dictation behaviour.
class SettingsScreen extends StatefulWidget {
  final DictationController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _activeProviderId = defaultProvider.id;
  final Map<String, TextEditingController> _keyControllers = {};
  final Map<String, String> _selectedModels = {};
  final Map<String, bool> _obscure = {};

  bool _enableDictation = false;
  int _hotkeyIndex = 0;
  bool _playSounds = true;
  bool _pauseMusic = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (final p in providerRegistry) {
      _keyControllers[p.id] = TextEditingController();
      _obscure[p.id] = true;
    }
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final active = await AppSettings.activeProvider();
    for (final p in providerRegistry) {
      _keyControllers[p.id]!.text = await AppSettings.apiKey(p);
      _selectedModels[p.id] = await AppSettings.selectedModelId(p);
    }
    setState(() {
      _activeProviderId = active.id;
      _enableDictation = prefs.getBool(AppSettings.kEnableDictation) ?? false;
      _hotkeyIndex = prefs.getInt(AppSettings.kHotkeyIndex) ?? 0;
      _playSounds = prefs.getBool(AppSettings.kPlaySounds) ?? true;
      _pauseMusic = prefs.getBool(AppSettings.kPauseMusic) ?? true;
      _loading = false;
    });
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppTheme.spaceXs),
        Text(
          'Manage AI providers and dictation behaviour.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppTheme.spaceLg),
        _sectionLabel('AI Providers'),
        const SizedBox(height: AppTheme.spaceSm),
        for (final p in providerRegistry) ...[
          _ProviderCard(
            provider: p,
            isActive: _activeProviderId == p.id,
            keyController: _keyControllers[p.id]!,
            obscure: _obscure[p.id]!,
            selectedModel: _selectedModels[p.id]!,
            onMakeActive: () => _makeActive(p),
            onToggleObscure: () =>
                setState(() => _obscure[p.id] = !_obscure[p.id]!),
            onKeyChanged: (value) {
              AppSettings.setApiKey(p, value);
              setState(() {}); // refresh lock icon + "Set active" availability
            },
            onModelChanged: (modelId) {
              setState(() => _selectedModels[p.id] = modelId);
              AppSettings.setSelectedModel(p, modelId);
            },
            onCopyConsole: () {
              Clipboard.setData(ClipboardData(text: p.consoleUrl));
              _toast('API key URL copied to clipboard');
            },
          ),
          const SizedBox(height: AppTheme.spaceMd),
        ],
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel('Dictation'),
        const SizedBox(height: AppTheme.spaceSm),
        _dictationCard(),
        const SizedBox(height: AppTheme.spaceXl),
        Center(
          child: Text(
            'Whistle • Bring your own API key. No tracking, no data collection.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  Future<void> _makeActive(TranscriptionProvider p) async {
    setState(() => _activeProviderId = p.id);
    await AppSettings.setActiveProvider(p.id);
    _toast('${p.displayName} is now the active provider');
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _dictationCard() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable dictation'),
            subtitle: const Text('Turn the global dictation hotkey on or off.'),
            value: _enableDictation,
            onChanged: (v) async {
              setState(() => _enableDictation = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppSettings.kEnableDictation, v);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.keyboard_rounded),
            title: const Text('Dictation shortcut'),
            subtitle: Text(hotkeyOptions[_hotkeyIndex].name),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _selectShortcut,
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_rounded),
            title: const Text('Play dictation sounds'),
            subtitle: const Text('Audio feedback when recording starts/stops.'),
            value: _playSounds,
            onChanged: (v) async {
              setState(() => _playSounds = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppSettings.kPlaySounds, v);
            },
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.music_off_rounded),
            title: const Text('Pause music during dictation'),
            subtitle: const Text('Mute system audio while recording.'),
            value: _pauseMusic,
            onChanged: (v) async {
              setState(() => _pauseMusic = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppSettings.kPauseMusic, v);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _selectShortcut() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select keyboard shortcut'),
        children: [
          RadioGroup<int>(
            groupValue: _hotkeyIndex,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                hotkeyOptions.length,
                (index) => RadioListTile<int>(
                  value: index,
                  title: Text(hotkeyOptions[index].name),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (result == null || result == _hotkeyIndex) return;

    if (!await _isShortcutAvailable(result)) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Shortcut conflict'),
          content: Text(
              '"${hotkeyOptions[result].name}" appears to be in use by another '
              'application. Please pick a different shortcut.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _hotkeyIndex = result);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppSettings.kHotkeyIndex, result);
    await widget.controller.registerHotkey();
  }

  Future<bool> _isShortcutAvailable(int index) async {
    try {
      final option = hotkeyOptions[index];
      final hotKey = HotKey(
        key: option.key,
        modifiers: option.modifiers,
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(hotKey, keyDownHandler: (_) {});
      await hotKeyManager.unregister(hotKey);
      return true;
    } catch (e) {
      debugPrint('Error checking hotkey: $e');
      return false;
    }
  }
}

class _ProviderCard extends StatelessWidget {
  final TranscriptionProvider provider;
  final bool isActive;
  final TextEditingController keyController;
  final bool obscure;
  final String selectedModel;
  final VoidCallback onMakeActive;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onModelChanged;
  final VoidCallback onCopyConsole;

  const _ProviderCard({
    required this.provider,
    required this.isActive,
    required this.keyController,
    required this.obscure,
    required this.selectedModel,
    required this.onMakeActive,
    required this.onToggleObscure,
    required this.onKeyChanged,
    required this.onModelChanged,
    required this.onCopyConsole,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasKey = keyController.text.trim().isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(
          color: isActive
              ? provider.accentColor.withValues(alpha: 0.7)
              : theme.dividerColor,
          width: isActive ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProviderAvatar(provider: provider),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(provider.displayName,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(width: AppTheme.spaceSm),
                          if (isActive) _activeBadge(context),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isActive)
                  OutlinedButton(
                    onPressed: hasKey ? onMakeActive : null,
                    child: const Text('Set active'),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            TextField(
              controller: keyController,
              obscureText: obscure,
              onChanged: onKeyChanged,
              decoration: InputDecoration(
                labelText: '${provider.displayName} API key',
                hintText: provider.apiKeyHint,
                prefixIcon: Icon(
                  hasKey ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Show' : 'Hide',
                  icon: Icon(
                    obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Row(
              children: [
                Expanded(
                  child: DropdownMenu<String>(
                    initialSelection: selectedModel,
                    expandedInsets: EdgeInsets.zero,
                    label: const Text('Model'),
                    dropdownMenuEntries: [
                      for (final m in provider.models)
                        DropdownMenuEntry(value: m.id, label: m.label),
                    ],
                    onSelected: (v) {
                      if (v != null) onModelChanged(v);
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                TextButton.icon(
                  onPressed: onCopyConsole,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Get key'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: provider.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ACTIVE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: provider.accentColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}
