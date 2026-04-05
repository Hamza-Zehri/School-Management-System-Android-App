import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/providers.dart';
import '../../core/services/student_count_providers.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'section_students_screen.dart';

class ClassesScreen extends ConsumerWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classes & Sections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showClassDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (classes) {
          if (classes.isEmpty) {
            return EmptyState(
              message: 'No classes yet.\nAdd your first class.',
              icon: Icons.class_outlined,
              actionLabel: 'Add Class',
              onAction: () => _showClassDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            itemBuilder: (ctx, i) =>
                _ClassCard(cls: classes[i], ref: ref),
          );
        },
      ),
    );
  }

  Future<void> _showClassDialog(BuildContext context, WidgetRef ref,
      [SchoolClass? existing]) async {
    final ctrl =
        TextEditingController(text: existing?.className ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Class' : 'Edit Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Class Name *'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (result == true && ctrl.text.trim().isNotEmpty) {
      final cls = SchoolClass(
        id: existing?.id,
        className: ctrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        sortOrder: existing?.sortOrder ?? 0,
      );
      if (existing == null) {
        await ExtendedDatabaseHelper.instance.insertClass(cls);
      } else {
        await ExtendedDatabaseHelper.instance.updateClass(cls);
      }
      ref.invalidate(classesProvider);
    }
  }
}

class _ClassCard extends ConsumerWidget {
  final SchoolClass cls;
  final WidgetRef ref;

  const _ClassCard({required this.cls, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(sectionsByClassProvider(cls.id!));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.class_outlined,
              color: AppTheme.primary, size: 20),
        ),
        title: Text(cls.className,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        subtitle: Consumer(builder: (context, ref, _) {
          final sectionsAsync = ref.watch(sectionsByClassProvider(cls.id!));
          final countsAsync = ref.watch(classStudentCountsProvider);
          return Row(
            children: [
              sectionsAsync.maybeWhen(
                data: (sections) => Text('${sections.length} sections',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                orElse: () => const Text('Loading sections...', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
              const Text(' • ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              countsAsync.maybeWhen(
                data: (counts) => Text('${counts[cls.id] ?? 0} students',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                orElse: () => const Text('0 students', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ],
          );
        }),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.primary),
              onPressed: () => _editClass(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppTheme.danger),
              onPressed: () => _deleteClass(context),
            ),
          ],
        ),
        children: [
          sectionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (sections) => _SectionsList(
              sections: sections,
              cls: cls,
              ref: ref,
            ),
          ),
        ],
      ),
    );
  }

  void _editClass(BuildContext context) async {
    final ctrl = TextEditingController(text: cls.className);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Class'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Class Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == true && ctrl.text.trim().isNotEmpty) {
      await ExtendedDatabaseHelper.instance.updateClass(
          SchoolClass(id: cls.id, className: ctrl.text.trim()));
      ref.invalidate(classesProvider);
    }
  }

  void _deleteClass(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Class',
      message:
          'Delete "${cls.className}"? This will also delete its sections. Students will not be deleted.',
    );
    if (confirmed) {
      await ExtendedDatabaseHelper.instance.deleteClass(cls.id!);
      ref.invalidate(classesProvider);
    }
  }
}

class _SectionsList extends ConsumerWidget {
  final List<Section> sections;
  final SchoolClass cls;
  final WidgetRef ref;

  const _SectionsList(
      {required this.sections, required this.cls, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          Row(
            children: [
              const Text('Sections',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addSection(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Section', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (sections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No sections yet',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sections.map((s) => Consumer(builder: (context, ref, _) {
                final counts = ref.watch(sectionStudentCountsProvider).valueOrNull ?? {};
                final count = counts[s.id] ?? 0;
                return InputChip(
                  label: Text('${s.sectionName} ($count)'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SectionStudentsScreen(cls: cls, section: s))),
                  onDeleted: () => _deleteSection(context, s, ref),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  backgroundColor: AppTheme.primary.withOpacity(0.08),
                  side: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
                  labelStyle: const TextStyle(fontSize: 12, color: AppTheme.primary),
                );
              })).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _addSection(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Section'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Section Name', hintText: 'e.g. A, B, Blue'),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true && ctrl.text.trim().isNotEmpty) {
      await ExtendedDatabaseHelper.instance.insertSection(
          Section(classId: cls.id!, sectionName: ctrl.text.trim().toUpperCase()));
      ref.invalidate(sectionsByClassProvider(cls.id!));
    }
  }

  Future<void> _deleteSection(
      BuildContext context, Section s, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Section',
      message: 'Delete section "${s.sectionName}"?',
    );
    if (confirmed) {
      await ExtendedDatabaseHelper.instance.deleteSection(s.id!);
      ref.invalidate(sectionsByClassProvider(cls.id!));
    }
  }
}
