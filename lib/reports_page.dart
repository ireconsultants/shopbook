import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'barber_report.dart';

final _money = NumberFormat('#,##0.00');
final _dateFmt = DateFormat('dd-MM-yy');

String _fmt(double v) {
  if (v.isNegative) return '(${_money.format(-v)})';
  return _money.format(v);
}

String _plain(double v) => _money.format(v);

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

class FullReportsScreen extends StatelessWidget {
  const FullReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _menuTile(context, 'Trial Balance',
              'Every account with debit / credit balances',
              Icons.balance, const TrialBalancePage()),
          _menuTile(context, 'Profit & Loss',
              'Income minus expenses for a period',
              Icons.trending_up, const ProfitLossPage()),
          _menuTile(context, 'Balance Sheet',
              'Assets, liabilities and equity at a date',
              Icons.account_balance, const BalanceSheetPage()),
          _menuTile(context, 'Ledger Viewer',
              'Every transaction in any account',
              Icons.menu_book, const LedgerListPage()),
          _menuTile(context, 'Day Book',
              'All journal entries by date',
              Icons.event_note, const DayBookPage()),
          _menuTile(context, 'Barber Productivity',
              'Services and revenue by barber',
              Icons.people_alt, const BarberReportPage()),
        ],
      ),
    );
  }

  Widget _menuTile(BuildContext context, String title, String subtitle,
      IconData icon, Widget page) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Icon(icon, color: Colors.teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}

class _TBRow {
  final String name;
  final String type;
  final double debit;
  final double credit;
  _TBRow(this.name, this.type, this.debit, this.credit);
}

class TrialBalancePage extends StatefulWidget {
  const TrialBalancePage({super.key});
  @override
  State<TrialBalancePage> createState() => _TrialBalancePageState();
}

class _TrialBalancePageState extends State<TrialBalancePage> {
  bool _loading = true;
  List<_TBRow> _rows = [];
  double _totalDebit = 0;
  double _totalCredit = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final d = await db.database;
    final data = await d.rawQuery('''
      SELECT a.name AS account_name, a.type AS account_type,
             COALESCE(SUM(jl.debit), 0) AS total_debit,
             COALESCE(SUM(jl.credit), 0) AS total_credit
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      WHERE a.active = 1
      GROUP BY a.id
      ORDER BY a.type, a.name
    ''');

    final rows = <_TBRow>[];
    double td = 0, tc = 0;
    for (var r in data) {
      final debit = (r['total_debit'] as num).toDouble();
      final credit = (r['total_credit'] as num).toDouble();
      final net = debit - credit;
      if (net == 0) continue;
      if (net > 0) {
        rows.add(_TBRow(r['account_name'] as String,
            r['account_type'] as String, net, 0));
        td += net;
      } else {
        rows.add(_TBRow(r['account_name'] as String,
            r['account_type'] as String, 0, -net));
        tc += -net;
      }
    }

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _totalDebit = td;
      _totalCredit = tc;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trial Balance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No transactions yet.',
                      textAlign: TextAlign.center)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 560,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          ..._rows.map(_row),
                          _totalRow(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _header() {
    const style = TextStyle(fontWeight: FontWeight.bold, color: Colors.white);
    return Container(
      color: Colors.teal.shade800,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: const Row(children: [
        SizedBox(width: 260, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Account', style: style))),
        SizedBox(width: 100, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Type', style: style))),
        SizedBox(width: 100, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Debit', style: style, textAlign: TextAlign.right))),
        SizedBox(width: 100, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Credit', style: style, textAlign: TextAlign.right))),
      ]),
    );
  }

  Widget _row(_TBRow r) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        SizedBox(width: 260, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(r.name, style: const TextStyle(fontSize: 13)))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(_typeLabel(r.type),
              style: const TextStyle(fontSize: 12, color: Colors.grey)))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(r.debit == 0 ? '' : _plain(r.debit),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13)))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(r.credit == 0 ? '' : _plain(r.credit),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13)))),
      ]),
    );
  }

  Widget _totalRow() {
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final balanced = (_totalDebit - _totalCredit).abs() < 0.01;
    return Container(
      decoration: BoxDecoration(
        color: balanced ? Colors.green.shade50 : Colors.red.shade50,
        border: Border(top: BorderSide(
            color: balanced ? Colors.green.shade800 : Colors.red.shade800,
            width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const SizedBox(width: 260, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('TOTAL', style: bold))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(balanced ? 'Balanced' : 'Out of balance',
              style: TextStyle(fontSize: 11,
                  color: balanced ? Colors.green.shade800 : Colors.red)))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(_plain(_totalDebit),
              textAlign: TextAlign.right, style: bold))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(_plain(_totalCredit),
              textAlign: TextAlign.right, style: bold))),
      ]),
    );
  }
}

