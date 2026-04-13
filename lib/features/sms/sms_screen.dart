import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/providers.dart';
import '../../core/services/sms_service.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class SmsScreen extends ConsumerStatefulWidget {
  const SmsScreen({super.key});
  @override
  ConsumerState<SmsScreen> createState() => _State();
}
class _State extends ConsumerState<SmsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('SMS Center'),
      bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Send SMS'), Tab(text: 'Templates')]),
    ),
    body: TabBarView(controller: _tabs, children: const [_SendSmsTab(), _TemplatesTab()]),
  );
}

class _SendSmsTab extends ConsumerStatefulWidget {
  const _SendSmsTab();
  @override
  ConsumerState<_SendSmsTab> createState() => _SendState();
}
class _SendState extends ConsumerState<_SendSmsTab> {
  String _sendMode = 'custom';
  final _msgCtrl = TextEditingController();
  int? _classId, _sectionId;
  List<SchoolClass> _classes = [];
  List<Section> _sections = [];
  bool _sending = false;

  @override
  void initState() { super.initState(); _loadClasses(); }
  Future<void> _loadClasses() async { final c = await ExtendedDatabaseHelper.instance.getAllClasses(); setState(() => _classes = c); }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty) { showSnack(context, 'Enter a message', isError: true); return; }
    final granted = await SmsService.instance.requestPermission();
    if (!granted) {
      if (mounted) {
        showSnack(context, 'SMS permission denied', isError: true);
      }
      return;
    }

    setState(() => _sending = true);
    List<Student> targets = [];

    switch (_sendMode) {
      case 'all':
        targets = await ExtendedDatabaseHelper.instance.getAllStudents(isActive: true);
        break;
      case 'class':
        if (_classId != null) {
          targets = (await ExtendedDatabaseHelper.instance.getAllStudents(isActive: true)).where((s) => s.classId == _classId).toList();
        }
        break;
      case 'section':
        if (_classId != null && _sectionId != null) targets = await ExtendedDatabaseHelper.instance.getStudentsByClassSection(_classId!, _sectionId!, isActive: true);
        break;
      default:
        if (mounted) {
          showSnack(context, 'Custom SMS sent directly requires a phone number', isError: true);
        }
        setState(() => _sending = false);
        return;
    }

    if (targets.isEmpty) {
      showSnack(context, 'No students found', isError: true);
      setState(() => _sending = false);
      return;
    }

    final ok = await showConfirmDialog(context, title: 'Send SMS', message: 'Send to ${targets.length} guardian(s)?\n\n"${_msgCtrl.text.trim()}"', confirmText: 'Send', confirmColor: AppTheme.primary);
    if (!mounted || !ok) {
      setState(() => _sending = false);
      return;
    }

    final recipients = targets.map((s) => {'phone': s.guardianPhone, 'message': _msgCtrl.text.trim(), 'studentId': s.id, 'purpose': 'custom_notice'}).toList();
    final result = await SmsService.instance.sendBulkSms(recipients: recipients);
    setState(() => _sending = false);
    if (mounted) showSnack(context, 'Sent: ${result['sent']}, Failed: ${result['failed']}');
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const SectionHeader(title: 'Send To'),
    Card(child: Column(children: [
      _modeRow('All Students', 'all', Icons.group_outlined),
      _modeRow('By Class', 'class', Icons.class_outlined),
      _modeRow('By Class + Section', 'section', Icons.groups_outlined),
      _modeRow('Custom Message', 'custom', Icons.edit_outlined),
    ])),
    if (_sendMode == 'class' || _sendMode == 'section') ...[
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        value: _classId, hint: const Text('Select Class'), decoration: const InputDecoration(labelText: 'Class'),
        items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className))).toList(),
        onChanged: (v) async {
          setState(() { _classId = v; _sectionId = null; _sections = []; });
          if (v != null) {
            final s = await ExtendedDatabaseHelper.instance.getSectionsByClass(v);
            if (mounted) setState(() => _sections = s);
          }
        },
      ),
      if (_sendMode == 'section' && _sections.isNotEmpty) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _sectionId, hint: const Text('Select Section'), decoration: const InputDecoration(labelText: 'Section'),
          items: _sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sectionName))).toList(),
          onChanged: (v) => setState(() => _sectionId = v),
        ),
      ],
    ],
    const SizedBox(height: 16),
    const SectionHeader(title: 'Message'),
    TextFormField(controller: _msgCtrl, maxLines: 5, maxLength: 480, decoration: const InputDecoration(hintText: 'Type your message here...')),
    const SizedBox(height: 16),
    SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        onPressed: _sending ? null : _send,
        icon: const Icon(Icons.send_outlined),
        label: _sending ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send SMS'),
      ),
    ),
  ]);

  Widget _modeRow(String label, String mode, IconData icon) => RadioListTile<String>(
    value: mode, groupValue: _sendMode,
    title: Text(label, style: const TextStyle(fontSize: 14)),
    secondary: Icon(icon, size: 18, color: AppTheme.primary),
    onChanged: (v) => setState(() => _sendMode = v ?? 'all'),
    dense: true,
  );
}

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(smsTemplatesProvider);
    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (templates) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: templates.length,
        itemBuilder: (ctx, i) => _TemplateTile(template: templates[i], onSaved: () => ref.invalidate(smsTemplatesProvider)),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final SmsTemplate template;
  final VoidCallback onSaved;
  const _TemplateTile({required this.template, required this.onSaved});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      title: Text(template.templateName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(template.templateBody, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: IconButton(icon: const Icon(Icons.edit_outlined, color: AppTheme.primary), onPressed: () => _edit(context)),
    ),
  );

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: template.templateBody);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template.templateName),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Available placeholders: {student_name}, {class_name}, {section_name}, {date}, {due_amount}, {paid_amount}, {month_name}, {year}, {due_date}, {payment_date}, {custom_message}',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextField(controller: ctrl, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await ExtendedDatabaseHelper.instance.updateSmsTemplate(SmsTemplate(id: template.id, templateKey: template.templateKey, templateName: template.templateName, templateBody: ctrl.text));
      onSaved();
    }
  }
}
