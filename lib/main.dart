import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared/theme/app_theme.dart';
import 'core/db/extended_database_helper.dart';
import 'features/setup/first_launch_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-initialize the extended DB (runs migrations automatically)
  await ExtendedExtendedDatabaseHelper.instance.database;
  runApp(const ProviderScope(child: SchoolManagerApp()));
}

class SchoolManagerApp extends StatelessWidget {
  const SchoolManagerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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

  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    final settings = await ExtendedExtendedDatabaseHelper.instance.getSchoolSettings();
    setState(() { _hasSchool = settings != null; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();
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
          Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.school, size: 56, color: Colors.white)),
          const SizedBox(height: 24),
          const Text('School Manager', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Offline • Secure • Reliable', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 48),
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
        ]),
      ),
    );
  }
}
