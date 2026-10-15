import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

const _uuid = Uuid();
final _dateFmt = DateFormat('dd-MM-yy');

class SuppliesFormPage extends StatefulWidget {
  final VoidCallback onChanged;
  const SuppliesFormPage({super.key, required this.onChanged});
  @override
  State<SuppliesFormPage> createState() => _SuppliesFormPageState();
}

class _SuppliesFormPageState extends State<SuppliesFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _suppliers = [];
  String _supplierId = '';
  String _mode = 'paid';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    final db = DatabaseHelper();
    final list = await db.getActiveSuppliers();
    if (!mounted) return;
    setState(() => _suppliers = list);
  }

  Future<String> _ensureAccount(
      DatabaseHelper db, String name, String type) async {
    final a = await db.getAccountByName(name);
    if (a != null) return a['id'] as String;
    final id = _uuid.v4();
    await db.insertAccount({
      'id': id, 'name': name, 'type': type,
      'is_system': 1, 'active': 1,
    });
    return id;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseHelper();

    final cashId = await _ensureAccount(db, 'Cash in Hand', 'asset');
    final supId =
        await _ensureAccount(db, 'Supplies Purchased', 'expense');

    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (amt <= 0) return;

    double paidNow;
    double unpaid;
    if (_mode == 'paid') {
      paidNow = amt; unpaid = 0;
    } else if (_mode == 'credit') {
      paidNow = 0; unpaid = amt;
    } else {
      paidNow = double.tryParse(_paidCtrl.text) ?? 0;
      if (paidNow < 0) paidNow = 0;
      if (paidNow > amt) paidNow = amt;
      unpaid = amt - paidNow;
    }

    // Supplier-specific AP account (or fallback to generic)
    String apId;
    String apName;
    if (_supplierId.isNotEmpty) {
      final supplier = _suppliers.firstWhere(
        (s) => s['id'] == _supplierId,
        orElse: () => <String, dynamic>{},
      );
      final supplierName = supplier['name'] as String?;
      if (supplierName != null && supplierName.isNotEmpty) {
        apName = 'AP - $supplierName';
      } else {
        apName = 'Accounts Payable';
      }
    } else {
      apName = 'Accounts Payable';
    }
    apId = await _ensureAccount(db, apName, 'liability');

    final entryId = _uuid.v4();
    final desc = _descCtrl.text.trim();
    final narration = 'Supplies: $desc${unpaid > 0 ? " (credit)" : ""}';

    final lines = <Map<String, dynamic>>[];
    lines.add(
        {'id': _uuid.v4(), 'account_id': supId, 'debit': amt, 'credit': 0});
    if (paidNow > 0) {
      lines.add({'id': _uuid.v4(),
        'account_id': cashId, 'debit': 0, 'credit': paidNow});
    }
    if (unpaid > 0) {
      lines.add(
          {'id': _uuid.v4(), 'account_id': apId, 'debit': 0, 'credit': unpaid});
    }
    if (paidNow > 0) {
      lines.add(
          {'id': _uuid.v4(), 'account_id': apId, 'debit': paidNow, 'credit': 0});
      lines.add({'id': _uuid.v4(),
        'account_id': cashId, 'debit': 0, 'credit': paidNow});
    }

    await db.insertJournalEntry(
      id: entryId,
      date: _date.toIso8601String(),
      narration: narration,
      source: 'purchase',
      lines: lines,
    );

    await db.insertPurchaseItems([{
      'id': _uuid.v4(),
      'entry_id': entryId,
      'item_name': desc,
      'price': amt,
      'quantity': 1,
      'total': amt,
      'vendor': _supplierId.isEmpty ? null : _supplierId,
    }]);

    if (_supplierId.isNotEmpty && unpaid > 0) {
      await db.adjustSupplierBalance(_supplierId, unpaid);
    }

    if (!mounted) return;
    _descCtrl.clear();
    _amountCtrl.clear();
    _paidCtrl.clear();
    setState(() {
      _mode = 'paid';
      _supplierId = '';
    });
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Supplies recorded: ${amt.toStringAsFixed(2)}')),
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('Date: ${_dateFmt.format(_date)}'),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (p != null) setState(() => _date = p);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'What did you buy?',
                  hintText: 'e.g. Shampoo bottles',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _supplierId,
              decoration: const InputDecoration(
                  labelText: 'Supplier (optional)',
                  border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: '', child: Text('No supplier')),
                ..._suppliers.map((s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(s['name'] as String),
                    )),
              ],
              onChanged: (v) => setState(() => _supplierId = v ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                  labelText: 'Total amount',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final d = double.tryParse(v);
                if (d == null || d <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Payment mode',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'paid', label: Text('Paid'),
                    icon: Icon(Icons.payments, size: 16)),
                ButtonSegment(value: 'credit', label: Text('Credit'),
                    icon: Icon(Icons.schedule, size: 16)),
                ButtonSegment(value: 'partial', label: Text('Partial'),
                    icon: Icon(Icons.edit_note, size: 16)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            if (_mode == 'partial') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidCtrl,
                decoration: const InputDecoration(
                    labelText: 'Amount paid now',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Supplies',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
