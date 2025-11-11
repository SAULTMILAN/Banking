import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// --- Models ---
class Account {
  final String type;
  final String accountNumber;
  final double balance;

  Account({required this.type, required this.accountNumber, required this.balance});

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        type: j['type'] as String,
        accountNumber: j['account_number'] as String,
        balance: (j['balance'] as num).toDouble(),
      );
}

class Txn {
  final DateTime date;
  final String description;
  final double amount;

  Txn({required this.date, required this.description, required this.amount});

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        date: DateTime.parse(j['date'] as String),
        description: j['description'] as String,
        amount: (j['amount'] as num).toDouble(),
      );
}

/// --- Data Service for local JSON assets ---
class BankRepository {
  Future<List<Account>> loadAccounts() async {
    final raw = await rootBundle.loadString('assets/accounts.json');
    final map = json.decode(raw) as Map<String, dynamic>;
    final list = (map['accounts'] as List).cast<Map<String, dynamic>>();
    return list.map(Account.fromJson).toList();
  }

  /// Returns map: accountType -> transactions
  Future<Map<String, List<Txn>>> loadTransactions() async {
    final raw = await rootBundle.loadString('assets/transactions.json');
    final map = json.decode(raw) as Map<String, dynamic>;
    final txnsMap = (map['transactions'] as Map<String, dynamic>);
    return txnsMap.map((key, value) {
      final txns = (value as List).cast<Map<String, dynamic>>().map(Txn.fromJson).toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // newest first
      return MapEntry(key, txns);
    });
  }
}

/// --- App ---
void main() {
  runApp(const BankingApp());
}

class BankingApp extends StatelessWidget {
  const BankingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Banking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      // Allow back navigation ONLY in this order: Transactions -> Accounts -> Welcome.
      initialRoute: WelcomeScreen.routeName,
      routes: {
        WelcomeScreen.routeName: (_) => const WelcomeScreen(),
        AccountsScreen.routeName: (_) => const AccountsScreen(),
        TransactionsScreen.routeName: (_) => const TransactionsScreen(),
      },
    );
  }
}

/// --- Screens ---

class WelcomeScreen extends StatelessWidget {
  static const routeName = '/';
  const WelcomeScreen({super.key});

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance, size: 96),
              const SizedBox(height: 16),
              Text('Welcome to Simple Bank',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text("Today's date: ${_today()}"),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(AccountsScreen.routeName);
                },
                child: const Text('View Accounts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountsScreen extends StatefulWidget {
  static const routeName = '/accounts';
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final repo = BankRepository();
  late Future<List<Account>> _future;
  Account? _selected;

  @override
  void initState() {
    super.initState();
    _future = repo.loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    // Disable system back from Accounts -> any other page except Welcome (we still allow pop).
    return WillPopScope(
      onWillPop: () async {
        // Allow back to Welcome.
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accounts'),
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: FutureBuilder<List<Account>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final accounts = snap.data!;
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final a = accounts[i];
                      final selected = _selected?.accountNumber == a.accountNumber;
                      return InkWell(
                        onTap: () => setState(() => _selected = a),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.credit_card, size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.type, style: Theme.of(context).textTheme.titleLarge),
                                    const SizedBox(height: 4),
                                    Text(a.accountNumber, style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                              Text('\$${a.balance.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    // Only ONE "View Transactions" button,
                    // enabled only when an account is selected.
                    child: FilledButton.icon(
                      onPressed: _selected == null
                          ? null
                          : () {
                              Navigator.of(context).pushNamed(
                                TransactionsScreen.routeName,
                                arguments: _selected,
                              );
                            },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View Transactions'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TransactionsScreen extends StatelessWidget {
  static const routeName = '/transactions';
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Account account = ModalRoute.of(context)!.settings.arguments as Account;
    final repo = BankRepository();

    return WillPopScope(
      // Allow navigating back ONLY to the Accounts list.
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${account.type} Transactions'),
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: FutureBuilder<Map<String, List<Txn>>>(
          future: repo.loadTransactions(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final map = snap.data!;
            final txns = map[account.type] ?? const <Txn>[];
            if (txns.isEmpty) {
              return const Center(child: Text('No transactions for this account.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: txns.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final t = txns[i];
                final isCredit = t.amount >= 0;
                return ListTile(
                  leading: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward),
                  title: Text(t.description),
                  subtitle: Text('${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}'),
                  trailing: Text(
                    (isCredit ? '+' : '') + '\$${t.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: isCredit
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
