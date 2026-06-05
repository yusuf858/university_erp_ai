import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _focusNode   = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    context.read<ChatProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: AppConstants.animNormal,
          curve:    Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryOverlay,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3), width: 0.5,
                ),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppColors.primaryLight,
                size:  18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Assistant', style: AppTextStyles.heading3),
                Row(
                  children: [
                    Container(
                      width: 5, height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('online', style: AppTextStyles.overline.copyWith(
                      color: AppColors.success,
                    )),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.textMuted,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => _ClearDialog(
                  onConfirm: () =>
                      context.read<ChatProvider>().clearHistory(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _MessageList(scrollCtrl: _scrollCtrl)),
          _InputBar(
            controller: _controller,
            focusNode:  _focusNode,
            onSend:     _send,
          ),
        ],
      ),
    );
  }
}

// ── Message list ──────────────────────────────────────────────
class _MessageList extends StatelessWidget {
  final ScrollController scrollCtrl;
  const _MessageList({required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (_, cp, __) {
        if (cp.messages.isEmpty) return _EmptyState();

        return ListView.builder(
          controller:  scrollCtrl,
          padding:     const EdgeInsets.fromLTRB(
            AppConstants.paddingLG, AppConstants.paddingMD,
            AppConstants.paddingLG, AppConstants.paddingMD,
          ),
          itemCount:   cp.messages.length,
          itemBuilder: (_, i) => ChatBubble(message: cp.messages[i]),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'Show MCA attendance today',
      'How many fees are pending for BCA?',
      'Which faculty are absent today?',
      'Compare all departments',
      'Generate monthly attendance report',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingXL),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryOverlay,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2), width: 0.5,
              ),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: AppColors.primaryLight,
              size:  36,
            ),
          ),
          const SizedBox(height: 16),
          const Text('AI ERP Assistant', style: AppTextStyles.heading2),
          const SizedBox(height: 8),
          const Text(
            'Ask about attendance, fees, admissions, faculty, or request analytics reports.',
            style:     AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Text('Try asking:', style: AppTextStyles.overline),
          const SizedBox(height: 12),
          ...suggestions.map((s) => _SuggestionTile(text: s)),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String text;
  const _SuggestionTile({required this.text});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.read<ChatProvider>().sendMessage(text),
    child: Container(
      width:   double.infinity,
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG,
        vertical:   AppConstants.paddingMD,
      ),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border:       Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.send_rounded, color: AppColors.primary, size: 14),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textDisabled,
            size:  12,
          ),
        ],
      ),
    ),
  );
}

// ── Input bar ─────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  final VoidCallback          onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (_, cp, __) => Container(
        padding: EdgeInsets.fromLTRB(
          AppConstants.paddingMD,
          AppConstants.paddingSM,
          AppConstants.paddingMD,
          AppConstants.paddingSM +
              MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color:  AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.borderColor, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Text field
              Expanded(
                child: TextField(
                  controller:  controller,
                  focusNode:   focusNode,
                  enabled:     !cp.processing,
                  maxLines:    3,
                  minLines:    1,
                  style:       AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: cp.processing
                        ? 'AI is thinking...'
                        : 'Ask about attendance, fees, faculty...',
                    filled:      true,
                    fillColor:   AppColors.cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      borderSide:   const BorderSide(
                        color: AppColors.borderColor, width: 0.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      borderSide:   const BorderSide(
                        color: AppColors.borderColor, width: 0.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      borderSide:   const BorderSide(
                        color: AppColors.primary, width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMD,
                      vertical:   AppConstants.paddingSM,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              AnimatedContainer(
                duration: AppConstants.animFast,
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        cp.processing
                      ? AppColors.cardBg
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: cp.processing
                    ? const Center(
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 1.5,
                    ),
                  ),
                )
                    : IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color:    Colors.white,
                  iconSize: 18,
                  padding:  EdgeInsets.zero,
                  onPressed: onSend,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Clear dialog ──────────────────────────────────────────────
class _ClearDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  const _ClearDialog({required this.onConfirm});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      side: const BorderSide(color: AppColors.borderColor, width: 0.5),
    ),
    title: const Text('Clear conversation', style: AppTextStyles.heading3),
    content: const Text(
      'This will remove all messages from this session.',
      style: AppTextStyles.body,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: AppTextStyles.label.copyWith(
          color: AppColors.textMuted,
        )),
      ),
      TextButton(
        onPressed: () {
          onConfirm();
          Navigator.pop(context);
        },
        child: Text('Clear', style: AppTextStyles.label.copyWith(
          color: AppColors.error,
        )),
      ),
    ],
  );
}