import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'reports_page.dart';

const _uuid = Uuid();

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});
  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.getActiveSuppliers();
    final List<Map<String, dynamic>> enriched = [];
    for (var r in rows) {
      final apName = 'AP - ${r['name']}';
      var apAcc = await _db.getAccountByName(apName);
      if (apAcc == null) {
        final id = _uuid.v4();
        await _db.insertAccount({
          'id': id, 'name': apName, 'type': 'liability',
          'is_system': 0, 'active': 1,
        });
        apAcc = {'id': id};
      }
      final bal = await _db.getAccountBalance(apAcc['id'] as String);
      enriched.add({...r, 'current_balance': bal, 'ap_id': apAcc['id']});
    }
    if (!mounted) return;
    setState(() { _suppliers = enriched; _loading = false; });
  }

  Future<void> _edit([Map<String, dynamic>? s]) async {
    final nameCtrl = TextEditingController(text: s?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: s?['phone'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s == null ? 'Add Supplier' : 'Edit Supplier'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true),
          const SizedBox(height: 8),
          TextField(
              controller: phoneCtrl,
              decoration:
                  const InputDecoration(labelText: 'Phone (optional)')),
        ]),
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
    if (ok != true) { nameCtrl.dispose(); phoneCtrl.dispose(); return; }
    final name = nameCtrl.text.trim();
    if (name.isEmpty) { nameCtrl.dispose(); phoneCtrl.dispose(); return; }

    final dup = _suppliers.firstWhere(
      (x) => (x['name'] as String).toLowerCase() == name.toLowerCase()
          && x['id'] != (s?['id'] ?? ''),
      orElse: () => <String, dynamic>{},
    );
    if (dup.isNotEmpty) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('A supplier named "$name" already exists.')));
      return;
    }

    if (s == null) {
      await _db.insertSupplier({
        'id': _uuid.v4(),
        'name': name,
        'phone': phoneCtrl.text.trim(),
        'current_balance': 0,
        'active': 1,
      });
      final apName = 'AP - $name';
      final existing = await _db.getAccountByName(apName);
      if (existing == null) {
        await _db.insertAccount({
          'id': _uuid.v4(), 'name': apName, 'type': 'liability',
          'is_system': 0, 'active': 1,
        });
      }
    } else {
      final oldName = s['name'] as String;
      await _db.updateSupplier(s['id'] as String, {
        'name': name,
        'phone': phoneCtrl.text.trim(),
        'current_balance': s['current_balance'],
        'active': 1,
      });
      if (oldName != name) {
        final oldAp = await _db.getAccountByName('AP - $oldName');
        if (oldAp != null) {
          await _db.updateAccount(oldAp['id'] as String, {
            'name': 'AP - $name',
            'type': 'liability',
            'is_system': oldAp['is_system'],
            'active': 1,
          });
        }
      }
    }
    nameCtrl.dispose();
    phoneCtrl.dispose();
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove supplier?'),
        content: Text('"${s['name']}" will be hidden.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteSupplier(s['id'] as String);
    await _load();
  }

  Future<void> _openLedger(Map<String, dynamic> s) async {
    final apName = 'AP - ${s['name']}';
    final apAcc = await _db.getAccountByName(apName);
    if (apAcc != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountLedgerPage(
            accountId: apAcc['id'] as String,
            accountName: 'Ledger: ${s['name']}',
            accountType: 'liability',
          ),
        ),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? const Center(child: Text('No suppliers yet.\nTap + to add.',
                  textAlign: TextAlign.center))
              : ListView.separated(
                  itemCount: _suppliers.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final s = _suppliers[i];
                    final bal = (s['current_balance'] as num).toDouble();
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFB2DFDB),
                        child: Icon(Icons.local_shipping,
                            color: Colors.teal),
                      ),
                      title: Text(s['name'] as String,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: (s['phone'] as String?)?.isEmpty ?? true
                          ? const Text('Tap to view ledger',
                              style: TextStyle(fontSize: 12))
                          : Text(s['phone'] as String,
                              style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (bal != 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(bal.toStringAsFixed(2),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: bal > 0
                                          ? Colors.orange
                                          : Colors.green)),
                            ),
                          IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _edit(s)),
                          IconButton(
                              icon: const Icon(Icons.delete,
                                  size: 20, color: Colors.redAccent),
                              onPressed: () => _delete(s)),
                        ],
                      ),
                      onTap: () => _openLedger(s),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ManageLedgersPage extends StatefulWidget {
  const ManageLedgersPage({super.key});
  @override
  State<ManageLedgersPage> createState() => _ManageLedgersPageState();
}

