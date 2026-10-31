import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'shopbook.db');
    return await openDatabase(path,
        version: 5,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('''CREATE TABLE accounts(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
      subtype TEXT DEFAULT 'normal',
      is_system INTEGER DEFAULT 0, active INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE items(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
      price REAL NOT NULL, category TEXT, account_id TEXT,
      active INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE customers(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT,
      opening_balance REAL DEFAULT 0, current_balance REAL DEFAULT 0,
      active INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE employees(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, role TEXT,
      active INTEGER DEFAULT 1)''');
    await db.execute('''CREATE TABLE journal_entries(
      id TEXT PRIMARY KEY, date TEXT NOT NULL, narration TEXT,
      source TEXT, source_id TEXT, created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE journal_lines(
      id TEXT PRIMARY KEY, entry_id TEXT NOT NULL, account_id TEXT NOT NULL,
      debit REAL DEFAULT 0, credit REAL DEFAULT 0,
      FOREIGN KEY (entry_id) REFERENCES journal_entries (id) ON DELETE CASCADE)''');
    await db.execute('''CREATE TABLE invoices(
      id TEXT PRIMARY KEY, invoice_no TEXT NOT NULL, date TEXT NOT NULL,
      customer_id TEXT, customer_name TEXT,
      subtotal REAL DEFAULT 0, discount REAL DEFAULT 0, vat REAL DEFAULT 0,
      total REAL NOT NULL, paid_amount REAL NOT NULL DEFAULT 0,
      balance_due REAL NOT NULL DEFAULT 0,
      payment_mode TEXT, received_by_id TEXT, received_by_name TEXT,
      journal_entry_id TEXT, narration TEXT)''');
    await db.execute('''CREATE TABLE sale_items(
      id TEXT PRIMARY KEY, invoice_id TEXT NOT NULL, item_id TEXT NOT NULL,
      item_name TEXT NOT NULL, price REAL NOT NULL, quantity INTEGER NOT NULL,
      total REAL NOT NULL, barber_id TEXT, barber_name TEXT)''');
    await db.execute('''CREATE TABLE purchase_items(
      id TEXT PRIMARY KEY, entry_id TEXT NOT NULL, item_name TEXT NOT NULL,
      price REAL NOT NULL, quantity INTEGER NOT NULL, total REAL NOT NULL,
      vendor TEXT)''');
    await db.execute('''CREATE TABLE suppliers(
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT,
      current_balance REAL DEFAULT 0, active INTEGER DEFAULT 1)''');
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 3) {
      await db.execute(
          "CREATE TABLE IF NOT EXISTS suppliers("
          "id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, "
          "current_balance REAL DEFAULT 0, active INTEGER DEFAULT 1)");
    }
    if (oldV < 5) {
      await db.execute("ALTER TABLE invoices ADD COLUMN subtotal REAL DEFAULT 0");
      await db.execute("ALTER TABLE invoices ADD COLUMN discount REAL DEFAULT 0");
      await db.execute("ALTER TABLE invoices ADD COLUMN vat REAL DEFAULT 0");
      await db.execute("UPDATE invoices SET subtotal = total WHERE subtotal = 0");
    }
    if (oldV < 4) {
      await db.execute(
          "ALTER TABLE accounts ADD COLUMN subtype TEXT DEFAULT 'normal'");
      await db.execute(
          "UPDATE accounts SET subtype = 'cash' WHERE name = 'Cash in Hand'");
      await db.execute(
          "UPDATE accounts SET subtype = 'receivable' "
          "WHERE name = 'Accounts Receivable'");
      await db.execute(
          "UPDATE accounts SET subtype = 'payable' "
          "WHERE name = 'Accounts Payable' OR name LIKE 'AP - %'");
      await db.execute(
          "UPDATE accounts SET subtype = 'fixed' "
          "WHERE type = 'asset' AND ("
          "LOWER(name) LIKE '%furniture%' OR "
          "LOWER(name) LIKE '%fixture%' OR "
          "LOWER(name) LIKE '%chair%' OR "
          "LOWER(name) LIKE '%equipment%' OR "
          "LOWER(name) LIKE '%vehicle%' OR "
          "LOWER(name) LIKE '%machine%' OR "
          "LOWER(name) LIKE '%computer%' OR "
          "LOWER(name) LIKE '%instrument%')");
      await db.execute(
          "UPDATE accounts SET subtype = 'bank' "
          "WHERE type = 'asset' "
          "AND (subtype IS NULL OR subtype = 'normal') "
          "AND name != 'Cash in Hand' "
          "AND name != 'Accounts Receivable'");
    }
  }

  // ---------- Settings ----------
  Future<String?> getSetting(String key) async {
    final db = await database;
    final r = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Accounts ----------
  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    final db = await database;
    return await db.query('accounts', orderBy: 'type, name');
  }

  Future<List<Map<String, dynamic>>> getAccountsByType(String type) async {
    final db = await database;
    return await db.query('accounts',
        where: 'type = ? AND active = 1', whereArgs: [type], orderBy: 'name');
  }

  Future<Map<String, dynamic>?> getAccountByName(String name) async {
    final db = await database;
    final r = await db.query('accounts', where: 'name = ?', whereArgs: [name]);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, dynamic>?> getAccountById(String id) async {
    final db = await database;
    final r = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, dynamic>?> getCashAccount() =>
      getAccountByName('Cash in Hand');

  Future<void> insertAccount(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('accounts', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAccount(String id, Map<String, dynamic> row) async {
    final db = await database;
    await db.update('accounts', row, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Items ----------
  Future<List<Map<String, dynamic>>> getActiveItems() async {
    final db = await database;
    return await db
        .query('items', where: 'active = 1', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> insertItem(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('items', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateItem(String id, Map<String, dynamic> row) async {
    final db = await database;
    await db.update('items', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.update('items', {'active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Customers ----------
  Future<List<Map<String, dynamic>>> getActiveCustomers() async {
    final db = await database;
    return await db.query('customers',
        where: 'active = 1', orderBy: 'name COLLATE NOCASE');
  }

  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    final db = await database;
    final r = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<void> insertCustomer(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('customers', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> row) async {
    final db = await database;
    await db.update('customers', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCustomer(String id) async {
    final db = await database;
    await db.update('customers', {'active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustCustomerBalance(String id, double delta) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE customers SET current_balance = current_balance + ? WHERE id = ?',
        [delta, id]);
  }

  // ---------- Employees ----------
  Future<List<Map<String, dynamic>>> getActiveEmployees() async {
    final db = await database;
    return await db.query('employees',
        where: 'active = 1', orderBy: 'name COLLATE NOCASE');
  }

  Future<void> insertEmployee(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('employees', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> row) async {
    final db = await database;
    await db.update('employees', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteEmployee(String id) async {
    final db = await database;
    await db.update('employees', {'active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Journal ----------
  Future<void> insertJournalEntry({
    required String id,
    required String date,
    required String narration,
    required String source,
    String? sourceId,
    required List<Map<String, dynamic>> lines,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('journal_entries', {
        'id': id,
        'date': date,
        'narration': narration,
        'source': source,
        'source_id': sourceId,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (var l in lines) {
        await txn.insert('journal_lines', {
          'id': l['id'],
          'entry_id': id,
          'account_id': l['account_id'],
          'debit': l['debit'] ?? 0,
          'credit': l['credit'] ?? 0,
        });
      }
    });
  }

  Future<void> insertSaleItems(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var r in rows) {
        await txn.insert('sale_items', r);
      }
    });
  }

  Future<void> insertPurchaseItems(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var r in rows) {
        await txn.insert('purchase_items', r);
      }
    });
  }

  Future<void> insertInvoice(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('invoices', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- Invoice Number ----------
  Future<String> nextInvoiceNo() async {
    final db = await database;
    final year = DateTime.now().year;
    final r = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM invoices WHERE invoice_no LIKE ?",
        ['INV-$year-%']);
    final n = ((r.first['c'] as int) + 1);
    return 'INV-$year-${n.toString().padLeft(4, '0')}';
  }

  Future<List<Map<String, dynamic>>> getInvoicesForCustomer(
      String customerId) async {
    final db = await database;
    return await db.query('invoices',
        where: 'customer_id = ?',
        whereArgs: [customerId],
        orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getSaleItemsForInvoice(
      String invoiceId) async {
    final db = await database;
    return await db
        .query('sale_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
  }

  Future<Map<String, dynamic>?> getInvoiceById(String id) async {
    final db = await database;
    final r = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  // ---------- Subtype helpers ----------
  Future<List<Map<String, dynamic>>> getPaymentAccounts() async {
    final db = await database;
    return await db.query('accounts',
        where: "type = 'asset' AND subtype IN ('cash', 'bank', 'wallet') AND active = 1",
        orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> getFixedAssets() async {
    final db = await database;
    return await db.query('accounts',
        where: "type = 'asset' AND subtype = 'fixed' AND active = 1",
        orderBy: 'name');
  }

  // ---------- Suppliers ----------
  Future<List<Map<String, dynamic>>> getActiveSuppliers() async {
    final db = await database;
    return await db.query('suppliers', where: 'active = 1',
        orderBy: 'name COLLATE NOCASE');
  }

  Future<void> insertSupplier(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('suppliers', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSupplier(String id, Map<String, dynamic> row) async {
    final db = await database;
    await db.update('suppliers', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSupplier(String id) async {
    final db = await database;
    await db.update('suppliers', {'active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustSupplierBalance(String id, double delta) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE suppliers SET current_balance = current_balance + ? WHERE id = ?',
        [delta, id]);
  }


  // ---------- Safe Delete ----------
  Future<void> deleteJournalEntryWithReverse(String entryId) async {
    final db = await database;
    await db.transaction((txn) async {
      final entries = await txn.query('journal_entries', where: 'id = ?', whereArgs: [entryId]);
      if (entries.isEmpty) return;
      final entry = entries.first;
      final source = entry['source'];
      final sourceId = entry['source_id'];

      // 1. Reverse Customer Balances for Sales
      if (source == 'sale' && sourceId != null) {
        final invs = await txn.query('invoices', where: 'id = ?', whereArgs: [sourceId]);
        if (invs.isNotEmpty) {
          final inv = invs.first;
          final custId = inv['customer_id'];
          final due = (inv['balance_due'] as num?)?.toDouble() ?? 0;
          if (custId != null && due != 0) {
            await txn.rawUpdate('UPDATE customers SET current_balance = current_balance - ? WHERE id = ?', [due, custId]);
          }
          await txn.delete('invoices', where: 'id = ?', whereArgs: [sourceId]);
          await txn.delete('sale_items', where: 'invoice_id = ?', whereArgs: [sourceId]);
        }
      }

      // 2. Reverse Supplier Balances for Purchases
      if (source == 'purchase') {
        final pis = await txn.query('purchase_items', where: 'entry_id = ?', whereArgs: [entryId]);
        if (pis.isNotEmpty) {
          final pi = pis.first;
          final vendorId = pi['vendor'];
          final total = (pi['total'] as num?)?.toDouble() ?? 0;
          
          // Calculate how much was paid via cash/bank
          double paid = 0;
          final lines = await txn.rawQuery('''
            SELECT SUM(jl.debit) AS d FROM journal_lines jl
            JOIN accounts a ON a.id = jl.account_id
            WHERE jl.entry_id = ? AND a.subtype IN ('cash', 'bank', 'wallet')
          ''', [entryId]);
          if (lines.isNotEmpty && lines.first['d'] != null) {
            paid = (lines.first['d'] as num).toDouble();
          }
          
          final unpaid = total - paid;
          if (vendorId != null && unpaid > 0) {
            await txn.rawUpdate('UPDATE suppliers SET current_balance = current_balance - ? WHERE id = ?', [unpaid, vendorId]);
          }
          await txn.delete('purchase_items', where: 'entry_id = ?', whereArgs: [entryId]);
        }
      }

      // 3. Delete the journal entry (cascades to lines)
      await txn.delete('journal_entries', where: 'id = ?', whereArgs: [entryId]);
    });
  }
  // ---------- Balances & Totals ----------
  Future<double> getAccountBalance(String accountId) async {
    final db = await database;
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(debit),0) AS td, COALESCE(SUM(credit),0) AS tc FROM journal_lines WHERE account_id = ?',
        [accountId]);
    final debit = (r.first['td'] as num).toDouble();
    final credit = (r.first['tc'] as num).toDouble();
    final acc = await getAccountById(accountId);
    if (acc == null) return 0;
    final t = acc['type'] as String;
    return (t == 'asset' || t == 'expense') ? debit - credit : credit - debit;
  }

  Future<double> getCashBalance() async {
    final a = await getCashAccount();
    return a == null ? 0 : getAccountBalance(a['id'] as String);
  }

  Future<double> getDaySales(DateTime day) async {
    final db = await database;
    final s = DateTime(day.year, day.month, day.day).toIso8601String();
    final e =
        DateTime(day.year, day.month, day.day, 23, 59, 59).toIso8601String();
    final r = await db.rawQuery('''
      SELECT COALESCE(SUM(jl.credit),0) AS t FROM journal_lines jl
      JOIN journal_entries je ON je.id = jl.entry_id
      JOIN accounts a ON a.id = jl.account_id
      WHERE a.type = 'income' AND je.date >= ? AND je.date <= ?''', [s, e]);
    return (r.first['t'] as num).toDouble();
  }

  Future<double> getDayExpenses(DateTime day) async {
    final db = await database;
    final s = DateTime(day.year, day.month, day.day).toIso8601String();
    final e =
        DateTime(day.year, day.month, day.day, 23, 59, 59).toIso8601String();
    final r = await db.rawQuery('''
      SELECT COALESCE(SUM(jl.debit),0) AS t FROM journal_lines jl
      JOIN journal_entries je ON je.id = jl.entry_id
      JOIN accounts a ON a.id = jl.account_id
      WHERE a.type = 'expense' AND je.date >= ? AND je.date <= ?''', [s, e]);
    return (r.first['t'] as num).toDouble();
  }

  Future<double> getTotalReceivable() async {
    final db = await database;
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(current_balance),0) AS b FROM customers WHERE current_balance > 0 AND active = 1');
    return (r.first['b'] as num).toDouble();
  }
}
