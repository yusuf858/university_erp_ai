import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/voice_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../voice/waveform_painter.dart';
import '../../widgets/mic_animation_widget.dart';
import '../../models/models.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  @override
  void initState() {
    super.initState();
    // Start auto-refresh when voice screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceProvider>().startAutoRefresh();
    });
  }

  @override
  void dispose() {
    // Stop auto-refresh when leaving voice screen
    context.read<VoiceProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor:   AppColors.surface,
        title: const Text('Voice Assistant', style: AppTextStyles.heading3),
        leading: IconButton(
          icon:      const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          color:     AppColors.textMuted,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<VoiceProvider>(
        builder: (_, vp, __) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingXL,
              vertical:   AppConstants.paddingLG,
            ),
            child: Column(
              children: [
                // ── Status message ──────────────────────────
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: AppConstants.animNormal,
                  child: Text(
                    vp.statusMessage,
                    key:       ValueKey(vp.statusMessage),
                    style:     AppTextStyles.heading3.copyWith(
                      color: _statusColor(vp.state),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                // IMPROVEMENT 4: Live partial transcript display
                _LiveTranscript(vp: vp),

                const Spacer(),

                // ── Waveform ────────────────────────────────
                SoundWaveform(
                  isActive:   vp.isListening,
                  soundLevel: vp.soundLevel,
                  color:      vp.isListening ? AppColors.primary : AppColors.accent,
                  width:      260,
                  height:     56,
                ),

                const SizedBox(height: 32),

                // ── Mic button ──────────────────────────────
                MicAnimationWidget(
                  state: vp.state,
                  size:  84,
                  onTap: () => _handleMicTap(context, vp),
                ),

                const SizedBox(height: 20),

                // ── Mic tap hint ────────────────────────────
                AnimatedOpacity(
                  opacity:  vp.isIdle || vp.hasError ? 1.0 : 0.0,
                  duration: AppConstants.animFast,
                  child: Text(
                    vp.hasError ? 'Tap to try again' : 'Tap to speak',
                    style: AppTextStyles.caption,
                  ),
                ),

                const Spacer(),

                // ── Error suggestions ───────────────────────
                if (vp.hasError && vp.lastError != null)
                  _ErrorSuggestions(error: vp.lastError!, vp: vp),

                // ── Last intent chip ────────────────────────
                if (vp.lastIntent != null &&
                    !vp.hasError &&
                    vp.lastIntent!.isValid)
                  _IntentResult(intent: vp.lastIntent!),

                // ── Suggestion chips when idle ──────────────
                if (vp.isIdle && vp.lastIntent == null)
                  _IdleSuggestions(vp: vp),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleMicTap(BuildContext ctx, VoiceProvider vp) {
    if (vp.hasError)      { vp.resetError(); return; }
    if (vp.isListening)   { vp.stopListening(); return; }
    if (vp.isSpeaking)    { vp.stopSpeaking(); return; }
    if (vp.isProcessing)  return;
    vp.startListening();
  }

  Color _statusColor(VoiceState s) {
    switch (s) {
      case VoiceState.listening:  return AppColors.primaryLight;
      case VoiceState.processing: return AppColors.accent;
      case VoiceState.speaking:   return AppColors.success;
      case VoiceState.error:      return AppColors.error;
      default:                    return AppColors.textSecondary;
    }
  }
}

// ── IMPROVEMENT 4: Live partial transcript widget ─────────────
class _LiveTranscript extends StatelessWidget {
  final VoiceProvider vp;
  const _LiveTranscript({required this.vp});

  @override
  Widget build(BuildContext context) {
    final text = vp.partialText;
    final show = (vp.isListening || vp.isProcessing) && text.isNotEmpty;

    return AnimatedContainer(
      duration: AppConstants.animFast,
      height:   show ? null : 0,
      child: show
          ? Container(
        margin:  const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLG,
          vertical:   AppConstants.paddingMD,
        ),
        decoration: BoxDecoration(
          color:        AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3), width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Pulsing dot to show live recognition
            _PulsingDot(),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  '"$text"',
                  key:      ValueKey(text),
                  style:    AppTextStyles.body.copyWith(
                    color:     AppColors.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines:  3,
                  overflow:  TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      )
          : const SizedBox.shrink(),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width:  8, height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
    ),
  );
}

// ── Error suggestions ─────────────────────────────────────────
class _ErrorSuggestions extends StatelessWidget {
  final VoiceError    error;
  final VoiceProvider vp;
  const _ErrorSuggestions({required this.error, required this.vp});

  @override
  Widget build(BuildContext context) {
    if (error.suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Text('Try saying:', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: error.suggestions.map((s) => GestureDetector(
            onTap: () {
              vp.resetError();
              vp.processTranscript(s);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color:        AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.borderColor, width: 0.5,
                ),
              ),
              child: Text(s,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary)),
            ),
          )).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Intent result display ─────────────────────────────────────
class _IntentResult extends StatelessWidget {
  final IntentModel intent;
  const _IntentResult({required this.intent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      margin:  const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:        AppColors.successOverlay,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: AppColors.success.withOpacity(0.3), width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 14),
              const SizedBox(width: 6),
              Text(
                intent.intent.replaceAll('_', ' '),
                style: AppTextStyles.mono.copyWith(
                    color: AppColors.success, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${(intent.confidence * 100).round()}%',
                style: AppTextStyles.mono.copyWith(
                    color: AppColors.success, fontSize: 11),
              ),
            ],
          ),
          if (intent.summary != null) ...[
            const SizedBox(height: 4),
            Text(intent.summary!,
                style: AppTextStyles.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

// ── Idle suggestion chips ─────────────────────────────────────
class _IdleSuggestions extends StatelessWidget {
  final VoiceProvider vp;
  const _IdleSuggestions({required this.vp});

  static const _suggestions = [
    'Show MCA attendance today',
    'How many fees are pending?',
    'Which faculty are absent?',
    'Compare all departments',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Try asking:', style: AppTextStyles.overline),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _suggestions.map((s) => GestureDetector(
            onTap: () => vp.processTranscript(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:        AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_none_rounded,
                      color: AppColors.textMuted, size: 12),
                  const SizedBox(width: 5),
                  Text(s, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}