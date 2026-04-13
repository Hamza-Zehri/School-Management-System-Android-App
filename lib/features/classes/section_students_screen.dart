import 'package:flutter/material.dart';
import '../../core/db/extended_database_helper.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../students/student_profile_screen.dart';

class SectionStudentsScreen extends StatelessWidget {
  final SchoolClass cls;
  final Section section;

  const SectionStudentsScreen({super.key, required this.cls, required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${cls.className} - ${section.sectionName}'),
      ),
      body: FutureBuilder<List<Student>>(
        future: ExtendedDatabaseHelper.instance.getStudentsByClassSection(cls.id!, section.id!),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final students = snap.data ?? [];
          if (students.isEmpty) return const EmptyState(message: 'No students in this section', icon: Icons.people_outline);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (ctx, i) {
              final s = students[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                    child: Text(s.fullName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Roll No: ${s.rollNo} | Reg: ${s.registrationNo}', style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfileScreen(studentId: s.id!))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
