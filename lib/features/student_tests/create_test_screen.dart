import 'package:flutter/material.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/student_test_service.dart';
import '../../models/models.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});
  @override
  State<CreateTestScreen> createState() => _State();
}
class _State extends State<CreateTestScreen> {
  final _titleCtrl = TextEditingController();
  int? _classId, _sectionId, _subjectId;
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  List<SchoolClass> _classes = [];
  List<Section> _sections = [];
  List<Subject> _subjects = [];
  List<Student> _students = [];

  // Marks controllers: studentId -> {total, obtained, remarks}
  final Map<int, TextEditingController> _totalCtrl = {};
  final Map<int, TextEditingController> _obtainedCtrl = {};
  final Map<int, TextEditingController> _remarksCtrl = {};

  bool _sendSms = false, _saving = false, _studentsLoaded = false;

  @override
  void initState() { super.initState(); _loadClasses(); }

  Future<void> _loadClasses() async {
    final c = await ExtendedExtendedDatabaseHelper.instance.getAllClasses();
    setState(() => _classes = c);
  }

  Future<void> _onClassChanged(int? v) async {
    setState(() { _classId = v; _sectionId = null; _subjectId = null; _sections = []; _subjects = []; _students = []; _studentsLoaded = false; });
    if (v != null) {
      final s = await ExtendedExtendedDatabaseHelper.instance.getSectionsByClass(v);
      final sub = await ExtendedExtendedDatabaseHelper.instance.getSubjectsByClass(v);
      setState(() { _sections = s; _subjects = sub; });
    }
  }

  Future<void> _loadStudents() async {
    if (_classId == null || _sectionId == null) { showSnack(context, 'Select class and section', isError: true); return; }
    final students = await ExtendedExtendedDatabaseHelper.instance.getStudentsByClassSection(_classId!, _sectionId!, isActive: true);
    // Init controllers
    _totalCtrl.clear(); _obtainedCtrl.clear(); _remarksCtrl.clear();
    for (final s in students) {
      _totalCtrl[s.id!] = TextEditingController(text: '10');
      _obtainedCtrl[s.id!] = TextEditingController();
      _remarksCtrl[s.id!] = TextEditingController();
    }
    setState(() { _students = students; _studentsLoaded = true; });
  }

  Future<void> _save() async {
    if (!_studentsLoaded || _students.isEmpty) { showSnack(context, 'Load students first', isError: true); return; }
    if (_subjectId == null) { showSnack(context, 'Select a subject', isError: true); return; }

    // Validate marks
    for (final s in _students) {
      final total = double.tryParse(_totalCtrl[s.id!]?.text ?? '');
      final obtained = double.tryParse(_obtainedCtrl[s.id!]?.text ?? '');
      if (total == null || obtained == null) { showSnack(context, 'Enter valid marks for all students', isError: true); return; }
      if (obtained > total) { showSnack(context, '${s.fullName}: Obtained cannot exceed Total marks', isError: true); return; }
    }

    setState(() => _saving = true);

    final test = StudentTest(
      testDate: _date,
      classId: _classId!,
      sectionId: _sectionId!,
      subjectId: _subjectId!,
      title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
    );

    final marks = _students.map((s) => StudentTestMark(
      testId: 0, // will be set by service
      studentId: s.id!,
      totalMarks: double.tryParse(_totalCtrl[s.id!]?.text ?? '10') ?? 10,
      obtainedMarks: double.tryParse(_obtainedCtrl[s.id!]?.text ?? '0') ?? 0,
      remarks: _remarksCtrl[s.id!]?.text.trim().isEmpty == true ? null : _remarksCtrl[s.id!]?.text.trim(),
      studentName: s.fullName,
      guardianPhone: s.guardianPhone,
      rollNo: s.rollNo,
    )).toList();

    final result = await StudentTestService.instance.saveTestWithMarks(test: test, marks: marks, sendSms: _sendSms);

    setState(() => _saving = false);
    if (mounted) {
      showSnack(context, 'Test saved! ${_sendSms ? "SMS: ${result['smsSent']} sent, ${result['smsFailed']} failed" : ""}');
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final c in [..._totalCtrl.values, ..._obtainedCtrl.values, ..._remarksCtrl.values]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Test')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SectionHeader(title: 'Test Details'),
        TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Test Title (optional)', hintText: 'e.g. Unit Test 1, Surprise Quiz')),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: DateTime.parse(_date), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _date = d.toIso8601String().substring(0, 10));
          },
          child: InputDecorator(decoration: const InputDecoration(labelText: 'Test Date', suffixIcon: Icon(Icons.calendar_today_outlined)), child: Text(_date)),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Class & Subject'),
        DropdownButtonFormField<int>(
          value: _classId, hint: const Text('Select Class'), decoration: const InputDecoration(labelText: 'Class'),
          items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className))).toList(),
          onChanged: _onClassChanged,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: DropdownButtonFormField<int>(
            value: _sectionId, hint: const Text('Section'), decoration: const InputDecoration(labelText: 'Section'),
            items: _sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sectionName))).toList(),
            onChanged: (v) => setState(() { _sectionId = v; _students = []; _studentsLoaded = false; }),
          )),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<int>(
            value: _subjectId, hint: const Text('Subject'), decoration: const InputDecoration(labelText: 'Subject'),
            items: _subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.subjectName))).toList(),
            onChanged: (v) => setState(() => _subjectId = v),
          )),
        ]),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.people_outlined), label: const Text('Load Students'), onPressed: _loadStudents)),

        if (_studentsLoaded) ...[
          const SizedBox(height: 16),
          SectionHeader(title: '${_students.length} Students — Enter Marks'),
          // Column headers
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: const [
              Expanded(flex: 3, child: Text('Student', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
              SizedBox(width: 4),
              SizedBox(width: 60, child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.center)),
              SizedBox(width: 4),
              SizedBox(width: 60, child: Text('Obtained', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), textAlign: TextAlign.center)),
              SizedBox(width: 4),
              SizedBox(width: 80, child: Text('Remarks', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
            ]),
          ),
          ..._students.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  Text('Roll: ${s.rollNo}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ])),
                const SizedBox(width: 4),
                SizedBox(width: 60, child: TextFormField(controller: _totalCtrl[s.id!], keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8)))),
                const SizedBox(width: 4),
                SizedBox(width: 60, child: TextFormField(controller: _obtainedCtrl[s.id!], keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8)))),
                const SizedBox(width: 4),
                SizedBox(width: 80, child: TextFormField(controller: _remarksCtrl[s.id!], decoration: const InputDecoration(hintText: 'Good...', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8)))),
              ]),
            ),
          )),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.sms_outlined, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 8),
            const Text('Send result SMS to guardians', style: TextStyle(fontSize: 13)),
            const Spacer(),
            Switch(value: _sendSms, onChanged: (v) => setState(() => _sendSms = v), activeColor: AppTheme.primary),
          ]),
        ],

        const SizedBox(height: 16),
        if (_studentsLoaded)
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Test & Marks', style: TextStyle(fontSize: 16)),
            ),
          ),
        const SizedBox(height: 20),
      ]),
    );
  }
}
