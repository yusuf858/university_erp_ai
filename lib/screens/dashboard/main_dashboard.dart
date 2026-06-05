import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/voice_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../navigation/app_router.dart';
import '../../widgets/dashboard_card.dart';
import '../../models/models.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  late final List<AnimationController> _cardControllers;
  late final List<Animation<double>>   _cardAnims;
  static const int _cardCount = 4;

  @override
  void initState() {
    super.initState();
    _cardControllers = List.generate(_cardCount, (i) => AnimationController(
      vsync:    this,
      duration: AppConstants.animNormal,
    ));
    _cardAnims = _cardControllers.map((c) =>
        CurvedAnimation(parent: c, curve: Curves.easeOut),
    ).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    final dept = context.read<AuthProvider>().currentUser?.departmentCode;
    await context.read<DashboardProvider>().loadDashboard(department: dept);
    for (var i = 0; i < _cardCount; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (mounted) _cardControllers[i].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _cardControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 1) { context.push(RouteNames.voice);     return; }
          if (i == 2) { context.push(RouteNames.chat);      return; }
          if (i == 3) { context.push(RouteNames.analytics); return; }
          setState(() => _currentIndex = i);
        },
      ),
      floatingActionButton: _MicFAB(
        onTap: () => context.push(RouteNames.voice),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _DashboardTab(cardAnims: _cardAnims, onRefresh: _loadDashboard);
      case 4:
        return const _NotificationsTab();
      default:
        return _DashboardTab(cardAnims: _cardAnims, onRefresh: _loadDashboard);
    }
  }
}

// ── App bar with working notifications button ─────────────────
class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().currentUser;
    final hour  = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning'
        : hour < 17 ? 'Good afternoon'
        : 'Good evening';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG,
        vertical:   AppConstants.paddingMD,
      ),
      decoration: const BoxDecoration(
        color:  AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting${user != null ? ", ${user.name.split(' ').first}" : ""}',
                  style: AppTextStyles.heading3,
                ),
                if (user != null)
                  Text(
                    '${user.displayRole}'
                        '${user.departmentCode != null ? " · ${user.departmentCode}" : ""}',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          // ── FIXED: Notifications button now opens bottom sheet ──
          Consumer<DashboardProvider>(
            builder: (_, dash, __) => Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon:  const Icon(Icons.notifications_outlined),
                  color: AppColors.textMuted,
                  onPressed: () => _showNotificationsSheet(context),
                ),
                if (dash.unreadNotifications > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error,
                      ),
                      child: Center(
                        child: Text(
                          '${dash.unreadNotifications}',
                          style: AppTextStyles.overline.copyWith(
                            color: Colors.white, fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusXL),
                ),
              ),
              builder: (_) => _ProfileSheet(user: user),
            ),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                color:  AppColors.primaryOverlay,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  user?.initials ?? 'U',
                  style: AppTextStyles.label.copyWith(color: AppColors.primaryLight),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      builder: (_) => const _NotificationsSheet(),
    );
  }
}

