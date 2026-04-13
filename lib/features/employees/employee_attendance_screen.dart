import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/extended_providers.dart';
import '../../core/services/employee_service.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class EmployeeAttendanceScreen extends ConsumerStatefulWidget {
  const EmployeeAttendanceScreen({super.key});
  @override
  ConsumerState<EmployeeAttendanceScreen> createState() => _State();
}
class _State extends ConsumerState<EmployeeAttendanceScreen> {
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  List<Employee> _employees = [];
  Map<int, String> _statusMap = {};
  bool _loading = false, _saving = false;

  @override
  void initState() { super.initState(); _loadEmployees(); }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    final emps = await ExtendedDatabaseHelper.instance.getAllEmployees(isActive: true);
    final existing = await ExtendedDatabaseHelper.instance.getEmployeeAttendanceByDate(_date);
    final existingMap = {for (final a in existing) a.employeeId: a.status};
    final statusMap = <int, String>{};
    for (final e in emps) {
      statusMap[e.id!] = existingMap[e.id] ?? 'Present';
    }
    setState(() { _employees = emps; _statusMap = statusMap; _loading = false; });
  }

  Future<void> _save() async {
    if (_employees.isEmpty) { showSnack(context, 'No employees loaded', isError: true); return; }
    setState(() => _saving = true);
    final records = _employees.map((e) => EmployeeAttendance(employeeId: e.id!, attendanceDate: _date, status: _statusMap[e.id!] ?? 'Present')).toList();
    await ExtendedDatabaseHelper.instance.saveEmployeeAttendanceBatch(records);
    // Send SMS to absent employees
    final absentRecords = records.where((r) => r.status == 'Absent').toList();
    for (final r in absentRecords) {
      await EmployeeService.instance.sendEmployeeAbsentSms(r);
    }
    setState(() => _saving = false);
    if (mounted) showSnack(context, 'Attendance saved for ${records.length} employees');
    ref.invalidate(employeeAttendanceByDateProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime.parse(_date), firstDate: DateTime(2020), lastDate: DateTime.now());
              if (d != null) { setState(() { _date = d.toIso8601String().substring(0, 10); _employees = []; _statusMap = {}; }); _loadEmployees(); }
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', isDense: true, suffixIcon: Icon(Icons.calendar_today_outlined, size: 16)), child: Text(_date)),
          )),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _loadEmployees, child: const Text('Reload')),
        ]),
      ),
      if (_employees.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Text('${_employees.length} employees', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            _qBtn('All Present', 'Present', AppTheme.accent),
            const SizedBox(width: 6),
            _qBtn('All Absent', 'Absent', AppTheme.danger),
          ]),
        ),
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
            ? const EmptyState(message: 'Tap Reload to load employees', icon: Icons.people_outline)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                itemCount: _employees.length,
                itemBuilder: (ctx, i) {
                  final e = _employees[i];
                  final status = _statusMap[e.id!] ?? 'Present';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(e.fullName.substring(0,1), style: const TextStyle(color: AppTheme.primary, fontSize: 12))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.fullName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          Text(e.designation, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ])),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Present', label: Text('P', style: TextStyle(fontSize: 10))),
                            ButtonSegment(value: 'Absent', label: Text('A', style: TextStyle(fontSize: 10))),
                            ButtonSegment(value: 'Leave', label: Text('L', style: TextStyle(fontSize: 10))),
                          ],
                          selected: {status},
                          onSelectionChanged: (s) => setState(() => _statusMap[e.id!] = s.first),
                          style: ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(28, 32))),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
      if (_employees.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Employee Attendance'),
            ),
          ),
        ),
    ]);
  }

  Widget _qBtn(String label, String status, Color color) => OutlinedButton(
    onPressed: () => setState(() { for (final e in _employees) {
      _statusMap[e.id!] = status;
    } }),
    style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}
