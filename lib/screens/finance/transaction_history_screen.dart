// lib/screens/finance/transaction_history_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    hide Transaction; // Oculta la clase Transaction de cloud_firestore
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/models/transaction.dart';
import 'package:manual_ganadero_flutter/screens/finance/add_edit_transaction_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? _filterType;
  String? _filterCategory;
  int? _filterMonth;
  int? _filterYear;

  final Map<String, List<String>> _incomeCategories = {
    'Venta de Animales': ['Bovinos', 'Ovinos / Caprinos', 'Cerdos'],
    'Otros Ingresos': [
      'Subsidios',
      'Intereses',
      'Venta de Productos Lácteos',
      'Venta de Carne'
    ],
  };

  final Map<String, List<String>> _expenseCategories = {
    'Alimentación': ['Alimento balanceado', 'Forraje / silo', 'Suplementos'],
    'Salud': ['Vacunas', 'Medicamentos', 'Material Médico'],
    'Personal': ['Sueldos', 'Bonos'],
    'Mantenimiento e Infraestructura': [
      'Reparaciones',
      'Nuevas construcciones',
      'Herramientas'
    ],
    'Servicios': ['Luz', 'Agua', 'Internet', 'Combustible'],
    'Otros Egresos': ['Seguros', 'Impuestos', 'Transporte', 'Gastos Bancarios'],
  };

  List<String> _getAllCategories() {
    final Set<String> categories = {};
    for (var cat in _incomeCategories.keys) {
      categories.add(cat);
    }
    for (var cat in _expenseCategories.keys) {
      categories.add(cat);
    }
    return categories.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterMonth = now.month;
    _filterYear = now.year;
  }

  // SOLUCIÓN 3: Formato compacto de moneda (Ej: $1.5M, $15K)
  String _formatCurrency(double amount) {
    // Usamos en_US para asegurar el uso de 'K' y 'M'
    final formatter =
        NumberFormat.compactCurrency(locale: 'en_US', symbol: '\$');
    return formatter.format(amount);
  }

  // Modificado: Solo consultamos a Firebase por fecha para evitar problemas de índices.
  Stream<QuerySnapshot> _getTransactionsStream(String ranchId) {
    if (_currentUser == null) {
      return const Stream.empty();
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('ranches')
        .doc(ranchId)
        .collection('transactions')
        .orderBy('date', descending: true);

    if (_filterYear != null && _filterMonth != null) {
      final startOfMonth = DateTime(_filterYear!, _filterMonth!, 1);
      final endOfMonth =
          DateTime(_filterYear!, _filterMonth! + 1, 0, 23, 59, 59);

      query = query
          .where('date', isGreaterThanOrEqualTo: startOfMonth)
          .where('date', isLessThanOrEqualTo: endOfMonth);
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text(
              'Error: Usuario no autenticado. Por favor, reinicia la aplicación.'),
        ),
      );
    }

    final List<String> monthNames = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    final List<int> years =
        List<int>.generate(10, (i) => DateTime.now().year - 5 + i);

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e1),
        title: const Text(
          'Historial de Transacciones',
          style: TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true, // <-- SOLUCIÓN 2: Evita el overflow
                        value: _filterType,
                        decoration: _inputDecoration('Tipo'),
                        items: const [
                          DropdownMenuItem(
                              value: null,
                              child: Text('Todos',
                                  overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'income',
                              child: Text('Ingresos',
                                  overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'expense',
                              child: Text('Egresos',
                                  overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true, // <-- SOLUCIÓN 2: Evita el overflow
                        value: _filterCategory,
                        decoration: _inputDecoration('Categoría'),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('Todas',
                                  overflow: TextOverflow.ellipsis)),
                          ..._getAllCategories()
                              .map((category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category,
                                        overflow: TextOverflow.ellipsis),
                                  )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterCategory = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _filterMonth,
                        decoration: _inputDecoration('Mes'),
                        items: List.generate(12, (index) => index + 1)
                            .map((month) {
                          return DropdownMenuItem(
                            value: month,
                            child: Text(monthNames[month - 1],
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _filterMonth = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _filterYear,
                        decoration: _inputDecoration('Año'),
                        items: years.map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year.toString(),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _filterYear = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6b4226))));
                  }

                  String? currentRanchId = (userSnapshot.data?.data()
                      as Map<String, dynamic>?)?['currentRanchId'];

                  if (currentRanchId == null) {
                    return const Center(
                      child: Text(
                          'Por favor, selecciona un rancho desde el Inicio.',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _getTransactionsStream(currentRanchId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6b4226)),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                            child: Text(
                                'No hay transacciones para el período seleccionado.'));
                      }

                      // Convertir a lista de transacciones
                      var transactions = snapshot.data!.docs.map((doc) {
                        return Transaction.fromFirestore(
                            doc.data() as Map<String, dynamic>, doc.id);
                      }).toList();

                      // SOLUCIÓN 1: Filtrar localmente en lugar de Firebase
                      // Esto arregla que los filtros "no sirvan" y evita errores de índices
                      if (_filterType != null) {
                        transactions = transactions
                            .where((t) => t.type == _filterType)
                            .toList();
                      }
                      if (_filterCategory != null) {
                        transactions = transactions
                            .where((t) => t.category == _filterCategory)
                            .toList();
                      }

                      if (transactions.isEmpty) {
                        return const Center(
                            child: Text(
                                'No se encontraron resultados con estos filtros.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            color: Colors.white,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: transaction.type == 'income'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                child: Icon(
                                  transaction.type == 'income'
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: transaction.type == 'income'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              title: Text(
                                transaction.category +
                                    (transaction.subCategory != null
                                        ? ' - ${transaction.subCategory}'
                                        : ''),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5e3a1c)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${DateFormat('dd MMM').format(transaction.date)} - ${transaction.notes ?? 'N/A'}',
                                style: TextStyle(color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                _formatCurrency(transaction.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: transaction.type == 'income'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AddEditTransactionScreen(
                                            transaction: transaction),
                                  ),
                                );
                                if (result == true) {
                                  setState(() {});
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                }),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Color(0xFFc99450), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Color(0xFF6b4226), width: 2.0),
      ),
    );
  }
}
