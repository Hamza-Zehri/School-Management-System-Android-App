import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/db/extended_database_helper.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../dashboard/dashboard_screen.dart';

class SchoolSetupScreen extends StatefulWidget {
  final bool isFirstRun;
  final SchoolSettings? existing;
  const SchoolSetupScreen({super.key, this.isFirstRun = false, this.existing});
  @override
  State<SchoolSetupScreen> createState() => _State();
}
class _State extends State<SchoolSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _logoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _nameCtrl.text = ex.schoolName;
      _addressCtrl.text = ex.schoolAddress;
      _phoneCtrl.text = ex.schoolPhone;
      _emailCtrl.text = ex.schoolEmail ?? '';
      _logoPath = ex.logoPath;
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _addressCtrl, _phoneCtrl, _emailCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _logoPath = file.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final settings = SchoolSettings(
      id: widget.existing?.id,
      schoolName: _nameCtrl.text.trim(),
      schoolAddress: _addressCtrl.text.trim(),
      schoolPhone: _phoneCtrl.text.trim(),
      schoolEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      logoPath: _logoPath,
    );
    await ExtendedDatabaseHelper.instance.saveSchoolSettings(settings);
    if (mounted) {
      setState(() => _saving = false);
      if (widget.isFirstRun) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DashboardScreen()), (_) => false);
      } else {
        showSnack(context, 'School settings updated');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isFirstRun ? 'Setup Your School' : 'Edit School Info'), automaticallyImplyLeading: !widget.isFirstRun),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.isFirstRun) ...[
              const Text("Let's set up your school", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              const Text('You can change these settings anytime later.', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 28),
            ],
            Center(child: GestureDetector(
              onTap: _pickLogo,
              child: Container(width: 100, height: 100,
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border, width: 2)),
                child: _logoPath != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(_logoPath!), fit: BoxFit.cover))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.camera_alt_outlined, size: 32, color: AppTheme.textSecondary),
                        SizedBox(height: 4),
                        Text('Add Logo', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ]),
              ),
            )),
            const SizedBox(height: 24),
            _field('School Name *', _nameCtrl, hint: 'e.g. Sunshine Public School', validator: _req),
            const SizedBox(height: 16),
            _field('School Address *', _addressCtrl, hint: 'Full address', maxLines: 2, validator: _req),
            const SizedBox(height: 16),
            _field('School Phone *', _phoneCtrl, hint: '03XXXXXXXXX', keyboardType: TextInputType.phone, validator: _req),
            const SizedBox(height: 16),
            _field('School Email', _emailCtrl, hint: 'school@example.com', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(widget.isFirstRun ? 'Save & Continue' : 'Save Changes', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) =>
      TextFormField(controller: ctrl, maxLines: maxLines, keyboardType: keyboardType, validator: validator, decoration: InputDecoration(labelText: label, hintText: hint));
  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null;
}