// ── Notifications bottom sheet ────────────────────────────────
class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    // Static notifications from DB data — all 8 from your notifications table
    final notifications = [
      _NotifData(
        title:    'Attendance Alert: MCA Sem 1',
        message:  'MCA Semester 1 attendance dropped below 75%. Immediate action required.',
        type:     'warning',
        priority: 'high',
        isRead:   false,
        time:     'Today',
      ),
      _NotifData(
        title:    'Fee Deadline Reminder',
        message:  'Semester 1 fee deadline is Sept 30. 6 students have not paid.',
        type:     'reminder',
        priority: 'high',
        isRead:   false,
        time:     'Today',
      ),
      _NotifData(
        title:    'New Admission Applications',
        message:  '5 new applications received for MCA 2025-26 batch.',
        type:     'info',
        priority: 'medium',
        isRead:   false,
        time:     'Today',
      ),
      _NotifData(
        title:    'Faculty Meeting Scheduled',
        message:  'All HODs to attend VC meeting on June 1st at 10 AM.',
        type:     'alert',
        priority: 'high',
        isRead:   false,
        time:     'Today',
      ),
      _NotifData(
        title:    'BCA Lab Schedule Updated',
        message:  'BCA Programming Lab moved to Room 204 from Monday.',
        type:     'info',
        priority: 'low',
        isRead:   false,
        time:     'Today',
      ),
      _NotifData(
        title:    'Exam Schedule Published',
        message:  'End semester exam schedule for all departments is now published.',
        type:     'info',
        priority: 'medium',
        isRead:   false,
        time:     'Today',
      ),
      _NotifData(
        title:    'MBA Fee Concession Approved',
        message:  '3 MBA students approved for fee concession under scholarship scheme.',
        type:     'info',
        priority: 'medium',
        isRead:   true,
        time:     'Yesterday',
      ),
      _NotifData(
        title:    'Annual Report Due',
        message:  'Department annual reports due by June 15th. Submit to admin office.',
        type:     'reminder',
        priority: 'high',
        isRead:   false,
        time:     'Today',
      ),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize:     0.95,
      minChildSize:     0.4,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLG,
              vertical:   AppConstants.paddingSM,
            ),
            child: Row(
              children: [
                const Text('Notifications', style: AppTextStyles.heading2),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppColors.errorOverlay,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${notifications.where((n) => !n.isRead).length} unread',
                    style: AppTextStyles.overline.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: ListView.separated(
              controller:  scrollCtrl,
              padding:     const EdgeInsets.symmetric(vertical: AppConstants.paddingSM),
              itemCount:   notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) => _NotifTile(data: notifications[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifData {
  final String title, message, type, priority, time;
  final bool isRead;
  const _NotifData({
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.isRead,
    required this.time,
  });
}

class _NotifTile extends StatelessWidget {
  final _NotifData data;
  const _NotifTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final icon  = _icon();

    return Container(
      color: data.isRead ? Colors.transparent : AppColors.primaryOverlay,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG,
        vertical:   AppConstants.paddingMD,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        style: AppTextStyles.label.copyWith(
                          color: data.isRead
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!data.isRead)
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  data.message,
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(data.time, style: AppTextStyles.overline),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color:        color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        data.priority.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color: color, fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _color() {
    switch (data.type) {
      case 'warning':  return AppColors.warning;
      case 'alert':    return AppColors.error;
      case 'reminder': return AppColors.accent;
      default:         return AppColors.primary;
    }
  }

  IconData _icon() {
    switch (data.type) {
      case 'warning':  return Icons.warning_amber_rounded;
      case 'alert':    return Icons.campaign_rounded;
      case 'reminder': return Icons.alarm_rounded;
      default:         return Icons.info_outline_rounded;
    }
  }
}

// ── Notifications full tab (when bottom nav tab 4 tapped) ─────
class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Notifications — coming in next phase',
      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
    ),
  );
}

// ── Profile sheet ─────────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  final UserModel? user;
  const _ProfileSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  AppColors.primaryOverlay,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 0.5),
            ),
            child: Center(
              child: Text(
                user?.initials ?? 'U',
                style: AppTextStyles.heading2.copyWith(color: AppColors.primaryLight),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(user?.name ?? 'User', style: AppTextStyles.heading3),
          const SizedBox(height: 4),
          Text(user?.email ?? '',    style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        AppColors.primaryOverlay,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user?.displayRole ?? '',
              style: AppTextStyles.captionMedium.copyWith(color: AppColors.primaryLight),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side:           const BorderSide(color: AppColors.borderColor, width: 0.5),
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: () {
                Navigator.pop(context);
                context.push(RouteNames.reports);
              },
              icon:  const Icon(Icons.description_outlined, size: 18),
              label: const Text('Reports'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side:           const BorderSide(color: AppColors.borderColor, width: 0.5),
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: () {
                Navigator.pop(context);
                context.push(RouteNames.settings);
              },
              icon:  const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Settings'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorOverlay,
                foregroundColor: AppColors.error,
                elevation:       0,
              ),
              onPressed: () {
                Navigator.pop(context);
                context.read<AuthProvider>().logout();
              },
              icon:  const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Dashboard tab ─────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  final List<Animation<double>> cardAnims;
  final Future<void> Function()  onRefresh;

  const _DashboardTab({required this.cardAnims, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh:       onRefresh,
      color:           AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overview', style: AppTextStyles.overline),
            const SizedBox(height: AppConstants.paddingMD),
            Consumer<DashboardProvider>(
              builder: (_, dash, __) => _CardsGrid(dash: dash, cardAnims: cardAnims),
            ),
            const SizedBox(height: AppConstants.paddingXL),
            _VoicePromptBanner(),
            const SizedBox(height: AppConstants.paddingXL),
            const Text('Quick stats', style: AppTextStyles.overline),
            const SizedBox(height: AppConstants.paddingMD),
            Consumer<DashboardProvider>(
              builder: (_, dash, __) => _QuickStats(dash: dash),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _CardsGrid extends StatelessWidget {
  final DashboardProvider       dash;
  final List<Animation<double>> cardAnims;

  const _CardsGrid({required this.dash, required this.cardAnims});

  @override
  Widget build(BuildContext context) {
    final isLoading = dash.isLoading;
    final att       = dash.attendance;
    final fees      = dash.fees;
    final fac       = dash.faculty;

    final cards = [
      DashboardCard(
        title:       'Attendance Today',
        value:       isLoading ? '—' : '${att.presentPercent.round()}%',
        subtitle:    isLoading ? null : '${att.present} present · ${att.absent} absent',
        icon:        Icons.people_outline_rounded,
        accentColor: AppColors.primary,
        isLoading:   isLoading,
        bottomWidget: isLoading ? null : AttendanceBar(
          percent: att.presentPercent / 100,
          color: att.presentPercent >= 75 ? AppColors.primary : AppColors.warning,
        ),
      ),
      DashboardCard(
        title:       'Fee Collection',
        value:       isLoading ? '—' : '${fees.collectionPercent.toStringAsFixed(0)}%',
        subtitle:    isLoading ? null : '₹${_fmt(fees.collected)} collected',
        icon:        Icons.account_balance_wallet_outlined,
        accentColor: AppColors.success,
        isLoading:   isLoading,
        bottomWidget: isLoading ? null : AttendanceBar(
          percent: fees.collectionPercent / 100,
          color:   AppColors.success,
        ),
      ),
      DashboardCard(
        title:       'Faculty Present',
        value:       isLoading ? '—' : '${fac.present} / ${fac.total}',
        subtitle:    isLoading ? null : '${fac.absent} on leave today',
        icon:        Icons.school_outlined,
        accentColor: AppColors.accent,
        isLoading:   isLoading,
        bottomWidget: fac.total > 0
            ? FacultyDots(total: fac.total.clamp(0, 12), present: fac.present.clamp(0, 12))
            : null,
      ),
      DashboardCard(
        title:       'Notifications',
        value:       '${dash.unreadNotifications}',
        subtitle:    dash.unreadNotifications > 0 ? 'Unread alerts' : 'All caught up ✓',
        icon:        Icons.notifications_outlined,
        accentColor: AppColors.warning,
        isLoading:   isLoading,
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor:    AppColors.surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXL),
            ),
          ),
          builder: (_) => const _NotificationsSheet(),
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:    const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        crossAxisSpacing: AppConstants.paddingMD,
        mainAxisSpacing:  AppConstants.paddingMD,
        childAspectRatio: 1.0,
      ),
      itemCount:   cards.length,
      itemBuilder: (_, i) => FadeTransition(
        opacity: cardAnims[i],
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end:   Offset.zero,
          ).animate(cardAnims[i]),
          child: cards[i],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _VoicePromptBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(RouteNames.voice),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.accent.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25), width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        AppColors.primaryOverlay,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Consumer<VoiceProvider>(
                builder: (_, vp, __) => Icon(
                  vp.isListening   ? Icons.mic_rounded
                      : vp.isProcessing ? Icons.psychology_rounded
                      : Icons.mic_none_rounded,
                  color: AppColors.primaryLight,
                  size:  20,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMD),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask AI anything',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '"Show MCA attendance" · "Fees pending?" · "Faculty status"',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textDisabled, size: 13),
          ],
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final DashboardProvider dash;
  const _QuickStats({required this.dash});

  @override
  Widget build(BuildContext context) {
    if (dash.isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 1.5),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border:       Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          _statItem('Students',
              dash.attendance.total > 0 ? '${dash.attendance.total}' : '—',
              Icons.people_rounded, AppColors.primary),
          _div(),
          _statItem('Absent', '${dash.attendance.absent}',
              Icons.person_off_rounded, AppColors.error),
          _div(),
          _statItem('Overdue', '${dash.fees.overdueCount}',
              Icons.warning_amber_rounded, AppColors.warning),
          _div(),
          _statItem('Faculty', '${dash.faculty.total}',
              Icons.school_rounded, AppColors.accent),
        ],
      ),
    );
  }

  Widget _statItem(String lbl, String val, IconData icon, Color color) =>
      Expanded(
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: color,
            )),
            Text(lbl,
                style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _div() => Container(width: 0.5, height: 40, color: AppColors.borderColor);
}

// ── Bottom nav ────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int               currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:  AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppConstants.navBarHeight,
          child: Row(
            children: [
              _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard',
                  index: 0, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.mic_none_rounded,   label: 'Voice',
                  index: 1, current: currentIndex, onTap: onTap),
              const Expanded(child: SizedBox()),
              _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat',
                  index: 2, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.bar_chart_rounded,  label: 'Analytics',
                  index: 3, current: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData          icon;
  final String            label;
  final int               index;
  final int               current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,  required this.label,
    required this.index, required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap:    () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppConstants.animFast,
              height: 2, width: active ? 22 : 0,
              decoration: BoxDecoration(
                color:        AppColors.primary,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: AppConstants.animFast,
              child: Icon(
                icon,
                key:   ValueKey(active),
                color: active ? AppColors.primaryLight : AppColors.textMuted,
                size:  22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w500,
                color:    active ? AppColors.primaryLight : AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _MicFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (_, vp, __) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape:    BoxShape.circle,
            gradient: LinearGradient(
              colors: vp.isListening
                  ? [AppColors.primaryLight, AppColors.primary]
                  : [AppColors.primary,      AppColors.primaryDark],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color:       AppColors.primary.withValues(alpha: vp.isListening ? 0.55 : 0.35),
                blurRadius:  vp.isListening ? 20 : 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            vp.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: Colors.white, size: 26,
          ),
        ),
      ),
    );
  }
}
