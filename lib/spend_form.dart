import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

const _uuid = Uuid();
final _dateFmt = DateFormat('dd-MM-yy');

const _fixedCategories = <String>[
  'Land and Building',
  'Furniture and Fixtures',
  'Computer Accessories',
  'Machinery and Equipment',
  'Vehicles',
  'Other Fixed Assets',
];

class SpendFormPage extends StatefulWidget {
  final VoidCallback onChanged;
  const SpendFormPage({super.key, required this.onChanged});
  @override
  State<SpendFormPage> createState() => _SpendFormPageState();
}

class _SpendFormPageState extends State<SpendFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  String _kind = 'expense'; // 'expense' or 'asset'
  String _expenseAccId = '';
  String _fixedCategory = _fixedCategories.first;

  String _paymentMode = 'cash';
  String _paymentAccId = '';
  String _supplierId = '';

  List<Map<String, dynamic>> _expenseAccounts = [];
  List<Map<String, dynamic>> _cashAccounts = [];
  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _loansShort = [];
  List<Map<String, dynamic>> _loansLong = [];
  List<Map<String, dynamic>> _equityAccs = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final all = await db.getAllAccounts();
    final sup = await db.getActiveSuppliers();

    final exp = all
        .where((a) =>
            a['type'] == 'expense' &&
            a['active'] == 1 &&
            a['name'] != 'Supplies Purchased')
        .toList();
    final cash = all
        .where((a) =>
            a['type'] == 'asset' &&
            a['active'] == 1 &&
            a['subtype'] == 'cash')
        .toList();
    final bank = all
        .where((a) =>
            a['type'] == 'asset' &&
            a['active'] == 1 &&
            a['subtype'] == 'bank')
        .toList();
    final loansShort = all
        .where((a) =>
            a['type'] == 'liability' &&
            a['active'] == 1 &&
            a['subtype'] == 'loan_short')
        .toList();
    final loansLong = all
        .where((a) =>
            a['type'] == 'liability' &&
            a['active'] == 1 &&
            a['subtype'] == 'loan_long')
        .toList();
    final equity = all
        .where((a) =>
            a['type'] == 'equity' &&
            a['active'] == 1 &&
            a['name'] != 'Owner Drawings')
        .toList();

    if (!mounted) return;
    setState(() {
      _expenseAccounts = exp;
      _cashAccounts = cash;
      _bankAccounts = bank;
      _suppliers = sup;
      _loansShort = loansShort;
      _loansLong = loansLong;
      _equityAccs = equity;

      if (exp.isNotEmpty) _expenseAccId = exp.first['id'] as String;
      if (cash.isNotEmpty) _paymentAccId = cash.first['id'] as String;
      if (sup.isNotEmpty) _supplierId = sup.first['id'] as String;
      _loading = false;
    });
  }

  Future<String> _ensureAccount(
      DatabaseHelper db, String name, String type, String subtype) async {
    final a = await db.getAccountByName(name);
    if (a != null) return a['id'] as String;
    final id = _uuid.v4();
    await db.insertAccount({
      'id': id,
      'name': name,
      'type': type,
      'subtype': subtype,
      'is_system': 1,
      'active': 1,
    });
    return id;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (amt <= 0) return;

    final db = DatabaseHelper();

    // Debit side
    String debitAccId;
    if (_kind == 'asset') {
      // Ensure the standard fixed-asset account exists
      debitAccId = await _ensureAccount(
          db, _fixedCategory, 'asset', 'fixed');
    } else {
      if (_expenseAccId.isEmpty) return;
      debitAccId = _expenseAccId;
    }

    // Credit side
    String creditAccId;
    String? supplierForBalance;

    if (_paymentMode == 'cash' || _paymentMode == 'bank') {
      if (_paymentAccId.isEmpty) return;
      creditAccId = _paymentAccId;
    } else if (_paymentMode == 'supplier') {
      if (_supplierId.isEmpty) return;
      final supplier = _suppliers.firstWhere(
        (s) => s['id'] == _supplierId,
        orElse: () => <String, dynamic>{},
      );
      final sName = supplier['name'] as String?;
      if (sName == null || sName.isEmpty) return;
      final apName = 'AP - $sName';
      creditAccId = await _ensureAccount(
          db, apName, 'liability', 'payable');
      supplierForBalance = _supplierId;
    } else if (_paymentMode == 'loan_short') {
      if (_loansShort.isEmpty) return;
      creditAccId = _loansShort.first['id'] as String;
      // Use the selected one if user has more than one
      if (_paymentAccId.isNotEmpty &&
          _loansShort.any((a) => a['id'] == _paymentAccId)) {
        creditAccId = _paymentAccId;
      }
    } else if (_paymentMode == 'loan_long') {
      if (_loansLong.isEmpty) return;
      creditAccId = _loansLong.first['id'] as String;
      if (_paymentAccId.isNotEmpty &&
          _loansLong.any((a) => a['id'] == _paymentAccId)) {
        creditAccId = _paymentAccId;
      }
    } else if (_paymentMode == 'capital') {
      if (_equityAccs.isEmpty) return;
      creditAccId = _equityAccs.first['id'] as String;
      if (_paymentAccId.isNotEmpty &&
          _equityAccs.any((a) => a['id'] == _paymentAccId)) {
        creditAccId = _paymentAccId;
      }
    } else {
      return;
    }

    final desc = _descCtrl.text.trim();
    final narration = _kind == 'asset'
        ? 'Fixed asset: $desc'
        : 'Expense: $desc';

    await db.insertJournalEntry(
      id: _uuid.v4(),
      date: _date.toIso8601String(),
      narration: narration,
      source: _kind == 'asset' ? 'fixed_asset' : 'expense',
      lines: [
        {'id': _uuid.v4(),
          'account_id': debitAccId,
          'debit': amt, 'credit': 0},
        {'id': _uuid.v4(),
          'account_id': creditAccId,
          'debit': 0, 'credit': amt},
      ],
    );

    if (supplierForBalance != null) {
      await db.adjustSupplierBalance(supplierForBalance, amt);
    }

    if (!mounted) return;
    _descCtrl.clear();
    _amountCtrl.clear();
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recorded: ${amt.toStringAsFixed(2)}')),
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _paymentLabel(String mode) {
    switch (mode) {
      case 'cash': return 'Paid by Cash';
      case 'bank': return 'Paid by Bank / Wallet';
      case 'supplier': return 'On credit from Supplier';
      case 'loan_short': return 'Loan - Current (under 1 year)';
      case 'loan_long': return 'Loan - Non-Current (1+ years)';
      case 'capital': return "From Owner's Capital";
      default: return mode;
    }
  }

  List<Map<String, dynamic>> get _paymentAccountsForMode {
    switch (_paymentMode) {
      case 'cash': return _cashAccounts;
      case 'bank': return _bankAccounts;
      case 'loan_short': return _loansShort;
      case 'loan_long': return _loansLong;
      case 'capital': return _equityAccs;
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final showAmountOnly = true;
    final sourceList = _paymentAccountsForMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Record Spend',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Choose what you spent on and how you paid.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 16),

            // Date
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

            // What is this? (Expense or Fixed Asset)
            DropdownButtonFormField<String>(
              value: _kind,
              decoration: const InputDecoration(
                  labelText: 'What is this?',
                  border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'expense',
                    child: Text('Expense (bills, rent, salary, etc.)')),
                DropdownMenuItem(value: 'asset',
                    child: Text('Fixed Asset (furniture, machine, etc.)')),
              ],
              onChanged: (v) => setState(() => _kind = v!),
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                  labelText: _kind == 'asset'
                      ? 'Item name'
                      : 'Description',
                  hintText: _kind == 'asset'
                      ? 'e.g. Barber Chair, AC, Mirror'
                      : 'e.g. Electricity bill, October salary',
                  border: const OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Expense category OR Fixed asset category
            if (_kind == 'expense') ...[
              if (_expenseAccounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No expense accounts yet. Add one in Settings > Manage Ledgers.',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _expenseAccId,
                  decoration: const InputDecoration(
                      labelText: 'Expense category',
                      border: OutlineInputBorder()),
                  items: _expenseAccounts
                      .map((a) => DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text(a['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _expenseAccId = v ?? ''),
                ),
              const SizedBox(height: 12),
            ] else ...[
              DropdownButtonFormField<String>(
                value: _fixedCategory,
                decoration: const InputDecoration(
                    labelText: 'Asset category',
                    helperText: 'All items in this category share one ledger',
                    border: OutlineInputBorder()),
                items: _fixedCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _fixedCategory = v ?? ''),
              ),
              const SizedBox(height: 12),
            ],

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                  labelText: 'Amount',
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

            const Text('How was this paid?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: _paymentMode,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(
                    value: 'cash', child: Text('Paid by Cash')),
                const DropdownMenuItem(
                    value: 'bank', child: Text('Paid by Bank / Wallet')),
                const DropdownMenuItem(
                    value: 'supplier',
                    child: Text('On credit from Supplier')),
                const DropdownMenuItem(
                    value: 'loan_short',
                    child: Text('Loan - Current (under 1 year)')),
                const DropdownMenuItem(
                    value: 'loan_long',
                    child: Text('Loan - Non-Current (1+ years)')),
                const DropdownMenuItem(
                    value: 'capital',
                    child: Text("From Owner's Capital")),
              ],
              onChanged: (v) => setState(() {
                _paymentMode = v ?? 'cash';
                final list = _paymentAccountsForMode;
                _paymentAccId =
                    list.isNotEmpty ? list.first['id'] as String : '';
              }),
            ),
            const SizedBox(height: 10),

            // Payment source selector
            if (_paymentMode == 'supplier') ...[
              if (_suppliers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No suppliers yet. Add one from Settings > Suppliers first.',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _supplierId,
                  decoration: const InputDecoration(
                      labelText: 'Supplier',
                      border: OutlineInputBorder(), isDense: true),
                  items: _suppliers
                      .map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _supplierId = v ?? ''),
                ),
            ] else if (sourceList.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'No ${_paymentLabel(_paymentMode)} account yet. Create one in Settings > Manage Ledgers.',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _paymentAccId.isEmpty
                    ? sourceList.first['id'] as String
                    : _paymentAccId,
                decoration: const InputDecoration(
                    labelText: 'Specific account',
                    border: OutlineInputBorder(), isDense: true),
                items: sourceList
                    .map((a) => DropdownMenuItem(
                          value: a['id'] as String,
                          child: Text(a['name'] as String),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _paymentAccId = v ?? ''),
              ),

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(
                    _kind == 'asset' ? 'Save Fixed Asset' : 'Save Expense',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
