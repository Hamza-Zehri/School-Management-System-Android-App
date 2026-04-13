import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/extended_providers.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class TestResultScreen extends ConsumerWidget {
  final StudentTest test;
  const TestResultScreen({super.key, required this.test});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marksAsync = ref.watch(testMarksByTestProvider(test.id!));

    return Scaffold(
      appBar: AppBar(title: Text(test.title ?? '${test.subjectName} Test')),
      body: marksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (marks) {
          if (marks.isEmpty) return const EmptyState(message: 'No marks recorded', icon: Icons.grade_outlined);
          // Summary stats
          final totalObtained = marks.fold<double>(0, (s, m) => s + m.obtainedMarks);
          final avg = marks.isNotEmpty ? totalObtained / marks.length : 0;
          final highest = marks.reduce((a, b) => a.obtainedMarks > b.obtainedMarks ? a : b);
          final lowest = marks.reduce((a, b) => a.obtainedMarks < b.obtainedMarks ? a : b);

          return Column(children: [
            // Header
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InfoRow(label: 'Subject', value: test.subjectName ?? '-'),
                InfoRow(label: 'Class', value: '${test.className ?? ''} - ${test.sectionName ?? ''}'),
                InfoRow(label: 'Date', value: test.testDate),
                InfoRow(label: 'Students', value: '${marks.length}'),
                const Divider(height: 16),
                Row(children: [
                  _stat(context, 'Avg Score', avg.toStringAsFixed(1), AppTheme.primary),
                  _stat(context, 'Highest', highest.obtainedMarks.toStringAsFixed(0), AppTheme.accent),
                  _stat(context, 'Lowest', lowest.obtainedMarks.toStringAsFixed(0), AppTheme.danger),
                ]),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              itemCount: marks.length,
              itemBuilder: (ctx, i) {
                final m = marks[i];
                final gradeColor = m.grade == 'A+' || m.grade == 'A' ? AppTheme.accent
                    : m.grade == 'B' || m.grade == 'C' ? AppTheme.warning
                    : AppTheme.danger;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      CircleAvatar(radius: 14, backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        child: Text(m.rollNo ?? '${i+1}', style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.studentName ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        if (m.remarks != null) Text(m.remarks!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${m.obtainedMarks.toStringAsFixed(0)}/${m.totalMarks.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${m.percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]),
                      const SizedBox(width: 8),
                      Container(width: 32, height: 32, decoration: BoxDecoration(color: gradeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Center(child: Text(m.grade, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: gradeColor)))),
                    ]),
                  ),
                );
              },
            )),
          ]);
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String val, Color color) => Expanded(child: Column(children: [
    Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]));
}
