import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/providers.dart';
import '../../core/services/student_count_providers.dart';
import '../../core/services/fee_service.dart';
import '../../core/services/pdf_service.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'fee_payment_screen.dart';
import 'fee_structure_screen.dart';

class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key});
  @override
  ConsumerState<FeesScreen> createState() => _State();
}
class _State extends ConsumerState<FeesScreen> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  String _status = 'all';
  int? _classId;
  int? _sectionId;
  String _search = '';

  static const _months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _statuses = ['all','unpaid','partial','paid','overdue'];

  @override
  Widget build(BuildContext context) {
    final filter = FeeFilter(classId: _classId, sectionId: _sectionId, month: _month, year: _year, status: _status == 'all' ? null : _status, searchQuery: _search);
    final recordsAsync = ref.watch(feeRecordsProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Management'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Fee Structure', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeeStructureScreen()))),
          PopupMenuButton(itemBuilder: (_) => [
            const PopupMenuItem(value: 'generate', child: Text('Generate Fee Records')),
            const PopupMenuItem(value: 'pdf', child: Text('Export PDF Report')),
          ], onSelected: (v) { if (v == 'generate') {
            _generateFees();
          } else if (v == 'pdf') _exportPdf(recordsAsync.valueOrNull ?? []); }),
        ],
      ),
      body: Column(children: [
        // Filters
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: _month, decoration: const InputDecoration(labelText: 'Month', isDense: true),
                items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text(_months[i+1]))),
                onChanged: (v) => setState(() => _month = v ?? _month),
              )),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<int>(
                initialValue: _year, decoration: const InputDecoration(labelText: 'Year', isDense: true),
                items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - i, child: Text('${DateTime.now().year - i}'))),
                onChanged: (v) => setState(() => _year = v ?? _year),
              )),
            ]),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(s.toUpperCase(), style: const TextStyle(fontSize: 11)),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                    selectedColor: AppTheme.statusColor(s).withValues(alpha: 0.15),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by student name or reg no...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
                suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _search = '')) : null,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Consumer(builder: (context, ref, _) {
                final classes = ref.watch(classesProvider).valueOrNull ?? [];
                final counts = ref.watch(classStudentCountsProvider).valueOrNull ?? {};
                return DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: _classId,
                  hint: const Text('Filter by Class', style: TextStyle(fontSize: 12)),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Classes', style: TextStyle(fontSize: 12))),
                    ...classes.map((c) {
                      final count = counts[c.id] ?? 0;
                      return DropdownMenuItem(value: c.id, child: Text('${c.className} ($count)', style: const TextStyle(fontSize: 12)));
                    }),
                  ],
                  onChanged: (v) => setState(() {
                    _classId = v;
                    _sectionId = null;
                  }),
                );
              })),
              if (_classId != null) ...[
                const SizedBox(width: 8),
                Expanded(child: Consumer(builder: (context, ref, _) {
                  final sections = ref.watch(sectionsByClassProvider(_classId!)).valueOrNull ?? [];
                  return DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _sectionId,
                    hint: const Text('Section', style: TextStyle(fontSize: 12)),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Sections', style: TextStyle(fontSize: 12))),
                      ...sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.sectionName, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: (v) => setState(() => _sectionId = v),
                  );
                })),
              ],
            ]),
          ]),
        ),
        const Divider(height: 1),
        // Summary
        recordsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (records) => Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              _summStat('Total', records.length.toString(), Theme.of(context).colorScheme.onSurface),
              _summStat('Paid', records.where((r) => r.status=='paid').length.toString(), AppTheme.paid),
              _summStat('Unpaid', records.where((r) => r.status=='unpaid').length.toString(), AppTheme.unpaid),
              _summStat('Partial', records.where((r) => r.status=='partial').length.toString(), AppTheme.partial),
            ]),
          ),
        ),
        Expanded(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (records) => records.isEmpty
              ? EmptyState(message: 'No fee records for ${_months[_month]} $_year\nTap ⋮ → Generate to create records', icon: Icons.payments_outlined,
                  actionLabel: 'Generate Records', onAction: _generateFees)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: records.length,
                  itemBuilder: (ctx, i) => _FeeCard(record: records[i], onRefresh: () => ref.invalidate(feeRecordsProvider(filter))),
                ),
          ),
        ),
      ]),
    );
  }

  Widget _summStat(String label, String val, Color color) => Expanded(
    child: Column(children: [
      Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]),
  );

  Future<void> _generateFees() async {
    final ok = await showConfirmDialog(context, title: 'Generate Fee Records',
      message: 'Generate fee records for all active students for ${_months[_month]} $_year?', confirmText: 'Generate', confirmColor: AppTheme.primary);
    if (!ok) return;
    final result = await FeeService.instance.generateFeeRecords(month: _month, year: _year);
    if (mounted) {
      showSnack(context, 'Created: ${result['created']}, Skipped (exists): ${result['skipped']}');
      ref.invalidate(feeRecordsProvider(FeeFilter(month: _month, year: _year, status: _status == 'all' ? null : _status)));
    }
  }

  Future<void> _exportPdf(List<FeeRecord> records) async {
    final school = await ExtendedDatabaseHelper.instance.getSchoolSettings();
    if (school == null || !mounted) return;
    final path = await PdfService.instance.generateFeeStatusReport(records: records, status: _status, month: _month, year: _year, school: school);
    if (mounted) showSnack(context, 'PDF saved: $path');
  }
}

class _FeeCard extends StatelessWidget {
  final FeeRecord record;
  final VoidCallback onRefresh;
  const _FeeCard({required this.record, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeePaymentScreen(feeRecord: r))).then((_) => onRefresh()),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.studentName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${r.className ?? ''} - ${r.sectionName ?? ''}  |  Reg: ${r.registrationNo ?? ''}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Row(children: [
                Text('Total: Rs.${r.finalTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Text('Paid: Rs.${r.paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.paid)),
                if (r.dueAmount > 0) ...[
                  const SizedBox(width: 12),
                  Text('Due: Rs.${r.dueAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.unpaid)),
                ],
              ]),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              StatusChip(status: r.status),
              const SizedBox(height: 4),
              Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ]),
          ]),
        ),
      ),
    );
  }
}
