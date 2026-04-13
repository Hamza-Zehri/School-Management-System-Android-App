import 'package:flutter/material.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/promotion_service.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});
  @override
  State<PromotionScreen> createState() => _State();
}

class _State extends State<PromotionScreen> {
  int? _fromClassId, _fromSectionId, _toClassId, _toSectionId;
  List<SchoolClass> _classes = [];
  List<Section> _fromSections = [], _toSections = [];
  List<Student> _students = [];
  Map<int, String> _actions = {}; // studentId -> action
  bool _loading = false;
  final _yearCtrl = TextEditingController(text: '${DateTime.now().year}');

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final c = await ExtendedDatabaseHelper.instance.getAllClasses();
    setState(() => _classes = c);
  }

  Future<void> _onFromClassChanged(int? v) async {
    setState(() {
      _fromClassId = v;
      _fromSectionId = null;
      _fromSections = [];
      _students = [];
      _actions = {};
    });
    if (v != null) {
      final s = await ExtendedDatabaseHelper.instance.getSectionsByClass(v);
      setState(() => _fromSections = s);
    }
  }

  Future<void> _onToClassChanged(int? v) async {
    setState(() {
      _toClassId = v;
      _toSectionId = null;
      _toSections = [];
    });
    if (v != null) {
      final s = await ExtendedDatabaseHelper.instance.getSectionsByClass(v);
      setState(() => _toSections = s);
    }
  }

  Future<void> _loadStudents() async {
    if (_fromClassId == null || _fromSectionId == null) {
      showSnack(context, 'Select from class and section', isError: true);
      return;
    }
    final students =
        await ExtendedDatabaseHelper.instance
            .getStudentsByClassSection(_fromClassId!, _fromSectionId!,
                isActive: true);
    final actions = <int, String>{for (final s in students) s.id!: 'promote'};
    setState(() {
      _students = students;
      _actions = actions;
    });
  }

  Future<void> _promote() async {
    if (_students.isEmpty) {
      showSnack(context, 'Load students first', isError: true);
      return;
    }
    if (_toClassId == null || _toSectionId == null) {
      showSnack(context, 'Select destination class and section', isError: true);
      return;
    }
    final year = _yearCtrl.text.trim();

    // Build preview
    final counts = {'promote': 0, 'repeat': 0, 'inactive': 0, 'transfer': 0};
    for (final action in _actions.values) {
      counts[action] = (counts[action] ?? 0) + 1;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Promotion'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Year: $year'),
              const Divider(),
              _previewRow(
                  'Promote to next class', counts['promote']!, AppTheme.accent),
              _previewRow(
                  'Repeat same class', counts['repeat']!, AppTheme.warning),
              _previewRow(
                  'Mark inactive (left)', counts['inactive']!, AppTheme.danger),
              _previewRow('Transfer', counts['transfer']!, AppTheme.info),
              const Divider(),
              const Text(
                  'This will update student class/section.\nAll historical records are preserved.',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Promote')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    final entries = _students
        .map((s) => PromotionEntry(
              student: s,
              action: _actions[s.id!] ?? 'promote',
              newClassId: _toClassId,
              newSectionId: _toSectionId,
            ))
        .toList();

    final result = await PromotionService.instance
        .promoteStudents(entries: entries, promotionYear: year);
    setState(() {
      _loading = false;
      _students = [];
      _actions = {};
    });

    if (mounted) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Promotion Complete'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  _previewRow('Promoted', result.promoted, AppTheme.accent),
                  _previewRow('Repeated', result.repeated, AppTheme.warning),
                  _previewRow(
                      'Marked Inactive', result.inactive, AppTheme.danger),
                  _previewRow('Transferred', result.transferred, AppTheme.info),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'))
                ],
              ));
    }
  }

  Widget _previewRow(String label, int count, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text('$count',
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Promotion')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SectionHeader(title: 'Academic Year'),
        TextFormField(
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Promotion Year', hintText: '2025')),
        const SizedBox(height: 16),
        const SectionHeader(title: 'From (Current Class)'),
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<int>(
            initialValue: _fromClassId,
            hint: const Text('Class'),
            decoration: const InputDecoration(labelText: 'From Class'),
            items: _classes
                .map((c) =>
                    DropdownMenuItem(value: c.id, child: Text(c.className)))
                .toList(),
            onChanged: _onFromClassChanged,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: DropdownButtonFormField<int>(
            initialValue: _fromSectionId,
            hint: const Text('Section'),
            decoration: const InputDecoration(labelText: 'From Section'),
            items: _fromSections
                .map((s) =>
                    DropdownMenuItem(value: s.id, child: Text(s.sectionName)))
                .toList(),
            onChanged: (v) => setState(() => _fromSectionId = v),
          )),
        ]),
        const SizedBox(height: 8),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                icon: const Icon(Icons.people_outlined),
                label: const Text('Load Students'),
                onPressed: _loadStudents)),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Promote To'),
        Row(children: [
          Expanded(
              child: DropdownButtonFormField<int>(
            initialValue: _toClassId,
            hint: const Text('Class'),
            decoration: const InputDecoration(labelText: 'To Class'),
            items: _classes
                .map((c) =>
                    DropdownMenuItem(value: c.id, child: Text(c.className)))
                .toList(),
            onChanged: _onToClassChanged,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: DropdownButtonFormField<int>(
            initialValue: _toSectionId,
            hint: const Text('Section'),
            decoration: const InputDecoration(labelText: 'To Section'),
            items: _toSections
                .map((s) =>
                    DropdownMenuItem(value: s.id, child: Text(s.sectionName)))
                .toList(),
            onChanged: (v) => setState(() => _toSectionId = v),
          )),
        ]),
        if (_students.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionHeader(
            title: '${_students.length} Students',
            action: TextButton(
                onPressed: () {
                  setState(() {
                    for (final s in _students) {
                      _actions[s.id!] = 'promote';
                    }
                  });
                },
                child: const Text('Set All Promote')),
          ),
          ..._students.map((s) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        child: Text(s.fullName.substring(0, 1),
                            style: const TextStyle(
                                color: AppTheme.primary, fontSize: 12))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(s.fullName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500))),
                    DropdownButton<String>(
                      value: _actions[s.id!] ?? 'promote',
                      isDense: true,
                    items: const [
                      DropdownMenuItem(
                          value: 'promote',
                          child: Text('Promote',
                              style: TextStyle(
                                  color: AppTheme.accent, fontSize: 12))),
                      DropdownMenuItem(
                          value: 'repeat',
                          child: Text('Repeat',
                              style: TextStyle(
                                  color: AppTheme.warning, fontSize: 12))),
                      DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive',
                              style: TextStyle(
                                  color: AppTheme.danger, fontSize: 12))),
                      DropdownMenuItem(
                          value: 'transfer',
                          child: Text('Transfer',
                              style: TextStyle(
                                  color: AppTheme.info, fontSize: 12))),
                    ],
                      onChanged: (v) =>
                          setState(() => _actions[s.id!] = v ?? 'promote'),
                    ),
                  ]),
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _promote,
              icon: const Icon(Icons.upgrade_outlined),
              label: _loading
                  ? const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)
                  : const Text('Run Promotion', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }
}
