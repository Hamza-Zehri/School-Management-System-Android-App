import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/extended_providers.dart';
import '../../models/models.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'test_result_screen.dart';
import 'create_test_screen.dart';

class TestHistoryScreen extends ConsumerStatefulWidget {
  const TestHistoryScreen({super.key});
  @override
  ConsumerState<TestHistoryScreen> createState() => _State();
}
class _State extends ConsumerState<TestHistoryScreen> {
  int? _classId, _sectionId, _subjectId;
  List<SchoolClass> _classes = [];
  List<Section> _sections = [];
  List<Subject> _subjects = [];

  @override
  void initState() { super.initState(); _loadClasses(); }
  Future<void> _loadClasses() async {
    final c = await ExtendedDatabaseHelper.instance.getAllClasses();
    setState(() => _classes = c);
  }
  Future<void> _onClassChanged(int? v) async {
    setState(() { _classId = v; _sectionId = null; _subjectId = null; _sections = []; _subjects = []; });
    if (v != null) {
      final s = await ExtendedDatabaseHelper.instance.getSectionsByClass(v);
      final sub = await ExtendedDatabaseHelper.instance.getSubjectsByClass(v);
      setState(() { _sections = s; _subjects = sub; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = TestFilter(classId: _classId, sectionId: _sectionId, subjectId: _subjectId);
    final testsAsync = ref.watch(studentTestsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test History'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTestScreen()));
            if (result == true) ref.invalidate(studentTestsProvider);
          }),
        ],
      ),
      body: Column(children: [
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            DropdownButtonFormField<int>(
              initialValue: _classId, hint: const Text('All Classes'), decoration: const InputDecoration(labelText: 'Class', isDense: true),
              items: [const DropdownMenuItem(value: null, child: Text('All Classes')), ..._classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className)))],
              onChanged: _onClassChanged,
            ),
            if (_sections.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButtonFormField<int>(
                  initialValue: _sectionId, hint: const Text('All Sections'), decoration: const InputDecoration(labelText: 'Section', isDense: true),
                  items: [const DropdownMenuItem(value: null, child: Text('All')), ..._sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sectionName)))],
                  onChanged: (v) => setState(() => _sectionId = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<int>(
                  initialValue: _subjectId, hint: const Text('All Subjects'), decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                  items: [const DropdownMenuItem(value: null, child: Text('All')), ..._subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.subjectName)))],
                  onChanged: (v) => setState(() => _subjectId = v),
                )),
              ]),
            ],
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: testsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (tests) => tests.isEmpty
            ? EmptyState(message: 'No tests found\nTap + to create a new test', icon: Icons.quiz_outlined,
                actionLabel: 'Create Test', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTestScreen())).then((_) => ref.invalidate(studentTestsProvider)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                itemCount: tests.length,
                itemBuilder: (ctx, i) => _TestTile(test: tests[i]),
              ),
        )),
      ]),
    );
  }
}

class _TestTile extends StatelessWidget {
  final StudentTest test;
  const _TestTile({required this.test});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.quiz_outlined, color: AppTheme.primary, size: 22)),
        title: Text(test.title ?? '${test.subjectName ?? ''} Test', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${test.className ?? ''} - ${test.sectionName ?? ''} • ${test.subjectName ?? ''}', style: const TextStyle(fontSize: 12)),
          Text(test.testDate, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TestResultScreen(test: test))),
      ),
    );
  }
}
