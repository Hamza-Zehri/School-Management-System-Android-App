import 'package:flutter/material.dart';
import '../../core/db/extended_database_helper.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class StudentAttendanceHistoryScreen extends StatefulWidget {
  final Student? preselectedStudent;
  const StudentAttendanceHistoryScreen({super.key, this.preselectedStudent});
  @override
  State<StudentAttendanceHistoryScreen> createState() => _State();
}
class _State extends State<StudentAttendanceHistoryScreen> {
  List<Student> _students = [];
  Student? _selected;
  String? _fromDate, _toDate;
  List<Attendance> _history = [];
  Map<String, int> _summary = {};
  bool _loading = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
    if (widget.preselectedStudent != null) {
      _selected = widget.preselectedStudent;
    }
  }

  Future<void> _loadStudents() async {
    final s = await ExtendedExtendedDatabaseHelper.instance.getAllStudents(isActive: null);
    setState(() => _students = s);
  }

  Future<void> _loadHistory() async {
    if (_selected == null) return;
    setState(() => _loading = true);
    final history = await ExtendedExtendedDatabaseHelper.instance.getStudentAttendanceHistory(
      studentId: _selected!.id!, fromDate: _fromDate, toDate: _toDate);
    final summary = await ExtendedExtendedDatabaseHelper.instance.getStudentAttendanceSummary(
      _selected!.id!, fromDate: _fromDate, toDate: _toDate);
    setState(() { _history = history; _summary = summary; _loading = false; });
  }

  Future<void> _pickDate(bool isFrom) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) {
      final s = d.toIso8601String().substring(0, 10);
      setState(() { if (isFrom) _fromDate = s; else _toDate = s; });
    }
  }

  List<Student> get _filteredStudents => _search.isEmpty ? _students : _students.where((s) => s.fullName.toLowerCase().contains(_search.toLowerCase()) || s.registrationNo.contains(_search)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Attendance History')),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // Student picker
            InkWell(
              onTap: _pickStudent,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Student', isDense: true, suffixIcon: Icon(Icons.arrow_drop_down)),
                child: Text(_selected != null ? '${_selected!.fullName} (${_selected!.registrationNo})' : 'Tap to select student', style: TextStyle(color: _selected == null ? AppTheme.textSecondary : AppTheme.textPrimary)),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: InkWell(onTap: () => _pickDate(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'From', isDense: true, suffixIcon: Icon(Icons.calendar_today_outlined, size: 14)), child: Text(_fromDate ?? 'Select')))),
              const SizedBox(width: 8),
              Expanded(child: InkWell(onTap: () => _pickDate(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'To', isDense: true, suffixIcon: Icon(Icons.calendar_today_outlined, size: 14)), child: Text(_toDate ?? 'Select')))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _loadHistory, child: const Text('Load')),
            ]),
          ]),
        ),
        if (_summary.isNotEmpty)
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _statBox('Present', _summary['present'] ?? 0, AppTheme.accent),
              _statBox('Absent', _summary['absent'] ?? 0, AppTheme.danger),
              _statBox('Late', _summary['late'] ?? 0, AppTheme.warning),
              _statBox('Leave', _summary['leave'] ?? 0, AppTheme.info),
            ]),
          ),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _history.isEmpty
              ? EmptyState(message: _selected == null ? 'Select a student to view history' : 'No attendance records found', icon: Icons.calendar_month_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: _history.length,
                  itemBuilder: (ctx, i) {
                    final a = _history[i];
                    final color = AppTheme.statusColor(a.status);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Icon(_statusIcon(a.status), color: color, size: 20)),
                        title: Text(a.attendanceDate, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: a.remarks != null ? Text(a.remarks!) : null,
                        trailing: StatusChip(status: a.status),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Future<void> _pickStudent() async {
    final result = await showDialog<Student>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Student'),
        content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            decoration: const InputDecoration(hintText: 'Search name or reg no...', prefixIcon: Icon(Icons.search, size: 18), isDense: true),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 300, child: StatefulBuilder(builder: (ctx, ss) {
            final filtered = _search.isEmpty ? _students : _students.where((s) => s.fullName.toLowerCase().contains(_search.toLowerCase()) || s.registrationNo.contains(_search)).toList();
            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(filtered[i].fullName, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${filtered[i].className ?? ''} | ${filtered[i].registrationNo}', style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(ctx, filtered[i]),
                dense: true,
              ),
            );
          })),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
    if (result != null) {
      setState(() { _selected = result; _history = []; _summary = {}; _search = ''; });
    }
  }

  Widget _statBox(String label, int val, Color color) => Expanded(child: Column(children: [
    Text('$val', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
  ]));

  IconData _statusIcon(String status) {
    switch (status) {
      case 'present': return Icons.check_circle_outline;
      case 'absent': return Icons.cancel_outlined;
      case 'late': return Icons.access_time_outlined;
      default: return Icons.event_note_outlined;
    }
  }
}
