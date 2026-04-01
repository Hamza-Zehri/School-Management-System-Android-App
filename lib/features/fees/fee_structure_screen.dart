import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/extended_database_helper.dart';
import '../../core/services/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets/shared_widgets.dart';

class FeeStructureScreen extends ConsumerWidget {
  const FeeStructureScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Structures')),
      body: ref.watch(classesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (classes) => classes.isEmpty
          ? const EmptyState(message: 'No classes found. Add classes first.', icon: Icons.class_outlined)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (ctx, i) => _FeeStructureCard(cls: classes[i]),
            ),
      ),
    );
  }
}

class _FeeStructureCard extends StatefulWidget {
  final SchoolClass cls;
  const _FeeStructureCard({required this.cls});
  @override
  State<_FeeStructureCard> createState() => _State();
}
class _State extends State<_FeeStructureCard> {
  FeeStructure? _fs;
  final _mCtrl = TextEditingController();
  final _eCtrl = TextEditingController();
  final _tCtrl = TextEditingController();
  final _oCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final fs = await ExtendedDatabaseHelper.instance.getFeeStructureByClass(widget.cls.id!);
    setState(() {
      _fs = fs;
      _mCtrl.text = fs?.monthlyFee.toStringAsFixed(0) ?? '0';
      _eCtrl.text = fs?.examFee.toStringAsFixed(0) ?? '0';
      _tCtrl.text = fs?.transportFee.toStringAsFixed(0) ?? '0';
      _oCtrl.text = fs?.otherFee.toStringAsFixed(0) ?? '0';
    });
  }

  Future<void> _save() async {
    final fs = FeeStructure(
      id: _fs?.id, classId: widget.cls.id!,
      monthlyFee: double.tryParse(_mCtrl.text) ?? 0,
      examFee: double.tryParse(_eCtrl.text) ?? 0,
      transportFee: double.tryParse(_tCtrl.text) ?? 0,
      otherFee: double.tryParse(_oCtrl.text) ?? 0,
    );
    await ExtendedDatabaseHelper.instance.saveFeeStructure(fs);
    if (mounted) showSnack(context, '${widget.cls.className} fee structure saved');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(widget.cls.className, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: _fs != null ? Text('Monthly: Rs.${_fs!.monthlyFee.toStringAsFixed(0)} | Total: Rs.${_fs!.totalFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)) : const Text('Not configured'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              Row(children: [
                Expanded(child: _feeField('Monthly Fee', _mCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _feeField('Exam Fee', _eCtrl)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _feeField('Transport Fee', _tCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _feeField('Other Fee', _oCtrl)),
              ]),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('Save Fee Structure'))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _feeField(String label, TextEditingController ctrl) => TextFormField(
    controller: ctrl, keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label, isDense: true, prefixText: 'Rs. '),
  );
}
