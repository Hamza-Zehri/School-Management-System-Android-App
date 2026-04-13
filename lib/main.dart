import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/theme/app_theme.dart';
import 'core/db/extended_database_helper.dart';
import 'core/services/providers.dart';
import 'features/setup/first_launch_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'core/services/security_service.dart';
import 'shared/widgets/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-initialize the extended DB (runs migrations automatically)
  await ExtendedDatabaseHelper.instance.database;
  runApp(const ProviderScope(child: SchoolManagerApp()));
}

class SchoolManagerApp extends ConsumerWidget {
  const SchoolManagerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'School Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();
  @override
  State<_AppRouter> createState() => _AppRouterState();
}
class _AppRouterState extends State<_AppRouter> {
  bool _loading = true;
  bool _hasSchool = false;
  bool _unlocked = false;

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    final settings = await ExtendedDatabaseHelper.instance.getSchoolSettings();
    final lockEnabled = await SecurityService.instance.isLockEnabled();
    
    // Sync provider state
    if (mounted) {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(appLockEnabledProvider.notifier).state = lockEnabled;
    }

    setState(() {
      _hasSchool = settings != null;
      _unlocked = !lockEnabled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();
    if (!_unlocked) return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
    return _hasSchool ? const DashboardScreen() : const FirstLaunchScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.school, size: 56, color: Colors.white)),
          const SizedBox(height: 24),
          const Text('School Manager', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Offline • Secure • Reliable', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 48),
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
        ]),
      ),
    );
  }
}
