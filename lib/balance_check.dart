import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

final _dateFmt = DateFormat('dd-MM-yy');

class BalanceCheckPage extends StatefulWidget {
  const BalanceCheckPage({super.key});
  @override
  State<BalanceCheckPage> createState() => _BalanceCheckPageState();
}

class _BalanceCheckPageState extends State<BalanceCheckPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _broken = [];
  int _totalEntries = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper();
    final d = await db.database;
    final total = await d.rawQuery(
        'SELECT COUNT(*) AS c FROM journal_entries');
    final broken = await d.rawQuery('''
      SELECT je.id AS id, je.date AS date, je.narration AS narration,
             COALESCE(SUM(jl.debit), 0) AS td,
             COALESCE(SUM(jl.credit), 0) AS tc
      FROM journal_entries je
      JOIN journal_lines jl ON jl.entry_id = je.id
      GROUP BY je.id
      HAVING ABS(SUM(jl.debit) - SUM(jl.credit)) > 0.01
      ORDER BY je.date DESC
    ''');
    if (!mounted) return;
    setState(() {
      _broken = broken;
      _totalEntries = (total.first['c'] as int);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance Check')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _broken.isEmpty
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    border: Border.all(
                        color: _broken.isEmpty
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _broken.isEmpty
                            ? 'All journal entries are balanced'
                            : '${_broken.length} broken entries found',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _broken.isEmpty
                                ? Colors.green.shade900
                                : Colors.red.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text('Scanned $_totalEntries journal entries.',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_broken.isNotEmpty) ...[
                  const Text('Broken entries:',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._broken.map((e) {
                    final td = (e['td'] as num).toDouble();
                    final tc = (e['tc'] as num).toDouble();
                    final diff = (td - tc).abs();
                    final dt = DateTime.parse(e['date'] as String);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.error_outline,
                            color: Colors.red),
                        title: Text(
                            (e['narration'] as String?) ?? 'Untitled'),
                        subtitle: Text(
                            '${_dateFmt.format(dt)}  |  '
                            'Dr ${td.toStringAsFixed(2)} vs Cr ${tc.toStringAsFixed(2)}  |  '
                            'Diff ${diff.toStringAsFixed(2)}'),
                      ),
                    );
                  }),
                ],
              ],
            ),
    );
  }
}
