import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DashboardChartModule extends StatefulWidget {
  final String title;
  final VoidCallback onTap;
  final List<Map<String, dynamic>>? legendItems;

  const DashboardChartModule({
    super.key,
    required this.title,
    required this.onTap,
    this.legendItems,
  });

  @override
  State<DashboardChartModule> createState() => _DashboardChartModuleState();
}

class _DashboardChartModuleState extends State<DashboardChartModule> {
  // monthIndex → {income, expense}
  Map<int, double> _income = {};
  Map<int, double> _expense = {};
  bool _loading = true;
  List<String> _monthLabels = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final ranchId = userDoc.data()?['currentRanchId'] as String?;
      if (ranchId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Últimos 6 meses
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(ranchId)
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sixMonthsAgo))
          .get();

      final Map<int, double> income = {};
      final Map<int, double> expense = {};
      final List<String> labels = [];

      // Construir los 6 slots de mes (índice 0 = hace 5 meses, 5 = mes actual)
      for (int i = 0; i < 6; i++) {
        final m = DateTime(now.year, now.month - 5 + i, 1);
        final key = m.year * 100 + m.month;
        income[key] = 0;
        expense[key] = 0;
        labels.add(DateFormat('MMM', 'es_MX').format(m));
      }

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['date'];
        if (ts is! Timestamp) continue;
        final date = ts.toDate();
        final key = date.year * 100 + date.month;
        if (!income.containsKey(key)) continue;

        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final type = data['type'] as String? ?? '';
        if (type == 'income') {
          income[key] = (income[key] ?? 0) + amount;
        } else if (type == 'expense') {
          expense[key] = (expense[key] ?? 0) + amount;
        }
      }

      if (mounted) {
        setState(() {
          _income = income;
          _expense = expense;
          _monthLabels = labels;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5e3a1c))),
                if (widget.legendItems != null)
                  Row(
                    children: widget.legendItems!.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Row(
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: item['color'],
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(item['text'],
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
            const SizedBox(height: 15),
            _loading
                ? const SizedBox(
                    height: 120,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFc99450), strokeWidth: 2)))
                : _FinanceLineChart(
                    income: _income,
                    expense: _expense,
                    monthLabels: _monthLabels,
                  ),
          ],
        ),
      ),
    );
  }
}

class _FinanceLineChart extends StatelessWidget {
  final Map<int, double> income;
  final Map<int, double> expense;
  final List<String> monthLabels;

  const _FinanceLineChart({
    required this.income,
    required this.expense,
    required this.monthLabels,
  });

  @override
  Widget build(BuildContext context) {
    final keys = income.keys.toList()..sort();

    // Si no hay ningún dato, mostramos placeholder
    final hasData = keys.any((k) => (income[k] ?? 0) > 0 || (expense[k] ?? 0) > 0);
    if (!hasData) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('Sin movimientos en los últimos 6 meses',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );
    }

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (int i = 0; i < keys.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), income[keys[i]] ?? 0));
      expenseSpots.add(FlSpot(i.toDouble(), expense[keys[i]] ?? 0));
    }

    final maxY = [
      ...incomeSpots.map((s) => s.y),
      ...expenseSpots.map((s) => s.y),
    ].fold(0.0, (a, b) => a > b ? a : b);

    return AspectRatio(
      aspectRatio: 1.70,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY > 0 ? maxY * 1.2 : 100,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final label = s.barIndex == 0 ? 'Ingreso' : 'Egreso';
                final val = NumberFormat.compactCurrency(
                        locale: 'es_MX', symbol: '\$')
                    .format(s.y);
                return LineTooltipItem('$label\n$val',
                    const TextStyle(fontSize: 11, color: Colors.white));
              }).toList(),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= monthLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(monthLabels[idx],
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey));
                },
              ),
            ),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: incomeSpots,
              isCurved: true,
              color: const Color(0xFFa75c2e),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFFa75c2e).withValues(alpha: 0.15)),
            ),
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              color: const Color(0xFF673ab7),
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF673ab7).withValues(alpha: 0.10)),
            ),
          ],
        ),
      ),
    );
  }
}
