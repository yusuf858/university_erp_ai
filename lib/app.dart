import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'navigation/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/voice_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/reports_provider.dart';
import 'themes/app_theme.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthProvider      _authProvider;
  late final DashboardProvider _dashProvider;
  late final VoiceProvider     _voiceProvider;
  late final ChatProvider      _chatProvider;
  late final AnalyticsProvider _analyticsProvider;
  late final ReportsProvider   _reportsProvider;

  @override
  void initState() {
    super.initState();
    _authProvider      = AuthProvider();
    _dashProvider      = DashboardProvider();
    _voiceProvider     = VoiceProvider(_dashProvider);
    _chatProvider      = ChatProvider(_dashProvider);
    _analyticsProvider = AnalyticsProvider();
    _reportsProvider   = ReportsProvider();
  }

  @override
  void dispose() {
    _authProvider.dispose();
    _dashProvider.dispose();
    _voiceProvider.dispose();
    _chatProvider.dispose();
    _analyticsProvider.dispose();
    _reportsProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _dashProvider),
        ChangeNotifierProvider.value(value: _voiceProvider),
        ChangeNotifierProvider.value(value: _chatProvider),
        ChangeNotifierProvider.value(value: _analyticsProvider),
        ChangeNotifierProvider.value(value: _reportsProvider),
      ],
      child: Builder(
        builder: (context) {
          final router = AppRouter.create(
            context.read<AuthProvider>(),
          );
          return MaterialApp.router(
            title:            'University ERP AI',
            theme:            AppTheme.dark(),
            routerConfig:     router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
