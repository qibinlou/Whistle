import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/provider_registry.dart';
import '../providers/transcription_provider.dart';
import '../services/app_settings.dart';
import '../services/dictation_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/provider_avatar.dart';

/// The primary screen: a polished status hero plus session history.
class DashboardScreen extends StatelessWidget {
  final DictationController controller;
  const DashboardScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(AppTheme.spaceXl),
          children: [
            _Header(),
            const SizedBox(height: AppTheme.spaceLg),
            _HeroCard(controller: controller),
            if (controller.lastError != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              _ErrorBanner(message: controller.lastError!),
            ],
            const SizedBox(height: AppTheme.spaceXl),
            _HistorySection(controller: controller),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dictation', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppTheme.spaceXs),
        Text(
          'Speak anywhere on your Mac and Whistle types it for you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final DictationController controller;
  const _HeroCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recording = controller.isRecording;
    final transcribing = controller.status == DictationStatus.transcribing;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.22), scheme.primary),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatusPill(
                recording: recording,
                transcribing: transcribing,
              ),
              const Spacer(),
              const _ActiveProviderChip(),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          _MicButton(
            controller: controller,
            recording: recording,
            transcribing: transcribing,
          ),
          const SizedBox(height: AppTheme.spaceLg),
          FutureBuilder<String>(
            future: controller.currentShortcutLabel(),
            builder: (context, snapshot) {
              final shortcut = snapshot.data ?? '…';
              final label = recording
                  ? 'Listening… press the button or your shortcut to stop'
                  : transcribing
                      ? 'Transcribing your audio…'
                      : 'Press the button or $shortcut anywhere to dictate';
              return Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool recording;
  final bool transcribing;
  const _StatusPill({required this.recording, required this.transcribing});

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color dot;
    if (recording) {
      text = 'Recording';
      dot = const Color(0xFFFF5C5C);
    } else if (transcribing) {
      text = 'Transcribing';
      dot = const Color(0xFFFFC75C);
    } else {
      text = 'Ready';
      dot = const Color(0xFF5CFFA8);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActiveProviderChip extends StatelessWidget {
  const _ActiveProviderChip();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TranscriptionProvider>(
      future: AppSettings.activeProvider(),
      builder: (context, snapshot) {
        final provider = snapshot.data ?? defaultProvider;
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProviderAvatar(provider: provider, size: 22),
              const SizedBox(width: 8),
              Text(
                provider.displayName,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MicButton extends StatelessWidget {
  final DictationController controller;
  final bool recording;
  final bool transcribing;
  const _MicButton({
    required this.controller,
    required this.recording,
    required this.transcribing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: transcribing ? null : controller.toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: recording
              ? const Color(0xFFFF5C5C)
              : Colors.white.withValues(alpha: 0.16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
        ),
        child: transcribing
            ? const Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(
                recording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 44,
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final DictationController controller;
  const _HistorySection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = controller.history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent transcriptions',
                style: theme.textTheme.titleLarge),
            const Spacer(),
            if (history.isNotEmpty)
              TextButton.icon(
                onPressed: controller.clearHistory,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        if (history.isEmpty)
          _EmptyHistory()
        else
          for (final entry in history) ...[
            _HistoryTile(entry: entry),
            const SizedBox(height: AppTheme.spaceSm),
          ],
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded,
                  size: 40, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                'No transcriptions yet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Your dictations will appear here for quick re-use.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final TranscriptionEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = providerById(entry.providerId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProviderAvatar(provider: provider, size: 24),
                const SizedBox(width: AppTheme.spaceSm),
                Text(provider.displayName,
                    style: theme.textTheme.labelMedium),
                const SizedBox(width: 6),
                Text(
                  '· ${_timeAgo(entry.timestamp)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              entry.text,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
