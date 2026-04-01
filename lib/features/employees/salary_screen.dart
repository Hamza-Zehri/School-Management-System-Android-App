import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/extended_providers.dart';
import '../../core/services/employee_service.dart';
import '../../models/extended_models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class SalaryScreen extends ConsumerStatefulWidget {
  const SalaryScreen({super.key});
  @override
  ConsumerState<SalaryScreen> createState() => _State();
}
class _State extends ConsumerState<SalaryScreen> {
  int _month = DateTime.now().month, _year = DateTime.now().year;
  String _status = 'All';
  static const _months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final filter = SalaryFilter(month: _month, year: _year, status: _status == 'All' ? null : _status);
    final salaryAsync = ref.watch(salaryRecordsProvider(filter));

    return Column(children: [
      Container(
        color: Colors.white,
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
          Row(children: [
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: ['All','Paid','Unpaid','Partial'].map((s) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(label: Text(s, style: const TextStyle(fontSize: 11)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
              )).toList()),
            )),
            ElevatedButton(onPressed: _generateRecords, child: const Text('Generate')),
          ]),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: salaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (records) => records.isEmpty
          ? EmptyState(message: 'No salary records for ${_months[_month]} $_year\nTap Generate to create records', icon: Icons.payments_outlined, actionLabel: 'Generate', onAction: _generateRecords)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              itemCount: records.length,
              itemBuilder: (ctx, i) => _SalaryCard(record: records[i], onRefresh: () => ref.invalidate(salaryRecordsProvider(filter))),
            ),
      )),
    ]);
  }

  Future<void> _generateRecords() async {
    final ok = await showConfirmDialog(context, title: 'Generate Salary Records',
      message: 'Generate salary records for all active employees for ${_months[_month]} $_year?', confirmText: 'Generate', confirmColor: AppTheme.primary);
    if (!ok) return;
    final result = await EmployeeService.instance.generateMonthlySalaryRecords(month: _month, year: _year);
    if (mounted) {
      showSnack(context, 'Created: ${result['created']}, Skipped: ${result['skipped']}');
      ref.invalidate(salaryRecordsProvider);
    }
  }
}

class _SalaryCard extends StatelessWidget {
  final SalaryRecord record;
  final VoidCallback onRefresh;
  const _SalaryCard({required this.record, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final statusColor = r.status == 'Paid' ? AppTheme.paid : r.status == 'Partial' ? AppTheme.partial : AppTheme.unpaid;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPaymentDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.employeeName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${r.designation ?? ''} • ${r.employeePhone ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Row(children: [
                Text('Total: Rs.${r.totalPayable.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 10),
                if (r.paidAmount > 0) Text('Paid: Rs.${r.paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.paid)),
                if (r.dueAmount > 0) ...[const SizedBox(width: 10), Text('Due: Rs.${r.dueAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.unpaid))],
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Text(r.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor))),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog(BuildContext context) async {
    final r = record;
    if (r.dueAmount <= 0) { showSnack(context, 'Already fully paid'); return; }
    final amtCtrl = TextEditingController(text: r.dueAmount.toStringAsFixed(0));
    String method = 'Cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        title: Text('Pay Salary — ${r.employeeName}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          InfoRow(label: 'Due Amount', value: 'Rs. ${r.dueAmount.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pay Amount (Rs.)')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: method, decoration: const InputDecoration(labelText: 'Method', isDense: true),
            items: ['Cash','Bank Transfer','Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => ss(() => method = v ?? 'Cash'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pay')),
        ],
      )),
    );
    if (ok != true) return;
    final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
    if (amt <= 0) return;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await EmployeeService.instance.recordSalaryPayment(salaryRecordId: r.id!, amount: amt, paymentDate: date, method: method);
    if (context.mounted) showSnack(context, 'Salary payment recorded');
    onRefresh();
  }
}
