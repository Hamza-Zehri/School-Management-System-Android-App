import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../setup/school_setup_screen.dart';
import '../backup_restore/backup_restore_screen.dart';
import '../sms/sms_screen.dart';
import '../fees/fee_structure_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolAsync = ref.watch(schoolSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: schoolAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (school) =>
            ListView(padding: const EdgeInsets.all(16), children: [
          if (school != null)
            Card(
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.school,
                        color: AppTheme.primary, size: 24)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(school.schoolName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(school.schoolPhone,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ])),
                TextButton(
                    onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    SchoolSetupScreen(existing: school)))
                        .then((_) => ref.invalidate(schoolSettingsProvider)),
                    child: const Text('Edit')),
              ]),
            )),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Preference'),
          Card(
            child: SwitchListTile(
              secondary: Icon(ref.watch(themeModeProvider) == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode, color: AppTheme.primary),
              title: const Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: ref.watch(themeModeProvider) == ThemeMode.dark,
              onChanged: (v) => ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light,
            ),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Management'),
          _tile(context, 'Fee Structure', 'Set monthly fee per class',
              Icons.payments_outlined, const FeeStructureScreen()),
          _tile(context, 'SMS Templates', 'Edit automated SMS messages',
              Icons.message_outlined, const SmsScreen()),
          _tile(context, 'Backup & Restore', 'Manage data backups',
              Icons.backup_outlined, const BackupRestoreScreen()),
          const SizedBox(height: 16),
          const SectionHeader(title: 'About'),
          const Card(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoRow(label: 'App Name', value: 'School Manager'),
                  InfoRow(label: 'Version', value: '1.0.0'),
                  InfoRow(label: 'Developer', value: 'Engr. Hamza Asad'),
                  InfoRow(
                      label: 'DB Version', value: '2 (with Employees & Tests)'),
                  InfoRow(label: 'Mode', value: '100% Offline'),
                  InfoRow(label: 'Platform', value: 'Android'),
                  InfoRow(label: 'Database', value: 'SQLite (Local)'),
                ]),
          )),
        ]),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, String subtitle,
          IconData icon, Widget screen) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: AppTheme.primary, size: 20)),
          title: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, size: 16),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => screen)),
        ),
      );
}
