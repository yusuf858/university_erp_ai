import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/chat_provider.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';
import '../utils/constants.dart';
import 'intent_chip.dart';
import 'package:provider/provider.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  bool get _isUser => message.sender == MessageSender.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
        _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Intent chip above AI message
          if (!_isUser && message.intentModel != null && !message.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: IntentChip(intent: message.intentModel!),
            ),

          // Bubble
          Row(
            mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isUser) _AiAvatar(),
              if (!_isUser) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:        _isUser ? AppColors.primary : AppColors.cardBg,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(14),
                      topRight:    const Radius.circular(14),
                      bottomLeft:  Radius.circular(_isUser ? 14 : 2),
                      bottomRight: Radius.circular(_isUser ? 2 : 14),
                    ),
                    border: _isUser
                        ? null
                        : Border.all(color: AppColors.borderColor, width: 0.5),
                  ),
                  child: message.isLoading
                      ? _TypingIndicator()
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MessageText(
                        text:    message.text,
                        isUser:  _isUser,
                        isError: message.isError,
                      ),

                      // IMPROVEMENT 5: Clarification suggestion chips
                      if (!_isUser &&
                          message.resultData?['clarify'] == true &&
                          message.resultData?['suggestions'] != null)
                        _SuggestionChips(
                          suggestions: List<String>.from(
                              message.resultData!['suggestions']),
                        ),

                      // IMPROVEMENT 6: Retry button on errors
                      if (message.isError &&
                          message.resultData?['retry_query'] != null)
                        _RetryButton(
                          query: message.resultData!['retry_query'] as String,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Timestamp
          if (!message.isLoading)
            Padding(
              padding: EdgeInsets.only(
                top:   3,
                left:  _isUser ? 0 : 40,
                right: _isUser ? 4 : 0,
              ),
              child: Text(
                _formatTime(message.timestamp),
                style: AppTextStyles.overline.copyWith(fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── AI Avatar ─────────────────────────────────────────────────
class _AiAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 28, height: 28,
    decoration: BoxDecoration(
      shape:  BoxShape.circle,
      color:  AppColors.primary.withOpacity(0.12),
      border: Border.all(
          color: AppColors.primary.withOpacity(0.3), width: 0.5),
    ),
    child: const Icon(
      Icons.psychology_rounded,
      color: AppColors.primaryLight,
      size:  16,
    ),
  );
}

// ── IMPROVEMENT 5: Clarification suggestion chips ─────────────
class _SuggestionChips extends StatelessWidget {
  final List<String> suggestions;
  const _SuggestionChips({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing:    6,
        runSpacing: 6,
        children: suggestions.map((s) => GestureDetector(
          onTap: () => context.read<ChatProvider>().sendMessage(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        AppColors.primaryOverlay,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.4),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.send_rounded,
                    color: AppColors.primaryLight, size: 11),
                const SizedBox(width: 5),
                Text(
                  s,
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ── IMPROVEMENT 6: Retry button ───────────────────────────────
class _RetryButton extends StatelessWidget {
  final String query;
  const _RetryButton({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: () => context.read<ChatProvider>().sendMessage(query),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        AppColors.primaryOverlay,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.4),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded,
                  color: AppColors.primaryLight, size: 13),
              const SizedBox(width: 5),
              Text(
                'Tap to retry',
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>>   _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 400),
    ));
    _anims = _ctrls.map((c) =>
        Tween<double>(begin: 0, end: -6).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOut),
        )).toList();

    void loop(int i) async {
      while (mounted) {
        await Future.delayed(Duration(milliseconds: 200 * i));
        if (!mounted) break;
        await _ctrls[i].forward();
        if (!mounted) break;
        await _ctrls[i].reverse();
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
    for (var i = 0; i < 3; i++) loop(i);
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ...List.generate(3, (i) => AnimatedBuilder(
        animation: _anims[i],
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _anims[i].value),
          child: Container(
            width:  6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textMuted,
            ),
          ),
        ),
      )),
      const SizedBox(width: 8),
      Text(
        'Thinking...',
        style: AppTextStyles.caption.copyWith(
          color:     AppColors.textMuted,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );
}

// ── Message text with markdown bold support ───────────────────
class _MessageText extends StatelessWidget {
  final String text;
  final bool   isUser;
  final bool   isError;

  const _MessageText({
    required this.text,
    required this.isUser,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final spans = _parseMarkdown(text, isUser);
    return RichText(
      text: TextSpan(
        style: AppTextStyles.body.copyWith(
          color:  isUser  ? Colors.white
              : isError ? AppColors.error
              :           AppColors.textSecondary,
          height: 1.55,
        ),
        children: spans,
      ),
    );
  }

  List<InlineSpan> _parseMarkdown(String text, bool isUser) {
    final spans = <InlineSpan>[];
    final re    = RegExp(r'\*\*(.+?)\*\*');
    int   last  = 0;

    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text:  m.group(1),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isUser ? Colors.white : AppColors.textPrimary,
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}