import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ai/gemini_service.dart';
import '../../ai/gemini_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl = TextEditingController();
  bool  _obscure = true;
  bool  _loading = false;

  bool?   _keyValid;
  String  _keyStatus       = '';
  String? _savedKeyPreview;

  @override
  void initState() {
    super.initState();
    _loadCurrentKey();
  }

  Future<void> _loadCurrentKey() async {
    final key = await StorageService.instance.readGeminiKey();
    if (key != null && key.isNotEmpty) {
      setState(() {
        _savedKeyPreview =
        '${key.substring(0, 8)}••••••••••••••${key.substring(key.length - 4)}';
        _keyValid  = true;
        _keyStatus = 'Key saved';
      });
    }
  }

  Future<void> _testAndSave() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      _showSnack('Enter your Gemini API key first', isError: true);
      return;
    }

    setState(() { _loading = true; _keyValid = null; _keyStatus = 'Validating...'; });

    final result = await GeminiService.instance.validateKey(key);

    setState(() {
      _loading   = false;
      _keyValid  = result.isValid;
      _keyStatus = result.isValid
          ? 'Key validated and saved ✓'
          : result.error ?? 'Validation failed';
    });

    if (result.isValid) {
      await StorageService.instance.saveGeminiKey(key);
      _keyCtrl.clear();
      await _loadCurrentKey();
      _showSnack('Gemini API key saved successfully');
    } else {
      _showSnack(result.error ?? 'Invalid key', isError: true);
    }
  }

  Future<void> _deleteKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          side: const BorderSide(color: AppColors.borderColor, width: 0.5),
        ),
        title:   Text('Remove API key', style: AppTextStyles.heading3),
        content: Text(
          'The voice assistant will stop working until a new key is added.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.label.copyWith(
                color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: AppTextStyles.label.copyWith(
                color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.instance.deleteGeminiKey();
      setState(() {
        _savedKeyPreview = null;
        _keyValid        = null;
        _keyStatus       = '';
      });
      _showSnack('API key removed');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.body.copyWith(color: Colors.white)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Settings', style: AppTextStyles.heading3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        children: [
          _SectionHeader(title: 'AI Configuration'),
          const SizedBox(height: AppConstants.paddingMD),
          _GeminiKeyCard(
            keyCtrl:         _keyCtrl,
            obscure:         _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onTestAndSave:   _testAndSave,
            onDeleteKey:     _savedKeyPreview != null ? _deleteKey : null,
            loading:         _loading,
            keyValid:        _keyValid,
            keyStatus:       _keyStatus,
            savedKeyPreview: _savedKeyPreview,
          ),

          const SizedBox(height: AppConstants.paddingXL),

          _InfoCard(
            icon:  Icons.info_outline_rounded,
            color: AppColors.info,
            title: 'Getting a Gemini API key',
            body:  '1. Open aistudio.google.com\n'
                '2. Sign in with a personal Gmail (not college email)\n'
                '3. Click "Get API key" → "Create API key in new project"\n'
                '4. Copy the key and paste it above\n\n'
                'Use gemini-2.5-flash model — free tier supports '
                'sufficient requests for normal demo use.',
          ),

          const SizedBox(height: AppConstants.paddingMD),

          _SectionHeader(title: 'Network'),
          const SizedBox(height: AppConstants.paddingMD),
          _NetworkCard(),

          const SizedBox(height: AppConstants.paddingXL),

          _SectionHeader(title: 'Account'),
          const SizedBox(height: AppConstants.paddingMD),
          _AccountCard(),

          const SizedBox(height: AppConstants.paddingXL),

          _SectionHeader(title: 'About'),
          const SizedBox(height: AppConstants.paddingMD),
          _AboutCard(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) =>
      Text(title.toUpperCase(), style: AppTextStyles.overline);
}

class _GeminiKeyCard extends StatelessWidget {
  final TextEditingController keyCtrl;
  final bool          obscure;
  final VoidCallback  onToggleObscure;
  final VoidCallback  onTestAndSave;
  final VoidCallback? onDeleteKey;
  final bool          loading;
  final bool?         keyValid;
  final String        keyStatus;
  final String?       savedKeyPreview;

  const _GeminiKeyCard({
    required this.keyCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onTestAndSave,
    required this.loading,
    required this.keyStatus,
    this.onDeleteKey,
    this.keyValid,
    this.savedKeyPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border:       Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (savedKeyPreview != null) ...[
            Row(
              children: [
                const Icon(Icons.key_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(savedKeyPreview!,
                    style: AppTextStyles.mono.copyWith(color: AppColors.success))),
                if (onDeleteKey != null)
                  IconButton(
                    icon:     const Icon(Icons.delete_outline_rounded),
                    color:    AppColors.error,
                    iconSize: 18,
                    onPressed: onDeleteKey,
                    tooltip:  'Remove key',
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMD),
            const Divider(),
            const SizedBox(height: AppConstants.paddingMD),
            Text('Update key:', style: AppTextStyles.caption),
            const SizedBox(height: AppConstants.paddingSM),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Text('No API key configured',
                    style: AppTextStyles.body.copyWith(color: AppColors.warning)),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMD),
          ],

          TextField(
            controller:  keyCtrl,
            obscureText: obscure,
            enabled:     !loading,
            style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:   'Paste your Gemini API key here (AIza...)',
              prefixIcon: const Icon(Icons.vpn_key_rounded,
                  color: AppColors.textMuted, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                ),
                color:    AppColors.textMuted,
                onPressed: onToggleObscure,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          if (keyStatus.isNotEmpty)
            AnimatedContainer(
              duration: AppConstants.animFast,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: keyValid == true ? AppColors.successOverlay
                    : keyValid == false  ? AppColors.errorOverlay
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    keyValid == true  ? Icons.check_circle_rounded
                        : keyValid == false ? Icons.error_outline_rounded
                        : Icons.hourglass_empty_rounded,
                    color: keyValid == true  ? AppColors.success
                        : keyValid == false  ? AppColors.error
                        : AppColors.textMuted,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      keyStatus,
                      style: AppTextStyles.caption.copyWith(
                        color: keyValid == true  ? AppColors.success
                            : keyValid == false  ? AppColors.error
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppConstants.paddingMD),

          SizedBox(
            width: double.infinity, height: 44,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onTestAndSave,
              icon: loading
                  ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
              )
                  : const Icon(Icons.verified_rounded, size: 18),
              label: Text(loading ? 'Validating...' : 'Test and Save Key'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border:       Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingRow(
            icon:   Icons.computer_rounded,
            label:  'Backend URL',
            value:  AppConstants.baseUrl,
            isMono: true,
          ),
          const Divider(height: 24),
          // FIXED: shows actual current model from GeminiConfig
          _SettingRow(
            icon:   Icons.cloud_outlined,
            label:  'Gemini model',
            value:  GeminiConfig.model,
            isMono: true,
          ),
          const Divider(height: 24),
          _SettingRow(
            icon:  Icons.timer_outlined,
            label: 'AI timeout',
            value: '${GeminiConfig.intentTimeoutSeconds} seconds',
          ),
          const Divider(height: 24),
          _SettingRow(
            icon:  Icons.security_rounded,
            label: 'Key storage',
            value: 'Android Keystore (hardware-backed)',
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     isMono;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.textMuted, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: AppTextStyles.body)),
      Text(
        value,
        style: isMono
            ? AppTextStyles.mono.copyWith(fontSize: 11)
            : AppTextStyles.caption,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _AccountCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border:       Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          _SettingRow(icon: Icons.person_outline_rounded, label: 'Name',  value: user?.name ?? '—'),
          const Divider(height: 24),
          _SettingRow(icon: Icons.mail_outline_rounded,   label: 'Email', value: user?.email ?? '—'),
          const Divider(height: 24),
          _SettingRow(icon: Icons.badge_outlined,         label: 'Role',  value: user?.displayRole ?? '—'),
          if (user?.departmentCode != null) ...[
            const Divider(height: 24),
            _SettingRow(icon: Icons.apartment_rounded, label: 'Department',
                value: user!.departmentCode!),
          ],
          const SizedBox(height: AppConstants.paddingMD),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side:            const BorderSide(color: AppColors.error, width: 0.5),
              ),
              onPressed: () => context.read<AuthProvider>().logout(),
              icon:  const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border:       Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: const Column(
        children: [
          _SettingRow(icon: Icons.info_outline_rounded,
              label: 'App name', value: 'University ERP AI'),
          Divider(height: 24),
          _SettingRow(icon: Icons.tag_rounded,
              label: 'Version',  value: '1.0.0'),
          Divider(height: 24),
          _SettingRow(icon: Icons.architecture_rounded,
              label: 'Stack',    value: 'Flutter · PHP · MySQL · Gemini'),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   body;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppConstants.paddingLG),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      border:       Border.all(color: color.withOpacity(0.25), width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.label.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 10),
        Text(body, style: AppTextStyles.body),
      ],
    ),
  );
}