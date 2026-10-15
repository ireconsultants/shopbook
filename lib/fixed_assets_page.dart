import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'reports_page.dart';

const _uuid = Uuid();
final _dateFmt = DateFormat('dd-MM-yy');
final _money = NumberFormat('#,##0.00');

class FixedAssetsPage extends StatefulWidget {
  const FixedAssetsPage({super.key});
  @override
  State<FixedAssetsPage> createState() => _FixedAssetsPageState();
}

class _FixedAssetsPageState extends State<FixedAssetsPage> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _assets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.getFixedAssets();
    final enriched = <Map<String, dynamic>>[];
    for (var r in rows) {
      final bal = await _db.getAccountBalance(r['id'] as String);
      enriched.add({...r, 'balance': bal});
    }
    if (!mounted) return;
    setState(() { _assets = enriched; _loading = false; });
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String sourceType = 'capital';
    String sourceAccId = '';
    String supplierId = '';

    final allAcc = await _db.getAllAccounts();
    final capitalAccs = allAcc
        .where((a) => a['type'] == 'equity' && a['active'] == 1)
        .toList();
    final currentLiabAccs = allAcc
        .where((a) =>
            a['type'] == 'liability' &&
            a['active'] == 1 &&
            (a['subtype'] == 'payable' || a['subtype'] == 'accrued') &&
            !(a['name'] as String).startsWith('AP - '))
        .toList();
    final nonCurrentLiabAccs = allAcc
        .where((a) =>
            a['type'] == 'liability' &&
            a['active'] == 1 &&
            a['subtype'] == 'long_term_liability')
        .toList();
    final suppliers = await _db.getActiveSuppliers();

    if (capitalAccs.isNotEmpty) {
      sourceAccId = capitalAccs.first['id'] as String;
    }
    if (suppliers.isNotEmpty) supplierId = suppliers.first['id'] as String;

    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          List<Map<String, dynamic>> shownAccs = [];
          String label = '';
          String hint = '';
          if (sourceType == 'capital') {
            shownAccs = capitalAccs;
            label = 'Capital account';
            hint = 'e.g. Owner Capital - paid from your own money';
          } else if (sourceType == 'supplier') {
            label = 'Supplier';
            hint = 'Vendor you bought from, payment due later';
          } else if (sourceType == 'loan_current') {
            shownAccs = currentLiabAccs;
            label = 'Current liability';
            hint = 'Short-term - to be paid within 1 year';
          } else if (sourceType == 'loan_noncurrent') {
            shownAccs = nonCurrentLiabAccs;
            label = 'Non-current liability';
            hint = 'Long-term - to be paid after 1+ years';
          }
          if (sourceType != 'supplier' &&
              shownAccs.isNotEmpty &&
              !shownAccs.any((a) => a['id'] == sourceAccId)) {
            sourceAccId = shownAccs.first['id'] as String;
          }

          return AlertDialog(
            title: const Text('Add Fixed Asset'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Asset name',
                      hintText: 'e.g. Barber Chair, AC, Mirror'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Cost', prefixText: 'Rs '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${_dateFmt.format(date)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) setSt(() => date = p);
                  },
                ),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('How was this paid for?',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: sourceType,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(
                        value: 'capital',
                        child: Text("Own money (Owner's Capital)")),
                    DropdownMenuItem(
                        value: 'supplier',
                        child: Text('Bought from supplier on credit')),
                    DropdownMenuItem(
                        value: 'loan_current',
                        child: Text('Bank/Other loan - pay within 1 year')),
                    DropdownMenuItem(
                        value: 'loan_noncurrent',
                        child: Text('Long-term loan - pay after 1+ years')),
                  ],
                  onChanged: (v) => setSt(() => sourceType = v!),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(hint,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black54)),
                ),
                const SizedBox(height: 10),
                if (sourceType == 'supplier') ...[
                  if (suppliers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'No suppliers yet. Add one from\nSettings > Suppliers first.',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: supplierId,
                      decoration: const InputDecoration(
                          labelText: 'Supplier',
                          border: OutlineInputBorder(), isDense: true),
                      items: suppliers
                          .map((s) => DropdownMenuItem(
                                value: s['id'] as String,
                                child: Text(s['name'] as String),
                              ))
                          .toList(),
                      onChanged: (v) => setSt(() => supplierId = v ?? ''),
                    ),
                ] else if (shownAccs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'No $label found. Create one in\nSettings > Manage Ledgers first.',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: sourceAccId,
                    decoration: InputDecoration(
                        labelText: label,
                        border: const OutlineInputBorder(),
                        isDense: true),
                    items: shownAccs
                        .map((a) => DropdownMenuItem(
                              value: a['id'] as String,
                              child: Text(a['name'] as String),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setSt(() => sourceAccId = v ?? ''),
                  ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save')),
            ],
          );
        },
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final amt = double.tryParse(amountCtrl.text) ?? 0;
    if (name.isEmpty || amt <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter asset name and cost.')));
      }
      return;
    }

    // Resolve which account funds this asset
    String crAccId = '';
    String crAccName = '';
    String? supplierBalanceId;

    if (sourceType == 'supplier') {
      if (supplierId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please select a supplier.')));
        }
        return;
      }
      final supplier = suppliers.firstWhere(
        (s) => s['id'] == supplierId,
        orElse: () => <String, dynamic>{},
      );
      final sName = supplier['name'] as String?;
      if (sName == null || sName.isEmpty) return;
      final apName = 'AP - $sName';
      var apAcc = await _db.getAccountByName(apName);
      if (apAcc == null) {
        final id = _uuid.v4();
        await _db.insertAccount({
          'id': id, 'name': apName, 'type': 'liability',
          'subtype': 'payable', 'is_system': 0, 'active': 1,
        });
        apAcc = {'id': id, 'name': apName};
      }
      crAccId = apAcc['id'] as String;
      crAccName = apName;
      supplierBalanceId = supplierId;
    } else {
      if (sourceAccId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please select a source account.')));
        }
        return;
      }
      crAccId = sourceAccId;
    }

    // Create or reuse the fixed asset account
    var assetAcc = await _db.getAccountByName(name);
    if (assetAcc == null || assetAcc['subtype'] != 'fixed') {
      final id = _uuid.v4();
      await _db.insertAccount({
        'id': id,
        'name': name,
        'type': 'asset',
        'subtype': 'fixed',
        'is_system': 0,
        'active': 1,
      });
      assetAcc = {'id': id, 'name': name};
    }

    // Post the journal entry
    await _db.insertJournalEntry(
      id: _uuid.v4(),
      date: date.toIso8601String(),
      narration: 'Fixed asset: $name',
      source: 'fixed_asset',
      lines: [
        {'id': _uuid.v4(),
          'account_id': assetAcc['id'] as String,
          'debit': amt, 'credit': 0},
        {'id': _uuid.v4(),
          'account_id': crAccId,
          'debit': 0, 'credit': amt},
      ],
    );

    if (supplierBalanceId != null) {
      await _db.adjustSupplierBalance(supplierBalanceId, amt);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$name recorded: Rs ${_money.format(amt)}'),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fixed Assets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No fixed assets yet.\n'
                      'Tap + to record furniture, chairs, AC, equipment, etc.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _assets.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final a = _assets[i];
                    final bal = (a['balance'] as num).toDouble();
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFB2DFDB),
                        child: Icon(Icons.chair, color: Colors.teal),
                      ),
                      title: Text(a['name'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: const Text('Fixed asset',
                          style: TextStyle(fontSize: 12)),
                      trailing: Text(_money.format(bal),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AccountLedgerPage(
                            accountId: a['id'] as String,
                            accountName: a['name'] as String,
                            accountType: 'asset',
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
