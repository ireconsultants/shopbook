import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import 'reports_page.dart';
import 'balance_check.dart';
import 'fixed_assets_page.dart';
import 'supplies_form.dart';
import 'accounts_page.dart';
import 'spend_form.dart';

void main() => runApp(const ShopBookApp());

const _uuid = Uuid();
final _money = NumberFormat('#,##0.00');
final _dateFmt = DateFormat('dd-MM-yy');

String money(double v) => _money.format(v);

const _seedItems = <List<String>>[
  ['Haircut', '500'],
  ['Kids Haircut', '300'],
  ['Shave', '200'],
  ['Beard Trim', '300'],
  ['Facial', '800'],
  ['Head Massage', '1000'],
  ['Hair Color', '2500'],
  ['Wash & Blow Dry', '600'],
];

const _seedAccounts = <List<String>>[
  ['Cash in Hand', 'asset', 'cash'],
  ['Accounts Receivable', 'asset', 'receivable'],
  ['Service Income', 'income', 'normal'],
  ['Supplies Purchased', 'expense', 'normal'],
  ['Rent', 'expense', 'normal'],
  ['Utilities', 'expense', 'normal'],
  ['Salary', 'expense', 'normal'],
  ['Tea & Refreshments', 'expense', 'normal'],
  ['Misc Expense', 'expense', 'normal'],
  ['Accrued Expenses', 'liability', 'accrued'],
  ['Owner Capital', 'equity', 'normal'],
  ['Owner Drawings', 'equity', 'normal'],
  ['Accounts Payable', 'liability', 'payable'],
];

// ============================================================
// APP
// ============================================================

class ShopBookApp extends StatelessWidget {
  const ShopBookApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barber Shop Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      ),
      home: const _Boot(),
    );
  }
}

class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  final _db = DatabaseHelper();
  bool _loading = true;
  bool _setupDone = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final name = await _db.getSetting('shop_name');
    if (!mounted) return;
    setState(() {
      _setupDone = name != null && name.isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _setupDone ? const MainShell() : const SetupScreen();
  }
}

