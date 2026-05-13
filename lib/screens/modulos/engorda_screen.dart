import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/models/animal_stat.dart';

class EngordaScreen extends StatefulWidget {
  const EngordaScreen({super.key});

  @override
  State<EngordaScreen> createState() => _EngordaScreenState();
}

class _EngordaScreenState extends State<EngordaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _currentRanchId;
  bool _isLoadingRanch = true;

  final double estimacionCanal = 0.58;

  @override
  void initState() {
    super.initState();
    _loadCurrentRanchId(); // Cargamos el rancho al iniciar
  }

  Future<void> _loadCurrentRanchId() async {
    if (_currentUser == null) return;
    try {
      final doc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (mounted) {
        setState(() {
          _currentRanchId =
              (doc.data() as Map<String, dynamic>?)?['currentRanchId'];
          _isLoadingRanch = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRanch = false);
    }
  }

  // Traemos a los animales de ambos propósitos
  Stream<QuerySnapshot> _getAnimals() {
    if (_currentUser == null || _currentRanchId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('ranches') // Agregado
        .doc(_currentRanchId) // Agregado
        .collection('animals')
        .where('purpose', whereIn: ['Engorda', 'Carne']).snapshots();
  }

  double _getUltimoPeso(Animal animal) {
    List<AnimalStat> weightStats =
        animal.stats.where((s) => s.label == 'Peso').toList();
    if (weightStats.isNotEmpty) {
      weightStats.sort((a, b) => b.date.compareTo(a.date));
      return weightStats.first.value;
    }
    return animal.birthWeight ?? 0.0;
  }

  double _calcularGDP(Animal animal) {
    List<AnimalStat> weightStats =
        animal.stats.where((s) => s.label == 'Peso').toList();
    if (weightStats.length < 2) return 0.0;

    weightStats.sort((a, b) => a.date.compareTo(b.date));
    AnimalStat first = weightStats.first;
    AnimalStat last = weightStats.last;

    int days = last.date.difference(first.date).inDays;
    if (days == 0) return 0.0;

    return (last.value - first.value) / days;
  }

  // --- NUEVA FUNCIÓN: EDITAR META DE PESO DE UN ANIMAL ---
  Future<void> _showEditTargetWeightDialog(
      String animalId, double currentTarget, String animalName) async {
    final TextEditingController weightController =
        TextEditingController(text: currentTarget.toString());
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFFfbf6ec),
              title: Text('Meta para $animalName',
                  style: const TextStyle(
                      color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Define el peso ideal al que deseas llevar este animal.',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: weightController,
                    maxLength: 10,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Peso Meta (kg)',
                      prefixIcon: const Icon(Icons.monitor_weight,
                          color: Color(0xFFc99450)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFc99450)),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final double? newWeight =
                              double.tryParse(weightController.text.trim());
                          if (newWeight != null && newWeight > 0) {
                            setStateDialog(() => isSaving = true);
                            try {
                              await _firestore
                                  .collection('users')
                                  .doc(_currentUser!.uid)
                                  .collection('ranches')
                                  .doc(_currentRanchId)
                                  .collection('animals')
                                  .doc(animalId)
                                  .set({'targetWeight': newWeight},
                                      SetOptions(merge: true));
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              setStateDialog(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar',
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FUNCIÓN: PASAR A CARNE ---
  void _moverACarne(Animal animal) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Mover a Lote de Carne',
                  style: TextStyle(
                      color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
              content: Text(
                  '¿Deseas dar por terminada la engorda de ${animal.name} y moverlo al lote de animales listos para procesar (Carne)?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFc99450)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _firestore
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .collection('ranches') // Agregado
                        .doc(_currentRanchId) // Agregado
                        .collection('animals')
                        .doc(animal.id)
                        .update({'purpose': 'Carne'});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Animal movido a Producción de Carne'),
                          backgroundColor: Colors.green));
                    }
                  },
                  child: const Text('Sí, Mover',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
  }

  // --- FUNCIÓN: ELIMINAR Y MANDAR AL RASTRO ---
  void _confirmarEnvioRastro(Animal animal, String pesoVivo, String pesoCanal) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 28),
                  SizedBox(width: 10),
                  Text('¡Atención!',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                  'Al confirmar el envío al rastro, ${animal.name} se eliminará permanentemente de tu inventario de ganado vivo.\n\n¿Estás seguro?',
                  style: const TextStyle(fontSize: 15)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar',
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(
                            child: CircularProgressIndicator(
                                color: Colors.redAccent)));
                    try {
                      await _firestore
                          .collection('users')
                          .doc(_currentUser!.uid)
                          .collection('ranches') // Agregado
                          .doc(_currentRanchId) // Agregado
                          .collection('animals')
                          .doc(animal.id)
                          .delete();
                      if (mounted) Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Animal procesado y eliminado del inventario exitosamente.'),
                            backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Sí, Enviar y Eliminar',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ));
  }

  void _showRastroDialog(Animal animal) {
    final pesoVivoController = TextEditingController(
        text: _getUltimoPeso(animal) > 0
            ? _getUltimoPeso(animal).toString()
            : '');
    final pesoCanalController = TextEditingController();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25))),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 25),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(FontAwesomeIcons.truckFast,
                              color: Colors.redAccent)),
                      const SizedBox(width: 15),
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Enviar al Rastro',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5e3a1c))),
                            Text('Procesar animal y sacarlo del inventario',
                                style:
                                    TextStyle(fontSize: 13, color: Colors.grey))
                          ])),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: pesoVivoController,
                      maxLength: 10,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Peso vivo final (kg)',
                          prefixIcon: const Icon(Icons.monitor_weight_outlined,
                              color: Colors.grey),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 15),
                  TextFormField(
                      controller: pesoCanalController,
                      maxLength: 10,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Peso en Canal (Limpio en kg)',
                          helperText:
                              '* El peso exacto ya sin vísceras ni piel.',
                          helperStyle: const TextStyle(
                              color: Color(0xFFc99450),
                              fontStyle: FontStyle.italic),
                          prefixIcon:
                              const Icon(Icons.set_meal, color: Colors.grey),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmarEnvioRastro(animal, pesoVivoController.text,
                            pesoCanalController.text);
                      },
                      child: const Text('Confirmar Venta y Eliminar',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        });
  }

  void _showAddWeightDialog(Animal animal) {
    final TextEditingController weightController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setStateModal) {
            return Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 25),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25))),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Registrar Nuevo Pesaje',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5e3a1c))),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: weightController,
                        maxLength: 10,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: 'Peso en kg',
                            prefixIcon:
                                const Icon(Icons.scale, color: Colors.grey),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFc99450),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: () async {
                          if (weightController.text.isEmpty) return;
                          double weight = double.parse(weightController.text);
                          Navigator.pop(ctx);
                          await _firestore
                              .collection('users')
                              .doc(_currentUser!.uid)
                              .collection('ranches') // Agregado
                              .doc(_currentRanchId) // Agregado
                              .collection('animals')
                              .doc(animal.id)
                              .update({
                            'stats': FieldValue.arrayUnion([
                              {
                                'label': 'Peso',
                                'value': weight,
                                'date': Timestamp.fromDate(selectedDate)
                              }
                            ])
                          });
                        },
                        child: const Text('Guardar Peso',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRanch) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentRanchId == null) {
      return const Scaffold(
          body: Center(
              child: Text("Por favor selecciona un rancho en tu perfil")));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          backgroundColor: const Color(0xFFfbf6ec),
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
              onPressed: () => Navigator.of(context).pop()),
          title: const Text('Línea de Producción',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5e3a1c))),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Color(0xFF5e3a1c),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFc99450),
            tabs: [
              Tab(icon: Icon(Icons.trending_up), text: "En Engorda"),
              Tab(icon: Icon(Icons.set_meal), text: "Listos (Carne)"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _getAnimals(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFc99450)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text('No hay animales en este flujo de producción.',
                      style: TextStyle(color: Colors.grey)));
            }

            // --- LECTURA DE DATOS ACTUALIZADA ---
            List<Animal> allAnimals = [];
            List<Map<String, dynamic>> animalRawData = [];

            for (var doc in snapshot.data!.docs) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              allAnimals.add(Animal.fromFirestore(data, doc.id));
              animalRawData
                  .add(data); // Guardamos la data cruda para leer targetWeight
            }

            // Separamos por propósitos
            List<int> engordaIndexes = [];
            List<int> carneIndexes = [];

            for (int i = 0; i < allAnimals.length; i++) {
              if (allAnimals[i].purpose == 'Engorda') engordaIndexes.add(i);
              if (allAnimals[i].purpose == 'Carne') carneIndexes.add(i);
            }

            return TabBarView(
              children: [
                _buildEngordaTab(engordaIndexes, allAnimals, animalRawData),
                _buildCarneTab(carneIndexes, allAnimals),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- PESTAÑA 1: ENGORDA ---
  Widget _buildEngordaTab(List<int> indexes, List<Animal> allAnimals,
      List<Map<String, dynamic>> rawData) {
    if (indexes.isEmpty) {
      return const Center(
          child: Text('No hay animales en engorda.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: indexes.length,
      itemBuilder: (context, i) {
        int originalIndex = indexes[i];
        Animal animal = allAnimals[originalIndex];
        Map<String, dynamic> data = rawData[originalIndex];

        // Leemos la meta específica (500.0 por defecto si no existe)
        double pesoMeta = (data['targetWeight'] as num?)?.toDouble() ?? 500.0;

        double ultimoPeso = _getUltimoPeso(animal);
        double gdp = _calcularGDP(animal);
        double progreso =
            pesoMeta > 0 ? (ultimoPeso / pesoMeta).clamp(0.0, 1.0) : 0.0;
        bool llegoMeta = ultimoPeso >= pesoMeta && pesoMeta > 0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                  color: llegoMeta ? Colors.green : Colors.transparent,
                  width: 2)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      backgroundColor: const Color(0xFFfbf6ec),
                      child: const Icon(FontAwesomeIcons.cow,
                          color: Color(0xFFc99450))),
                  title: Text('${animal.name} (${animal.earTagNumber})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(
                      'Ganancia Diaria: ${gdp > 0 ? '${(gdp * 1000).toStringAsFixed(0)} gr' : 'Faltan datos'}'),
                  trailing: IconButton(
                      icon:
                          const Icon(Icons.remove_red_eye, color: Colors.grey),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AnimalDetailScreen(animalId: animal.id)))),
                ),
                const SizedBox(height: 10),

                // --- NUEVA SECCIÓN: BARRA DE PROGRESO Y BOTÓN META ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progreso: ${(progreso * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      onTap: () => _showEditTargetWeightDialog(
                          animal.id, pesoMeta, animal.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFc99450).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Meta: ${pesoMeta.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFc99450),
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.edit,
                                size: 14, color: Color(0xFFc99450)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        llegoMeta ? Colors.green : const Color(0xFFc99450)),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Actual: ${ultimoPeso.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFc99450),
                                side:
                                    const BorderSide(color: Color(0xFFc99450)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            icon: const Icon(Icons.scale, size: 18),
                            label: const Text('Pesar'),
                            onPressed: () => _showAddWeightDialog(animal))),
                    const SizedBox(width: 15),
                    Expanded(
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: llegoMeta
                                    ? Colors.green
                                    : Colors.grey.shade600,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            icon: const Icon(Icons.arrow_forward,
                                color: Colors.white, size: 18),
                            label: const Text('A Carne',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            onPressed: () => _moverACarne(animal))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- PESTAÑA 2: CARNE (LISTOS PARA RASTRO) ---
  Widget _buildCarneTab(List<int> indexes, List<Animal> allAnimals) {
    if (indexes.isEmpty) {
      return const Center(
          child: Text('No hay animales listos para procesar.',
              style: TextStyle(color: Colors.grey)));
    }

    double pesoVivoTotal = 0;
    for (var index in indexes) {
      pesoVivoTotal += _getUltimoPeso(allAnimals[index]);
    }
    double carneEstimada = pesoVivoTotal * estimacionCanal;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF8B0000), Color(0xFFB22222)]),
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ]),
            child: Column(
              children: [
                const Text('PROYECCIÓN DE RENDIMIENTO',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryStat('Cabezas', indexes.length.toString()),
                    Container(width: 1, height: 40, color: Colors.white30),
                    _buildSummaryStat(
                        'Peso Total', '${pesoVivoTotal.toStringAsFixed(0)} kg'),
                    Container(width: 1, height: 40, color: Colors.white30),
                    _buildSummaryStat(
                        'Carne Est.', '${carneEstimada.toStringAsFixed(0)} kg',
                        isHighlight: true),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                Animal animal = allAnimals[indexes[i]];
                double pesoVivo = _getUltimoPeso(animal);
                double canalEst = pesoVivo * estimacionCanal;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              backgroundColor: Colors.red.shade50,
                              child: const Icon(FontAwesomeIcons.cow,
                                  color: Colors.redAccent, size: 20)),
                          title: Text('${animal.name} (${animal.earTagNumber})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('Raza: ${animal.breed ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12)),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.shopping_cart, size: 16),
                            label: const Text('Al Rastro',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _showRastroDialog(animal),
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Peso Vivo Actual',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                    Text('${pesoVivo.toStringAsFixed(1)} kg',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold))
                                  ]),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Rendimiento Esperado (58%)',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                    Text(
                                        '${canalEst.toStringAsFixed(1)} kg de carne',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent))
                                  ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: indexes.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStat(String label, String value,
      {bool isHighlight = false}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: isHighlight ? Colors.yellowAccent : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
