import 'dart:math';
import 'package:flutter/material.dart';
import '../providers/voice_provider.dart';
import '../themes/app_colors.dart';

class MicAnimationWidget extends StatefulWidget {
  final VoiceState   state;
  final VoidCallback onTap;
  final double       size;

  const MicAnimationWidget({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 80,
  });

  @override
  State<MicAnimationWidget> createState() => _MicAnimationWidgetState();
}

class _MicAnimationWidgetState extends State<MicAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _arcCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _applyState(widget.state);
  }

  @override
  void didUpdateWidget(MicAnimationWidget old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _applyState(widget.state);
  }

  void _applyState(VoiceState s) {
    switch (s) {
      case VoiceState.listening:
        _pulseCtrl.repeat();
        _arcCtrl.stop();
      case VoiceState.processing:
        _pulseCtrl.stop();
        _arcCtrl.repeat();
      default:
        _pulseCtrl.stop();
        _arcCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _arcCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: s + 32, height: s + 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring (listening)
            if (widget.state == VoiceState.listening)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  width:  s + 32 * _pulseAnim.value,
                  height: s + 32 * _pulseAnim.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(
                        1 - _pulseAnim.value,
                      ),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

            // Processing arc
            if (widget.state == VoiceState.processing)
              AnimatedBuilder(
                animation: _arcCtrl,
                builder: (_, __) => CustomPaint(
                  size: Size(s + 16, s + 16),
                  painter: _ArcPainter(_arcCtrl.value),
                ),
              ),

            // Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:  s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _bgColor(),
                border: Border.all(color: _borderColor(), width: 1.5),
              ),
              child: Icon(
                _icon(),
                color: _iconColor(),
                size: s * 0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _bgColor() {
    switch (widget.state) {
      case VoiceState.idle:       return AppColors.surface;
      case VoiceState.listening:  return AppColors.primary.withOpacity(0.12);
      case VoiceState.processing: return AppColors.accent.withOpacity(0.12);
      case VoiceState.speaking:   return AppColors.success.withOpacity(0.12);
      case VoiceState.error:      return AppColors.error.withOpacity(0.12);
    }
  }

  Color _borderColor() {
    switch (widget.state) {
      case VoiceState.idle:       return AppColors.borderColor;
      case VoiceState.listening:  return AppColors.primary;
      case VoiceState.processing: return AppColors.accent;
      case VoiceState.speaking:   return AppColors.success;
      case VoiceState.error:      return AppColors.error;
    }
  }

  Color _iconColor() {
    switch (widget.state) {
      case VoiceState.idle:       return AppColors.textMuted;
      case VoiceState.listening:  return AppColors.primaryLight;
      case VoiceState.processing: return AppColors.accent;
      case VoiceState.speaking:   return AppColors.success;
      case VoiceState.error:      return AppColors.error;
    }
  }

  IconData _icon() {
    switch (widget.state) {
      case VoiceState.idle:       return Icons.mic_none_rounded;
      case VoiceState.listening:  return Icons.mic_rounded;
      case VoiceState.processing: return Icons.psychology_rounded;
      case VoiceState.speaking:   return Icons.volume_up_rounded;
      case VoiceState.error:      return Icons.mic_off_rounded;
    }
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = AppColors.accent
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap   = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 2,
    );

    canvas.drawArc(
      rect,
      progress * 2 * pi - pi / 2,
      pi * 0.7,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Waveform bars widget ──────────────────────────────────────
class WaveformWidget extends StatefulWidget {
  final bool isActive;
  final Color color;

  const WaveformWidget({
    super.key,
    required this.isActive,
    this.color = AppColors.primary,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with TickerProviderStateMixin {
  static const int _barCount = 9;
  late List<AnimationController> _controllers;
  late List<Animation<double>>   _animations;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_barCount, (i) => AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600 + _rng.nextInt(400)),
    ));
    _animations = _controllers.map((c) =>
        Tween<double>(begin: 4, end: 26).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOut),
        ),
    ).toList();

    _applyActive(widget.isActive);
  }

  @override
  void didUpdateWidget(WaveformWidget old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) _applyActive(widget.isActive);
  }

  void _applyActive(bool active) {
    for (var i = 0; i < _barCount; i++) {
      if (active) {
        Future.delayed(Duration(milliseconds: i * 60), () {
          if (mounted) _controllers[i].repeat(reverse: true);
        });
      } else {
        _controllers[i].animateTo(0,
            duration: const Duration(milliseconds: 300));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(_barCount, (i) => AnimatedBuilder(
        animation: _animations[i],
        builder: (_, __) => Container(
          width:  4,
          height: widget.isActive ? _animations[i].value : 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color:        widget.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      )),
    );
  }
}