class ProfitLossPage extends StatefulWidget {
  const ProfitLossPage({super.key});
  @override
  State<ProfitLossPage> createState() => _ProfitLossPageState();
}

class _ProfitLossPageState extends State<ProfitLossPage> {
  bool _loading = true;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  List<Map<String, dynamic>> _income = [];
  List<Map<String, dynamic>> _expense = [];
  double _incomeTotal = 0;
  double _expenseTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();
    final d = await db.database;
    final start = DateTime(_from.year, _from.month, _from.day).toIso8601String();
    final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59).toIso8601String();

    final inc = await d.rawQuery('''
      SELECT a.name AS account_name,
             COALESCE(SUM(jl.credit - jl.debit), 0) AS amount
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      LEFT JOIN journal_entries je ON je.id = jl.entry_id
      WHERE a.type = 'income' AND a.active = 1
        AND (je.date IS NULL OR (je.date >= ? AND je.date <= ?))
      GROUP BY a.id HAVING amount != 0 ORDER BY a.name
    ''', [start, end]);

    final exp = await d.rawQuery('''
      SELECT a.name AS account_name,
             COALESCE(SUM(jl.debit - jl.credit), 0) AS amount
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      LEFT JOIN journal_entries je ON je.id = jl.entry_id
      WHERE a.type = 'expense' AND a.active = 1
        AND (je.date IS NULL OR (je.date >= ? AND je.date <= ?))
      GROUP BY a.id HAVING amount != 0 ORDER BY a.name
    ''', [start, end]);

    double it = 0, et = 0;
    for (var r in inc) { it += (r['amount'] as num).toDouble(); }
    for (var r in exp) { et += (r['amount'] as num).toDouble(); }

    if (!mounted) return;
    setState(() {
      _income = inc;
      _expense = exp;
      _incomeTotal = it;
      _expenseTotal = et;
      _loading = false;
    });
  }

  Future<void> _pickFrom() async {
    final p = await showDatePicker(context: context,
        initialDate: _from, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (p != null) { setState(() => _from = p); _load(); }
  }

  Future<void> _pickTo() async {
    final p = await showDatePicker(context: context,
        initialDate: _to, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (p != null) { setState(() => _to = p); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final profit = _incomeTotal - _expenseTotal;
    return Scaffold(
      appBar: AppBar(title: const Text('Profit & Loss')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.teal.shade50,
                  child: Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _pickFrom,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('From: ${_dateFmt.format(_from)}',
                          style: const TextStyle(fontSize: 12)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _pickTo,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('To: ${_dateFmt.format(_to)}',
                          style: const TextStyle(fontSize: 12)),
                    )),
                  ]),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const _SectionHeader('Income'),
                      if (_income.isEmpty)
                        const Padding(padding: EdgeInsets.all(8),
                            child: Text('No income in this period.',
                                style: TextStyle(color: Colors.grey)))
                      else
                        ..._income.map((r) => _lineItem(
                            r['account_name'] as String,
                            (r['amount'] as num).toDouble())),
                      _subtotal('Total Income', _incomeTotal),
                      const SizedBox(height: 16),
                      const _SectionHeader('Expenses'),
                      if (_expense.isEmpty)
                        const Padding(padding: EdgeInsets.all(8),
                            child: Text('No expenses in this period.',
                                style: TextStyle(color: Colors.grey)))
                      else
                        ..._expense.map((r) => _lineItem(
                            r['account_name'] as String,
                            (r['amount'] as num).toDouble())),
                      _subtotal('Total Expenses', _expenseTotal),
                      const SizedBox(height: 20),
                      _netProfit(profit),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _lineItem(String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(children: [
        Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
        Text(_plain(amount),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _subtotal(String label, double amount) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
        Text(_plain(amount),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _netProfit(double profit) {
    final isProfit = profit >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isProfit ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isProfit ? Colors.green.shade700 : Colors.red.shade700,
            width: 2),
      ),
      child: Row(children: [
        Expanded(child: Text(
          isProfit ? 'Net Profit' : 'Net Loss',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: isProfit ? Colors.green.shade900 : Colors.red.shade900),
        )),
        Text(_plain(profit.abs()),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: isProfit ? Colors.green.shade900 : Colors.red.shade900)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      color: Colors.teal.shade800,
      child: Text(title,
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

class _BSGroup {
  final String title;
  final List<Map<String, dynamic>> items;
  _BSGroup(this.title, this.items);
  double get total =>
      items.fold(0.0, (s, r) => s + (r['amount'] as num).toDouble());
}

class BalanceSheetPage extends StatefulWidget {
  const BalanceSheetPage({super.key});
  @override
  State<BalanceSheetPage> createState() => _BalanceSheetPageState();
}

class _BalanceSheetPageState extends State<BalanceSheetPage> {
  bool _loading = true;
  DateTime _asOf = DateTime.now();

  List<_BSGroup> _nonCurrentAssets = [];
  List<_BSGroup> _currentAssets = [];
  List<_BSGroup> _equity = [];
  List<_BSGroup> _nonCurrentLiabilities = [];
  List<_BSGroup> _currentLiabilities = [];

  double _ncaTotal = 0, _caTotal = 0, _eqTotal = 0;
  double _nclTotal = 0, _clTotal = 0;
  double _netProfit = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper();
    final d = await db.database;
    final cutoff = DateTime(_asOf.year, _asOf.month, _asOf.day, 23, 59, 59)
        .toIso8601String();

    // All accounts with debit-normal balance (asset / expense)
    final assetRows = await d.rawQuery('''
      SELECT a.name AS n, a.subtype AS st,
             COALESCE(SUM(jl.debit - jl.credit), 0) AS amount
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      LEFT JOIN journal_entries je ON je.id = jl.entry_id
      WHERE a.type = 'asset' AND a.active = 1
        AND (je.date IS NULL OR je.date <= ?)
      GROUP BY a.id
      ORDER BY a.name
    ''', [cutoff]);

    final liabRows = await d.rawQuery('''
      SELECT a.name AS n, a.subtype AS st,
             COALESCE(SUM(jl.credit - jl.debit), 0) AS amount
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      LEFT JOIN journal_entries je ON je.id = jl.entry_id
      WHERE a.type = 'liability' AND a.active = 1
        AND (je.date IS NULL OR je.date <= ?)
      GROUP BY a.id
      ORDER BY a.name
    ''', [cutoff]);

    final equityRows = await d.rawQuery('''
      SELECT a.name AS n,
             COALESCE(SUM(jl.credit - jl.debit), 0) AS amount
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      LEFT JOIN journal_entries je ON je.id = jl.entry_id
      WHERE a.type = 'equity' AND a.active = 1
        AND (je.date IS NULL OR je.date <= ?)
      GROUP BY a.id
      ORDER BY a.name
    ''', [cutoff]);

    final pl = await d.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN a.type = 'income'
            THEN jl.credit - jl.debit ELSE 0 END), 0) AS inc,
        COALESCE(SUM(CASE WHEN a.type = 'expense'
            THEN jl.debit - jl.credit ELSE 0 END), 0) AS exp
      FROM accounts a
      JOIN journal_lines jl ON jl.account_id = a.id
      JOIN journal_entries je ON je.id = jl.entry_id
      WHERE je.date <= ?
    ''', [cutoff]);
    _netProfit = (pl.first['inc'] as num).toDouble() -
        (pl.first['exp'] as num).toDouble();

    // Group assets
    List<Map<String, dynamic>> pick(
        List<Map<String, dynamic>> rows, List<String> subs) {
      return rows.where((r) => subs.contains(r['st'])).toList();
    }

    final fixedItems = pick(assetRows, ['fixed']);
    final inventoryItems = pick(assetRows, ['inventory']);
    final receivableItems = pick(assetRows, ['receivable']);
    final prepayItems = pick(assetRows, ['prepayment']);
    final cashItems = pick(assetRows, ['cash', 'bank', 'wallet']);
    final otherAssetItems = pick(assetRows, ['normal']);

    _nonCurrentAssets = [
      if (fixedItems.isNotEmpty) _BSGroup('Property and Equipment', fixedItems),
    ];

    _currentAssets = [
      if (inventoryItems.isNotEmpty)
        _BSGroup('Inventory', inventoryItems),
      if (receivableItems.isNotEmpty)
        _BSGroup('Accounts Receivable', receivableItems),
      if (prepayItems.isNotEmpty) _BSGroup('Prepayments', prepayItems),
      if (cashItems.isNotEmpty) _BSGroup('Cash and Bank', cashItems),
      if (otherAssetItems.isNotEmpty)
        _BSGroup('Other Current Assets', otherAssetItems),
    ];

    _equity = [
      _BSGroup('Capital', equityRows),
    ];

    final longTermLoanItems = pick(liabRows, ['loan_long']);
    final payableItems = pick(liabRows, ['payable']);
    final accruedItems = pick(liabRows, ['accrued']);
    final shortLoanItems = pick(liabRows, ['loan_short']);
    final otherLiabItems = pick(liabRows, ['normal']);

    _nonCurrentLiabilities = [
      if (longTermLoanItems.isNotEmpty)
        _BSGroup('Long-Term Loans', longTermLoanItems),
    ];

    _currentLiabilities = [
      if (payableItems.isNotEmpty)
        _BSGroup('Trade Payables', payableItems),
      if (accruedItems.isNotEmpty)
        _BSGroup('Accrued Expenses', accruedItems),
      if (shortLoanItems.isNotEmpty)
        _BSGroup('Short-Term Loans', shortLoanItems),
      if (otherLiabItems.isNotEmpty)
        _BSGroup('Other Current Liabilities', otherLiabItems),
    ];

    _ncaTotal = _nonCurrentAssets.fold(0.0, (s, g) => s + g.total);
    _caTotal = _currentAssets.fold(0.0, (s, g) => s + g.total);
    _eqTotal = _equity.fold(0.0, (s, g) => s + g.total) + _netProfit;
    _nclTotal = _nonCurrentLiabilities.fold(0.0, (s, g) => s + g.total);
    _clTotal = _currentLiabilities.fold(0.0, (s, g) => s + g.total);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(context: context,
        initialDate: _asOf, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (p != null) { setState(() => _asOf = p); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final totalAssets = _ncaTotal + _caTotal;
    final totalLiabAndEq = _nclTotal + _clTotal + _eqTotal;
    final balanced = (totalAssets - totalLiabAndEq).abs() < 0.01;

    return Scaffold(
      appBar: AppBar(title: const Text('Balance Sheet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.teal.shade50,
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('As of: ${_dateFmt.format(_asOf)}',
                      style: const TextStyle(fontSize: 14))),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Change'),
                  ),
                ]),
              ),
              Expanded(child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const _SectionHeader('NON-CURRENT ASSETS'),
                  ..._renderGroups(_nonCurrentAssets),
                  _subtotal('Total Non-Current Assets', _ncaTotal),
                  const SizedBox(height: 16),
                  const _SectionHeader('CURRENT ASSETS'),
                  ..._renderGroups(_currentAssets),
                  _subtotal('Total Current Assets', _caTotal),
                  const SizedBox(height: 16),
                  _subtotal('TOTAL ASSETS', totalAssets, big: true),
                  const SizedBox(height: 24),
                  const _SectionHeader('EQUITY'),
                  ..._renderGroups(_equity),
                  _lineItem(_netProfit >= 0 ? 'Profit for the period'
                      : 'Loss for the period', _netProfit),
                  _subtotal('Total Equity', _eqTotal),
                  const SizedBox(height: 16),
                  const _SectionHeader('NON-CURRENT LIABILITIES'),
                  if (_nonCurrentLiabilities.isEmpty)
                    const Padding(padding: EdgeInsets.all(8),
                        child: Text('None',
                            style: TextStyle(color: Colors.grey)))
                  else
                    ..._renderGroups(_nonCurrentLiabilities),
                  _subtotal('Total Non-Current Liabilities', _nclTotal),
                  const SizedBox(height: 16),
                  const _SectionHeader('CURRENT LIABILITIES'),
                  if (_currentLiabilities.isEmpty)
                    const Padding(padding: EdgeInsets.all(8),
                        child: Text('None',
                            style: TextStyle(color: Colors.grey)))
                  else
                    ..._renderGroups(_currentLiabilities),
                  _subtotal('Total Current Liabilities', _clTotal),
                  const SizedBox(height: 16),
                  _subtotal('TOTAL EQUITY + LIABILITIES', totalLiabAndEq,
                      big: true),
                  const SizedBox(height: 24),
                  _balanceCheck(balanced, totalLiabAndEq),
                ],
              )),
            ]),
    );
  }

  List<Widget> _renderGroups(List<_BSGroup> groups) {
    final out = <Widget>[];
    for (var g in groups) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Text(g.title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: Colors.teal)),
      ));
      for (var it in g.items) {
        out.add(Padding(
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4, right: 4),
          child: Row(children: [
            Expanded(child: Text(it['n'] as String,
                style: const TextStyle(fontSize: 13))),
            Text(_plain((it['amount'] as num).toDouble()),
                style: const TextStyle(fontSize: 13)),
          ]),
        ));
      }
      out.add(Padding(
        padding: const EdgeInsets.only(left: 16, right: 4, top: 2, bottom: 6),
        child: Row(children: [
          Expanded(child: Text('Subtotal - ${g.title}',
              style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Text(_plain(g.total),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ));
    }
    return out;
  }

  Widget _lineItem(String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(children: [
        Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
        Text(_plain(amount),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _subtotal(String label, double amount, {bool big = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: big ? Colors.teal.shade800 : Colors.grey,
              width: big ? 2 : 1),
        ),
      ),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(fontSize: big ? 14 : 13,
                fontWeight: FontWeight.bold,
                color: big ? Colors.teal.shade900 : Colors.black))),
        Text(_plain(amount),
            style: TextStyle(fontSize: big ? 15 : 13,
                fontWeight: FontWeight.bold,
                color: big ? Colors.teal.shade900 : Colors.black)),
      ]),
    );
  }

  Widget _balanceCheck(bool balanced, double liabilitiesAndEquity) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: balanced ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: balanced ? Colors.green.shade700 : Colors.red.shade700,
            width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(balanced ? 'Assets = Liabilities + Equity'
            : 'Does not balance',
            style: TextStyle(fontWeight: FontWeight.bold,
                color: balanced ? Colors.green.shade900 : Colors.red.shade900)),
        const SizedBox(height: 6),
        Text('Assets: ${_plain(_ncaTotal + _caTotal)}',
            style: const TextStyle(fontSize: 13)),
        Text('Liabilities + Equity: ${_plain(liabilitiesAndEquity)}',
            style: const TextStyle(fontSize: 13)),
      ]),
    );
  }
}

class LedgerListPage extends StatefulWidget {
  const LedgerListPage({super.key});
  @override
  State<LedgerListPage> createState() => _LedgerListPageState();
}

class _LedgerListPageState extends State<LedgerListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _accounts = [];

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
      _accounts = all.where((a) => a['active'] == 1).toList();
      _loading = false;
    });
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'asset': return Icons.account_balance_wallet;
      case 'liability': return Icons.credit_card;
      case 'equity': return Icons.foundation;
      case 'income': return Icons.trending_up;
      case 'expense': return Icons.trending_down;
      default: return Icons.account_balance;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ledger Viewer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _accounts.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final a = _accounts[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Icon(_iconFor(a['type'] as String),
                        size: 20, color: Colors.teal),
                  ),
                  title: Text(a['name'] as String),
                  subtitle: Text(_typeLabel(a['type'] as String),
                      style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountLedgerPage(
                        accountId: a['id'] as String,
                        accountName: a['name'] as String,
                        accountType: a['type'] as String,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AccountLedgerPage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String accountType;
  const AccountLedgerPage({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.accountType,
  });
  @override
  State<AccountLedgerPage> createState() => _AccountLedgerPageState();
}

class _AccountLedgerPageState extends State<AccountLedgerPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _lines = [];
  double _totalDebit = 0;
  double _totalCredit = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final d = await db.database;
    final rows = await d.rawQuery('''
      SELECT je.date AS date, je.narration AS narration,
             jl.debit AS debit, jl.credit AS credit
      FROM journal_lines jl
      JOIN journal_entries je ON je.id = jl.entry_id
      WHERE jl.account_id = ?
      ORDER BY je.date ASC
    ''', [widget.accountId]);

    double td = 0, tc = 0;
    for (var r in rows) {
      td += (r['debit'] as num).toDouble();
      tc += (r['credit'] as num).toDouble();
    }

    if (!mounted) return;
    setState(() {
      _lines = rows;
      _totalDebit = td;
      _totalCredit = tc;
      _loading = false;
    });
  }

  double get _netBalance {
    final t = widget.accountType;
    if (t == 'asset' || t == 'expense') return _totalDebit - _totalCredit;
    return _totalCredit - _totalDebit;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.accountName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                color: Colors.teal.shade50,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type: ${_typeLabel(widget.accountType)}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Net balance: ${_fmt(_netBalance)}',
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  )),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Dr: ${_plain(_totalDebit)}',
                        style: const TextStyle(fontSize: 11)),
                    Text('Cr: ${_plain(_totalCredit)}',
                        style: const TextStyle(fontSize: 11)),
                  ]),
                ]),
              ),
              Expanded(
                child: _lines.isEmpty
                    ? const Center(child: Text('No transactions in this account.',
                        style: TextStyle(color: Colors.grey)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: SizedBox(width: 720,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _header(),
                                ..._lines.asMap().entries
                                    .map((e) => _row(e.value, e.key + 1)),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _header() {
    const style = TextStyle(fontWeight: FontWeight.bold, color: Colors.white);
    return Container(
      color: Colors.teal.shade800,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: const Row(children: [
        SizedBox(width: 40, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('#', style: style))),
        SizedBox(width: 90, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Date', style: style))),
        SizedBox(width: 340, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Narration', style: style))),
        SizedBox(width: 90, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Debit', style: style, textAlign: TextAlign.right))),
        SizedBox(width: 90, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Credit', style: style, textAlign: TextAlign.right))),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> r, int idx) {
    final debit = (r['debit'] as num).toDouble();
    final credit = (r['credit'] as num).toDouble();
    final date = DateTime.parse(r['date'] as String);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 40, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('$idx',
              style: const TextStyle(fontSize: 11, color: Colors.grey)))),
        SizedBox(width: 90, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(_dateFmt.format(date),
              style: const TextStyle(fontSize: 12)))),
        SizedBox(width: 340, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text((r['narration'] as String?) ?? '',
              style: const TextStyle(fontSize: 12)))),
        SizedBox(width: 90, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(debit == 0 ? '' : _plain(debit),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12)))),
        SizedBox(width: 90, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(credit == 0 ? '' : _plain(credit),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12)))),
      ]),
    );
  }
}

class DayBookPage extends StatefulWidget {
  const DayBookPage({super.key});
  @override
  State<DayBookPage> createState() => _DayBookPageState();
}

class _DayBookPageState extends State<DayBookPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final d = await db.database;
    final rows = await d.rawQuery('''
      SELECT je.id AS id, je.date AS date, je.narration AS narration,
             je.source AS source
      FROM journal_entries je
      ORDER BY je.date DESC
      LIMIT 500
    ''');
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Day Book')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No entries yet.'))
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final e = _entries[i];
                    final d = DateTime.parse(e['date'] as String);
                    return ListTile(
                      dense: true,
                      leading: Text(_dateFmt.format(d),
                          style: const TextStyle(fontSize: 12)),
                      title: Text((e['narration'] as String?) ?? '-',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text((e['source'] as String?) ?? '',
                          style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
    );
  }
}
