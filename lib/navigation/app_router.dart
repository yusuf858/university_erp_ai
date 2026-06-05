import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/main_dashboard.dart';
import '../screens/voice/voice_assistant_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/reports/reports_screen.dart';

class RouteNames {
  RouteNames._();
  static const String splash    = '/';
  static const String login     = '/login';
  static const String dashboard = '/dashboard';
  static const String voice     = '/voice';
  static const String chat      = '/chat';
  static const String analytics = '/analytics';
  static const String settings  = '/settings';
  static const String reports   = '/reports';
}

class AppRouter {
  AppRouter._();

  static GoRouter create(AuthProvider authProvider) {
    return GoRouter(
      initialLocation:   RouteNames.splash,
      refreshListenable: authProvider,
      redirect: (context, state) {
        final status   = authProvider.status;
        final location = state.matchedLocation;

        if (status == AuthStatus.idle || status == AuthStatus.loading) {
          return location == RouteNames.splash ? null : RouteNames.splash;
        }

        final isAuth   = status == AuthStatus.authenticated;
        final onSplash = location == RouteNames.splash;
        final onLogin  = location == RouteNames.login;

        if (!isAuth && !onLogin)             return RouteNames.login;
        if (isAuth && (onLogin || onSplash)) return RouteNames.dashboard;
        return null;
      },
      routes: [
        GoRoute(
          path:        RouteNames.splash,
          pageBuilder: (_, s) => _fade(s, const SplashScreen()),
        ),
        GoRoute(
          path:        RouteNames.login,
          pageBuilder: (_, s) => _fade(s, const LoginScreen()),
        ),
        GoRoute(
          path:        RouteNames.dashboard,
          pageBuilder: (_, s) => _fade(s, const MainDashboard()),
        ),
        GoRoute(
          path:        RouteNames.voice,
          pageBuilder: (_, s) => _slideUp(s, const VoiceAssistantScreen()),
        ),
        GoRoute(
          path:        RouteNames.chat,
          pageBuilder: (_, s) => _slide(s, const ChatScreen()),
        ),
        GoRoute(
          path:        RouteNames.analytics,
          pageBuilder: (_, s) => _slide(s, const AnalyticsScreen()),
        ),
        GoRoute(
          path:        RouteNames.settings,
          pageBuilder: (_, s) => _slide(s, const SettingsScreen()),
        ),
        GoRoute(
          path:        RouteNames.reports,
          pageBuilder: (_, s) => _slide(s, const ReportsScreen()),
        ),
      ],
      errorBuilder: (_, state) => Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: Center(child: Text('Page not found: ${state.error}',
            style: const TextStyle(color: Colors.white70))),
      ),
    );
  }

  static CustomTransitionPage _fade(GoRouterState s, Widget child) =>
      CustomTransitionPage(
        key: s.pageKey, child: child,
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      );

  static CustomTransitionPage _slide(GoRouterState s, Widget child) =>
      CustomTransitionPage(
        key: s.pageKey, child: child,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, a, __, c) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: FadeTransition(opacity: a, child: c),
        ),
      );

  static CustomTransitionPage _slideUp(GoRouterState s, Widget child) =>
      CustomTransitionPage(
        key: s.pageKey, child: child,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, a, __, c) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: c,
        ),
      );
}
