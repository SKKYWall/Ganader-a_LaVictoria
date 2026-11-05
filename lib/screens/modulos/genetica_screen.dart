import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:manual_ganadero_flutter/core/breed_groups.dart';
import 'package:manual_ganadero_flutter/core/contemporary_groups.dart';
import 'package:manual_ganadero_flutter/core/pedigree.dart';
import 'package:manual_ganadero_flutter/core/weaning_gdp.dart';

// Comparaciones de sexo normalizadas (espacios y mayúsculas no deberían
// importar — un dato capturado como " macho" o "MACHO" es válido).
bool _isMale(String? sex) => sex?.trim().toLowerCase() == 'macho';
bool _isFemale(String? sex) => sex?.trim().toLowerCase() == 'hembra';
bool _isDairyPurpose(String? purpose) =>
    purpose?.trim().toLowerCase() == 'leche';

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
  // Null = "No aplica" (el animal es de propósito Leche — las estrellas de
  // carne no tienen sentido ahí). 0 = sin datos suficientes para calificar.
  // Los umbrales se ajustan por grupo racial: comparar el destete de un
  // Cebú de marco chico contra el umbral de un Charolais castiga una raza
  // que simplemente es más pequeña por naturaleza, no peor genéticamente.
  static const Map<BreedGroup, double> _meatStarThresholdMultiplier = {
    BreedGroup.continental: 1.0,
    BreedGroup.lechera: 1.0,
    BreedGroup.cruzaOtro: 0.92,
    BreedGroup.cebu: 0.85,
  };

  int? _calculateMeatStars(Animal animal) {
    if (_isDairyPurpose(animal.purpose)) return null;
    final mult = _meatStarThresholdMultiplier[breedGroupOf(animal.breed)] ?? 1.0;
    double score = 0;
    if (animal.weaningWeight != null) {
      final w = animal.weaningWeight!;
      if (w >= 220 * mult) {
        score += 5;
      } else if (w >= 180 * mult) {
        score += 4;
      } else if (w >= 150 * mult) {
        score += 3;
      } else {
        score += 2;
      }
    } else if (animal.birthWeight != null) {
      final w = animal.birthWeight!;
      if (w >= 40 * mult) {
        score += 5;
      } else if (w >= 35 * mult) {
        score += 4;
      } else if (w >= 30 * mult) {
        score += 3;
      } else {
        score += 2;
      }
    } else {
      return 0;
    }
    return score.clamp(1, 5).toInt();
  }

  // ─── DEP destete (diferencia vs grupo de contemporáneos) ──────────────────
  // Se compara contra animales de la misma raza + sexo + año de nacimiento
  // cuando hay suficientes (ver ContemporaryGroups); si no, se cae al
  // promedio general del hato y se indica explícitamente en la UI, para no
  // aparentar una precisión de EPD certificado que esta app no calcula.
  (double dep, bool isContemporary)? _calcDEP(
      Animal animal, ContemporaryGroups groups) {
    if (animal.weaningWeight == null) return null;
    final (avg, isContemporary) = groups.averageFor(animal);
    return (animal.weaningWeight! - avg, isContemporary);
  }

  // ─── Verificación de consanguinidad (coeficiente de Wright) ───────────────
  InbreedingResult _checkInbreeding(
      Animal mother, Animal father, Map<String, Animal> byEarTag) {
    return calculateInbreeding(father, mother, byEarTag);
  }

  Color _riskColor(InbreedingRisk risk) {
    switch (risk) {
      case InbreedingRisk.critical:
        return Colors.red;
      case InbreedingRisk.high:
        return Colors.deepOrange;
      case InbreedingRisk.moderate:
        return Colors.orange;
      case InbreedingRisk.low:
        return Colors.amber.shade700;
      case InbreedingRisk.none:
        return Colors.green;
    }
  }

  // ─── Riesgo de distocia (parto difícil) ───────────────────────────────────
  // Compara el peso al nacer proyectado contra el historial de partos
  // propios de la madre (sus crías previas ya registradas en el sistema,
  // ligadas por earTag) cuando existe; si la madre no tiene crías previas
  // registradas, usa el promedio del hato como referencia general.
  String? _checkDystociaRisk(Animal mother, double predictedBirthWeight,
      List<Animal> allAnimals, double herdAvgBirth) {
    final motherTag = mother.earTagNumber.trim();
    final priorCalves = allAnimals
        .where((a) => a.mother != null && a.mother == motherTag && a.birthWeight != null)
        .map((a) => a.birthWeight!)
        .toList();

    if (priorCalves.isNotEmpty) {
      final maxPrior = priorCalves.reduce((a, b) => a > b ? a : b);
      if (predictedBirthWeight > maxPrior * 1.15) {
        return 'El peso al nacer proyectado (${predictedBirthWeight.toStringAsFixed(1)} kg) '
            'supera en más de 15% el mayor peso de cría que esta madre ha tenido antes '
            '(${maxPrior.toStringAsFixed(1)} kg) — vigila de cerca el parto.';
      }
      return null;
    }

    if (predictedBirthWeight > herdAvgBirth * 1.20) {
      return 'El peso al nacer proyectado (${predictedBirthWeight.toStringAsFixed(1)} kg) '
          'es notablemente mayor al promedio del hato (${herdAvgBirth.toStringAsFixed(1)} kg). '
          'Esta madre no tiene partos previos registrados para comparar — vigila de cerca el parto.';
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
            Tab(icon: Icon(Icons.analytics, size: 20), text: "Índice vs. Hato"),
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

          final contemporaryGroups = ContemporaryGroups.fromAnimals(allAnimals);
          // Incluye animales de cualquier estado (activo/inactivo) — el
          // pedigrí de un animal archivado sigue siendo real y necesario
          // para resolver la genealogía de sus descendientes.
          final byEarTag = buildEarTagIndex(allAnimals);

          final females = allAnimals.where((a) => _isFemale(a.sex)).toList();
          final males = allAnimals.where((a) => _isMale(a.sex)).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDepTab(allAnimals, contemporaryGroups),
              _buildSimulatorTab(females, males, herdAvgWeaning, herdAvgBirth,
                  allAnimals, byEarTag),
              _buildRankingTab(allAnimals, contemporaryGroups),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: ANÁLISIS DEP
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDepTab(List<Animal> animals, ContemporaryGroups groups) {
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
        final gdp = calculateWeaningGdp(animal);
        final depWeaning = _calcDEP(animal, groups);
        final isMale = _isMale(animal.sex);

        String rasgoPartoLabel =
            isMale ? 'Tamaño de Crías:' : 'Facilidad de Parto:';
        String rasgoPartoValor = 'Faltan datos';
        if (animal.birthWeight != null) {
          if (isMale) {
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
              backgroundColor: isMale ? Colors.blue.shade50 : Colors.pink.shade50,
              child: Icon(FontAwesomeIcons.dna,
                  color: isMale ? Colors.blue : Colors.pink, size: 20),
            ),
            title: Text('${animal.name} (${animal.earTagNumber})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(children: [
              if (meatStars == null)
                const Text('No aplica (propósito Leche)',
                    style: TextStyle(fontSize: 10, color: Colors.grey))
              else
                ...List.generate(
                    5,
                    (i) => Icon(
                        i < meatStars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16)),
              const SizedBox(width: 6),
              Text(isMale ? 'Semental' : 'Vientre',
                  style: TextStyle(
                      fontSize: 10, color: isMale ? Colors.blue : Colors.pink)),
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
                    _sectionLabel('RENDIMIENTO (ÍNDICE VS. HATO, APROX.)'),
                    const SizedBox(height: 8),
                    _depRow(depWeaning),
                    const SizedBox(height: 8),
                    _buildStatRow(
                        'Ganancia Diaria (GDP):',
                        gdp == null
                            ? 'Faltan datos'
                            : '${gdp.gramsPerDay.toStringAsFixed(0)} gr/día'
                                '${gdp.usedRealWeaningDate ? '' : ' (est. 205d)'}'),
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

  Widget _depRow((double dep, bool isContemporary)? result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Peso Destete vs. Hato:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: result == null
                      ? Colors.grey.shade200
                      : (result.$1 >= 0
                          ? Colors.green.shade50
                          : Colors.red.shade50),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(
                result == null
                    ? 'Sin datos'
                    : '${result.$1 >= 0 ? '+' : ''}${result.$1.toStringAsFixed(1)} kg',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: result == null
                        ? Colors.grey
                        : (result.$1 >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700)),
              ),
            ),
          ],
        ),
        if (result != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              result.$2
                  ? 'vs. contemporáneos (misma raza/sexo/año de nacimiento)'
                  : 'vs. promedio general del hato (pocos contemporáneos reales)',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: SIMULADOR DE CRUZAS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSimulatorTab(
      List<Animal> females,
      List<Animal> males,
      double herdAvgWeaning,
      double herdAvgBirth,
      List<Animal> allAnimals,
      Map<String, Animal> byEarTag) {
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
              'Selecciona dos animales. Se proyecta un estimado de peso y el '
              'riesgo de consanguinidad de la cría, basado en los datos ya '
              'registrados — no es un valor genómico certificado.',
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
            _buildSimulationResult(
                herdAvgWeaning, herdAvgBirth, allAnimals, byEarTag),
        ],
      ),
    );
  }

  Widget _buildSimulationResult(double herdAvgWeaning, double herdAvgBirth,
      List<Animal> allAnimals, Map<String, Animal> byEarTag) {
    final mother = _selectedMother!;
    final father = _selectedFather!;
    final inbreeding = _checkInbreeding(mother, father, byEarTag);
    final bannerColor = _riskColor(inbreeding.risk);
    final completenessPct =
        (inbreeding.pedigreeCompleteness * 100).toStringAsFixed(0);
    final bannerText = inbreeding.risk == InbreedingRisk.none
        ? 'Sin relación detectada en la genealogía disponible '
            '($completenessPct% de 3 generaciones verificada).'
        : 'Riesgo de consanguinidad ${inbreeding.riskLabel} — '
            'F ≈ ${(inbreeding.coefficient * 100).toStringAsFixed(1)}% '
            '($completenessPct% de 3 generaciones verificada).';

    final mBW = mother.birthWeight ?? herdAvgBirth;
    final fBW = father.birthWeight ?? herdAvgBirth;
    final predictedBirthWeight = (mBW + fBW) / 2;

    final mWW = mother.weaningWeight ?? herdAvgWeaning;
    final fWW = father.weaningWeight ?? herdAvgWeaning;
    final baseWeaningWeight = (mWW + fWW) / 2;
    // Heterosis (vigor híbrido): una cruza entre grupos raciales distintos
    // suele destetar más pesado que el simple promedio de los padres. Se
    // aplica un bono conservador (+8%) solo al peso al destete, documentado
    // en la literatura para cruzas industria-cebú/continental — nunca al
    // peso al nacer, que depende más del tamaño de la madre.
    final motherGroup = breedGroupOf(mother.breed);
    final fatherGroup = breedGroupOf(father.breed);
    final isCrossbred = motherGroup != fatherGroup;
    final predictedWeaningWeight =
        isCrossbred ? baseWeaningWeight * 1.08 : baseWeaningWeight;

    final predictedDEP = predictedWeaningWeight - herdAvgWeaning;

    // Predicción GDP (nacimiento → destete en 205 días estándar — es una
    // proyección, no hay fecha real que usar todavía).
    final predictedGDP =
        (predictedWeaningWeight - predictedBirthWeight) / 205;

    final dystociaAlert = _checkDystociaRisk(
        mother, predictedBirthWeight, allAnimals, herdAvgBirth);

    // Herencia de marcadores y resistencia
    final motherResist = mother.diseaseResistance ?? '';
    final fatherResist = father.diseaseResistance ?? '';
    final sharedResist = motherResist.isNotEmpty && fatherResist.isNotEmpty
        ? 'Madre: $motherResist\nPadre: $fatherResist'
        : (motherResist.isNotEmpty
            ? 'Madre: $motherResist'
            : (fatherResist.isNotEmpty ? 'Padre: $fatherResist' : ''));

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: bannerColor, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('PRONÓSTICO DE LA CRÍA',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: bannerColor)),
            const Divider(thickness: 2),
            const SizedBox(height: 10),
            _alertBanner(
                bannerText,
                bannerColor,
                bannerColor.withValues(alpha: 0.08),
                inbreeding.risk == InbreedingRisk.none
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded),
            if (isCrossbred) ...[
              const SizedBox(height: 6),
              _alertBanner(
                  'Cruza entre grupos raciales distintos: se aplicó un bono '
                  'de heterosis (+8%) al peso al destete estimado.',
                  Colors.blue,
                  Colors.blue.shade50,
                  Icons.science),
            ],
            if (dystociaAlert != null) ...[
              const SizedBox(height: 6),
              _alertBanner(dystociaAlert, Colors.deepOrange,
                  Colors.orange.shade50, Icons.priority_high),
            ],
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
                const Text('Índice Proyectado vs. Hato:',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  '${predictedDEP >= 0 ? '+' : ''}${predictedDEP.toStringAsFixed(1)} kg',
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
  Widget _buildRankingTab(List<Animal> animals, ContemporaryGroups groups) {
    // Separar y ordenar machos y hembras por índice vs. hato descendente
    double depValueOf(Animal a) => _calcDEP(a, groups)?.$1 ?? 0;

    final males = animals
        .where((a) => _isMale(a.sex) && a.weaningWeight != null)
        .toList()
      ..sort((a, b) => depValueOf(b).compareTo(depValueOf(a)));

    final females = animals
        .where((a) => _isFemale(a.sex) && a.weaningWeight != null)
        .toList()
      ..sort((a, b) => depValueOf(b).compareTo(depValueOf(a)));

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
                      'Ranking basado en el índice de peso al destete vs. hato '
                      '(aproximado — compara contra contemporáneos de la misma '
                      'raza/sexo/año cuando hay suficientes, o contra el promedio '
                      'general si no). El animal con mayor índice positivo transmite '
                      'más kilos extra a su progenie.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5e3a1c)))),
            ]),
          ),
          const SizedBox(height: 20),

          if (males.isNotEmpty) ...[
            _rankSectionTitle('Sementales (Machos)', Colors.blue),
            const SizedBox(height: 10),
            ...males.asMap().entries.map(
                (e) => _rankCard(e.key + 1, e.value, groups, Colors.blue)),
            const SizedBox(height: 20),
          ],

          if (females.isNotEmpty) ...[
            _rankSectionTitle('Vientres (Hembras)', Colors.pink),
            const SizedBox(height: 10),
            ...females.asMap().entries.map(
                (e) => _rankCard(e.key + 1, e.value, groups, Colors.pink)),
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
      int rank, Animal animal, ContemporaryGroups groups, Color color) {
    final depResult = _calcDEP(animal, groups);
    final dep = depResult?.$1 ?? 0;
    final gdp = calculateWeaningGdp(animal);
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
                      '${animal.breed ?? 'Sin raza'}  ·  ${gdp != null ? '${gdp.gramsPerDay.toStringAsFixed(0)} gr/día' : 'Sin GDP'}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 4),
                  if (stars == null)
                    const Text('No aplica (propósito Leche)',
                        style: TextStyle(fontSize: 10, color: Colors.grey))
                  else
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
                    '${dep >= 0 ? '+' : ''}${dep.toStringAsFixed(1)} kg',
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
