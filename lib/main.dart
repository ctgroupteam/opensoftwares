import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'core/constants.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'views/auth/login_screen.dart';
import 'views/main_navigation_screen.dart';
import 'views/quick_alert/quick_alert_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation & status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppConstants.pureWhite,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Supabase (with client-safe URL and anon key only)
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  // Initialize Firebase Core & Push Notifications
  try {
    await Firebase.initializeApp();
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  runApp(
    const ProviderScope(
      child: OpenSoftwaresCrmApp(),
    ),
  );
}

class OpenSoftwaresCrmApp extends ConsumerStatefulWidget {
  const OpenSoftwaresCrmApp({super.key});

  @override
  ConsumerState<OpenSoftwaresCrmApp> createState() => _OpenSoftwaresCrmAppState();
}

class _OpenSoftwaresCrmAppState extends ConsumerState<OpenSoftwaresCrmApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Setup deep linking from notification taps
    NotificationService.onNotificationClick.listen((data) {
      final target = data['payload'] ?? data['target_screen'] ?? '';
      if (target == 'quick_alert' || data['actionId'] != null) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const QuickAlertScreen()),
        );
      }
    });

    // Check for GitHub updates silently in the background after launch
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final ctx = _navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        UpdateService.instance.checkForUpdates(ctx, silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _buildHomeState(authState),
    );
  }

  Widget _buildHomeState(AuthState state) {
    if (state.isLoading) {
      return Scaffold(
        body: GradientBackdrop(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppConstants.pureWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppConstants.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.darkBlue.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppConstants.darkBlue,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.isAuthenticated) {
      return const MainNavigationScreen();
    }

    return const LoginScreen();
  }
}