// ============================================================
// SETUP
// ============================================================

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopCtrl = TextEditingController();
  final _cashCtrl = TextEditingController(text: '0');
  final _ownerNameCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = DatabaseHelper();

    for (var a in _seedAccounts) {
      final ex = await db.getAccountByName(a[0]);
      if (ex == null) {
        await db.insertAccount({
          'id': _uuid.v4(),
          'name': a[0],
          'type': a[1],
          'subtype': a.length > 2 ? a[2] : 'normal',
          'is_system': 1,
          'active': 1,
        });
      }
    }

    await db.setSetting('shop_name', _shopCtrl.text.trim());

    final incomeAcc = await db.getAccountByName('Service Income');
    for (var p in _seedItems) {
      await db.insertItem({
        'id': _uuid.v4(),
        'name': p[0],
        'type': 'service',
        'price': double.tryParse(p[1]) ?? 0,
        'category': null,
        'account_id': incomeAcc?['id'],
        'active': 1,
      });
    }

    final ownerName = _ownerNameCtrl.text.trim();
    if (ownerName.isNotEmpty) {
      await db.insertEmployee({
        'id': _uuid.v4(),
        'name': ownerName,
        'role': 'Barber',
        'active': 1,
      });
    }

    final cash = double.tryParse(_cashCtrl.text) ?? 0;
    if (cash > 0) {
      final cashAcc = await db.getAccountByName('Cash in Hand');
      final capAcc = await db.getAccountByName('Owner Capital');
      if (cashAcc != null && capAcc != null) {
        await db.insertJournalEntry(
          id: _uuid.v4(),
          date: DateTime.now().toIso8601String(),
          narration: 'Opening cash',
          source: 'opening',
          lines: [
            {
              'id': _uuid.v4(),
              'account_id': cashAcc['id'],
              'debit': cash,
              'credit': 0
            },
            {
              'id': _uuid.v4(),
              'account_id': capAcc['id'],
              'debit': 0,
              'credit': cash
            },
          ],
        );
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  void dispose() {
    _shopCtrl.dispose();
    _cashCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barber Shop Book', style: TextStyle(fontSize: 18)),
        actions: [
          Center(
            child: Text(
              'Powered by IRE Consultants',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset('assets/logo.png', height: 48),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Welcome!',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Set up your shop in 30 seconds.',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _shopCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop name',
                  hintText: 'e.g. Al-Noor Hair Salon',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your name (the main barber)',
                  hintText: 'e.g. Ali',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cashCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cash in hand right now',
                  helperText: 'How much is in your cash box? (0 if none)',
                  border: OutlineInputBorder(),
                  prefixText: 'Rs ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _finish,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Start', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '8 standard services and basic accounts will be ready. You can add customers, staff, and payment accounts anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAIN SHELL
// ============================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  String _shopName = '';
  double _cash = 0;
  double _receivable = 0;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _loadHeader();
  }

  Future<void> _loadHeader() async {
    final db = DatabaseHelper();
    final name = await db.getSetting('shop_name');
    final cash = await db.getCashBalance();
    final rec = await db.getTotalReceivable();
    if (!mounted) return;
    setState(() {
      _shopName = name ?? 'My Shop';
      _cash = cash;
      _receivable = rec;
    });
  }

  void _bump() {
    _refreshTick++;
    _loadHeader();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      SaleScreen(key: ValueKey('sale-$_refreshTick'), onChanged: _bump),
      CustomersScreen(key: ValueKey('cust-$_refreshTick'), onChanged: _bump),
      SuppliesScreen(key: ValueKey('sup-$_refreshTick'), onChanged: _bump),
      ExpenseScreen(key: ValueKey('exp-$_refreshTick'), onChanged: _bump),
      ItemsScreen(onChanged: _bump),
      FullReportsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_shopName, style: const TextStyle(fontSize: 18)),
        actions: [
          Center(
            child: Text(
              'Powered by IRE Consultants',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Image.asset('assets/logo.png', height: 48),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Cash: ${money(_cash)}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  if (_receivable > 0)
                    Text('Due: ${money(_receivable)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orange)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _bump();
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.content_cut), label: 'Sale'),
          NavigationDestination(
              icon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(
              icon: Icon(Icons.shopping_bag), label: 'Supplies'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long), label: 'Expense'),
          NavigationDestination(
              icon: Icon(Icons.list_alt), label: 'Items'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'Reports'),
        ],
      ),
    );
  }
}

// ============================================================
// SALE SCREEN
// ============================================================

class SaleScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const SaleScreen({super.key, required this.onChanged});
  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _paymentAccounts = [];
  final List<_Line> _bill = [];
  bool _loading = true;

  DateTime _saleDate = DateTime.now();
  Map<String, dynamic>? _customer;
  String? _currentBarberId;
  String? _receivedById;
  String? _paymentAccountId;
  final _paidCtrl = TextEditingController();
  bool _paymentSplit = false;
  final _discountCtrl = TextEditingController();
  bool _vatEnabled = false;
  double _vatRate = 0;
  String _vatBasis = 'gross';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _db.getActiveItems();
    final custs = await _db.getActiveCustomers();
    final emps = await _db.getActiveEmployees();
    final advStr = await _db.getSetting('advanced_mode');
    final vatEnStr = await _db.getSetting('vat_enabled');
    final vatRateStr = await _db.getSetting('vat_rate') ?? '0';
    final vatBasisStr = await _db.getSetting('vat_basis') ?? 'gross';
    final adv = advStr == '1';
    final vatOn = adv && vatEnStr == '1';
    final vatRate = double.tryParse(vatRateStr) ?? 0;
    final all = await _db.getAllAccounts();
    final payAccs = all
        .where((a) =>
            a['type'] == 'asset' &&
            (a['subtype'] == 'cash' || a['subtype'] == 'bank' ||
             a['subtype'] == 'wallet'))
        .toList();
    if (!mounted) return;
    setState(() {
      _items = items;
      _customers = custs;
      _employees = emps;
      _paymentAccounts = payAccs;
      _currentBarberId =
          emps.isNotEmpty ? emps.first['id'] as String : null;
      _receivedById =
          emps.isNotEmpty ? emps.first['id'] as String : null;
      _paymentAccountId =
          payAccs.isNotEmpty ? payAccs.first['id'] as String : null;
      _vatEnabled = vatOn;
      _vatRate = vatRate;
      _vatBasis = vatBasisStr;
      _loading = false;
    });
  }

  double get _subtotal => _bill.fold(0.0, (s, l) => s + l.total);
  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _vat {
    if (!_vatEnabled || _vatRate <= 0) return 0;
    double base = _subtotal;
    if (_vatBasis == 'net') {
      base = _subtotal - _discount;
      if (base < 0) base = 0;
    }
    return double.parse((base * _vatRate / 100).toStringAsFixed(2));
  }
  double get _total => _subtotal - _discount + _vat;
  double get _paid {
    if (!_paymentSplit) return _total;
    return double.tryParse(_paidCtrl.text) ?? 0;
  }

  double get _unpaid {
    final d = _total - _paid;
    return d < 0 ? 0 : d;
  }

  double get _advance {
    final d = _paid - _total;
    return d > 0 ? d : 0;
  }

  void _addItem(Map<String, dynamic> item) {
    setState(() {
      final i = _bill.indexWhere((l) =>
          l.itemId == item['id'] && l.barberId == _currentBarberId);
      if (i >= 0) {
        _bill[i].qty++;
      } else {
        final barber = _employees.firstWhere(
            (e) => e['id'] == _currentBarberId,
            orElse: () => <String, dynamic>{});
        _bill.add(_Line(
          itemId: item['id'],
          name: item['name'],
          price: (item['price'] as num).toDouble(),
          barberId: _currentBarberId,
          barberName: barber['name'] as String?,
        ));
      }
    });
  }

  void _clear() {
    setState(() {
      _bill.clear();
      _paidCtrl.clear();
      _discountCtrl.clear();
      _paymentSplit = false;
    });
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.directions_walk, color: Colors.grey),
              title: const Text('Walk-in (no name)'),
              onTap: () => Navigator.pop(ctx, <String, dynamic>{}),
            ),
            const Divider(height: 1),
            if (_customers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No customers yet. Add from Customers tab.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _customers.length,
                  itemBuilder: (_, i) {
                    final c = _customers[i];
                    final bal = (c['current_balance'] as num).toDouble();
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(c['name'] as String),
                      subtitle: (c['phone'] as String?)?.isEmpty ?? true
                          ? null
                          : Text(c['phone'] as String),
                      trailing: bal != 0
                          ? Text(money(bal.abs()),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: bal > 0
                                      ? Colors.orange
                                      : Colors.green))
                          : null,
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _customer = picked.isEmpty ? null : picked);
  }

  Future<void> _changeDate() async {
    if (_bill.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Change date?'),
          content: const Text('Current bill will be cleared.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Change')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    final p = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) {
      setState(() {
        _saleDate = p;
        _bill.clear();
      });
    }
  }

  Future<void> _save({bool share = false}) async {
    if (_bill.isEmpty) return;
    if (_paymentAccountId == null) return;

    final cash = _total;
    final subtotal = _subtotal;
    final discount = _discount;
    final vat = _vat;
    final paid = _paid;
    final unpaid = _unpaid;
    final advance = _advance;

    final paymentAcc = await _db.getAccountById(_paymentAccountId!);
    final incomeAcc = await _db.getAccountByName('Service Income');
    final recAcc = await _db.getAccountByName('Accounts Receivable');
    if (paymentAcc == null || incomeAcc == null || recAcc == null) return;

    Future<String> ensure(String name, String type) async {
      final a = await _db.getAccountByName(name);
      if (a != null) return a['id'] as String;
      final id = _uuid.v4();
      await _db.insertAccount({
        'id': id, 'name': name, 'type': type,
        'is_system': 1, 'active': 1,
      });
      return id;
    }
    final discountAccId =
        discount > 0 ? await ensure('Discount Allowed', 'expense') : null;
    final vatAccId =
        vat > 0 ? await ensure('VAT Payable', 'liability') : null;

    final lines = <Map<String, dynamic>>[];

    if (paid > 0) {
      lines.add({
        'id': _uuid.v4(),
        'account_id': paymentAcc['id'],
        'debit': paid,
        'credit': 0,
      });
    }

    if (unpaid > 0) {
      lines.add({
        'id': _uuid.v4(),
        'account_id': recAcc['id'],
        'debit': unpaid,
        'credit': 0,
      });
    }

    if (discountAccId != null) {
      lines.add({
        'id': _uuid.v4(),
        'account_id': discountAccId,
        'debit': discount,
        'credit': 0,
      });
    }

    if (vatAccId != null) {
      lines.add({
        'id': _uuid.v4(),
        'account_id': vatAccId,
        'debit': 0,
        'credit': vat,
      });
    }

    lines.add({
      'id': _uuid.v4(),
      'account_id': incomeAcc['id'],
      'debit': 0,
      'credit': subtotal,
    });

    if (advance > 0) {
      lines.add({
        'id': _uuid.v4(),
        'account_id': recAcc['id'],
        'debit': 0,
        'credit': advance,
      });
    }

    final invoiceId = _uuid.v4();
    final invNo = await _db.nextInvoiceNo();
    final combined = DateTime(
      _saleDate.year,
      _saleDate.month,
      _saleDate.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );

    final serviceLine = _bill.map((l) => '${l.qty}x ${l.name}').join(', ');
    final narration = 'Sale $invNo: $serviceLine';

    await _db.insertJournalEntry(
      id: _uuid.v4(),
      date: combined.toIso8601String(),
      narration: narration,
      source: 'sale',
      sourceId: invoiceId,
      lines: lines,
    );

    await _db.insertInvoice({
      'id': invoiceId,
      'invoice_no': invNo,
      'date': combined.toIso8601String(),
      'customer_id': _customer?['id'],
      'customer_name': _customer?['name'] ?? 'Walk-in',
      'subtotal': subtotal,
      'discount': discount,
      'vat': vat,
      'total': cash,
      'paid_amount': paid,
      'balance_due': unpaid - advance,
      'payment_mode': paymentAcc['name'],
      'received_by_id': _receivedById,
      'received_by_name': _receivedById == null
          ? null
          : _employees
              .firstWhere((e) => e['id'] == _receivedById,
                  orElse: () => <String, dynamic>{})['name'],
      'journal_entry_id': null,
      'narration': serviceLine,
    });

    await _db.insertSaleItems(_bill
        .map((l) => {
              'id': _uuid.v4(),
              'invoice_id': invoiceId,
              'item_id': l.itemId,
              'item_name': l.name,
              'price': l.price,
              'quantity': l.qty,
              'total': l.total,
              'barber_id': l.barberId,
              'barber_name': l.barberName,
            })
        .toList());

    if (_customer != null && _customer!['id'] != null) {
      final delta = unpaid - advance;
      if (delta != 0) {
        await _db.adjustCustomerBalance(
            _customer!['id'] as String, delta);
      }
    }

    if (!mounted) return;

    final shopName = await _db.getSetting('shop_name') ?? 'Shop';
    final invText = _buildInvoiceText(
        shopName,
        invNo,
        _customer?['name'] ?? 'Walk-in',
        _bill,
        cash,
        paid,
        unpaid - advance,
        paymentAcc['name'] as String);

    if (share) {
      await Share.share(invText);
    }

    _clear();
    widget.onChanged();
    await _load();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $invNo - ${money(cash)}')),
      );
    }
  }

  String _buildInvoiceText(String shop, String invNo, String cust,
      List<_Line> bill, double total, double paid, double due, String mode) {
    final b = StringBuffer();
    b.writeln('*$shop*');
    b.writeln(invNo);
    b.writeln('Date: ${_dateFmt.format(_saleDate)}');
    b.writeln('Customer: $cust');
    b.writeln('');
    for (var l in bill) {
      b.writeln(
          '- ${l.qty}x ${l.name}${l.barberName != null ? " (${l.barberName})" : ""}   ${money(l.total)}');
    }
    b.writeln('');
    b.writeln('Total: ${money(total)}');
    b.writeln('Paid: ${money(paid)} ($mode)');
    if (due > 0) b.writeln('*Due: ${money(due)}*');
    b.writeln('');
    b.writeln('Thank you for your business!');
    b.writeln('_Powered by IRE Consultants_');
    return b.toString();
  }

  bool get _isToday {
    final n = DateTime.now();
    return _saleDate.year == n.year &&
        _saleDate.month == n.month &&
        _saleDate.day == n.day;
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _buildTopBar(),
        Expanded(child: _buildGrid()),
        if (_bill.isNotEmpty) _buildBillPanel(),
      ],
    );
  }

  Widget _buildTopBar() {
    final custLabel =
        _customer == null ? 'Walk-in' : _customer!['name'] as String;
    return Container(
      color: _isToday ? Colors.teal.shade50 : Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickCustomer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.teal.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person,
                            size: 18,
                            color: _customer == null
                                ? Colors.grey
                                : Colors.teal),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            custLabel,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _customer == null
                                    ? Colors.grey.shade700
                                    : Colors.black87),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(_isToday ? Icons.today : Icons.event_note,
                    color: _isToday ? Colors.teal : Colors.orange.shade800),
                onPressed: _changeDate,
                tooltip: _isToday ? 'Today' : _dateFmt.format(_saleDate),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Service by',
                            style: TextStyle(fontSize: 10, color: Colors.black54)),
                      ),
                      DropdownButton<String>(
                        value: _currentBarberId,
                        isDense: true,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _employees
                            .map((e) => DropdownMenuItem(
                                  value: e['id'] as String,
                                  child: Text(e['name'] as String,
                                      style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _currentBarberId = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Cash received by',
                            style: TextStyle(fontSize: 10, color: Colors.black54)),
                      ),
                      DropdownButton<String>(
                        value: _receivedById,
                        isDense: true,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _employees
                            .map((e) => DropdownMenuItem(
                                  value: e['id'] as String,
                                  child: Text(e['name'] as String,
                                      style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _receivedById = v),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_items.isEmpty) {
      return const Center(
        child: Text('No services yet.\nGo to Items tab.',
            textAlign: TextAlign.center),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.35,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        final inBill = _bill
            .where((l) => l.itemId == item['id'])
            .fold(0, (s, l) => s + l.qty);
        return Card(
          elevation: inBill > 0 ? 4 : 2,
          color: inBill > 0 ? Colors.teal.shade50 : null,
          child: InkWell(
            onTap: () => _addItem(item),
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['name'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(money((item['price'] as num).toDouble()),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.teal)),
                    ],
                  ),
                ),
                if (inBill > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.teal, shape: BoxShape.circle),
                      child: Text('$inBill',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _bill.length,
              itemBuilder: (_, i) {
                final l = _bill[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l.qty}x ${l.name}'),
                  subtitle: l.barberName != null
                      ? Text(l.barberName!,
                          style: const TextStyle(fontSize: 11))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(money(l.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.redAccent),
                        onPressed: () =>
                            setState(() => _bill.removeAt(i)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 8),
          Row(
            children: [
              const Text('Payment mode:',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _paymentAccountId,
                  isDense: true,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: _paymentAccounts
                      .map((a) => DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text(a['name'] as String,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _paymentAccountId = v),
                ),
              ),
            ],
          ),
          if (_paymentSplit) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Amount paid: ',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _paidCtrl,
                    decoration: const InputDecoration(
                        isDense: true, prefixText: 'Rs '),
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountCtrl,
                  decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Discount',
                      prefixText: 'Rs '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Total:',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(money(_total),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal)),
            ],
          ),
          if (_paymentSplit && _unpaid > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text('Due: ${money(_unpaid)}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600)),
            ),
          if (_paymentSplit && _advance > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text('Advance: ${money(_advance)}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.green,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _paymentSplit = !_paymentSplit;
                      if (!_paymentSplit) _paidCtrl.clear();
                    });
                  },
                  icon: Icon(
                      _paymentSplit ? Icons.lock_open : Icons.edit_note),
                  label: Text(
                      _paymentSplit ? 'Full Payment' : 'Partial'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                    onPressed: _clear, child: const Text('Clear')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _save(share: false),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _save(share: true),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Save & Share',
                      style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line {
  final String itemId;
  final String name;
  final double price;
  final String? barberId;
  final String? barberName;
  int qty;
  _Line({
    required this.itemId,
    required this.name,
    required this.price,
    this.barberId,
    this.barberName,
    this.qty = 1,
  });
  double get total => price * qty;
}

// ============================================================
// CUSTOMERS
// ============================================================

class CustomersScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const CustomersScreen({super.key, required this.onChanged});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.getActiveCustomers();
    if (!mounted) return;
    setState(() {
      _customers = rows;
      _loading = false;
    });
  }

  Future<void> _addEdit([Map<String, dynamic>? c]) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => CustomerFormPage(existing: c)),
    );
    if (result != null) {
      if (c == null) {
        await _db.insertCustomer(result);
      } else {
        await _db.updateCustomer(c['id'] as String, result);
      }
      await _load();
      widget.onChanged();
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text('"${c['name']}" will be hidden.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.deleteCustomer(c['id'] as String);
    await _load();
    widget.onChanged();
  }

  Future<void> _openLedger(Map<String, dynamic> c) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CustomerLedgerPage(customer: c)));
    await _load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _customers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No customers yet.\nTap + to add your first customer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
              ),
            )
          : ListView.separated(
              itemCount: _customers.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final c = _customers[i];
                final bal = (c['current_balance'] as num).toDouble();
                final name = c['name'] as String;
                final phone = c['phone'] as String?;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  subtitle: (phone == null || phone.isEmpty)
                      ? null
                      : Text(phone),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (bal != 0)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(bal.abs()),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: bal > 0
                                        ? Colors.orange
                                        : Colors.green)),
                            Text(bal > 0 ? 'Owes' : 'Advance',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey)),
                          ],
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            size: 20, color: Colors.black54),
                        onPressed: () => _addEdit(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.redAccent),
                        onPressed: () => _delete(c),
                      ),
                    ],
                  ),
                  onTap: () => _openLedger(c),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ============================================================
