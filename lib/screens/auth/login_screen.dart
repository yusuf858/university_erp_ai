import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool  _obscure      = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: AppConstants.animSlow,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthProvider>().login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (ok && mounted) {
      // Router guard handles navigation
    }
  }

  void _fillDemo(String role) {
    final creds = {
      'vc':      ['vc@university.edu',      'vc@123'],
      'hod':     ['hod.mca@university.edu', 'hod@123'],
      'admin':   ['admin@university.edu',   'admin@123'],
      'faculty': ['faculty1@university.edu','faculty@123'],
    };
    final c = creds[role];
    if (c != null) {
      _emailCtrl.text    = c[0];
      _passwordCtrl.text = c[1];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingXL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                _Header(),
                const SizedBox(height: 40),
                _LoginForm(
                  formKey:      _formKey,
                  emailCtrl:    _emailCtrl,
                  passwordCtrl: _passwordCtrl,
                  obscure:      _obscure,
                  onToggle:     () => setState(() => _obscure = !_obscure),
                  onLogin:      _login,
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) {
                    if (auth.error.isEmpty) return const SizedBox();
                    return _ErrorBanner(message: auth.error);
                  },
                ),
                const SizedBox(height: 32),
                _DemoLogins(onTap: _fillDemo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.psychology_rounded,
          color: Colors.white,
          size:  28,
        ),
      ),
      const SizedBox(height: 20),
      Text('University ERP AI', style: AppTextStyles.display),
      const SizedBox(height: 6),
      Text(
        'Sign in to your dashboard',
        style: AppTextStyles.body,
      ),
    ],
  );
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool                  obscure;
  final VoidCallback          onToggle;
  final VoidCallback          onLogin;

  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggle,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) => Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              controller:  emailCtrl,
              enabled:     !auth.isLoading,
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText:   'Email address',
                labelStyle:  TextStyle(color: AppColors.textMuted),
                prefixIcon:  Icon(Icons.mail_outline_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: AppConstants.paddingMD),
            TextFormField(
              controller:  passwordCtrl,
              enabled:     !auth.isLoading,
              obscureText: obscure,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText:  'Password',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.textMuted, size: 20),
                suffixIcon: IconButton(
                  icon:  Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textMuted,
                    size:  20,
                  ),
                  onPressed: onToggle,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                return null;
              },
              onFieldSubmitted: (_) => onLogin(),
            ),
            const SizedBox(height: AppConstants.paddingXL),
            SizedBox(
              width:  double.infinity,
              height: 50,
              child:  ElevatedButton(
                onPressed: auth.isLoading ? null : onLogin,
                child: auth.isLoading
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2,
                  ),
                )
                    : const Text('Sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppConstants.paddingMD),
    decoration: BoxDecoration(
      color:        AppColors.errorOverlay,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      border:       Border.all(
        color: AppColors.error.withOpacity(0.3), width: 0.5,
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: AppTextStyles.caption.copyWith(
          color: AppColors.error,
        ))),
      ],
    ),
  );
}

class _DemoLogins extends StatelessWidget {
  final void Function(String) onTap;
  const _DemoLogins({required this.onTap});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Demo accounts', style: AppTextStyles.overline),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: ['vc', 'hod', 'admin', 'faculty'].map((role) =>
            GestureDetector(
              onTap: () => onTap(role),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color:        AppColors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border:       Border.all(
                    color: AppColors.borderColor, width: 0.5,
                  ),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ),
        ).toList(),
      ),
      const SizedBox(height: 8),
      Text(
        'Tap a role above to prefill demo credentials',
        style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
      ),
    ],
  );
}