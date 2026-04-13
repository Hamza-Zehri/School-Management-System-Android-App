import 'package:flutter/material.dart';
import '../../core/db/extended_database_helper.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class EmployeeAttendanceHistoryScreen extends StatefulWidget {
  const EmployeeAttendanceHistoryScreen({super.key});
  @override
  State<EmployeeAttendanceHistoryScreen> createState() => _State();
}
class _State extends State<EmployeeAttendanceHistoryScreen> {
  Employee? _selectedEmp;
  List<Employee> _employees = [];
  String? _fromDate, _toDate;
  List<EmployeeAttendance> _history = [];
  Map<String, int> _summary = {};
  bool _loading = false;

  @override
  void initState() { super.initState(); _loadEmployees(); }
  Future<void> _loadEmployees() async {
    final e = await ExtendedDatabaseHelper.instance.getAllEmployees(isActive: null);
    setState(() => _employees = e);
  }

  Future<void> _loadHistory() async {
    if (_selectedEmp == null) return;
    setState(() => _loading = true);
    final history = await ExtendedDatabaseHelper.instance.getEmployeeAttendanceHistory(
      employeeId: _selectedEmp!.id!, fromDate: _fromDate, toDate: _toDate);
    final summary = await ExtendedDatabaseHelper.instance.getEmployeeAttendanceSummary(
      _selectedEmp!.id!, fromDate: _fromDate, toDate: _toDate);
    setState(() { _history = history; _summary = summary; _loading = false; });
  }

  Future<void> _pickDate(bool isFrom) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d != null) {
      final s = d.toIso8601String().substring(0, 10);
      setState(() { if (isFrom) {
        _fromDate = s;
      } else {
        _toDate = s;
      } });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Attendance History')),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            DropdownButtonFormField<Employee>(
              initialValue: _selectedEmp, hint: const Text('Select Employee'), decoration: const InputDecoration(labelText: 'Employee', isDense: true),
              items: _employees.map((e) => DropdownMenuItem(value: e, child: Text('${e.fullName} (${e.employeeId})'))).toList(),
              onChanged: (v) => setState(() { _selectedEmp = v; _history = []; _summary = {}; }),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: InkWell(onTap: () => _pickDate(true), child: InputDecorator(decoration: const InputDecoration(labelText: 'From Date', isDense: true, suffixIcon: Icon(Icons.calendar_today_outlined, size: 14)), child: Text(_fromDate ?? 'Select')))),
              const SizedBox(width: 8),
              Expanded(child: InkWell(onTap: () => _pickDate(false), child: InputDecorator(decoration: const InputDecoration(labelText: 'To Date', isDense: true, suffixIcon: Icon(Icons.calendar_today_outlined, size: 14)), child: Text(_toDate ?? 'Select')))),
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
              _statBox('Present', _summary['Present'] ?? 0, AppTheme.accent),
              _statBox('Absent', _summary['Absent'] ?? 0, AppTheme.danger),
              _statBox('Leave', _summary['Leave'] ?? 0, AppTheme.info),
              _statBox('Total', _history.length, AppTheme.primary),
            ]),
          ),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _history.isEmpty
              ? EmptyState(message: _selectedEmp == null ? 'Select an employee to view history' : 'No attendance records found', icon: Icons.calendar_today_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: _history.length,
                  itemBuilder: (ctx, i) {
                    final a = _history[i];
                    final color = a.status == 'Present' ? AppTheme.accent : a.status == 'Absent' ? AppTheme.danger : AppTheme.info;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Icon(a.status == 'Present' ? Icons.check_circle_outline : a.status == 'Absent' ? Icons.cancel_outlined : Icons.event_note_outlined, color: color, size: 20)),
                        title: Text(a.attendanceDate, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: a.remarks != null ? Text(a.remarks!) : null,
                        trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                          child: Text(a.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _statBox(String label, int val, Color color) => Expanded(child: Column(children: [
    Text('$val', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
  ]));
}
