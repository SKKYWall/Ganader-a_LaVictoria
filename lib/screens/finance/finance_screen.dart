// lib/screens/finance/finance_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/models/transaction.dart';
import 'package:manual_ganadero_flutter/screens/finance/add_edit_transaction_screen.dart';
import 'package:manual_ganadero_flutter/screens/finance/transaction_history_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Formateador de moneda
  final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // Obtener transacciones en tiempo real
  Stream<QuerySnapshot> _getTransactionsStream() {
    if (_currentUser == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  // NUEVO: Obtener el total de animales para calcular el Costo por Cabeza
  Future<int> _getTotalAnimals() async {
    if (_currentUser == null) return 0;
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('animals')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentMonthName =
        DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    currentMonthName =
        currentMonthName[0].toUpperCase() + currentMonthName.substring(1);

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Inteligencia Financiera',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c))),
        centerTitle: true,
      ),
      body: FutureBuilder<int>(
          future: _getTotalAnimals(),
          builder: (context, animalSnapshot) {
            int totalAnimals = animalSnapshot.data ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: _getTransactionsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFc99450)));
                }

                List<Transaction> allTransactions = [];
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  allTransactions = snapshot.data!.docs.map((doc) {
                    return Transaction.fromFirestore(
                        doc.data() as Map<String, dynamic>, doc.id);
                  }).toList();
                }

                DateTime now = DateTime.now();
                List<Transaction> currentMonthTransactions =
                    allTransactions.where((t) {
                  return t.date.year == now.year && t.date.month == now.month;
                }).toList();

                double monthlyIncome = 0;
                double monthlyExpense = 0;

                for (var t in currentMonthTransactions) {
                  if (t.type == 'income') monthlyIncome += t.amount;
                  if (t.type == 'expense') monthlyExpense += t.amount;
                }
                double balance = monthlyIncome - monthlyExpense;

                // CÁLCULO DEL KPI ESTRELLA: Costo por Cabeza
                double costPerHead =
                    totalAnimals > 0 ? (monthlyExpense / totalAnimals) : 0;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Flujo de $currentMonthName',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF5e3a1c))),
                                IconButton(
                                  icon: const Icon(Icons.history,
                                      color: Color(0xFFc99450)),
                                  tooltip: 'Ver Historial Completo',
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const TransactionHistoryScreen())),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),

                            // --- TARJETA PRINCIPAL DE BALANCE ---
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF5e3a1c),
                                  Color(0xFF8c5c32)
                                ]),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5))
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Text('UTILIDAD NETA MENSUAL',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70,
                                          letterSpacing: 1.5)),
                                  const SizedBox(height: 10),
                                  Text(
                                    currencyFormat.format(balance),
                                    style: TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.bold,
                                        color: balance >= 0
                                            ? Colors.white
                                            : Colors.redAccent.shade100),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(height: 1, color: Colors.white24),
                                  const SizedBox(height: 15),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildMiniStat('Ingresos', monthlyIncome,
                                          Colors.greenAccent),
                                      Container(
                                          width: 1,
                                          height: 40,
                                          color: Colors.white24),
                                      _buildMiniStat('Egresos', monthlyExpense,
                                          Colors.redAccent),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),

                            // --- KPI INNOVADOR: COSTO POR CABEZA ---
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border:
                                      Border.all(color: Colors.grey.shade300)),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                      backgroundColor: Colors.blue.shade50,
                                      child: const Icon(FontAwesomeIcons.cow,
                                          color: Colors.blue, size: 20)),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Costo de Mantenimiento',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87)),
                                        Text(
                                            'Gasto promedio por cada animal este mes ($totalAnimals cabezas)',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Text(currencyFormat.format(costPerHead),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 25),

                            const Text('Transacciones Recientes',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5e3a1c))),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),

                    // --- LISTA DE TRANSACCIONES ---
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (currentMonthTransactions.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                  child: Text(
                                      'Aún no hay movimientos este mes.',
                                      style: TextStyle(color: Colors.grey))),
                            );
                          }
                          if (index >= currentMonthTransactions.length ||
                              index >= 10) return null;

                          Transaction t = currentMonthTransactions[index];
                          bool isIncome = t.type == 'income';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 5),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            color: Colors.white,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isIncome
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color:
                                        isIncome ? Colors.green : Colors.red),
                              ),
                              title: Text(t.category,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              subtitle: Text(
                                  DateFormat('dd MMM yyyy').format(t.date),
                                  style: const TextStyle(fontSize: 12)),
                              trailing: Text(
                                '${isIncome ? '+' : '-'}${currencyFormat.format(t.amount)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color:
                                        isIncome ? Colors.green : Colors.red),
                              ),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AddEditTransactionScreen(
                                          transaction: t))),
                            ),
                          );
                        },
                        childCount: currentMonthTransactions.isEmpty
                            ? 1
                            : (currentMonthTransactions.length > 10
                                ? 10
                                : currentMonthTransactions.length),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            );
          }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddEditTransactionScreen())),
        label: const Text('Registrar Movimiento',
            style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFc99450),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
                color == Colors.greenAccent
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: color,
                size: 16),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 5),
        Text(currencyFormat.format(amount),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
