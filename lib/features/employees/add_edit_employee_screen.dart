import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/employee_service.dart';
import '../../core/services/extended_providers.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class AddEditEmployeeScreen extends ConsumerStatefulWidget {
  final Employee? employee;
  const AddEditEmployeeScreen({super.key, this.employee});
  @override
  ConsumerState<AddEditEmployeeScreen> createState() => _State();
}
class _State extends ConsumerState<AddEditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _fatherCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _joiningCtrl = TextEditingController();
  String _designation = 'Teacher';
  bool _active = true, _saving = false;

  static const _designations = ['Teacher', 'Senior Teacher', 'Principal', 'Vice Principal', 'Clerk', 'Accountant', 'Librarian', 'Lab Assistant', 'Peon', 'Security Guard', 'Gardener', 'Cook', 'Driver', 'Other'];

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    if (e != null) {
      _empIdCtrl.text = e.employeeId;
      _nameCtrl.text = e.fullName;
      _fatherCtrl.text = e.fatherName;
      _phoneCtrl.text = e.phone;
      _cnicCtrl.text = e.cnic ?? '';
      _salaryCtrl.text = e.salary.toStringAsFixed(0);
      _addressCtrl.text = e.address ?? '';
      _joiningCtrl.text = e.joiningDate ?? '';
      _designation = e.designation;
      _active = e.isActive;
    } else {
      _generateEmpId();
    }
  }

  Future<void> _generateEmpId() async {
    final id = await EmployeeService.instance.generateEmployeeId();
    if (mounted) setState(() => _empIdCtrl.text = id);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final emp = Employee(
      id: widget.employee?.id,
      employeeId: _empIdCtrl.text.trim(),
      fullName: _nameCtrl.text.trim(),
      fatherName: _fatherCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      cnic: _cnicCtrl.text.trim().isEmpty ? null : _cnicCtrl.text.trim(),
      designation: _designation,
      joiningDate: _joiningCtrl.text.trim().isEmpty ? null : _joiningCtrl.text.trim(),
      salary: double.tryParse(_salaryCtrl.text.trim()) ?? 0,
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      isActive: _active,
    );
    try {
      if (widget.employee == null) {
        await ExtendedDatabaseHelper.instance.insertEmployee(emp);
        if (mounted) showSnack(context, 'Employee added');
      } else {
        await ExtendedDatabaseHelper.instance.updateEmployee(emp);
        if (mounted) showSnack(context, 'Employee updated');
      }
      ref.invalidate(employeesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', isError: true);
    }
    setState(() => _saving = false);
  }

  @override
  void dispose() {
    for (final c in [_empIdCtrl,_nameCtrl,_fatherCtrl,_phoneCtrl,_cnicCtrl,_salaryCtrl,_addressCtrl,_joiningCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _sec('Employee ID'),
          _tf('Employee ID *', _empIdCtrl, val: _req, hint: 'EMP-001'),
          _g(), _sec('Personal Information'),
          _tf('Full Name *', _nameCtrl, val: _req),
          _g(), _tf('Father Name *', _fatherCtrl, val: _req),
          _g(), _tf('Phone *', _phoneCtrl, val: _req, kb: TextInputType.phone, hint: '03XXXXXXXXX'),
          _g(), _tf('CNIC', _cnicCtrl, hint: '3XXXX-XXXXXXX-X', kb: TextInputType.number),
          _g(), _sec('Job Details'),
          DropdownButtonFormField<String>(
            initialValue: _designation, decoration: const InputDecoration(labelText: 'Designation *'),
            items: _designations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _designation = v ?? 'Teacher'),
          ),
          _g(),
          TextFormField(
            controller: _joiningCtrl, readOnly: true, onTap: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
              if (d != null) _joiningCtrl.text = d.toIso8601String().substring(0, 10);
            },
            decoration: const InputDecoration(labelText: 'Joining Date', suffixIcon: Icon(Icons.calendar_today_outlined)),
          ),
          _g(), _tf('Monthly Salary (Rs.) *', _salaryCtrl, val: _req, kb: TextInputType.number, hint: '25000'),
          _g(), _tf('Address', _addressCtrl, maxLines: 2),
          if (widget.employee != null) ...[
            _g(), _sec('Status'),
            SwitchListTile(title: const Text('Active Employee'), value: _active, onChanged: (v) => setState(() => _active = v), activeThumbColor: AppTheme.primary),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text(widget.employee == null ? 'Add Employee' : 'Update Employee', style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)));
  Widget _g() => const SizedBox(height: 12);
  Widget _tf(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, TextInputType kb = TextInputType.text, String? Function(String?)? val}) =>
      TextFormField(controller: ctrl, maxLines: maxLines, keyboardType: kb, validator: val, decoration: InputDecoration(labelText: label, hintText: hint));
  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
