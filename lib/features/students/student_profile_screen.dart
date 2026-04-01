import 'package:flutter/material.dart';
import '../../core/db/extended_database_helper.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'add_edit_student_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final int studentId;
  const StudentProfileScreen({super.key, required this.studentId});
  @override
  State<StudentProfileScreen> createState() => _State();
}
class _State extends State<StudentProfileScreen> {
  Student? _student;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = await ExtendedDatabaseHelper.instance.getStudentById(widget.studentId);
    if (mounted) setState(() => _student = s);
  }

  @override
  Widget build(BuildContext context) {
    if (_student == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = _student!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditStudentScreen(student: s)));
            _load();
          }),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header card
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(radius: 32, backgroundColor: AppTheme.primary.withOpacity(0.12),
                child: Text(s.fullName.substring(0,1).toUpperCase(), style: const TextStyle(fontSize: 24, color: AppTheme.primary, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${s.className ?? ''} - ${s.sectionName ?? ''}', style: const TextStyle(color: AppTheme.textSecondary)),
                Text('Reg: ${s.registrationNo}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
              StatusChip(status: s.isActive ? 'active' : 'inactive'),
            ]),
          )),
          const SizedBox(height: 12),
          const SectionHeader(title: 'Student Information'),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              InfoRow(label: 'Roll No', value: s.rollNo),
              InfoRow(label: 'Father Name', value: s.fatherName),
              InfoRow(label: 'Guardian Name', value: s.guardianName),
              InfoRow(label: 'Guardian Phone', value: s.guardianPhone),
              if (s.guardianPhone2 != null) InfoRow(label: 'Guardian Phone 2', value: s.guardianPhone2!),
              InfoRow(label: 'Gender', value: s.gender),
              if (s.dob != null) InfoRow(label: 'Date of Birth', value: s.dob!),
              if (s.address != null) InfoRow(label: 'Address', value: s.address!),
            ]),
          )),
        ]),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(context, title: 'Delete Student', message: 'This will permanently delete "${_student!.fullName}". All their records will remain.');
    if (ok) {
      await ExtendedDatabaseHelper.instance.deleteStudent(widget.studentId);
      if (mounted) Navigator.pop(context);
    }
  }
}
