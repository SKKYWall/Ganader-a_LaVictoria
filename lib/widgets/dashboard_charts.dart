import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardChartModule extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5e3a1c))),
                if (legendItems != null)
                  Row(
                    children: legendItems!.map((item) {
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
            const _LineChartExample(),
          ],
        ),
      ),
    );
  }
}

class _LineChartExample extends StatelessWidget {
  const _LineChartExample();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.70,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: const FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 20),
                FlSpot(1, 45),
                FlSpot(3, 80),
                FlSpot(5, 43)
              ],
              isCurved: true,
              color: const Color(0xFFa75c2e),
              barWidth: 3,
              belowBarData: BarAreaData(
                  show: true, color: const Color(0xFFa75c2e).withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }
}
