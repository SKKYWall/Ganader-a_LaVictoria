import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);
  static const Color _cream = Color(0xFFfbf6ec);

  bool _isLoading = true;
  String _errorMessage = '';
  String _nombreRancho = 'Cargando...';

  // Inventario
  int _total = 0, _hembras = 0, _machos = 0, _gestantes = 0;
  Map<String, int> _razas = {};
  Map<String, int> _propositos = {};

  // Métricas productivas
  double _avgBirthWeight = 0;
  int _countBirthWeight = 0;
  double _avgWeaningWeight = 0;
  int _countWeaningWeight = 0;
  double _avgGDP = 0; // Ganancia diaria de peso (engorda)
  int _countGDP = 0;
  int _vacunados30dias = 0; // vacunados en los últimos 30 días
  int _sinVacunas = 0;

  // Distribución por edad
  int _terneros = 0;   // < 12 meses
  int _novillos = 0;   // 12-24 meses
  int _adultos = 0;    // > 24 meses
  int _sinFecha = 0;   // sin fecha de nacimiento
  double _avgAgeMonths = 0;
  int _countAge = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Usuario no autenticado.';
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final currentRanchId = userDoc.data()?['currentRanchId'];
      if (currentRanchId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Por favor selecciona o registra un rancho primero.';
          _nombreRancho = 'Sin rancho seleccionado';
        });
        return;
      }

      final ranchDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(currentRanchId)
          .get();

      final ranchName = ranchDoc.data()?['name'] ?? 'Mi Rancho';

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(currentRanchId)
          .collection('animals')
          .get();

      int activeCount = 0;
      int h = 0, m = 0, g = 0;
      Map<String, int> rCount = {};
      Map<String, int> pCount = {};
      double totalBW = 0, totalWW = 0, totalGDP = 0;
      int cntBW = 0, cntWW = 0, cntGDP = 0;
      int vac30 = 0, sinVac = 0;
      int terneros = 0, novillos = 0, adultos = 0, sinFecha = 0;
      double totalAgeMonths = 0;
      int cntAge = 0;
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if ((data['status'] as String? ?? 'activo') != 'activo') continue;
        activeCount++;

        // Sexo
        final sex = data['sex'] as String? ?? '';
        if (sex == 'Hembra') {
          h++;
        } else if (sex == 'Macho') {
          m++;
        }

        // Gestación
        if (data['isPregnant'] == true) g++;

        // Razas
        final raza = data['breed'] as String? ?? 'Sin raza';
        rCount[raza] = (rCount[raza] ?? 0) + 1;

        // Propósitos
        final prop = data['purpose'] as String? ?? 'Sin propósito';
        pCount[prop] = (pCount[prop] ?? 0) + 1;

        // Peso al nacer
        final bw = (data['birthWeight'] as num?)?.toDouble();
        if (bw != null && bw > 0) {
          totalBW += bw;
          cntBW++;
        }

        // Peso al destete
        final ww = (data['weaningWeight'] as num?)?.toDouble();
        if (ww != null && ww > 0) {
          totalWW += ww;
          cntWW++;
        }

        // GDP desde stats de peso
        final stats = data['stats'];
        if (stats is List) {
          final pesoStats = stats
              .whereType<Map>()
              .where((s) {
                final label = s['label']?.toString() ?? '';
                return label == 'Peso' || label.startsWith('Peso ');
              })
              .toList();

          if (pesoStats.length >= 2) {
            pesoStats.sort((a, b) {
              final da = _toDateTime(a['date']);
              final db = _toDateTime(b['date']);
              return da.compareTo(db);
            });
            final first = pesoStats.first;
            final last = pesoStats.last;
            final days = _toDateTime(last['date'])
                .difference(_toDateTime(first['date']))
                .inDays;
            if (days > 0) {
              final firstVal = (first['value'] as num?)?.toDouble() ?? 0;
              final lastVal = (last['value'] as num?)?.toDouble() ?? 0;
              if (lastVal > firstVal) {
                totalGDP += (lastVal - firstVal) / days;
                cntGDP++;
              }
            }
          }

          // Vacunaciones recientes
          final vaccinations = data['vaccinations'];
          if (vaccinations is List && vaccinations.isNotEmpty) {
            bool hasRecent = false;
            for (final v in vaccinations) {
              if (v is Map) {
                final vDate = _toDateTime(v['date']);
                if (vDate.isAfter(thirtyDaysAgo)) {
                  hasRecent = true;
                  break;
                }
              }
            }
            if (hasRecent) vac30++;
          } else {
            sinVac++;
          }
        } else {
          sinVac++;
        }

        // Distribución por edad
        final birthDateRaw = data['birthDate'];
        if (birthDateRaw != null) {
          final birthDate = _toDateTime(birthDateRaw);
          if (birthDate.year > 2000) {
            final ageMonths = now.difference(birthDate).inDays / 30.44;
            totalAgeMonths += ageMonths;
            cntAge++;
            if (ageMonths < 12) { terneros++; }
            else if (ageMonths < 24) { novillos++; }
            else { adultos++; }
          } else {
            sinFecha++;
          }
        } else {
          sinFecha++;
        }
      }

      setState(() {
        _nombreRancho = ranchName;
        _total = activeCount;
        _hembras = h;
        _machos = m;
        _gestantes = g;
        _razas = rCount;
        _propositos = pCount;
        _avgBirthWeight = cntBW > 0 ? totalBW / cntBW : 0;
        _countBirthWeight = cntBW;
        _avgWeaningWeight = cntWW > 0 ? totalWW / cntWW : 0;
        _countWeaningWeight = cntWW;
        _avgGDP = cntGDP > 0 ? totalGDP / cntGDP : 0;
        _countGDP = cntGDP;
        _vacunados30dias = vac30;
        _sinVacunas = sinVac;
        _terneros = terneros;
        _novillos = novillos;
        _adultos = adultos;
        _sinFecha = sinFecha;
        _avgAgeMonths = cntAge > 0 ? totalAgeMonths / cntAge : 0;
        _countAge = cntAge;
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      debugPrint("Error cargando stats: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ocurrió un error al cargar los datos.';
      });
    }
  }

  DateTime _toDateTime(dynamic raw) {
    if (raw == null) return DateTime(2000);
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      try { return DateTime.parse(raw); } catch (_) {}
    }
    return DateTime(2000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: Text(_nombreRancho,
            style: const TextStyle(
                color: _brown, fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _brown),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _errorMessage.isNotEmpty
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _fetchStats,
                  color: _gold,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Resumen del Inventario"),
                        const SizedBox(height: 12),
                        _buildInventorySummary(),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Distribución por Sexo"),
                        _buildPieChart(_hembras, _machos, "Hembras", "Machos"),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Métricas Productivas"),
                        const SizedBox(height: 12),
                        _buildProductiveMetrics(),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Sanidad"),
                        const SizedBox(height: 12),
                        _buildHealthMetrics(),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Distribución por Edad"),
                        const SizedBox(height: 12),
                        _buildAgeDistribution(),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Razas Principales"),
                        _buildBarChart(),
                        const SizedBox(height: 24),
                        _buildSectionTitle("Uso del Inventario"),
                        _buildPurposeList(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(_errorMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brown),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchStats();
            },
            child: const Text('Reintentar',
                style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildInventorySummary() {
    return Column(
      children: [
        Row(
          children: [
            _statCard("Total", _total.toString(), FontAwesomeIcons.cow, _brown),
            const SizedBox(width: 12),
            _statCard("Preñadas", _gestantes.toString(), Icons.favorite,
                Colors.pink.shade400),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard("Hembras", _hembras.toString(), Icons.female,
                Colors.pink.shade300),
            const SizedBox(width: 12),
            _statCard("Machos", _machos.toString(), Icons.male, Colors.blue.shade400),
          ],
        ),
      ],
    );
  }

  Widget _buildProductiveMetrics() {
    return Column(
      children: [
        Row(
          children: [
            _metricCard(
              icon: Icons.monitor_weight,
              color: Colors.orange.shade600,
              label: 'Peso Nac. Prom.',
              value: _countBirthWeight > 0
                  ? '${_avgBirthWeight.toStringAsFixed(1)} kg'
                  : 'Sin datos',
              subtitle: '$_countBirthWeight animales registrados',
            ),
            const SizedBox(width: 12),
            _metricCard(
              icon: Icons.scale,
              color: Colors.green.shade600,
              label: 'Peso Destete Prom.',
              value: _countWeaningWeight > 0
                  ? '${_avgWeaningWeight.toStringAsFixed(1)} kg'
                  : 'Sin datos',
              subtitle: '$_countWeaningWeight animales registrados',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _metricCardWide(
          icon: Icons.trending_up,
          color: Colors.teal,
          label: 'Ganancia Diaria de Peso Promedio (GDP)',
          value: _countGDP > 0
              ? '${(_avgGDP * 1000).toStringAsFixed(0)} gr/día'
              : 'Sin suficientes pesajes',
          subtitle: _countGDP > 0
              ? 'Basado en $_countGDP animales con 2+ pesajes'
              : 'Registra al menos 2 pesajes por animal',
        ),
        if (_total > 0) ...[
          const SizedBox(height: 12),
          _metricCardWide(
            icon: Icons.pregnant_woman,
            color: Colors.pink.shade400,
            label: 'Tasa de Preñez del Hato',
            value: _hembras > 0
                ? '${(_gestantes / _hembras * 100).toStringAsFixed(1)}%'
                : 'Sin hembras',
            subtitle: '$_gestantes preñadas de $_hembras hembras totales',
          ),
        ],
      ],
    );
  }

  Widget _buildHealthMetrics() {
    final vacPercent =
        _total > 0 ? (_vacunados30dias / _total * 100).toStringAsFixed(1) : '0';
    return Column(
      children: [
        Row(
          children: [
            _metricCard(
              icon: Icons.vaccines,
              color: Colors.blue.shade600,
              label: 'Vacunados (30 días)',
              value: '$_vacunados30dias',
              subtitle: '$vacPercent% del hato',
            ),
            const SizedBox(width: 12),
            _metricCard(
              icon: Icons.warning_amber,
              color: Colors.orange.shade700,
              label: 'Sin Vacunas',
              value: '$_sinVacunas',
              subtitle: 'Requieren atención',
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _metricCardWide({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(int val1, int val2, String label1, String label2) {
    if (val1 == 0 && val2 == 0) {
      return Container(
        height: 180,
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(
            child: Text("Sin datos en este rancho",
                style: TextStyle(color: Colors.grey))),
      );
    }
    return Container(
      height: 180,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                      value: val1.toDouble(),
                      color: Colors.pink.shade300,
                      title: '$val1\n$label1',
                      radius: 55,
                      titleStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 11)),
                  PieChartSectionData(
                      value: val2.toDouble(),
                      color: Colors.blue.shade400,
                      title: '$val2\n$label2',
                      radius: 55,
                      titleStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 11)),
                ],
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legend(Colors.pink.shade300, '$label1: $val1'),
              const SizedBox(height: 8),
              _legend(Colors.blue.shade400, '$label2: $val2'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String text) {
    return Row(
      children: [
        Container(
            width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  Widget _buildAgeDistribution() {
    final hasData = _countAge > 0;
    final avgYears = _avgAgeMonths / 12;

    return Column(
      children: [
        if (hasData)
          _metricCardWide(
            icon: Icons.cake,
            color: _brown,
            label: 'Edad Promedio del Hato',
            value: avgYears >= 1
                ? '${avgYears.toStringAsFixed(1)} años'
                : '${_avgAgeMonths.toStringAsFixed(0)} meses',
            subtitle: 'Calculado sobre $_countAge animales con fecha de nacimiento',
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
          ),
          child: Column(
            children: [
              _ageRow('Terneros', '< 1 año', _terneros, Colors.amber.shade600),
              const SizedBox(height: 10),
              _ageRow('Novillos/Vaquillas', '1-2 años', _novillos, Colors.orange.shade700),
              const SizedBox(height: 10),
              _ageRow('Adultos', '> 2 años', _adultos, _brown),
              if (_sinFecha > 0) ...[
                const SizedBox(height: 10),
                _ageRow('Sin fecha', 'Sin registro', _sinFecha, Colors.grey),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _ageRow(String label, String subtitle, int count, Color color) {
    final total = _total > 0 ? _total : 1;
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$label  ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('$count (${(count / total * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: count / total,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    if (_razas.isEmpty) return const SizedBox();
    final sorted = _razas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();

    return Container(
      height: 220,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= top.length) return const SizedBox();
                        final label = top[i].key;
                        final shortLabel = label.length > 8
                            ? '${label.substring(0, 7)}…'
                            : label;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(shortLabel,
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.grey)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: top.asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(
                        toY: e.value.value.toDouble(),
                        color: _gold,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                        rodStackItems: [
                          BarChartRodStackItem(0, e.value.value.toDouble(), _gold),
                        ])
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeList() {
    if (_propositos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text("Sin datos", style: TextStyle(color: Colors.grey)),
      );
    }
    final sorted = _propositos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.teal, Colors.orange, Colors.blue, Colors.pink, Colors.purple,
      Colors.green,
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final pct = _total > 0 ? (e.value / _total * 100) : 0.0;
          final color = colors[i % colors.length];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(e.key,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    Text('${e.value} (${pct.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _total > 0 ? e.value / _total : 0,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.bold, color: _brown));
  }
}
