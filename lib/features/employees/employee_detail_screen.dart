import 'package:flutter/material.dart';
import '../../core/db/extended_database_helper.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'add_edit_employee_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final int employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});
  @override
  State<EmployeeDetailScreen> createState() => _State();
}
class _State extends State<EmployeeDetailScreen> {
  Employee? _emp;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final e = await ExtendedDatabaseHelper.instance.getEmployeeById(widget.employeeId);
    if (mounted) setState(() => _emp = e);
  }

  @override
  Widget build(BuildContext context) {
    if (_emp == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final e = _emp!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditEmployeeScreen(employee: e)));
            _load();
          }),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white), onPressed: _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(radius: 30, backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                child: Text(e.fullName.substring(0,1).toUpperCase(), style: const TextStyle(fontSize: 22, color: AppTheme.primary, fontWeight: FontWeight.bold))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(e.designation, style: const TextStyle(color: AppTheme.textSecondary)),
                Text(e.employeeId, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ])),
              StatusChip(status: e.isActive ? 'active' : 'inactive'),
            ]),
          )),
          const SizedBox(height: 12),
          const SectionHeader(title: 'Details'),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              InfoRow(label: 'Father Name', value: e.fatherName),
              InfoRow(label: 'Phone', value: e.phone),
              if (e.cnic != null) InfoRow(label: 'CNIC', value: e.cnic!),
              InfoRow(label: 'Salary', value: 'Rs. ${e.salary.toStringAsFixed(0)}/month'),
              if (e.joiningDate != null) InfoRow(label: 'Joining Date', value: e.joiningDate!),
              if (e.address != null) InfoRow(label: 'Address', value: e.address!),
            ]),
          )),
        ]),
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(context, title: 'Delete Employee', message: 'Delete "${_emp!.fullName}"? Salary and attendance records will remain.');
    if (ok) {
      await ExtendedDatabaseHelper.instance.deleteEmployee(widget.employeeId);
      if (mounted) Navigator.pop(context);
    }
  }
}
