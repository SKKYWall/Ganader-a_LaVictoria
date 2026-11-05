import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';

class GeneticaScreen extends StatefulWidget {
  const GeneticaScreen({super.key});

  @override
  State<GeneticaScreen> createState() => _GeneticaScreenState();
}

class _GeneticaScreenState extends State<GeneticaScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _currentRanchId;
  bool _isLoadingRanch = true;

  // Variables para el Simulador
  Animal? _selectedMother;
  Animal? _selectedFather;
  bool _showSimulation = false;

  // Búsqueda en la pestaña de Análisis DEP
  String _depQuery = '';

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentRanchId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRanchId() async {
    if (_currentUser == null) return;
    try {
      final userDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentRanchId = userDoc.data()?['currentRanchId'];
          _isLoadingRanch = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar rancho: $e");
      if (mounted) setState(() => _isLoadingRanch = false);
    }
  }

  Stream<QuerySnapshot> _getAllAnimals() {
    if (_currentUser == null || _currentRanchId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('ranches')
        .doc(_currentRanchId)
        .collection('animals')
        .snapshots();
  }

  // ─── Calificación por estrellas (carne) ───────────────────────────────────
  int _calculateMeatStars(Animal animal) {
    double score = 0;
    if (animal.weaningWeight != null) {
      if (animal.weaningWeight! >= 220) {
        score += 5;
      } else if (animal.weaningWeight! >= 180) {
        score += 4;
      } else if (animal.weaningWeight! >= 150) {
        score += 3;
      } else {
        score += 2;
      }
    } else if (animal.birthWeight != null) {
      if (animal.birthWeight! >= 40) {
        score += 5;
      } else if (animal.birthWeight! >= 35) {
        score += 4;
      } else if (animal.birthWeight! >= 30) {
        score += 3;
      } else {
        score += 2;
      }
    } else {
      return 0;
    }
    return score.clamp(1, 5).toInt();
  }

  // ─── DEP destete (diferencia vs promedio del hato) ────────────────────────
  double _calcDEP(Animal animal, double herdAvgWeaning) {
    if (animal.weaningWeight == null) return 0;
    return animal.weaningWeight! - herdAvgWeaning;
  }

  // ─── GDP (nacimiento → destete, 205 días estándar) ────────────────────────
  double _calcGDP(Animal animal) {
    if (animal.birthWeight == null || animal.weaningWeight == null) return 0;
    return (animal.weaningWeight! - animal.birthWeight!) / 205;
  }

  // ─── Verificación de consanguinidad ───────────────────────────────────────
  String? _checkInbreeding(Animal mother, Animal father) {
    if (mother.father != null && mother.father == father.earTagNumber) {
      return 'CRÍTICO: Cruza de Padre e Hija.';
    }
    if (father.mother != null && father.mother == mother.earTagNumber) {
      return 'CRÍTICO: Cruza de Madre e Hijo.';
    }
    if (mother.father != null &&
        father.father != null &&
        mother.father == father.father) {
      return 'ALTO RIESGO: Medios hermanos (Mismo Padre).';
    }
    if (mother.mother != null &&
        father.mother != null &&
        mother.mother == father.mother) {
      return 'ALTO RIESGO: Medios hermanos (Misma Madre).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRanch) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFc99450))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Inteligencia Genética',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c))),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5e3a1c),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFc99450),
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.analytics, size: 20), text: "Análisis DEP"),
            Tab(
                icon: Icon(Icons.monitor_heart, size: 20),
                text: "Simulador"),
            Tab(icon: Icon(Icons.emoji_events, size: 20), text: "Ranking"),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAllAnimals(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFc99450)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No hay animales registrados para evaluar.',
                    style: TextStyle(color: Colors.grey)));
          }

          final allAnimals = snapshot.data!.docs.map((doc) {
            return Animal.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          double totalWeaning = 0, totalBirth = 0;
          int countWeaning = 0, countBirth = 0;

          for (var a in allAnimals) {
            if (a.weaningWeight != null && a.weaningWeight! > 0) {
              totalWeaning += a.weaningWeight!;
              countWeaning++;
            }
            if (a.birthWeight != null && a.birthWeight! > 0) {
              totalBirth += a.birthWeight!;
              countBirth++;
            }
          }

          final herdAvgWeaning =
              countWeaning > 0 ? totalWeaning / countWeaning : 180.0;
          final herdAvgBirth =
              countBirth > 0 ? totalBirth / countBirth : 35.0;

          final females =
              allAnimals.where((a) => a.sex == 'Hembra').toList();
          final males =
              allAnimals.where((a) => a.sex == 'Macho').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDepTab(allAnimals, herdAvgWeaning, herdAvgBirth),
              _buildSimulatorTab(
                  females, males, herdAvgWeaning, herdAvgBirth),
              _buildRankingTab(allAnimals, herdAvgWeaning),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: ANÁLISIS DEP
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDepTab(
      List<Animal> animals, double herdAvgWeaning, double herdAvgBirth) {
    // Filtrado por nombre o número de arete (insensible a mayúsculas).
    final q = _depQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? animals
        : animals
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.earTagNumber.toLowerCase().contains(q))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (val) => setState(() => _depQuery = val),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o arete...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFFc99450)),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        if (filtered.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Ningún animal coincide con la búsqueda.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final animal = filtered[index];
        final meatStars = _calculateMeatStars(animal);
        final gdp = _calcGDP(animal);
        final depWeaning = _calcDEP(animal, herdAvgWeaning);

        String rasgoPartoLabel =
            animal.sex == 'Macho' ? 'Tamaño de Crías:' : 'Facilidad de Parto:';
        String rasgoPartoValor = 'Faltan datos';
        if (animal.birthWeight != null) {
          if (animal.sex == 'Macho') {
            if (animal.birthWeight! < 32) {
              rasgoPartoValor = 'Ligeras (Partos Fáciles)';
            } else if (animal.birthWeight! <= 38) {
              rasgoPartoValor = 'Promedio (Normales)';
            } else {
              rasgoPartoValor = 'Gigantes (Riesgo Distocia)';
            }
          } else {
            if (animal.birthWeight! < 32) {
              rasgoPartoValor = 'Alta (Partos Fáciles)';
            } else if (animal.birthWeight! <= 38) {
              rasgoPartoValor = 'Media (Normal)';
            } else {
              rasgoPartoValor = 'Baja (Riesgo de Distocia)';
            }
          }
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: animal.sex == 'Macho'
                  ? Colors.blue.shade50
                  : Colors.pink.shade50,
              child: Icon(FontAwesomeIcons.dna,
                  color: animal.sex == 'Macho' ? Colors.blue : Colors.pink,
                  size: 20),
            ),
            title: Text('${animal.name} (${animal.earTagNumber})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(children: [
              ...List.generate(
                  5,
                  (i) => Icon(
                      i < meatStars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16)),
              const SizedBox(width: 6),
              Text(
                  animal.sex == 'Macho' ? 'Semental' : 'Vientre',
                  style: TextStyle(
                      fontSize: 10,
                      color: animal.sex == 'Macho'
                          ? Colors.blue
                          : Colors.pink)),
            ]),
            trailing: GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AnimalDetailScreen(animalId: animal.id))),
              child: const Icon(Icons.open_in_new,
                  color: Color(0xFFc99450), size: 18),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        bottomRight: Radius.circular(15))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('RENDIMIENTO (DEP)'),
                    const SizedBox(height: 8),
                    _depRow(depWeaning, animal.weaningWeight),
                    const SizedBox(height: 8),
                    _buildStatRow(
                        'Ganancia Diaria (GDP):',
                        gdp > 0
                            ? '${(gdp * 1000).toStringAsFixed(0)} gr/día'
                            : 'Faltan datos'),
                    const SizedBox(height: 8),
                    _buildStatRow(rasgoPartoLabel, rasgoPartoValor),
                    const SizedBox(height: 12),
                    _sectionLabel('LINAJE'),
                    const SizedBox(height: 8),
                    _buildStatRow(
                        'Padre Semental:', animal.father ?? 'Desconocido'),
                    const SizedBox(height: 6),
                    _buildStatRow('Madre:', animal.mother ?? 'Desconocida'),
                    // Marcadores genéticos y resistencia (si existen)
                    if (animal.geneticMarkers != null &&
                        animal.geneticMarkers!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionLabel('MARCADORES GENÉTICOS'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(animal.geneticMarkers!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                      ),
                    ],
                    if (animal.diseaseResistance != null &&
                        animal.diseaseResistance!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionLabel('RESISTENCIA GENÉTICA A ENFERMEDADES'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(animal.diseaseResistance!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                      ),
                    ],
                    if (animal.fertilityInfo != null &&
                        animal.fertilityInfo!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionLabel('INFORMACIÓN DE FERTILIDAD'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(animal.fertilityInfo!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
              },
            ),
          ),
      ],
    );
  }

  Widget _depRow(double dep, double? weaningWeight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('DEP Destete:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: weaningWeight == null
                  ? Colors.grey.shade200
                  : (dep >= 0 ? Colors.green.shade50 : Colors.red.shade50),
              borderRadius: BorderRadius.circular(5)),
          child: Text(
            weaningWeight == null
                ? 'Sin datos'
                : '${dep >= 0 ? '+' : ''}${dep.toStringAsFixed(1)} kg',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: weaningWeight == null
                    ? Colors.grey
                    : (dep >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700)),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: SIMULADOR DE CRUZAS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSimulatorTab(List<Animal> females, List<Animal> males,
      double herdAvgWeaning, double herdAvgBirth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Simulador Predictivo de Cruzas:',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5e3a1c))),
          const SizedBox(height: 5),
          const Text(
              'Selecciona dos animales. El motor calculará la genética del futuro becerro.',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),
          DropdownButtonFormField<Animal>(
            isExpanded: true,
            decoration: InputDecoration(
                labelText: 'Hembra (Madre)',
                prefixIcon: const Icon(Icons.female, color: Colors.pink),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10))),
            items: females
                .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text('${f.name} (${f.earTagNumber})',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => setState(() {
              _selectedMother = val;
              _showSimulation = false;
            }),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<Animal>(
            isExpanded: true,
            decoration: InputDecoration(
                labelText: 'Macho Semental (Padre)',
                prefixIcon: const Icon(Icons.male, color: Colors.blue),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10))),
            items: males
                .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text('${m.name} (${m.earTagNumber})',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) => setState(() {
              _selectedFather = val;
              _showSimulation = false;
            }),
          ),
          const SizedBox(height: 25),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5e3a1c),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.science, color: Colors.white),
            label: const Text('Generar Pronóstico',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            onPressed:
                (_selectedMother != null && _selectedFather != null)
                    ? () => setState(() => _showSimulation = true)
                    : null,
          ),
          const SizedBox(height: 25),
          if (_showSimulation &&
              _selectedMother != null &&
              _selectedFather != null)
            _buildSimulationResult(herdAvgWeaning, herdAvgBirth),
        ],
      ),
    );
  }

  Widget _buildSimulationResult(
      double herdAvgWeaning, double herdAvgBirth) {
    final inbreedingAlert =
        _checkInbreeding(_selectedMother!, _selectedFather!);

    final mBW = _selectedMother!.birthWeight ?? herdAvgBirth;
    final fBW = _selectedFather!.birthWeight ?? herdAvgBirth;
    final predictedBirthWeight = (mBW + fBW) / 2;

    final mWW = _selectedMother!.weaningWeight ?? herdAvgWeaning;
    final fWW = _selectedFather!.weaningWeight ?? herdAvgWeaning;
    final predictedWeaningWeight = (mWW + fWW) / 2;

    final predictedDEP = predictedWeaningWeight - herdAvgWeaning;

    // Predicción GDP (nacimiento → destete en 205 días)
    final predictedGDP =
        (predictedWeaningWeight - predictedBirthWeight) / 205;

    // Herencia de marcadores y resistencia
    final motherResist = _selectedMother!.diseaseResistance ?? '';
    final fatherResist = _selectedFather!.diseaseResistance ?? '';
    final sharedResist = motherResist.isNotEmpty && fatherResist.isNotEmpty
        ? 'Madre: $motherResist\nPadre: $fatherResist'
        : (motherResist.isNotEmpty
            ? 'Madre: $motherResist'
            : (fatherResist.isNotEmpty ? 'Padre: $fatherResist' : ''));

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
              color:
                  inbreedingAlert != null ? Colors.red : Colors.green,
              width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('PRONÓSTICO DE LA CRÍA',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: inbreedingAlert != null
                        ? Colors.red
                        : Colors.green)),
            const Divider(thickness: 2),
            const SizedBox(height: 10),
            if (inbreedingAlert != null)
              _alertBanner(inbreedingAlert, Colors.red, Colors.red.shade50,
                  Icons.warning_amber_rounded)
            else
              _alertBanner(
                  'Cruza Segura: Baja probabilidad de consanguinidad.',
                  Colors.green,
                  Colors.green.shade50,
                  Icons.check_circle),
            const SizedBox(height: 10),
            _buildStatRow(
                'Peso al Nacer Estimado:',
                '${predictedBirthWeight.toStringAsFixed(1)} kg',
                isHighlight: true),
            const SizedBox(height: 10),
            _buildStatRow(
                'Peso Destete Estimado:',
                '${predictedWeaningWeight.toStringAsFixed(1)} kg',
                isHighlight: true),
            const SizedBox(height: 10),
            _buildStatRow(
                'GDP Estimado (205 días):',
                '${(predictedGDP * 1000).toStringAsFixed(0)} gr/día',
                isHighlight: true),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('DEP Proyectado:',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  '${predictedDEP >= 0 ? '+' : ''}${predictedDEP.toStringAsFixed(1)} kg vs Hato',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: predictedDEP >= 0
                          ? Colors.green
                          : Colors.red),
                ),
              ],
            ),
            if (sharedResist.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              _sectionLabel('RESISTENCIAS GENÉTICAS DE LOS PADRES'),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(sharedResist,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black87)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: RANKING DE MEJORES REPRODUCTORES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRankingTab(List<Animal> animals, double herdAvgWeaning) {
    // Separar y ordenar machos y hembras por DEP descendente
    final males = animals
        .where((a) => a.sex == 'Macho' && a.weaningWeight != null)
        .toList()
      ..sort((a, b) =>
          _calcDEP(b, herdAvgWeaning).compareTo(_calcDEP(a, herdAvgWeaning)));

    final females = animals
        .where((a) => a.sex == 'Hembra' && a.weaningWeight != null)
        .toList()
      ..sort((a, b) =>
          _calcDEP(b, herdAvgWeaning).compareTo(_calcDEP(a, herdAvgWeaning)));

    final noData = animals
        .where((a) => a.weaningWeight == null)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explicación
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFfff8ee),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFc99450).withValues(alpha: 0.4))),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFFc99450), size: 18),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Ranking basado en DEP al Destete. El animal con mayor DEP positivo '
                      'transmite más kilos extra a su progenie vs el promedio del hato.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5e3a1c)))),
            ]),
          ),
          const SizedBox(height: 20),

          if (males.isNotEmpty) ...[
            _rankSectionTitle('Sementales (Machos)', Colors.blue),
            const SizedBox(height: 10),
            ...males.asMap().entries.map((e) =>
                _rankCard(e.key + 1, e.value, herdAvgWeaning, Colors.blue)),
            const SizedBox(height: 20),
          ],

          if (females.isNotEmpty) ...[
            _rankSectionTitle('Vientres (Hembras)', Colors.pink),
            const SizedBox(height: 10),
            ...females.asMap().entries.map((e) =>
                _rankCard(e.key + 1, e.value, herdAvgWeaning, Colors.pink)),
            const SizedBox(height: 20),
          ],

          if (males.isEmpty && females.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                const Icon(Icons.bar_chart, size: 50, color: Colors.grey),
                const SizedBox(height: 10),
                const Text(
                    'No hay datos suficientes para el ranking.\n'
                    'Registra el peso al destete de tus animales para verlos clasificados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            ),

          if (noData.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${noData.length} animal(es) sin peso al destete registrado.',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _rankSectionTitle(String label, Color color) {
    return Row(children: [
      Icon(Icons.emoji_events, color: color, size: 22),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _rankCard(
      int rank, Animal animal, double herdAvgWeaning, Color color) {
    final dep = _calcDEP(animal, herdAvgWeaning);
    final gdp = _calcGDP(animal);
    final stars = _calculateMeatStars(animal);
    final isTop = rank <= 3;
    final medalColors = [Colors.amber, Colors.grey.shade400, Colors.brown.shade300];

    return Card(
      elevation: isTop ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isTop
              ? BorderSide(color: color.withValues(alpha: 0.4), width: 1.5)
              : BorderSide.none),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Posición / medalla
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isTop
                    ? medalColors[rank - 1].withValues(alpha: 0.15)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isTop
                    ? Icon(Icons.emoji_events,
                        color: medalColors[rank - 1], size: 20)
                    : Text('$rank',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),

            // Info del animal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${animal.name} (${animal.earTagNumber})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                      '${animal.breed ?? 'Sin raza'}  ·  ${gdp > 0 ? '${(gdp * 1000).toStringAsFixed(0)} gr/día' : 'Sin GDP'}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(children: List.generate(
                      5,
                      (i) => Icon(
                          i < stars ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 13))),
                ],
              ),
            ),

            // DEP
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: dep >= 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'DEP ${dep >= 0 ? '+' : ''}${dep.toStringAsFixed(1)} kg',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: dep >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              AnimalDetailScreen(animalId: animal.id))),
                  child: const Text('Ver perfil',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFc99450),
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Utilidades de UI ─────────────────────────────────────────────────────

  Widget _alertBanner(
      String text, Color textColor, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: textColor, size: 24),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey,
            letterSpacing: 0.5));
  }

  Widget _buildStatRow(String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(label,
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: isHighlight
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: isHighlight
                      ? const Color(0xFFc99450)
                      : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
