import 'package:flutter/material.dart';

import '../providers/transcription_provider.dart';

/// A rounded, brand-colored avatar representing a transcription provider.
class ProviderAvatar extends StatelessWidget {
  final TranscriptionProvider provider;
  final double size;

  const ProviderAvatar({
    super.key,
    required this.provider,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            provider.accentColor,
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.18),
              provider.accentColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: provider.accentColor.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        provider.icon,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
