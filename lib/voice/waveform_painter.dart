import 'dart:math';
import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

/// Smooth organic waveform drawn with CustomPainter.
/// Driven by a soundLevel value (–1.0 to 10.0) from speech_to_text.
class WaveformPainter extends CustomPainter {
  final double soundLevel;     // –1.0 → 10.0
  final double animValue;      // 0.0 → 1.0 from AnimationController
  final Color  color;
  final int    barCount;

  const WaveformPainter({
    required this.soundLevel,
    required this.animValue,
    this.color    = AppColors.primary,
    this.barCount = 24,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeCap   = StrokeCap.round
      ..strokeWidth = 3.5
      ..style       = PaintingStyle.stroke;

    final barW  = size.width / barCount;
    final normL = ((soundLevel + 1) / 11).clamp(0.0, 1.0);

    for (var i = 0; i < barCount; i++) {
      final x        = i * barW + barW / 2;
      final phase    = (i / barCount) * 2 * pi;
      final wave     = sin(animValue * 2 * pi + phase);
      final maxH     = size.height * 0.8;
      final minH     = 4.0;
      final barH     = minH + (maxH - minH) * normL * ((wave + 1) / 2);
      final opacity  = 0.4 + 0.6 * ((wave + 1) / 2);

      canvas.drawLine(
        Offset(x, size.height / 2 - barH / 2),
        Offset(x, size.height / 2 + barH / 2),
        paint..color = color.withOpacity(opacity.clamp(0.1, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.soundLevel != soundLevel || old.animValue != animValue;
}

/// Full waveform widget that combines the painter with animation.
class SoundWaveform extends StatefulWidget {
  final bool   isActive;
  final double soundLevel;
  final Color  color;
  final double width;
  final double height;

  const SoundWaveform({
    super.key,
    required this.isActive,
    this.soundLevel = 0.0,
    this.color      = AppColors.primary,
    this.width      = 220,
    this.height     = 48,
  });

  @override
  State<SoundWaveform> createState() => _SoundWaveformState();
}

class _SoundWaveformState extends State<SoundWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isActive) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(SoundWaveform old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isActive && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.animateTo(0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity:  widget.isActive ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: Size(widget.width, widget.height),
          painter: WaveformPainter(
            soundLevel: widget.soundLevel,
            animValue:  _ctrl.value,
            color:      widget.color,
          ),
        ),
      ),
    );
  }
}