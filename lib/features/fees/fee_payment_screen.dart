import 'package:flutter/material.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/fee_service.dart';
import '../../core/services/pdf_service.dart';
import '../../models/models.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/shared_widgets.dart';

class FeePaymentScreen extends StatefulWidget {
  final FeeRecord feeRecord;
  const FeePaymentScreen({super.key, required this.feeRecord});
  @override
  State<FeePaymentScreen> createState() => _State();
}
class _State extends State<FeePaymentScreen> {
  final _amtCtrl = TextEditingController();
  String _paymentMethod = 'Cash';
  bool _sendSms = true, _saving = false;
  List<FeePayment> _payments = [];
  late FeeRecord _record;

  @override
  void initState() { super.initState(); _record = widget.feeRecord; _loadPayments(); }

  Future<void> _loadPayments() async {
    final p = await ExtendedDatabaseHelper.instance.getPaymentsByFeeRecord(_record.id!);
    setState(() => _payments = p);
  }

  Future<void> _recordPayment() async {
    final amt = double.tryParse(_amtCtrl.text.trim());
    if (amt == null || amt <= 0) { showSnack(context, 'Enter valid amount', isError: true); return; }
    if (amt > _record.dueAmount) { showSnack(context, 'Amount exceeds due amount', isError: true); return; }
    setState(() => _saving = true);
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final updated = await FeeService.instance.recordPayment(
      feeRecordId: _record.id!, amount: amt, paymentDate: date,
      paymentMethod: _paymentMethod, sendSms: _sendSms,
    );
    if (updated != null) {
      setState(() { _record = updated; _amtCtrl.clear(); });
      await _loadPayments();
      if (mounted) {
        showSnack(context, 'Payment recorded: Rs.${amt.toStringAsFixed(0)}');
        if (_payments.isNotEmpty) {
          final school = await ExtendedDatabaseHelper.instance.getSchoolSettings();
          if (school != null) {
            final path = await PdfService.instance.generateFeeReceipt(
              feeRecord: _record, payment: _payments.first, school: school);
            if (mounted) showSnack(context, 'Receipt saved: $path');
          }
        }
      }
    }
    setState(() => _saving = false);
  }

  Future<void> _confirmDeletePayment(BuildContext context, FeePayment p) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Payment',
      message: 'Are you sure you want to delete this payment of Rs.${p.paidAmount.toStringAsFixed(0)}? This will recharge the due amount.',
      confirmText: 'Delete',
      confirmColor: AppTheme.danger,
    );
    if (confirmed) {
      final updated = await FeeService.instance.deletePayment(p.id!, _record.id!);
      if (updated != null) {
        setState(() => _record = updated);
        await _loadPayments();
        if (mounted) showSnack(context, 'Payment deleted');
      }
    }
  }

  Future<void> _showEditRecordDialog(BuildContext context) async {
    final totalCtrl = TextEditingController(text: _record.totalAmount.toStringAsFixed(0));
    final discCtrl = TextEditingController(text: _record.discountAmount.toStringAsFixed(0));
    final fineCtrl = TextEditingController(text: _record.fineAmount.toStringAsFixed(0));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Fee Record'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: totalCtrl, decoration: const InputDecoration(labelText: 'Original Total (Rs.)'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: discCtrl, decoration: const InputDecoration(labelText: 'Discount (Rs.)'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: fineCtrl, decoration: const InputDecoration(labelText: 'Fine (Rs.)'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      final t = double.tryParse(totalCtrl.text.trim()) ?? _record.totalAmount;
      final d = double.tryParse(discCtrl.text.trim()) ?? _record.discountAmount;
      final f = double.tryParse(fineCtrl.text.trim()) ?? _record.fineAmount;

      final updated = await FeeService.instance.updateFeeRecordTotals(
        recordId: _record.id!, total: t, discount: d, fine: f,
      );
      if (updated != null) {
        setState(() => _record = updated);
        if (mounted) showSnack(context, 'Fee record updated');
      }
    }
  }

  @override
  void dispose() { _amtCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(r.studentName ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                    onPressed: () => _showEditRecordDialog(context),
                  ),
                  StatusChip(status: r.status),
                ]),
              ]),
              const SizedBox(height: 4),
              Text('${r.className ?? ''} - ${r.sectionName ?? ''}', style: const TextStyle(color: AppTheme.textSecondary)),
              const Divider(height: 20),
              InfoRow(label: 'Month', value: '${_monthName(r.month)} ${r.year}'),
              InfoRow(label: 'Total Fee', value: 'Rs. ${r.totalAmount.toStringAsFixed(0)}'),
              if (r.discountAmount > 0) InfoRow(label: 'Discount', value: '- Rs. ${r.discountAmount.toStringAsFixed(0)}'),
              if (r.fineAmount > 0) InfoRow(label: 'Fine', value: '+ Rs. ${r.fineAmount.toStringAsFixed(0)}'),
              InfoRow(label: 'Final Total', value: 'Rs. ${r.finalTotal.toStringAsFixed(0)}'),
              InfoRow(label: 'Paid', value: 'Rs. ${r.paidAmount.toStringAsFixed(0)}'),
              InfoRow(label: 'Balance Due', value: 'Rs. ${r.dueAmount.toStringAsFixed(0)}'),
            ]),
          )),
          if (r.dueAmount > 0) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'Record Payment'),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextFormField(controller: _amtCtrl, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Amount (Rs.)', hintText: 'Max: ${r.dueAmount.toStringAsFixed(0)}')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: ['Cash', 'Bank Transfer', 'Cheque', 'Online']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Send Confirmation SMS', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Switch(value: _sendSms, onChanged: (v) => setState(() => _sendSms = v), activeThumbColor: AppTheme.primary),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _recordPayment,
                    icon: const Icon(Icons.payment_outlined),
                    label: _saving
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Record Payment'),
                  ),
                ),
              ]),
            )),
          ],
          if (_payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'Payment History'),
            ..._payments.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const Icon(Icons.receipt_outlined, color: AppTheme.accent),
                title: Text('Rs. ${p.paidAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.paymentDate} • ${p.receiptNo}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(p.paymentMethod ?? '',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => _confirmDeletePayment(context, p),
                  ),
                ]),
              ),
            )),
          ],
        ]),
      ),
    );
  }

  String _monthName(int m) {
    const months = ['','January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return m >= 1 && m <= 12 ? months[m] : '';
  }
}
