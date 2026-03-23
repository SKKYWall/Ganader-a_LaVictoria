import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:intl/intl.dart';

class LecheScreen extends StatefulWidget {
  const LecheScreen({super.key});

  @override
  State<LecheScreen> createState() => _LecheScreenState();
}

class _LecheScreenState extends State<LecheScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Stream para obtener las vacas lecheras
  Stream<QuerySnapshot> _getLecheAnimals() {
    if (_currentUser == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('animals')
        .where('purpose', isEqualTo: 'Leche')
        .snapshots();
  }

  // Verificar si una fecha es de hoy
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Lógica para saber si una vaca está seca (leyendo su historial)
  bool _isCowDry(Animal animal) {
    final statusStats = animal.stats
        .where((s) => s.label == 'Secado' || s.label == 'Lactancia')
        .toList();
    if (statusStats.isEmpty) return false; // Por defecto están lactando

    // Ordenar de la más reciente a la más antigua
    statusStats.sort((a, b) => b.date.compareTo(a.date));
    return statusStats.first.label == 'Secado';
  }

  // Lógica para Cambiar de Estado (Secar o Iniciar Lactancia)
  Future<void> _showToggleLactationDialog(
      Animal animal, bool isCurrentlyDry) async {
    final String newLabel = isCurrentlyDry ? 'Lactancia' : 'Secado';
    final String actionText =
        isCurrentlyDry ? 'Iniciar Lactancia' : 'Secar Vaca';
    final Color btnColor = isCurrentlyDry ? Colors.blue : Colors.orange;
    final String contentText = isCurrentlyDry
        ? '¿La vaca ya dio a luz y comenzará a producir leche nuevamente?'
        : '¿Mandar esta vaca al periodo seco? Dejará de aparecer en la lista de ordeña diaria.';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFfbf6ec),
          title: Text(actionText,
              style: TextStyle(color: btnColor, fontWeight: FontWeight.bold)),
          content: Text(contentText),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: btnColor),
              onPressed: () async {
                Navigator.pop(context);
                final newStat = AnimalStat(
                  date: DateTime.now(),
                  value: isCurrentlyDry ? 1.0 : 0.0, // 1 es lactando, 0 es seca
                  label: newLabel,
                );

                List<AnimalStat> updatedStats = List.from(animal.stats)
                  ..add(newStat);

                try {
                  await _firestore
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .collection('animals')
                      .doc(animal.id)
                      .update({
                    'stats': updatedStats.map((s) => s.toFirestore()).toList(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Estado actualizado a: $newLabel'),
                          backgroundColor: btnColor),
                    );
                  }
                } catch (e) {
                  print("Error cambiando estado: $e");
                }
              },
              child: const Text('Confirmar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Dialogo rápido para registrar ordeña
  Future<void> _showAddMilkDialog(Animal animal) async {
    final TextEditingController litersController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFfbf6ec),
          title: Text('Ordeña: ${animal.name}',
              style: const TextStyle(
                  color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: litersController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Litros obtenidos',
                prefixIcon: const Icon(FontAwesomeIcons.faucetDrip,
                    color: Colors.blue, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Ingresa los litros';
                if (double.tryParse(val) == null)
                  return 'Ingresa un número válido';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  final newStat = AnimalStat(
                    date: DateTime.now(),
                    value: double.parse(litersController.text),
                    label: 'Ordeña',
                  );
                  List<AnimalStat> updatedStats = List.from(animal.stats)
                    ..add(newStat);

                  try {
                    await _firestore
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .collection('animals')
                        .doc(animal.id)
                        .update({
                      'stats':
                          updatedStats.map((s) => s.toFirestore()).toList(),
                    });
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('¡Ordeña registrada!'),
                          backgroundColor: Colors.green));
                  } catch (e) {}
                }
              },
              child:
                  const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          backgroundColor: const Color(0xFFfbf6ec),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Producción Lechera',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5e3a1c))),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(icon: Icon(FontAwesomeIcons.faucetDrip), text: "En Ordeña"),
              Tab(icon: Icon(Icons.grass), text: "Vacas Secas"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _getLecheAnimals(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6b4226)));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return const Center(
                  child: Text('No tienes vacas lecheras.',
                      style: TextStyle(color: Colors.grey)));

            final animals = snapshot.data!.docs
                .map((d) => Animal.fromFirestore(
                    d.data() as Map<String, dynamic>, d.id))
                .toList();

            // Clasificamos las vacas
            final lactatingCows = animals.where((a) => !_isCowDry(a)).toList();
            final dryCows = animals.where((a) => _isCowDry(a)).toList();

            // Estadísticas Generales (Solo cuentan las que están en ordeña para el promedio)
            double totalLitersToday = 0;
            int cowsMilkedToday = 0;

            for (var animal in lactatingCows) {
              bool milkedToday = false;
              for (var stat in animal.stats) {
                if (stat.label == 'Ordeña' && _isToday(stat.date)) {
                  totalLitersToday += stat.value;
                  milkedToday = true;
                }
              }
              if (milkedToday) cowsMilkedToday++;
            }

            double averagePerCow = cowsMilkedToday > 0
                ? (totalLitersToday / cowsMilkedToday)
                : 0.0;

            return Column(
              children: [
                // PANEL DE RESUMEN SUPERIOR
                Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)]),
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('Litros Hoy',
                          '${totalLitersToday.toStringAsFixed(1)} L'),
                      Container(width: 1, height: 40, color: Colors.white54),
                      _buildSummaryStat(
                          'En Ordeña', lactatingCows.length.toString()),
                      Container(width: 1, height: 40, color: Colors.white54),
                      _buildSummaryStat('Promedio',
                          '${averagePerCow.toStringAsFixed(1)} L/vaca'),
                    ],
                  ),
                ),

                // PESTAÑAS (TABS)
                Expanded(
                  child: TabBarView(
                    children: [
                      // PESTAÑA 1: EN ORDEÑA
                      _buildLactatingList(lactatingCows),

                      // PESTAÑA 2: VACAS SECAS
                      _buildDryCowsList(dryCows),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // WIDGET PARA LISTA DE VACAS EN ORDEÑA
  Widget _buildLactatingList(List<Animal> lactatingCows) {
    if (lactatingCows.isEmpty)
      return const Center(
          child: Text('No hay vacas en ordeña.',
              style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: lactatingCows.length,
      itemBuilder: (context, index) {
        final animal = lactatingCows[index];
        final milkStats =
            animal.stats.where((s) => s.label == 'Ordeña').toList();
        milkStats.sort((a, b) => b.date.compareTo(a.date));

        String lastMilkText = 'Sin registro';
        if (milkStats.isNotEmpty) {
          final lastStat = milkStats.first;
          String dateStr = _isToday(lastStat.date)
              ? 'Hoy'
              : DateFormat('dd/MM/yy').format(lastStat.date);
          lastMilkText = '$dateStr: ${lastStat.value} L';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 15.0),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12.0),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              radius: 25,
              child: const Icon(FontAwesomeIcons.faucetDrip,
                  color: Colors.blue, size: 20),
            ),
            title: Text(animal.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF5e3a1c))),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Arete: ${animal.earTagNumber}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('Última: $lastMilkText',
                      style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
              ],
            ),
            // BOTONES DE ACCIÓN: SECAR (Naranja) Y ORDEÑAR (Azul)
            trailing: Wrap(
              spacing: 0,
              children: [
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline,
                      color: Colors.orange, size: 30),
                  tooltip: 'Mandar a periodo seco',
                  onPressed: () => _showToggleLactationDialog(animal, false),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: Colors.blue, size: 35),
                  tooltip: 'Registrar ordeña',
                  onPressed: () => _showAddMilkDialog(animal),
                ),
              ],
            ),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AnimalDetailScreen(animalId: animal.id))),
          ),
        );
      },
    );
  }

  // WIDGET PARA LISTA DE VACAS SECAS
  Widget _buildDryCowsList(List<Animal> dryCows) {
    if (dryCows.isEmpty)
      return const Center(
          child: Text('No tienes vacas en periodo seco.',
              style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: dryCows.length,
      itemBuilder: (context, index) {
        final animal = dryCows[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 15.0),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(12.0),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              radius: 25,
              child: const Icon(Icons.grass, color: Colors.orange, size: 20),
            ),
            title: Text(animal.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF5e3a1c))),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Arete: ${animal.earTagNumber}',
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('En descanso (Periodo Seco)',
                      style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
              ],
            ),
            // BOTÓN DE ACCIÓN: INICIAR LACTANCIA
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill,
                  color: Colors.blue, size: 35),
              tooltip: 'Iniciar lactancia (Post-parto)',
              onPressed: () => _showToggleLactationDialog(animal, true),
            ),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AnimalDetailScreen(animalId: animal.id))),
          ),
        );
      },
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
