import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/student_count_providers.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class AddEditStudentScreen extends ConsumerStatefulWidget {
  final Student? student;
  const AddEditStudentScreen({super.key, this.student});
  @override
  ConsumerState<AddEditStudentScreen> createState() => _State();
}
class _State extends ConsumerState<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _r = TextEditingController(); // reg no
  final _rn = TextEditingController(); // roll no
  final _n = TextEditingController(); // name
  final _fn = TextEditingController(); // father
  final _gn = TextEditingController(); // guardian
  final _ph = TextEditingController(); // phone
  final _ph2 = TextEditingController(); // phone2
  final _addr = TextEditingController();
  final _dob = TextEditingController();
  int? _cid, _sid;
  String _gender = 'Male';
  bool _active = true, _saving = false;
  List<SchoolClass> _classes = [];
  List<Section> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    final s = widget.student;
    if (s != null) {
      _r.text = s.registrationNo; _rn.text = s.rollNo; _n.text = s.fullName;
      _fn.text = s.fatherName; _gn.text = s.guardianName; _ph.text = s.guardianPhone;
      _ph2.text = s.guardianPhone2 ?? ''; _addr.text = s.address ?? '';
      _dob.text = s.dob ?? ''; _cid = s.classId; _sid = s.sectionId;
      _gender = s.gender; _active = s.isActive;
    }
  }

  Future<void> _loadClasses() async {
    final c = await ExtendedDatabaseHelper.instance.getAllClasses();
    setState(() => _classes = c);
    if (_cid != null) {
      final s = await ExtendedDatabaseHelper.instance.getSectionsByClass(_cid!);
      setState(() => _sections = s);
    }
  }

  Future<void> _onClassChanged(int? v) async {
    setState(() { _cid = v; _sid = null; _sections = []; });
    if (v != null) {
      final s = await ExtendedDatabaseHelper.instance.getSectionsByClass(v);
      setState(() => _sections = s);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cid == null || _sid == null) { showSnack(context, 'Select class and section', isError: true); return; }
    setState(() => _saving = true);
    final s = Student(
      id: widget.student?.id, registrationNo: _r.text.trim(), rollNo: _rn.text.trim(),
      fullName: _n.text.trim(), fatherName: _fn.text.trim(), guardianName: _gn.text.trim(),
      guardianPhone: _ph.text.trim(), guardianPhone2: _ph2.text.trim().isEmpty ? null : _ph2.text.trim(),
      classId: _cid!, sectionId: _sid!, gender: _gender,
      dob: _dob.text.trim().isEmpty ? null : _dob.text.trim(),
      address: _addr.text.trim().isEmpty ? null : _addr.text.trim(), isActive: _active,
    );
    try {
      if (widget.student == null) { 
        await ExtendedDatabaseHelper.instance.insertStudent(s); 
        if (mounted) showSnack(context, 'Student added'); 
      }
      else { 
        await ExtendedDatabaseHelper.instance.updateStudent(s); 
        if (mounted) showSnack(context, 'Student updated'); 
      }
      ref.invalidate(classStudentCountsProvider);
      ref.invalidate(sectionStudentCountsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) showSnack(context, 'Error: $e', isError: true); }
    setState(() => _saving = false);
  }

  @override
  void dispose() { for (final c in [_r,_rn,_n,_fn,_gn,_ph,_ph2,_addr,_dob]) {
    c.dispose();
  } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.student == null ? 'Add Student' : 'Edit Student')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _sec('Basic Information'),
          _tf('Registration No *', _r, hint: 'REG-2024-001', val: _req),
          _g(), _tf('Roll No *', _rn, hint: '01', val: _req),
          _g(), _tf('Full Name *', _n, val: _req),
          _g(), _tf('Father Name *', _fn, val: _req),
          _g(), _tf('Guardian Name *', _gn, val: _req),
          _g(), _tf('Guardian Phone *', _ph, hint: '03XXXXXXXXX', kb: TextInputType.phone, val: _req),
          _g(), _tf('Guardian Phone 2', _ph2, hint: '03XXXXXXXXX', kb: TextInputType.phone),
          _g(), _sec('Class & Section'),
          DropdownButtonFormField<int>(
            initialValue: _cid, hint: const Text('Select Class'), decoration: const InputDecoration(labelText: 'Class'),
            validator: (v) => v == null ? 'Select class' : null,
            items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className))).toList(),
            onChanged: _onClassChanged,
          ),
          _g(),
          DropdownButtonFormField<int>(
            initialValue: _sid, hint: const Text('Select Section'), decoration: const InputDecoration(labelText: 'Section'),
            validator: (v) => v == null ? 'Select section' : null,
            items: _sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sectionName))).toList(),
            onChanged: (v) => setState(() => _sid = v),
          ),
          _g(), _sec('Personal Details'),
          DropdownButtonFormField<String>(
            initialValue: _gender, decoration: const InputDecoration(labelText: 'Gender'),
            items: ['Male','Female','Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _gender = v ?? 'Male'),
          ),
          _g(),
          TextFormField(
            controller: _dob, readOnly: true, onTap: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime(2010), firstDate: DateTime(1990), lastDate: DateTime.now());
              if (d != null) _dob.text = d.toIso8601String().substring(0, 10);
            },
            decoration: const InputDecoration(labelText: 'Date of Birth', suffixIcon: Icon(Icons.calendar_today_outlined)),
          ),
          _g(), _tf('Address', _addr, maxLines: 2),
          if (widget.student != null) ...[
            _g(), _sec('Status'),
            SwitchListTile(title: const Text('Active Student'), value: _active, onChanged: (v) => setState(() => _active = v), activeThumbColor: AppTheme.primary),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text(widget.student == null ? 'Add Student' : 'Update Student', style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)));
  Widget _g() => const SizedBox(height: 12);
  Widget _tf(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, TextInputType kb = TextInputType.text, String? Function(String?)? val}) =>
      TextFormField(controller: ctrl, maxLines: maxLines, keyboardType: kb, validator: val, decoration: InputDecoration(labelText: label, hintText: hint));
  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
