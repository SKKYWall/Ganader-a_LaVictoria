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

  int _total = 0, _hembras = 0, _machos = 0, _gestantes = 0;
  Map<String, int> _razas = {};
  Map<String, int> _propositos = {};

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
      // 1. Obtener el rancho actual seleccionado por el usuario
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

      // 2. (Opcional) Obtener el nombre del rancho para el título
      final ranchDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(currentRanchId)
          .get();

      String ranchName = ranchDoc.data()?['name'] ?? 'Mi Rancho';

      // 3. Consultar los animales de ESE rancho específico
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches') // <-- Subcolección de ranchos
          .doc(currentRanchId) // <-- Rancho actual
          .collection('animals') // <-- Subcolección de animales
          .get();

      int h = 0, m = 0, g = 0;
      Map<String, int> rCount = {};
      Map<String, int> pCount = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Conteo Sexo
        if (data['sexo'] == 'Hembra' || data['sex'] == 'Hembra') {
          // Revisa si guardas como 'sexo' o 'sex'
          h++;
        } else if (data['sexo'] == 'Macho' || data['sex'] == 'Macho') {
          m++;
        }

        // Conteo Gestantes (ajusta según cómo lo guardes)
        if (data['gestante'] == true ||
            data['estado'] == 'Gestante' ||
            data['purpose'] == 'Reproductora') {
          // Agrega aquí la validación exacta que uses para saber si está preñada
          // Por ejemplo: if(data['isPregnant'] == true) g++;
          if (data['gestante'] == true) g++;
        }

        // Conteo Razas
        String raza = data['raza'] ?? data['breed'] ?? 'Otro';
        rCount[raza] = (rCount[raza] ?? 0) + 1;

        // Conteo Propósitos
        String prop = data['proposito'] ?? data['purpose'] ?? 'Reproductora';
        pCount[prop] = (pCount[prop] ?? 0) + 1;
      }

      setState(() {
        _nombreRancho = ranchName;
        _total = snapshot.docs.length;
        _hembras = h;
        _machos = m;
        _gestantes = g;
        _razas = rCount;
        _propositos = pCount;
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
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 25),
                        _buildSectionTitle("Distribución por Sexo"),
                        _buildPieChart(_hembras, _machos, "Hembras", "Machos"),
                        const SizedBox(height: 25),
                        _buildSectionTitle("Principales Razas"),
                        _buildBarChart(),
                        const SizedBox(height: 25),
                        _buildSectionTitle("Uso del Inventario (Propósitos)"),
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
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brown),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchStats();
            },
            child:
                const Text('Reintentar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _statCard("Total", _total.toString(), Icons.pets, _brown),
        const SizedBox(width: 15),
        _statCard("Preñadas", _gestantes.toString(), Icons.favorite,
            Colors.pink.shade400),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: _brown)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(int val1, int val2, String label1, String label2) {
    if (val1 == 0 && val2 == 0) {
      return Container(
        height: 200,
        margin: const EdgeInsets.only(top: 15),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(
            child: Text("Sin datos en este rancho",
                style: TextStyle(color: Colors.grey))),
      );
    }
    return Container(
      height: 200,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
                value: val1.toDouble(),
                color: Colors.pink.shade200,
                title: '$val1',
                radius: 50,
                titleStyle: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            PieChartSectionData(
                value: val2.toDouble(),
                color: Colors.blue.shade300,
                title: '$val2',
                radius: 50,
                titleStyle: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ],
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_razas.isEmpty) return const SizedBox();
    return Container(
      height: 200,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: _razas.entries.map((e) {
            int index = _razas.keys.toList().indexOf(e.key);
            return BarChartGroupData(x: index, barRods: [
              BarChartRodData(
                  toY: e.value.toDouble(),
                  color: _gold,
                  width: 18,
                  borderRadius: BorderRadius.circular(4))
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPurposeList() {
    if (_propositos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 15.0),
        child: Text("Sin datos", style: TextStyle(color: Colors.grey)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: _propositos.entries
            .map((e) => ListTile(
                  leading: const Icon(Icons.circle, color: _gold, size: 12),
                  title: Text(e.key),
                  trailing: Text(e.value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: _brown));
  }
}