class _ManageLedgersPageState extends State<ManageLedgersPage> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _db.getAllAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = all.where((a) => a['active'] == 1).toList();
      _loading = false;
    });
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'asset': return 'Asset';
      case 'liability': return 'Liability';
      case 'equity': return 'Equity';
      case 'income': return 'Income';
      case 'expense': return 'Expense';
      default: return t;
    }
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    String type = 'expense';
    String subtype = 'normal';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('New Ledger Account'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Account name',
                      hintText: 'e.g. Loan, Advertising, HBL Bank'),
                  autofocus: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'asset', child: Text('Asset')),
                  DropdownMenuItem(value: 'liability', child: Text('Liability')),
                  DropdownMenuItem(value: 'equity', child: Text('Equity')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                ],
                onChanged: (v) => setSt(() {
                  type = v!;
                  subtype = _defaultSubtype(type);
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: subtype,
                decoration: const InputDecoration(labelText: 'Subtype'),
                items: _subtypeItems(type),
                onChanged: (v) => setSt(() => subtype = v!),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(_subtypeHint(type, subtype),
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final existing = await _db.getAccountByName(name);
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('An account with this name already exists.')));
      return;
    }
    await _db.insertAccount({
      'id': _uuid.v4(),
      'name': name,
      'type': type,
      'subtype': subtype,
      'is_system': 0,
      'active': 1,
    });
    await _load();
  }

  String _defaultSubtype(String type) {
    if (type == 'asset') return 'bank';
    if (type == 'liability') return 'payable';
    return 'normal';
  }

  List<DropdownMenuItem<String>> _subtypeItems(String type) {
    if (type == 'asset') {
      return const [
        DropdownMenuItem(value: 'cash', child: Text('Cash')),
        DropdownMenuItem(value: 'bank', child: Text('Bank / Wallet')),
        DropdownMenuItem(value: 'fixed', child: Text('Fixed asset')),
        DropdownMenuItem(value: 'receivable', child: Text('Receivable')),
        DropdownMenuItem(value: 'normal', child: Text('Other asset')),
      ];
    }
    if (type == 'liability') {
      return const [
        DropdownMenuItem(value: 'payable',
            child: Text('Current liability (under 1 year)')),
        DropdownMenuItem(value: 'accrued',
            child: Text('Accrued expense (bill received, not paid)')),
        DropdownMenuItem(value: 'long_term_liability',
            child: Text('Non-current liability (over 1 year)')),
      ];
    }
    return const [DropdownMenuItem(value: 'normal', child: Text('Normal'))];
  }

  String _subtypeHint(String type, String subtype) {
    if (type == 'asset' && subtype == 'bank') {
      return 'Shows up in Payment Accounts for sales and purchases.';
    }
    if (type == 'asset' && subtype == 'fixed') {
      return 'Furniture, equipment, machines. Long-life assets.';
    }
    if (type == 'liability' && subtype == 'payable') {
      return 'Short-term: you owe this within a year.';
    }
    if (type == 'liability' && subtype == 'long_term_liability') {
      return 'Long-term: loan to be repaid after 1+ years.';
    }
    if (type == 'liability' && subtype == 'accrued') {
      return 'Bill received but payment not yet made.';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Ledgers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _accounts.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final a = _accounts[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.account_balance_wallet,
                      color: Colors.teal),
                  title: Text(a['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_typeLabel(a['type'] as String),
                      style: const TextStyle(fontSize: 12)),
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
