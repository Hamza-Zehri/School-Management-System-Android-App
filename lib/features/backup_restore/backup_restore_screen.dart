import 'package:flutter/material.dart';
import '../../core/services/backup_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});
  @override
  State<BackupRestoreScreen> createState() => _State();
}
class _State extends State<BackupRestoreScreen> {
  bool _loading = false;
  String? _lastMessage;

  Future<void> _createBackup() async {
    setState(() => _loading = true);
    try {
      final path = await BackupService.instance.createBackup();
      setState(() => _lastMessage = 'Backup saved to:\n$path');
      if (mounted) showSnack(context, 'Backup created successfully');
    } catch (e) {
      setState(() => _lastMessage = 'Backup failed: $e');
      if (mounted) showSnack(context, 'Backup failed: $e', isError: true);
    }
    setState(() => _loading = false);
  }

  Future<void> _restoreBackup() async {
    final ok = await showConfirmDialog(context,
      title: 'Restore Backup',
      message: 'This will REPLACE all current data with the backup. This cannot be undone. Continue?',
      confirmText: 'Restore', confirmColor: AppTheme.danger,
    );
    if (!ok) return;
    setState(() => _loading = true);
    final result = await BackupService.instance.restoreFromFile();
    setState(() { _loading = false; _lastMessage = result; });
    if (mounted) showSnack(context, result, isError: !result.contains('successful'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.warning.withOpacity(0.3))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Backups are saved as .json files in:\nDownloads/SchoolManager/Backups/\n\nAfter uninstalling the app, use Restore to recover all data from the backup file.', style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.textPrimary))),
          ]),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Backup'),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Create a full backup of all school data including students, attendance, fees, marks, SMS templates and all other records.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _createBackup,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Create Backup Now'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              ),
            ),
          ]),
        )),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Restore'),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Select a previously exported .json backup file to restore your school data. ALL current data will be replaced.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.warning_amber_outlined, color: AppTheme.danger, size: 16),
                SizedBox(width: 6),
                Expanded(child: Text('⚠ This action REPLACES all current data. Make a backup before restoring.', style: TextStyle(fontSize: 11, color: AppTheme.danger))),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _restoreBackup,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Select Backup File & Restore'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
              ),
            ),
          ]),
        )),
        if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (_lastMessage != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
            child: Text(_lastMessage!, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textPrimary)),
          ),
        ],
      ]),
    );
  }
}