// CUSTOMER FORM
// ============================================================

class CustomerFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const CustomerFormPage({super.key, this.existing});
  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _openBalCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?['name'] ?? '');
    _phoneCtrl =
        TextEditingController(text: widget.existing?['phone'] ?? '');
    _openBalCtrl = TextEditingController(
        text: widget.existing == null
            ? '0'
            : (widget.existing!['opening_balance'] as num).toString());
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'id': widget.existing?['id'] ?? _uuid.v4(),
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'opening_balance': double.tryParse(_openBalCtrl.text) ?? 0,
      'current_balance': widget.existing?['current_balance'] ??
          (double.tryParse(_openBalCtrl.text) ?? 0),
      'active': 1,
    };
    Navigator.pop(context, data);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _openBalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar:
          AppBar(title: Text(isEdit ? 'Edit Customer' : 'Add Customer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              if (!isEdit)
                TextFormField(
                  controller: _openBalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opening balance',
                    helperText:
                        'Amount already owed (0 if new customer)',
                    border: OutlineInputBorder(),
                    prefixText: 'Rs ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save',
                        style: TextStyle(fontSize: 16))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOMER LEDGER
// ============================================================

class CustomerLedgerPage extends StatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerLedgerPage({super.key, required this.customer});
  @override
  State<CustomerLedgerPage> createState() =>
      _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db
        .getInvoicesForCustomer(widget.customer['id'] as String);
    if (!mounted) return;
    setState(() {
      _invoices = list;
      _loading = false;
    });
  }

  Future<void> _receivePayment() async {
    final paidCtrl = TextEditingController();
    final picked = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive Payment'),
        content: TextField(
          controller: paidCtrl,
          decoration: const InputDecoration(
              labelText: 'Amount received',
              prefixText: 'Rs ',
              border: OutlineInputBorder()),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                final v = double.tryParse(paidCtrl.text) ?? 0;
                if (v > 0) Navigator.pop(ctx, v);
              },
              child: const Text('Receive')),
        ],
      ),
    );
    if (picked == null || picked <= 0) return;

    final all = await _db.getAllAccounts();
    final payAccs = all
        .where((a) =>
            a['type'] == 'asset' &&
            a['name'] != 'Accounts Receivable')
        .toList();
    if (payAccs.isEmpty) return;
    if (!mounted) return;
    final accId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: payAccs
              .map((a) => ListTile(
                    leading:
                        const Icon(Icons.account_balance_wallet),
                    title: Text(a['name'] as String),
                    onTap: () =>
                        Navigator.pop(ctx, a['id'] as String),
                  ))
              .toList(),
        ),
      ),
    );
    if (accId == null) return;

    final recAcc = await _db.getAccountByName('Accounts Receivable');
    final payAcc = await _db.getAccountById(accId);
    if (recAcc == null || payAcc == null) return;

    await _db.insertJournalEntry(
      id: _uuid.v4(),
      date: DateTime.now().toIso8601String(),
      narration: 'Payment from ${widget.customer['name']}',
      source: 'payment',
      lines: [
        {
          'id': _uuid.v4(),
          'account_id': payAcc['id'],
          'debit': picked,
          'credit': 0
        },
        {
          'id': _uuid.v4(),
          'account_id': recAcc['id'],
          'debit': 0,
          'credit': picked
        },
      ],
    );

    await _db.adjustCustomerBalance(
        widget.customer['id'] as String, -picked);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment received: ${money(picked)}')),
    );
    await _load();
    final updated =
        await _db.getCustomerById(widget.customer['id'] as String);
    if (updated != null && mounted) {
      setState(() => widget.customer['current_balance'] =
          updated['current_balance']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bal =
        (widget.customer['current_balance'] as num?)?.toDouble() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer['name'] as String),
        actions: [
          if (bal > 0)
            TextButton.icon(
              onPressed: _receivePayment,
              icon: const Icon(Icons.payments),
              label: const Text('Receive'),
              style:
                  TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: bal > 0
                ? Colors.orange.shade100
                : Colors.green.shade100,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bal > 0
                      ? 'Customer owes you'
                      : bal < 0
                          ? 'Advance with you'
                          : 'Account settled',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(money(bal.abs()),
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: bal > 0
                            ? Colors.orange.shade900
                            : Colors.green.shade800)),
                if ((widget.customer['phone'] as String?)
                        ?.isNotEmpty ??
                    false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(widget.customer['phone'] as String,
                        style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? const Center(
                        child: Text('No invoices yet.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: _invoices.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final inv = _invoices[i];
                          final due = (inv['balance_due'] as num?)
                                  ?.toDouble() ??
                              0;
                          return ListTile(
                            title: Text(inv['invoice_no'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${_dateFmt.format(DateTime.parse(inv['date'] as String))}\n${inv['narration'] ?? ''}'),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                    money((inv['total'] as num)
                                        .toDouble()),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                if (due > 0)
                                  Text('Due ${money(due)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EXPENSE + SUPPLIES
// ============================================================

class ExpenseScreen extends StatelessWidget {
  final VoidCallback onChanged;
  const ExpenseScreen({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SpendFormPage(key: key, onChanged: onChanged);
  }
}

class _ExpenseForm extends StatefulWidget {
  final VoidCallback onChanged;
  const _ExpenseForm({required this.onChanged});
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _expenseAccounts = [];
  String? _accId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final all = await db.getAllAccounts();
    if (!mounted) return;
    setState(() {
      _expenseAccounts = all
          .where((a) =>
              a['type'] == 'expense' &&
              a['name'] != 'Supplies Purchased')
          .toList();
      _accId = _expenseAccounts.isNotEmpty
          ? _expenseAccounts.first['id'] as String
          : null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _accId == null) return;
    final db = DatabaseHelper();
    final cashAcc = await db.getAccountByName('Cash in Hand');
    if (cashAcc == null) return;
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (amt <= 0) return;
    final acc =
        _expenseAccounts.firstWhere((a) => a['id'] == _accId);
    await db.insertJournalEntry(
      id: _uuid.v4(),
      date: _date.toIso8601String(),
      narration:
          'Expense (${acc['name']}): ${_descCtrl.text.trim()}',
      source: 'expense',
      lines: [
        {
          'id': _uuid.v4(),
          'account_id': _accId,
          'debit': amt,
          'credit': 0
        },
        {
          'id': _uuid.v4(),
          'account_id': cashAcc['id'],
          'debit': 0,
          'credit': amt
        },
      ],
    );
    if (!mounted) return;
    _descCtrl.clear();
    _amountCtrl.clear();
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expense recorded: ${money(amt)}')));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
            DropdownButtonFormField<String>(
              value: _accId,
              decoration: const InputDecoration(
                  labelText: 'Expense category',
                  border: OutlineInputBorder()),
              items: _expenseAccounts
                  .map((a) => DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text(a['name'] as String),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _accId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. October rent',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
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
                if (d == null || d <= 0) return 'Invalid';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Expense',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuppliesScreen extends StatelessWidget {
  final VoidCallback onChanged;
  const SuppliesScreen({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SuppliesFormPage(onChanged: onChanged);
  }
}

class _SuppliesForm extends StatefulWidget {
  final VoidCallback onChanged;
  const _SuppliesForm({required this.onChanged});
  @override
  State<_SuppliesForm> createState() => _SuppliesFormState();
}

class _SuppliesFormState extends State<_SuppliesForm> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseHelper();
    final cashAcc = await db.getAccountByName('Cash in Hand');
    final supAcc = await db.getAccountByName('Supplies Purchased');
    if (cashAcc == null || supAcc == null) return;
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (amt <= 0) return;
    final entryId = _uuid.v4();
    await db.insertJournalEntry(
      id: entryId,
      date: _date.toIso8601String(),
      narration: 'Supplies: ${_descCtrl.text.trim()}',
      source: 'purchase',
      lines: [
        {
          'id': _uuid.v4(),
          'account_id': supAcc['id'],
          'debit': amt,
          'credit': 0
        },
        {
          'id': _uuid.v4(),
          'account_id': cashAcc['id'],
          'debit': 0,
          'credit': amt
        },
      ],
    );
    await db.insertPurchaseItems([
      {
        'id': _uuid.v4(),
        'entry_id': entryId,
        'item_name': _descCtrl.text.trim(),
        'price': amt,
        'quantity': 1,
        'total': amt,
        'vendor': _vendorCtrl.text.trim().isEmpty
            ? null
            : _vendorCtrl.text.trim(),
      }
    ]);
    if (!mounted) return;
    _descCtrl.clear();
    _amountCtrl.clear();
    _vendorCtrl.clear();
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supplies recorded: ${money(amt)}')));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _vendorCtrl.dispose();
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
                  hintText: 'e.g. 2 shampoo bottles',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vendorCtrl,
              decoration: const InputDecoration(
                  labelText: 'Vendor (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
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
                if (d == null || d <= 0) return 'Invalid';
                return null;
              },
            ),
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

// ============================================================
// ITEMS
// ============================================================

class ItemsScreen extends StatefulWidget {
  final VoidCallback onChanged;
  const ItemsScreen({super.key, required this.onChanged});
  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.getActiveItems();
    if (!mounted) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final nameCtrl =
        TextEditingController(text: item?['name'] ?? '');
    final priceCtrl = TextEditingController(
        text: item == null ? '' : (item['price'] as num).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Add Service' : 'Edit Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Service name', hintText: 'e.g. Haircut'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Price', prefixText: 'Rs '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
    if (ok != true) {
      nameCtrl.dispose();
      priceCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text) ?? 0;
    if (name.isEmpty || price <= 0) {
      nameCtrl.dispose();
      priceCtrl.dispose();
      return;
    }
    final incAcc = await _db.getAccountByName('Service Income');
    if (item == null) {
      await _db.insertItem({
        'id': _uuid.v4(),
        'name': name,
        'type': 'service',
        'price': price,
        'category': null,
        'account_id': incAcc?['id'],
        'active': 1,
      });
    } else {
      await _db.updateItem(item['id'] as String, {
        'name': name,
        'type': item['type'],
        'price': price,
        'category': item['category'],
        'account_id': incAcc?['id'],
        'active': 1,
      });
    }
    nameCtrl.dispose();
    priceCtrl.dispose();
    await _load();
    widget.onChanged();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove service?'),
        content: Text('"${item['name']}" will be hidden.'),
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
    await _db.deleteItem(item['id'] as String);
    await _load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _items.isEmpty
          ? const Center(
              child: Text('No services yet.\nTap + to add.',
                  textAlign: TextAlign.center))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final it = _items[i];
                return ListTile(
                  title: Text(it['name'] as String,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(money((it['price'] as num).toDouble()),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            size: 20, color: Colors.black54),
                        onPressed: () => _edit(it),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.redAccent),
                        onPressed: () => _delete(it),
                      ),
                    ],
                  ),
                  onTap: () => _edit(it),
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

// ============================================================
// REPORTS
// ============================================================

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseHelper();
  bool _loading = true;
  double _daySales = 0, _dayExp = 0, _cash = 0, _rec = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final s = await _db.getDaySales(now);
    final e = await _db.getDayExpenses(now);
    final c = await _db.getCashBalance();
    final r = await _db.getTotalReceivable();
    if (!mounted) return;
    setState(() {
      _daySales = s;
      _dayExp = e;
      _cash = c;
      _rec = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final profit = _daySales - _dayExp;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Today",
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(_dateFmt.format(DateTime.now()),
              style:
                  const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          _card('Sales', money(_daySales), Colors.green),
          const SizedBox(height: 8),
          _card('Expenses', money(_dayExp), Colors.orange),
          const SizedBox(height: 8),
          _card('Profit', money(profit),
              profit >= 0 ? Colors.teal : Colors.red),
          const SizedBox(height: 20),
          const Text("Now",
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _card('Cash in Hand', money(_cash), Colors.blueGrey),
          const SizedBox(height: 8),
          _card('Customer Dues', money(_rec), Colors.deepOrange),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.construction, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Full P&L, Trial Balance, Ledger, PDF export coming next.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
        border: Border(left: BorderSide(color: color, width: 5)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: Colors.black87))),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

// ============================================================
// SETTINGS SCREEN
// ============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper();
  final _shopCtrl = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _payAccounts = [];
  bool _loading = true;
  bool _advancedMode = false;
  bool _vatEnabled = false;
  final _vatRateCtrl = TextEditingController();
  String _vatBasis = 'gross';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await _db.getSetting('shop_name') ?? '';
    final advStr = await _db.getSetting('advanced_mode');
    final vatEnStr = await _db.getSetting('vat_enabled');
    final vatRateStr = await _db.getSetting('vat_rate') ?? '0';
    final vatBasisStr = await _db.getSetting('vat_basis') ?? 'gross';
    final adv = advStr == '1';
    final emps = await _db.getActiveEmployees();
    final all = await _db.getAllAccounts();
    final pay = all
        .where((a) =>
            a['type'] == 'asset' &&
            (a['subtype'] == 'cash' || a['subtype'] == 'bank' ||
             a['subtype'] == 'wallet'))
        .toList();
    if (!mounted) return;
    setState(() {
      _shopCtrl.text = name;
      _employees = emps;
      _payAccounts = pay;
      _advancedMode = adv;
      _vatEnabled = vatEnStr == '1';
      _vatRateCtrl.text = vatRateStr;
      _vatBasis = vatBasisStr;
      _loading = false;
    });
  }

  Future<void> _saveVatSettings() async {
    await _db.setSetting('vat_enabled', _vatEnabled ? '1' : '0');
    await _db.setSetting('vat_rate', _vatRateCtrl.text);
    await _db.setSetting('vat_basis', _vatBasis);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('VAT settings saved'),
        duration: Duration(seconds: 1)));
  }

  Future<void> _toggleAdvancedMode(bool v) async {
    await _db.setSetting('advanced_mode', v ? '1' : '0');
    if (!mounted) return;
    setState(() => _advancedMode = v);
  }

  Future<void> _saveShopName() async {
    final v = _shopCtrl.text.trim();
    if (v.isEmpty) return;
    await _db.setSetting('shop_name', v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop name updated')));
  }

  Future<void> _editEmployee([Map<String, dynamic>? e]) async {
    final nameCtrl = TextEditingController(text: e?['name'] ?? '');
    final roleCtrl =
        TextEditingController(text: e?['role'] ?? 'Barber');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e == null ? 'Add Staff' : 'Edit Staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true),
            const SizedBox(height: 8),
            TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Role (e.g. Barber, Cashier)')),
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
    if (ok != true) {
      nameCtrl.dispose();
      roleCtrl.dispose();
      return;
    }
    if (nameCtrl.text.trim().isEmpty) {
      nameCtrl.dispose();
      roleCtrl.dispose();
      return;
    }
    if (e == null) {
      await _db.insertEmployee({
        'id': _uuid.v4(),
        'name': nameCtrl.text.trim(),
        'role': roleCtrl.text.trim(),
        'active': 1,
      });
    } else {
      await _db.updateEmployee(e['id'] as String, {
        'name': nameCtrl.text.trim(),
        'role': roleCtrl.text.trim(),
        'active': 1,
      });
    }
    nameCtrl.dispose();
    roleCtrl.dispose();
    await _load();
  }

  Future<void> _deleteEmployee(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove staff?'),
        content: Text('"${e['name']}" will be hidden.'),
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
    await _db.deleteEmployee(e['id'] as String);
    await _load();
  }

  Future<void> _addPaymentAccount() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment Account'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
              labelText: 'Account name',
              hintText: 'e.g. HBL Bank, JazzCash, EasyPaisa'),
          autofocus: true,
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
    if (ok != true) {
      nameCtrl.dispose();
      return;
    }
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      nameCtrl.dispose();
      return;
    }
    nameCtrl.dispose();
    await _db.insertAccount({
      'id': _uuid.v4(),
      'name': name,
      'type': 'asset',
      'subtype': 'bank',
      'is_system': 0,
      'active': 1,
    });
    await _load();
  }

  Future<void> _deletePaymentAccount(Map<String, dynamic> a) async {
    if (a['is_system'] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('System account cannot be removed')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
            '"${a['name']}" will be hidden from payment options.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _db.updateAccount(a['id'] as String, {'active': 0});
    await _load();
  }

  @override
  void dispose() {
    _shopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          Center(
            child: Text(
              'Powered by IRE Consultants',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset('assets/logo.png', height: 48),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Shop',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _shopCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Shop name',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.save, color: Colors.teal),
                onPressed: _saveShopName,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Staff',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editEmployee(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_employees.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No staff added yet.',
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ..._employees.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.person, color: Colors.teal),
                  title: Text(e['name'] as String),
                  subtitle: Text(e['role'] as String? ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editEmployee(e),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.redAccent),
                        onPressed: () => _deleteEmployee(e),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Advanced Mode',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text(
                'Show fixed assets, loans, capital and other accounting options'),
            value: _advancedMode,
            onChanged: _toggleAdvancedMode,
          ),
          if (_advancedMode) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VAT Settings',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text(
                      'Applied automatically to every sale when enabled',
                      style: TextStyle(
                          fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable VAT'),
                    value: _vatEnabled,
                    onChanged: (v) {
                      setState(() => _vatEnabled = v);
                      _saveVatSettings();
                    },
                  ),
                  if (_vatEnabled) ...[
                    TextField(
                      controller: _vatRateCtrl,
                      decoration: const InputDecoration(
                          labelText: 'VAT rate',
                          suffixText: '%',
                          isDense: true,
                          border: OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _saveVatSettings(),
                    ),
                    const SizedBox(height: 10),
                    const Text('Compute VAT on:',
                        style: TextStyle(fontSize: 12)),
                    DropdownButtonFormField<String>(
                      value: _vatBasis,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(
                            value: 'gross',
                            child: Text('Gross sale (before discount)')),
                        DropdownMenuItem(
                            value: 'net',
                            child: Text('Net sale (after discount)')),
                      ],
                      onChanged: (v) {
                        setState(() => _vatBasis = v ?? 'gross');
                        _saveVatSettings();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Accounts & Suppliers',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_shipping, color: Colors.teal),
            title: const Text('Suppliers'),
            subtitle: const Text('Vendors you buy from on credit'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SuppliersPage()));
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet, color: Colors.teal),
            title: const Text('Manage Ledgers'),
            subtitle: const Text('Create new ledger accounts'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManageLedgersPage()));
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chair, color: Colors.teal),
            title: const Text('Fixed Assets'),
            subtitle: const Text('Furniture, equipment, chairs, AC, etc.'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FixedAssetsPage()));
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle_outline, color: Colors.teal),
            title: const Text('Balance Check'),
            subtitle: const Text('Verify debits = credits in all entries'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BalanceCheckPage()));
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Payment Accounts',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addPaymentAccount,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
              'Cash is always available. Add bank or online wallet accounts here.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          ..._payAccounts.map((a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    a['name'] == 'Cash in Hand'
                        ? Icons.money
                        : Icons.account_balance,
                    color: Colors.teal),
                title: Text(a['name'] as String),
                subtitle: a['is_system'] == 1
                    ? const Text('System account',
                        style: TextStyle(fontSize: 11))
                    : null,
                trailing: a['is_system'] == 1
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.redAccent),
                        onPressed: () => _deletePaymentAccount(a),
                      ),
              )),
    ],
      ),
    );
  }
}
