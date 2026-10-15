import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

final _money = NumberFormat('#,##0.00');
final _dateFmt = DateFormat('dd-MM-yy');

class BarberReportPage extends StatefulWidget {
  const BarberReportPage({super.key});
  @override
  State<BarberReportPage> createState() => _BarberReportPageState();
}

class _BarberReportPageState extends State<BarberReportPage> {
  final _db = DatabaseHelper();
  bool _loading = true;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  List<Map<String, dynamic>> _rows = [];
  double _grandTotal = 0;
  int _grandCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await _db.database;
    final start = DateTime(_from.year, _from.month, _from.day).toIso8601String();
    final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59).toIso8601String();

    final rows = await d.rawQuery('''
      SELECT
        COALESCE(si.barber_name, '(none)') AS barber,
        COUNT(*) AS services,
        COALESCE(SUM(si.total), 0) AS revenue,
        COUNT(DISTINCT si.invoice_id) AS bills
      FROM sale_items si
      JOIN invoices i ON i.id = si.invoice_id
      WHERE i.date >= ? AND i.date <= ?
      GROUP BY si.barber_name
      ORDER BY revenue DESC
    ''', [start, end]);

    double gt = 0;
    int gc = 0;
    for (var r in rows) {
      gt += (r['revenue'] as num).toDouble();
      gc += (r['services'] as int);
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _grandTotal = gt;
      _grandCount = gc;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Barber Productivity')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
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
                child: _rows.isEmpty
                    ? const Center(child: Text('No sales in this period.',
                        style: TextStyle(color: Colors.grey)))
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
                                _total(),
                                const SizedBox(height: 24),
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
        SizedBox(width: 180, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Barber', style: style))),
        SizedBox(width: 100, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Services', style: style, textAlign: TextAlign.right))),
        SizedBox(width: 100, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Bills', style: style, textAlign: TextAlign.right))),
        SizedBox(width: 150, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Revenue', style: style, textAlign: TextAlign.right))),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        SizedBox(width: 180, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(r['barber'] as String,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${r['services']}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14)))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${r['bills']}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14)))),
        SizedBox(width: 150, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(_money.format((r['revenue'] as num).toDouble()),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  Widget _total() {
    const bold = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
    return Container(
      color: Colors.green.shade50,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const SizedBox(width: 180, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('TOTAL', style: bold))),
        SizedBox(width: 100, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$_grandCount',
              textAlign: TextAlign.right, style: bold))),
        const SizedBox(width: 100, child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('', textAlign: TextAlign.right, style: bold))),
        SizedBox(width: 150, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(_money.format(_grandTotal),
              textAlign: TextAlign.right, style: bold))),
      ]),
    );
  }
}
