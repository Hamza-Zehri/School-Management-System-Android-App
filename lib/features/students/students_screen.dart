import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/providers.dart';
import '../../core/services/student_count_providers.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'add_edit_student_screen.dart';
import 'student_profile_screen.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  String _search = '';
  int? _filterClassId;
  int? _filterSectionId;
  bool? _filterActive = true;
  bool _filterNoFee = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list_outlined), onPressed: _showFilterSheet),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditStudentScreen()));
          ref.invalidate(allStudentsProvider);
        },
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Student'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, reg no, father name...',
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _search = ''))
                    : null,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(label: const Text('Active'), selected: _filterActive == true,
                    onSelected: (_) => setState(() => _filterActive = true)),
                const SizedBox(width: 8),
                FilterChip(label: const Text('Inactive'), selected: _filterActive == false,
                    onSelected: (_) => setState(() => _filterActive = false)),
                const SizedBox(width: 8),
                FilterChip(label: const Text('All'), selected: _filterActive == null,
                    onSelected: (_) => setState(() => _filterActive = null)),
                const SizedBox(width: 8),
                FilterChip(label: const Text('No Fee'), selected: _filterNoFee,
                    onSelected: (v) => setState(() => _filterNoFee = v)),
                if (_filterClassId != null) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Clear Filter'),
                    avatar: const Icon(Icons.close, size: 14),
                    onPressed: () => setState(() { _filterClassId = null; _filterSectionId = null; }),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildStudentList()),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_search.isNotEmpty) {
      return FutureBuilder<List<Student>>(
        future: ExtendedDatabaseHelper.instance.searchStudents(_search),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          return _buildList(snap.data ?? []);
        },
      );
    }
    if (_filterClassId != null) {
      if (_filterSectionId != null) {
        final key = (classId: _filterClassId!, sectionId: _filterSectionId!);
        return ref.watch(studentsByClassSectionProvider(key)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (s) => _buildList(s),
        );
      } else {
        return FutureBuilder<List<Student>>(
          future: ExtendedDatabaseHelper.instance.getStudentsByClass(_filterClassId!, isActive: _filterActive),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            return _buildList(snap.data ?? []);
          },
        );
      }
    }
    return ref.watch(allStudentsProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (s) => _buildList(s),
    );
  }

  Widget _buildList(List<Student> students) {
    var list = students;
    if (_filterActive != null) list = list.where((s) => s.isActive == _filterActive).toList();
    if (_filterNoFee) list = list.where((s) => s.noFee).toList();

    if (list.isEmpty) return const EmptyState(message: 'No students found', icon: Icons.people_outline);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _StudentTile(student: list[i], onRefresh: () { 
        ref.invalidate(allStudentsProvider); 
        ref.invalidate(classStudentCountsProvider);
        ref.invalidate(sectionStudentCountsProvider);
        if (mounted) setState(() {}); 
      }),
    );
  }

  Future<void> _showFilterSheet() async {
    final classes = await ExtendedDatabaseHelper.instance.getAllClasses();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _FilterSheet(
        classes: classes, selectedClassId: _filterClassId, selectedSectionId: _filterSectionId,
        onApply: (classId, sectionId) => setState(() { _filterClassId = classId; _filterSectionId = sectionId; }),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  final VoidCallback onRefresh;
  const _StudentTile({required this.student, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Text(student.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${student.className ?? '-'} - ${student.sectionName ?? '-'}', style: const TextStyle(fontSize: 12)),
          Text('Reg: ${student.registrationNo}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!student.isActive) const StatusChip(status: 'inactive'),
          if (student.noFee) const Padding(padding: EdgeInsets.only(left: 4), child: StatusChip(status: 'No Fee')),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditStudentScreen(student: student)));
              onRefresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _confirmDelete(context),
          ),
          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ]),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentProfileScreen(studentId: student.id!))).then((_) => onRefresh()),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Student',
      message: 'Are you sure you want to delete "${student.fullName}"? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (ok == true) {
      await ExtendedDatabaseHelper.instance.deleteStudent(student.id!);
      onRefresh();
    }
  }
}

class _FilterSheet extends StatefulWidget {
  final List<SchoolClass> classes;
  final int? selectedClassId;
  final int? selectedSectionId;
  final Function(int?, int?) onApply;
  const _FilterSheet({required this.classes, required this.selectedClassId, required this.selectedSectionId, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _classId;
  int? _sectionId;
  List<Section> _sections = [];

  @override
  void initState() {
    super.initState();
    _classId = widget.selectedClassId;
    _sectionId = widget.selectedSectionId;
    if (_classId != null) _loadSections(_classId!);
  }

  Future<void> _loadSections(int classId) async {
    final s = await ExtendedDatabaseHelper.instance.getSectionsByClass(classId);
    if (mounted) setState(() => _sections = s);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final counts = ref.watch(classStudentCountsProvider).valueOrNull ?? {};
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Filter Students', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _classId, hint: const Text('Select Class'),
            decoration: const InputDecoration(labelText: 'Class'),
            items: widget.classes.map((c) {
              final count = counts[c.id] ?? 0;
              return DropdownMenuItem(value: c.id, child: Text('${c.className} ($count)'));
            }).toList(),
            onChanged: (v) { setState(() { _classId = v; _sectionId = null; _sections = []; }); if (v != null) _loadSections(v); },
          ),
          if (_sections.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _sectionId, hint: const Text('Select Section'),
              decoration: const InputDecoration(labelText: 'Section'),
              items: _sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sectionName))).toList(),
              onChanged: (v) => setState(() => _sectionId = v),
            ),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () { widget.onApply(null, null); Navigator.pop(context); }, child: const Text('Clear'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () { widget.onApply(_classId, _sectionId); Navigator.pop(context); }, child: const Text('Apply'))),
          ]),
        ]),
      );
    });
  }
}
