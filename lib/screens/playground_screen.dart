import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../providers/provider_registry.dart';
import '../providers/transcription_provider.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';

enum RunStatus { idle, running, done, error }

/// Mutable per-provider state for a comparison run.
class _ProviderRun {
  RunStatus status = RunStatus.idle;
  String? text;
  String? error;
  Duration? latency;
  String? modelId;
  bool selected = true;
}

/// Developer / internal playground: capture one audio clip and transcribe it
/// across several providers simultaneously to compare quality and latency.
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isComparing = false;
  String? _clipPath;
  Duration _clipDuration = Duration.zero;
  DateTime? _recordStarted;

  final Map<String, _ProviderRun> _runs = {
    for (final p in providerRegistry) p.id: _ProviderRun(),
  };
  final Map<String, bool> _keyAvailable = {};

  @override
  void initState() {
    super.initState();
    _refreshKeyAvailability();
  }

  Future<void> _refreshKeyAvailability() async {
    for (final p in providerRegistry) {
      _keyAvailable[p.id] = await AppSettings.hasApiKey(p);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _clipPath = path ?? _clipPath;
        _clipDuration = _recordStarted == null
            ? Duration.zero
            : DateTime.now().difference(_recordStarted!);
      });
    } else {
      if (!await _recorder.hasPermission()) return;
      final tempDir = await getTemporaryDirectory();
      final suffix = Random().nextInt(1000000).toString().padLeft(6, '0');
      final path = '${tempDir.path}/playground_$suffix.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _clipPath = path;
        _recordStarted = DateTime.now();
        for (final run in _runs.values) {
          run.status = RunStatus.idle;
          run.text = null;
          run.error = null;
          run.latency = null;
        }
      });
    }
  }

  Future<void> _playClip() async {
    if (_clipPath == null) return;
    await _player.stop();
    await _player.play(DeviceFileSource(_clipPath!));
  }

  Future<void> _runComparison() async {
    if (_clipPath == null || _isComparing) return;
    await _refreshKeyAvailability();
    if (!mounted) return;

    final selected = providerRegistry
        .where((p) => _runs[p.id]!.selected && (_keyAvailable[p.id] ?? false))
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one provider with an API key set.'),
        ),
      );
      return;
    }

    setState(() {
      _isComparing = true;
      for (final p in selected) {
        _runs[p.id]!
          ..status = RunStatus.running
          ..text = null
          ..error = null
          ..latency = null;
      }
    });

    await Future.wait(selected.map(_runProvider));

    if (mounted) setState(() => _isComparing = false);
  }

  Future<void> _runProvider(TranscriptionProvider provider) async {
    final run = _runs[provider.id]!;
    try {
      final apiKey = await AppSettings.apiKey(provider);
      final modelId = await AppSettings.selectedModelId(provider);
      final result = await provider.transcribe(
        filePath: _clipPath!,
        apiKey: apiKey,
        modelId: modelId,
        prompt: AppSettings.transcriptionPrompt,
      );
      if (!mounted) return;
      setState(() {
        run
          ..status = RunStatus.done
          ..text = result.text
          ..latency = result.latency
          ..modelId = result.modelId;
      });
    } on TranscriptionException catch (e) {
      _failRun(run, e.message);
    } catch (e) {
      _failRun(run, e.toString());
    }
  }

  void _failRun(_ProviderRun run, String message) {
    if (!mounted) return;
    setState(() {
      run
        ..status = RunStatus.error
        ..error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Playground', style: theme.textTheme.headlineMedium),
                      const SizedBox(width: AppTheme.spaceSm),
                      _devBadge(context),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    'Record one clip and compare every provider side by side.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceLg),
        _captureCard(context),
        const SizedBox(height: AppTheme.spaceLg),
        Text('Providers', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppTheme.spaceSm),
        _providerSelector(context),
        const SizedBox(height: AppTheme.spaceLg),
        _resultsGrid(context),
      ],
    );
  }

  Widget _devBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'DEV',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
      ),
    );
  }

  Widget _captureCard(BuildContext context) {
    final theme = Theme.of(context);
    final hasClip = _clipPath != null && !_isRecording;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Row(
          children: [
            _RecordButton(
              recording: _isRecording,
              onTap: _toggleRecording,
            ),
            const SizedBox(width: AppTheme.spaceLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecording
                        ? 'Recording…'
                        : hasClip
                            ? 'Clip ready'
                            : 'No clip yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isRecording
                        ? 'Tap the button again to stop.'
                        : hasClip
                            ? 'Captured ${_clipDuration.inSeconds}s of audio.'
                            : 'Tap record and speak a sentence to compare.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (hasClip) ...[
              IconButton.filledTonal(
                onPressed: _playClip,
                icon: const Icon(Icons.play_arrow_rounded),
                tooltip: 'Play clip',
              ),
              const SizedBox(width: AppTheme.spaceSm),
            ],
            FilledButton.icon(
              onPressed: hasClip && !_isComparing ? _runComparison : null,
              icon: _isComparing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.compare_arrows_rounded),
              label: Text(_isComparing ? 'Comparing…' : 'Compare'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerSelector(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spaceSm,
      runSpacing: AppTheme.spaceSm,
      children: [
        for (final p in providerRegistry)
          _ProviderChip(
            provider: p,
            selected: _runs[p.id]!.selected,
            hasKey: _keyAvailable[p.id] ?? false,
            onTap: () =>
                setState(() => _runs[p.id]!.selected = !_runs[p.id]!.selected),
          ),
      ],
    );
  }

  Widget _resultsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth > 720;
        final cards = [
          for (final p in providerRegistry)
            _ResultCard(
              provider: p,
              run: _runs[p.id]!,
              hasKey: _keyAvailable[p.id] ?? false,
            ),
        ];
        if (!twoColumns) {
          return Column(
            children: [
              for (final c in cards) ...[
                c,
                const SizedBox(height: AppTheme.spaceMd),
              ],
            ],
          );
        }
        return Wrap(
          spacing: AppTheme.spaceMd,
          runSpacing: AppTheme.spaceMd,
          children: [
            for (final c in cards)
              SizedBox(
                width: (constraints.maxWidth - AppTheme.spaceMd) / 2,
                child: c,
              ),
          ],
        );
      },
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool recording;
  final VoidCallback onTap;
  const _RecordButton({required this.recording, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recording
              ? const Color(0xFFFF5C5C)
              : scheme.primary.withValues(alpha: 0.12),
        ),
        child: Icon(
          recording ? Icons.stop_rounded : Icons.mic_rounded,
          color: recording ? Colors.white : scheme.primary,
          size: 30,
        ),
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  final TranscriptionProvider provider;
  final bool selected;
  final bool hasKey;
  final VoidCallback onTap;

  const _ProviderChip({
    required this.provider,
    required this.selected,
    required this.hasKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: ProviderAvatar(provider: provider, size: 22),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(provider.displayName),
          if (!hasKey) ...[
            const SizedBox(width: 6),
            Icon(Icons.key_off_rounded,
                size: 14, color: theme.colorScheme.error),
          ],
        ],
      ),
      selectedColor: provider.accentColor.withValues(alpha: 0.16),
      side: BorderSide(
        color: selected
            ? provider.accentColor.withValues(alpha: 0.6)
            : theme.dividerColor,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final TranscriptionProvider provider;
  final _ProviderRun run;
  final bool hasKey;

  const _ResultCard({
    required this.provider,
    required this.run,
    required this.hasKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProviderAvatar(provider: provider, size: 32),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provider.displayName,
                          style: theme.textTheme.titleMedium),
                      Text(
                        provider.resolveModel(run.modelId).label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (run.latency != null) _latencyBadge(context, run.latency!),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _body(context),
          ],
        ),
      ),
    );
  }

  Widget _latencyBadge(BuildContext context, Duration d) {
    final theme = Theme.of(context);
    final ms = d.inMilliseconds;
    final label = ms < 1000 ? '${ms}ms' : '${(ms / 1000).toStringAsFixed(1)}s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
              size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    switch (run.status) {
      case RunStatus.idle:
        return Text(
          hasKey
              ? 'Ready to compare. Record a clip and press Compare.'
              : 'No API key set — add one in Settings to include this provider.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      case RunStatus.running:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Text('Transcribing…', style: theme.textTheme.bodySmall),
          ],
        );
      case RunStatus.error:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spaceSm),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            run.error ?? 'Something went wrong.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
        );
      case RunStatus.done:
        final text = run.text ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              text.isEmpty ? '(no speech detected)' : text,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Row(
              children: [
                Text(
                  '${text.length} chars · ${_wordCount(text)} words',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: text.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied!')),
                          );
                        },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copy'),
                ),
              ],
            ),
          ],
        );
    }
  }

  int _wordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }
}
