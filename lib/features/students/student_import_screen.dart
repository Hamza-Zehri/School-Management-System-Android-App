import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/excel_import_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class StudentImportScreen extends StatefulWidget {
  const StudentImportScreen({super.key});
  @override
  State<StudentImportScreen> createState() => _State();
}
class _State extends State<StudentImportScreen> {
  bool _loading = false;
  ImportResult? _result;

  Future<void> _downloadTemplate() async {
    setState(() => _loading = true);
    try {
      final path = await ExcelImportService.instance.generateSampleTemplate();
      if (mounted) showSnack(context, 'Template saved: $path');
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', isError: true);
    }
    setState(() => _loading = false);
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    setState(() { _loading = true; _result = null; });
    final importResult = await ExcelImportService.instance.importStudents(path);
    setState(() { _loading = false; _result = importResult; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Students from Excel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.info.withValues(alpha: 0.3))),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.info_outline, color: AppTheme.info, size: 18), SizedBox(width: 8), Text('Required Excel Columns', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.info))]),
              SizedBox(height: 8),
              Text('registration_no, roll_no, full_name, father_name, guardian_name, guardian_phone, guardian_phone_2, class_name, section_name, gender, dob, address',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
              SizedBox(height: 8),
              Text('• Classes and sections are created automatically\n• Existing students (by reg no) are updated\n• New students are inserted', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.6)),
            ]),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Actions'),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _actionTile(Icons.download_outlined, 'Download Sample Template', 'Get a sample .xlsx file with correct column headers', AppTheme.accent, _downloadTemplate),
              const Divider(),
              _actionTile(Icons.upload_file_outlined, 'Import Students from Excel', 'Select your .xlsx file and import students', AppTheme.primary, _importFile),
            ]),
          )),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_result != null) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Import Summary'),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _summaryRow('Added', _result!.added, AppTheme.accent),
                _summaryRow('Updated', _result!.updated, AppTheme.info),
                _summaryRow('Failed', _result!.failed, AppTheme.danger),
                if (_result!.errors.isNotEmpty) ...[
                  const Divider(),
                  const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger)),
                  const SizedBox(height: 4),
                  ..._result!.errors.take(10).map((e) => Text('• $e', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                ],
              ]),
            )),
          ],
        ]),
      ),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  Widget _summaryRow(String label, int count, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 14)),
      const Spacer(),
      Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    ]),
  );
}
