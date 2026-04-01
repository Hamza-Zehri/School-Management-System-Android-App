import 'package:flutter/material.dart';
import '../../core/services/backup_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'school_setup_screen.dart';
import '../dashboard/dashboard_screen.dart';

class FirstLaunchScreen extends StatelessWidget {
  const FirstLaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Spacer(),
            Container(width: 110, height: 110,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.school, size: 64, color: Colors.white)),
            const SizedBox(height: 28),
            const Text('School Manager', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Complete offline school management\nfor private schools',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.75), height: 1.5)),
            const Spacer(),
            _OptionCard(
              icon: Icons.add_business_outlined,
              title: 'Setup New School',
              subtitle: 'Configure your school details and start fresh',
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SchoolSetupScreen(isFirstRun: true))),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.restore_outlined,
              title: 'Restore From Backup',
              subtitle: 'Import a previous school backup (.json file)',
              onTap: () => _restoreBackup(context),
            ),
            const Spacer(),
            Text('Version 1.0.0  •  100% Offline',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Future<void> _restoreBackup(BuildContext context) async {
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const LoadingOverlay(message: 'Restoring backup...'));
    final result = await BackupService.instance.restoreFromFile();
    if (context.mounted) {
      Navigator.pop(context);
      if (result.contains('successful')) {
        showSnack(context, result);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        showSnack(context, result, isError: true);
      }
    }
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OptionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppTheme.primary, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ])),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textSecondary),
          ]),
        ),
      ),
    );
  }
}
