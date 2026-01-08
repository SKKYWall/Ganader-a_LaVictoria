// lib/screens/finance/finance_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/models/transaction.dart';
import 'package:manual_ganadero_flutter/screens/finance/add_edit_transaction_screen.dart';
import 'package:manual_ganadero_flutter/screens/finance/transaction_history_screen.dart';
import 'package:fl_chart/fl_chart.dart'; // Importa fl_chart

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;
  List<Transaction> _recentTransactions = [];

  // Opciones de periodo para el gráfico
  String _selectedPeriod = '6 Meses'; // Valor por defecto
  final List<String> _periodOptions = [
    '1 Mes',
    '3 Meses',
    '6 Meses',
    '9 Meses',
    '1 Año'
  ];

  // Data for chart
  Map<int, double> _monthlyIncome = {};
  Map<int, double> _monthlyExpenses = {};
  List<String> _chartMonths =
      []; // Stores the names of months to display on the chart

  @override
  void initState() {
    super.initState();
    _loadFinancialSummary();
  }

  Future<void> _loadFinancialSummary() async {
    if (_currentUser == null) return;

    setState(() {
      _totalIncome = 0.0;
      _totalExpenses = 0.0;
      _recentTransactions = [];
      _monthlyIncome = {};
      _monthlyExpenses = {};
      _chartMonths = [];
    });

    final now = DateTime.now();

    // 1. Calculate totals for the selected period (Mes Actual / Año Actual)
    DateTime summaryStartDate;
    DateTime summaryEndDate;

    if (_selectedPeriod == '1 Mes') {
      summaryStartDate = DateTime(now.year, now.month, 1);
      summaryEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else {
      summaryStartDate = DateTime(now.year, 1, 1);
      summaryEndDate = DateTime(now.year, 12, 31, 23, 59, 59);
    }

    // 2. Determine date range for chart data based on _selectedPeriod
    DateTime chartStartDate = DateTime.now();
    DateTime chartEndDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    int monthsToShow = 0;
    switch (_selectedPeriod) {
      case '1 Mes':
        monthsToShow = 1;
        break;
      case '3 Meses':
        monthsToShow = 3;
        break;
      case '6 Meses':
        monthsToShow = 6;
        break;
      case '9 Meses':
        monthsToShow = 9;
        break;
      case '1 Año':
        monthsToShow = 12;
        chartStartDate = DateTime(now.year, 1, 1); // Inicio del año actual
        chartEndDate =
            DateTime(now.year, 12, 31, 23, 59, 59); // Fin del año actual
        break;
      default:
        monthsToShow = 6; // Default to 6 months
        break;
    }

    // Calculate chartStartDate for periods less than 1 year
    if (_selectedPeriod != '1 Año') {
      chartStartDate = DateTime(now.year, now.month - (monthsToShow - 1), 1);
      // Asegurarse de que chartStartDate no se vaya demasiado al pasado si monthsToShow es grande
      if (chartStartDate.isBefore(DateTime(
          chartEndDate.year - 1, chartEndDate.month, chartEndDate.day))) {
        chartStartDate = DateTime(
            chartEndDate.year - 1, chartEndDate.month, chartEndDate.day);
      }
    }

    try {
      // Fetch data for the summary (current period)
      final summaryQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: summaryStartDate)
          .where('date', isLessThanOrEqualTo: summaryEndDate)
          .get();

      double currentPeriodIncome = 0.0;
      double currentPeriodExpenses = 0.0;

      for (var doc in summaryQuerySnapshot.docs) {
        final transaction = Transaction.fromFirestore(doc.data(), doc.id);
        if (transaction.type == 'income') {
          currentPeriodIncome += transaction.amount;
        } else if (transaction.type == 'expense') {
          currentPeriodExpenses += transaction.amount;
        }
      }

      // Fetch data for the chart (trend period)
      final chartQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: chartStartDate)
          .where('date', isLessThanOrEqualTo: chartEndDate)
          .orderBy('date', descending: true)
          .get();

      Map<int, double> tempMonthlyIncome = {};
      Map<int, double> tempMonthlyExpenses = {};
      List<Transaction> tempRecentTransactions = [];

      // Initialize monthly data for the chart period to 0.0
      DateTime currentMonthIter =
          DateTime(chartStartDate.year, chartStartDate.month, 1);
      while (currentMonthIter
          .isBefore(chartEndDate.add(const Duration(days: 1)))) {
        final monthKey = currentMonthIter.month + (currentMonthIter.year * 100);
        tempMonthlyIncome[monthKey] = 0.0;
        tempMonthlyExpenses[monthKey] = 0.0;
        currentMonthIter =
            DateTime(currentMonthIter.year, currentMonthIter.month + 1, 1);
      }

      for (var doc in chartQuerySnapshot.docs) {
        final transaction = Transaction.fromFirestore(doc.data(), doc.id);
        final monthKey = transaction.date.month + (transaction.date.year * 100);

        if (transaction.date
                .isAfter(chartStartDate.subtract(const Duration(days: 1))) &&
            transaction.date
                .isBefore(chartEndDate.add(const Duration(days: 1)))) {
          if (transaction.type == 'income') {
            tempMonthlyIncome[monthKey] =
                (tempMonthlyIncome[monthKey] ?? 0.0) + transaction.amount;
          } else if (transaction.type == 'expense') {
            tempMonthlyExpenses[monthKey] =
                (tempMonthlyExpenses[monthKey] ?? 0.0) + transaction.amount;
          }
        }
        tempRecentTransactions.add(transaction);
      }

      // Prepare chart months for display (sort by date)
      List<String> preparedChartMonths = [];
      List<int> sortedMonthKeys = tempMonthlyIncome.keys.toList();
      sortedMonthKeys.sort((a, b) {
        final yearA = a ~/ 100;
        final monthA = a % 100;
        final yearB = b ~/ 100;
        final monthB = b % 100;
        if (yearA != yearB) return yearA.compareTo(yearB);
        return monthA.compareTo(monthB);
      });

      for (var monthKey in sortedMonthKeys) {
        final monthIndex = monthKey % 100;
        final year = monthKey ~/ 100;
        preparedChartMonths
            .add(DateFormat('MMM yy').format(DateTime(year, monthIndex)));
      }

      if (!mounted) return; // Add mounted check
      setState(() {
        _totalIncome = currentPeriodIncome;
        _totalExpenses = currentPeriodExpenses;
        _recentTransactions = tempRecentTransactions.take(5).toList();
        _monthlyIncome = tempMonthlyIncome;
        _monthlyExpenses = tempMonthlyExpenses;
        _chartMonths = preparedChartMonths;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el resumen financiero: $e')),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    if (amount.abs() >= 1000000) {
      double millions = amount / 1000000;
      return '${formatter.currencySymbol}${millions.toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      double thousands = amount / 1000;
      return '${formatter.currencySymbol}${thousands.toStringAsFixed(1)}K';
    }
    return formatter.format(amount);
  }

  Widget _buildFinanceChart() {
    // Calcular el groupWidth basado en la cantidad de meses para que no sea demasiado pequeño
    // o grande, ajustando el tamaño del grupo de barras.
    double groupWidth = 20; // Ancho base de cada grupo de barras
    if (_chartMonths.length > 6) {
      groupWidth = 15; // Reducir si hay muchos meses
    }
    if (_chartMonths.length > 9) {
      groupWidth = 10; // Más pequeño para más meses
    }

    // Asegurarse de que el maxYValue sea adecuado para los datos
    double maxYValue = 0;
    for (var value in _monthlyIncome.values) {
      if (value > maxYValue) maxYValue = value;
    }
    for (var value in _monthlyExpenses.values) {
      if (value > maxYValue) maxYValue = value;
    }

    if (maxYValue <= 0) {
      maxYValue = 100; // Valor por defecto si no hay datos
    } else {
      maxYValue =
          (maxYValue * 1.2).ceilToDouble(); // Añadir un 20% de margen superior
    }

    // Crear los grupos de barras para cada mes
    List<BarChartGroupData> barGroups = [];
    List<int> sortedMonthKeys =
        _monthlyIncome.keys.toList(); // Usa income keys como base
    sortedMonthKeys.addAll(_monthlyExpenses.keys.where((key) =>
        !sortedMonthKeys.contains(key))); // Agrega keys de expenses si no están
    sortedMonthKeys.sort((a, b) {
      final yearA = a ~/ 100;
      final monthA = a % 100;
      final yearB = b ~/ 100;
      final monthB = b % 100;
      if (yearA != yearB) return yearA.compareTo(yearB);
      return monthA.compareTo(monthB);
    });

    for (int i = 0; i < sortedMonthKeys.length; i++) {
      final monthKey = sortedMonthKeys[i];
      final income = _monthlyIncome[monthKey] ?? 0.0;
      final expenses = _monthlyExpenses[monthKey] ?? 0.0;

      barGroups.add(
        BarChartGroupData(
          x: i, // Índice en el eje X
          barRods: [
            BarChartRodData(
              toY: income,
              color: Colors.green, // Color para ingresos
              width: groupWidth / 2.5, // Ancho de la barra de ingresos
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade800],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            BarChartRodData(
              toY: expenses,
              color: Colors.red, // Color para egresos
              width: groupWidth / 2.5, // Ancho de la barra de egresos
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade800],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ],
          showingTooltipIndicators: [], // Sin tooltips fijos
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.70,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Flujo de Efectivo Mensual',
                style: TextStyle(
                  color: Color(0xFF5e3a1c),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                      right: 16.0, left: 6.0, top: 12, bottom: 0),
                  child: BarChart(
                    // Cambiamos a BarChart
                    BarChartData(
                      barGroups: barGroups,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return const FlLine(
                            color: Color(0xffececec),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, TitleMeta meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < _chartMonths.length) {
                                return SideTitleWidget(
                                  space: 8,
                                  meta: meta,
                                  child: Text(_chartMonths[index],
                                      style: const TextStyle(
                                          color: Color(0xff72719b),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10)),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (maxYValue / 4 > 0
                                ? (maxYValue / 4).ceilToDouble()
                                : 25),
                            getTitlesWidget: (value, TitleMeta meta) {
                              return SideTitleWidget(
                                space: 8,
                                meta: meta,
                                child: Text(
                                  _formatCurrency(value),
                                  style: const TextStyle(
                                      color: Color(0xff72719b),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10),
                                  textAlign: TextAlign.left,
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      barTouchData: BarTouchData(
                        // Agregamos la interactividad para tooltips
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) =>
                              const Color(0xFF6b4226), // Usar getTooltipColor
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String monthName = _chartMonths[group.x.toInt()];
                            String value = _formatCurrency(rod.toY);
                            String type = rodIndex == 0 ? 'Ingreso' : 'Egreso';
                            Color textColor = rodIndex == 0
                                ? Colors.greenAccent
                                : Colors.redAccent;

                            return BarTooltipItem(
                              '$monthName\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: '$type: $value',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      minY: 0,
                      maxY: maxYValue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(Colors.green, 'Ingresos'),
                  const SizedBox(width: 20),
                  _buildLegendItem(Colors.red, 'Egresos'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 12),
        ),
      ],
    );
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

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf5f0e1),
        title: const Text(
          'Finanzas',
          style: TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF5e3a1c)),
            underline: const SizedBox(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedPeriod = newValue!;
                _loadFinancialSummary();
              });
            },
            items: _periodOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value,
                    style: const TextStyle(color: Color(0xFF5e3a1c))),
              );
            }).toList(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFinancialSummary,
        color: const Color(0xFF6b4226),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFinanceChart(), // La gráfica de barras
              const SizedBox(height: 20),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                color: const Color(0xFFdcd2c4),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPeriod == '1 Mes'
                                ? 'Ganancia Neta (Mes Actual)'
                                : 'Ganancia Neta (Año Actual)',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF5e3a1c),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _formatCurrency(_totalIncome - _totalExpenses),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: (_totalIncome - _totalExpenses) >= 0
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        (_totalIncome - _totalExpenses) >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: (_totalIncome - _totalExpenses) >= 0
                            ? Colors.green[700]
                            : Colors.red[700],
                        size: 40,
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transacciones Recientes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5e3a1c),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const TransactionHistoryScreen(),
                        ),
                      );
                      if (result == true) {
                        _loadFinancialSummary();
                      }
                    },
                    child: const Text(
                      'Ver todo',
                      style: TextStyle(
                        color: Color(0xFFc99450),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _recentTransactions.isEmpty
                  ? const Center(child: Text('No hay transacciones recientes.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _recentTransactions[index];
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
                              transaction.category,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5e3a1c),
                              ),
                            ),
                            subtitle: Text(
                              '${DateFormat('dd MMM').format(transaction.date)} - ${transaction.notes ?? ''}',
                              style: TextStyle(color: Colors.grey[600]),
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
                                _loadFinancialSummary();
                              }
                            },
                          ),
                        );
                      },
                    ),
              const SizedBox(
                  height: 100), // Espacio adicional para el botón FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditTransactionScreen(),
            ),
          );
          if (result == true) {
            _loadFinancialSummary();
          }
        },
        label: const Text('Añadir Transacción'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF6b4226),
        foregroundColor: Colors.white,
      ),
    );
  }
}
