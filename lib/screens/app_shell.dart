import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../services/dictation_controller.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'playground_screen.dart';
import 'settings_screen.dart';

/// Top-level layout: a persistent navigation rail with the main destinations,
/// hosting the dashboard, playground and settings.
class AppShell extends StatefulWidget {
  final DictationController controller;
  const AppShell({super.key, required this.controller});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, WindowListener {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addObserver(this);
    widget.controller.onNeedsApiKey = () {
      if (!mounted) return;
      setState(() => _index = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.lastError ??
              'Add an API key to start transcribing.'),
        ),
      );
    };
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      await windowManager.hide();
    } else if (state == AppLifecycleState.resumed) {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(controller: widget.controller),
      const PlaygroundScreen(),
      SettingsScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: Row(
        children: [
          _NavRail(
            index: _index,
            controller: widget.controller,
            onSelect: (i) => setState(() => _index = i),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final DictationController controller;

  const _NavRail({
    required this.index,
    required this.onSelect,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLg),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              'Whistle',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(top: AppTheme.spaceLg),
        child: _RecordingIndicator(controller: controller),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.mic_none_rounded),
          selectedIcon: Icon(Icons.mic_rounded),
          label: Text('Dictate'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.science_outlined),
          selectedIcon: Icon(Icons.science_rounded),
          label: Text('Playground'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: Text('Settings'),
        ),
      ],
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final DictationController controller;
  const _RecordingIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isBusy) return const SizedBox.shrink();
        final recording = controller.isRecording;
        final color =
            recording ? const Color(0xFFFF5C5C) : const Color(0xFFFFC75C);
        return Tooltip(
          message: recording ? 'Recording' : 'Transcribing',
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
