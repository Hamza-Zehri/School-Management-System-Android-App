import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/sms_service.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _State();
}
class _State extends ConsumerState<AttendanceScreen> {
  int? _classId, _sectionId;
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  List<SchoolClass> _classes = [];
  List<Section> _sections = [];
  List<Student> _students = [];
  Map<int, String> _statusMap = {};
  bool _sendSms = false, _saving = false;

  @override
  void initState() { super.initState(); _loadClasses(); }

  Future<void> _loadClasses() async {
    final c = await ExtendedDatabaseHelper.instance.getAllClasses();
    setState(() => _classes = c);
  }

  Future<void> _onClassChanged(int? v) async {
    setState(() { _classId = v; _sectionId = null; _sections = []; _students = []; _statusMap = {}; });
    if (v != null) {
      final s = await ExtendedDatabaseHelper.instance.getSectionsByClass(v);
      setState(() => _sections = s);
    }
  }

  Future<void> _loadStudents() async {
    if (_classId == null || _sectionId == null) return;
    final students = await ExtendedDatabaseHelper.instance.getStudentsByClassSection(_classId!, _sectionId!, isActive: true);
    final existing = await ExtendedDatabaseHelper.instance.getAttendanceByClassSectionDate(_classId!, _sectionId!, _date);
    final existingMap = {for (final a in existing) a.studentId: a.status};
    final statusMap = <int, String>{};
    for (final s in students) {
      statusMap[s.id!] = existingMap[s.id] ?? 'present';
    }
    setState(() { _students = students; _statusMap = statusMap; });
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) { showSnack(context, 'Load students first', isError: true); return; }
    setState(() => _saving = true);
    final records = _students.map((s) => Attendance(studentId: s.id!, attendanceDate: _date, status: _statusMap[s.id!] ?? 'present')).toList();
    await ExtendedDatabaseHelper.instance.saveAttendanceBatch(records);
    if (_sendSms) {
      final absentRecords = records.where((r) => r.status == 'absent').toList();
      // Enrich with student details
      final absentWithDetails = <Attendance>[];
      for (final r in absentRecords) {
        final s = _students.firstWhere((st) => st.id == r.studentId);
        absentWithDetails.add(Attendance(studentId: r.studentId, attendanceDate: _date, status: 'absent',
          studentName: s.fullName, guardianPhone: s.guardianPhone,
          className: _classes.firstWhere((c) => c.id == _classId).className,
          sectionName: _sections.firstWhere((sec) => sec.id == _sectionId).sectionName,
        ));
      }
      final result = await SmsService.instance.sendAbsentSmsBatch(absentStudents: absentWithDetails, date: _date);
      if (mounted) showSnack(context, 'Attendance saved. SMS: ${result['sent']} sent, ${result['failed']} failed');
    } else {
      if (mounted) showSnack(context, 'Attendance saved successfully');
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Column(children: [
        // Filter row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: _classId, hint: const Text('Class'), decoration: const InputDecoration(labelText: 'Class', isDense: true),
                items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className))).toList(),
                onChanged: _onClassChanged,
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: _sectionId, hint: const Text('Section'), decoration: const InputDecoration(labelText: 'Section', isDense: true),
                items: _sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sectionName))).toList(),
                onChanged: (v) { setState(() { _sectionId = v; _students = []; }); },
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.parse(_date), firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) { setState(() => _date = d.toIso8601String().substring(0, 10)); _loadStudents(); }
                },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', isDense: true, suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)),
                  child: Text(_date)),
              )),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _loadStudents, child: const Text('Load')),
            ]),
          ]),
        ),
        const Divider(height: 1),
        // Quick actions
        if (_students.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Text('${_students.length} students', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              _quickBtn('All Present', 'present', AppTheme.accent),
              const SizedBox(width: 6),
              _quickBtn('All Absent', 'absent', AppTheme.danger),
            ]),
          ),
        Expanded(
          child: _students.isEmpty
            ? EmptyState(message: _classId == null ? 'Select class and section\nthen tap Load' : 'No students found', icon: Icons.fact_check_outlined)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                itemCount: _students.length,
                itemBuilder: (ctx, i) {
                  final s = _students[i];
                  final status = _statusMap[s.id!] ?? 'present';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(s.fullName.substring(0,1), style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          Text('Roll: ${s.rollNo}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ])),
                        _statusToggle(s.id!, status),
                      ]),
                    ),
                  );
                },
              ),
        ),
        // Bottom bar
        if (_students.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.sms_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Text('Send absent SMS to guardians', style: TextStyle(fontSize: 13)),
                const Spacer(),
                Switch(value: _sendSms, onChanged: (v) => setState(() => _sendSms = v), activeThumbColor: AppTheme.primary),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveAttendance,
                  child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Attendance'),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _quickBtn(String label, String status, Color color) => OutlinedButton(
    onPressed: () => setState(() { for (final s in _students) {
      _statusMap[s.id!] = status;
    } }),
    style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );

  Widget _statusToggle(int studentId, String status) {
    const statuses = ['present', 'absent', 'late', 'leave'];
    const colors = [AppTheme.accent, AppTheme.danger, AppTheme.warning, AppTheme.info];
    return SegmentedButton<String>(
      segments: statuses.asMap().entries.map((e) => ButtonSegment<String>(
        value: e.value,
        label: Text(e.value[0].toUpperCase(), style: const TextStyle(fontSize: 10)),
      )).toList(),
      selected: {status},
      onSelectionChanged: (s) => setState(() => _statusMap[studentId] = s.first),
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 10)),
        minimumSize: WidgetStateProperty.all(const Size(28, 28)),
      ),
    );
  }
}
