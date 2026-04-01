import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/providers.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({super.key});
  @override
  ConsumerState<MarksScreen> createState() => _State();
}
class _State extends ConsumerState<MarksScreen> {
  int? _classId, _examId;
  List<SchoolClass> _classes = [];

  @override
  void initState() { super.initState(); _loadClasses(); }
  Future<void> _loadClasses() async { final c = await ExtendedDatabaseHelper.instance.getAllClasses(); setState(() => _classes = c); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marks & Exams'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'New Exam', onPressed: _addExam),
          IconButton(icon: const Icon(Icons.library_books_outlined), tooltip: 'Subjects', onPressed: _manageSubjects),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              initialValue: _classId, hint: const Text('Select Class'), decoration: const InputDecoration(labelText: 'Class', isDense: true),
              items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className))).toList(),
              onChanged: (v) => setState(() { _classId = v; _examId = null; }),
            )),
          ]),
        ),
        const Divider(height: 1),
        if (_classId != null)
          Expanded(child: _buildExamsList()),
      ]),
    );
  }

  Widget _buildExamsList() {
    final examsAsync = ref.watch(examsProvider(_classId));
    return examsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (exams) => exams.isEmpty
        ? EmptyState(message: 'No exams for this class yet', icon: Icons.grade_outlined, actionLabel: 'Add Exam', onAction: _addExam)
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: exams.length,
            itemBuilder: (ctx, i) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined, color: AppTheme.primary),
                title: Text(exams[i].examName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(exams[i].examDate ?? 'Date not set'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openMarksEntry(exams[i]),
              ),
            ),
          ),
    );
  }

  Future<void> _addExam() async {
    if (_classId == null) { showSnack(context, 'Select a class first', isError: true); return; }
    final sections = await ExtendedDatabaseHelper.instance.getSectionsByClass(_classId!);
    if (!mounted) return;
    final nameCtrl = TextEditingController();
    int? sectionId = sections.isNotEmpty ? sections.first.id : null;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: const Text('New Exam'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Exam Name *', hintText: 'e.g. Mid Term 2024'), autofocus: true),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: sectionId, decoration: const InputDecoration(labelText: 'Section'),
            items: sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sectionName))).toList(),
            onChanged: (v) => ss(() => sectionId = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      )),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty && sectionId != null) {
      await ExtendedDatabaseHelper.instance.insertExam(Exam(examName: nameCtrl.text.trim(), classId: _classId!, sectionId: sectionId!));
      ref.invalidate(examsProvider(_classId));
    }
  }

  Future<void> _manageSubjects() async {
    if (_classId == null) { showSnack(context, 'Select a class first', isError: true); return; }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectsScreen(classId: _classId!)));
    ref.invalidate(subjectsProvider(_classId!));
  }

  Future<void> _openMarksEntry(Exam exam) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => MarksEntryScreen(exam: exam)));
  }
}

class SubjectsScreen extends StatefulWidget {
  final int classId;
  const SubjectsScreen({super.key, required this.classId});
  @override
  State<SubjectsScreen> createState() => _SubjState();
}
class _SubjState extends State<SubjectsScreen> {
  List<Subject> _subjects = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final s = await ExtendedDatabaseHelper.instance.getSubjectsByClass(widget.classId); setState(() => _subjects = s); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Subjects')),
    floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
    body: _subjects.isEmpty
      ? const EmptyState(message: 'No subjects added yet', icon: Icons.book_outlined)
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _subjects.length,
          itemBuilder: (ctx, i) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.book_outlined, color: AppTheme.primary),
              title: Text(_subjects[i].subjectName),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.danger), onPressed: () async {
                await ExtendedDatabaseHelper.instance.deleteStudent(_subjects[i].id!); _load();
              }),
            ),
          ),
      ),
  );

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Subject'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Subject Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ExtendedDatabaseHelper.instance.insertSubject(Subject(subjectName: ctrl.text.trim(), classId: widget.classId));
      _load();
    }
  }
}

class MarksEntryScreen extends StatefulWidget {
  final Exam exam;
  const MarksEntryScreen({super.key, required this.exam});
  @override
  State<MarksEntryScreen> createState() => _MEState();
}
class _MEState extends State<MarksEntryScreen> {
  List<Student> _students = [];
  List<Subject> _subjects = [];
  Subject? _subject;
  Map<int, TextEditingController> _totalCtrl = {};
  Map<int, TextEditingController> _obtainedCtrl = {};
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final students = await ExtendedDatabaseHelper.instance.getStudentsByClassSection(widget.exam.classId, widget.exam.sectionId, isActive: true);
    final subjects = await ExtendedDatabaseHelper.instance.getSubjectsByClass(widget.exam.classId);
    setState(() {
      _students = students; _subjects = subjects;
      if (subjects.isNotEmpty) _subject = subjects.first;
      _totalCtrl = {for (final s in students) s.id!: TextEditingController(text: '100')};
      _obtainedCtrl = {for (final s in students) s.id!: TextEditingController()};
    });
  }

  Future<void> _save() async {
    if (_subject == null) { showSnack(context, 'Select subject first', isError: true); return; }
    setState(() => _saving = true);
    final marks = _students.map((s) => Mark(
      examId: widget.exam.id!, studentId: s.id!, subjectId: _subject!.id!,
      totalMarks: double.tryParse(_totalCtrl[s.id!]?.text ?? '0') ?? 0,
      obtainedMarks: double.tryParse(_obtainedCtrl[s.id!]?.text ?? '0') ?? 0,
    )).toList();
    await ExtendedDatabaseHelper.instance.saveMarksBatch(marks);
    if (mounted) { showSnack(context, 'Marks saved'); setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.exam.examName)),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<Subject>(
          initialValue: _subject, decoration: const InputDecoration(labelText: 'Subject'),
          items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.subjectName))).toList(),
          onChanged: (v) => setState(() => _subject = v),
        ),
      ),
      const Divider(height: 1),
      Expanded(child: _students.isEmpty
        ? const EmptyState(message: 'No students in this class/section', icon: Icons.people_outline)
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: _students.length,
            itemBuilder: (ctx, i) {
              final s = _students[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    Expanded(child: Text(s.fullName, style: const TextStyle(fontSize: 13))),
                    SizedBox(width: 70, child: TextFormField(controller: _totalCtrl[s.id!], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total', isDense: true))),
                    const SizedBox(width: 8),
                    SizedBox(width: 70, child: TextFormField(controller: _obtainedCtrl[s.id!], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Obtained', isDense: true))),
                  ]),
                ),
              );
            }
          )),
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Marks'),
          ),
        ),
      ),
    ]),
  );
}
