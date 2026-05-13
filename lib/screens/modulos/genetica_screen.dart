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

class _GeneticaScreenState extends State<GeneticaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _currentRanchId;
  bool _isLoadingRanch = true;

  // Variables para el Simulador
  Animal? _selectedMother;
  Animal? _selectedFather;
  bool _showSimulation = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentRanchId();
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
    if (_currentUser == null || _currentRanchId == null)
      return const Stream.empty();

    return _firestore
        .collection('users') // <-- AGREGADO
        .doc(_currentUser!.uid) // <-- AGREGADO
        .collection('ranches')
        .doc(_currentRanchId)
        .collection('animals')
        .snapshots();
  }

  // --- 1. LÓGICA DE CALIFICACIÓN POR ESTRELLAS ---
  int _calculateMeatStars(Animal animal) {
    double score = 0;
    if (animal.weaningWeight != null) {
      if (animal.weaningWeight! >= 220)
        score += 5;
      else if (animal.weaningWeight! >= 180)
        score += 4;
      else if (animal.weaningWeight! >= 150)
        score += 3;
      else
        score += 2;
    } else if (animal.birthWeight != null) {
      if (animal.birthWeight! >= 40)
        score += 5;
      else if (animal.birthWeight! >= 35)
        score += 4;
      else if (animal.birthWeight! >= 30)
        score += 3;
      else
        score += 2;
    } else {
      return 0; // Sin datos
    }
    return score.clamp(1, 5).toInt();
  }

  // --- 2. VERIFICACIÓN DE CONSANGUINIDAD (INBREEDING) ---
  String? _checkInbreeding(Animal mother, Animal father) {
    if (mother.father != null && mother.father == father.earTagNumber)
      return 'CRÍTICO: Cruza de Padre e Hija.';
    if (father.mother != null && father.mother == mother.earTagNumber)
      return 'CRÍTICO: Cruza de Madre e Hijo.';
    if (mother.father != null &&
        father.father != null &&
        mother.father == father.father)
      return 'ALTO RIESGO: Medios hermanos (Mismo Padre).';
    if (mother.mother != null &&
        father.mother != null &&
        mother.mother == father.mother)
      return 'ALTO RIESGO: Medios hermanos (Misma Madre).';
    return null;
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
          title: const Text('Inteligencia Genética',
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
              Tab(icon: Icon(Icons.analytics), text: "Análisis DEP"),
              Tab(icon: Icon(Icons.monitor_heart), text: "Simulador Match"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _getAllAnimals(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFc99450)));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return const Center(
                  child: Text('No hay animales registrados para evaluar.'));

            List<Animal> allAnimals = snapshot.data!.docs.map((doc) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              return Animal.fromFirestore(data, doc.id);
            }).toList();

            double totalWeaning = 0;
            int countWeaning = 0;
            double totalBirth = 0;
            int countBirth = 0;

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

            double herdAvgWeaning =
                countWeaning > 0 ? totalWeaning / countWeaning : 180.0;
            double herdAvgBirth =
                countBirth > 0 ? totalBirth / countBirth : 35.0;

            List<Animal> females =
                allAnimals.where((a) => a.sex == 'Hembra').toList();
            List<Animal> males =
                allAnimals.where((a) => a.sex == 'Macho').toList();

            return TabBarView(
              children: [
                _buildMeritTab(allAnimals, herdAvgWeaning, herdAvgBirth),
                _buildSimulatorTab(
                    females, males, herdAvgWeaning, herdAvgBirth),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- PESTAÑA 1: ANÁLISIS DEP Y PERFIL GENÉTICO AVANZADO ---
  Widget _buildMeritTab(
      List<Animal> animals, double herdAvgWeaning, double herdAvgBirth) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: animals.length,
      itemBuilder: (context, index) {
        Animal animal = animals[index];
        int meatStars = _calculateMeatStars(animal);

        // 1. Ganancia Diaria de Peso (GDP) a los 205 días
        double gdp = 0.0;
        if (animal.birthWeight != null && animal.weaningWeight != null) {
          gdp = (animal.weaningWeight! - animal.birthWeight!) / 205;
        }

        // 2. Diferencia Esperada en la Progenie (DEP)
        double depWeaning = 0.0;
        if (animal.weaningWeight != null) {
          depWeaning = animal.weaningWeight! - herdAvgWeaning;
        }

        // 3. Predicción de Facilidad de Parto (Diferente para Machos y Hembras)
        String rasgoPartoLabel =
            animal.sex == 'Macho' ? 'Tamaño de Crías:' : 'Facilidad de Parto:';
        String rasgoPartoValor = 'Faltan datos';

        if (animal.birthWeight != null) {
          if (animal.sex == 'Macho') {
            if (animal.birthWeight! < 32)
              rasgoPartoValor = 'Ligeras (Partos Fáciles)';
            else if (animal.birthWeight! <= 38)
              rasgoPartoValor = 'Promedio (Normales)';
            else
              rasgoPartoValor = 'Gigantes (Riesgo Distocia)';
          } else {
            if (animal.birthWeight! < 32)
              rasgoPartoValor = 'Alta (Partos Fáciles)';
            else if (animal.birthWeight! <= 38)
              rasgoPartoValor = 'Media (Normal)';
            else
              rasgoPartoValor = 'Baja (Riesgo de Distocia)';
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
            subtitle: Row(
              children: [
                ...List.generate(
                    5,
                    (starIndex) => Icon(
                        starIndex < meatStars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16)),
              ],
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        bottomRight: Radius.circular(15))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ANÁLISIS DE RENTABILIDAD (DEP)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 5),
                    Text(
                        'El valor DEP compara a este animal contra el promedio general de tu rancho.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('DEP Destete:',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: animal.weaningWeight == null
                                  ? Colors.grey.shade200
                                  : (depWeaning >= 0
                                      ? Colors.green.shade50
                                      : Colors.red.shade50),
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(
                            animal.weaningWeight == null
                                ? 'Sin datos'
                                : '${depWeaning >= 0 ? '+' : ''}${depWeaning.toStringAsFixed(1)} kg',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: animal.weaningWeight == null
                                    ? Colors.grey
                                    : (depWeaning >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700)),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildStatRow(
                        'Ganancia Diaria (GDP):',
                        gdp > 0
                            ? '${(gdp * 1000).toStringAsFixed(0)} gr / día'
                            : 'Faltan datos'),
                    const SizedBox(height: 8),
                    _buildStatRow(rasgoPartoLabel, rasgoPartoValor),
                    const SizedBox(height: 15),
                    const Text('LINAJE',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const Divider(),
                    _buildStatRow(
                        'Padre Semental:', animal.father ?? 'Desconocido'),
                    const SizedBox(height: 8),
                    _buildStatRow('Madre:', animal.mother ?? 'Desconocida'),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // --- PESTAÑA 2: SIMULADOR DE CRUZAS (MATCHMAKER) ---
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
              'Selecciona dos animales. El motor matemático calculará la genética del futuro becerro.',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),
          DropdownButtonFormField<Animal>(
            decoration: InputDecoration(
                labelText: 'Hembra (Madre)',
                prefixIcon: const Icon(Icons.female, color: Colors.pink),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10))),
            items: females
                .map((f) => DropdownMenuItem(
                    value: f, child: Text('${f.name} (${f.earTagNumber})')))
                .toList(),
            onChanged: (val) => setState(() {
              _selectedMother = val;
              _showSimulation = false;
            }),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<Animal>(
            decoration: InputDecoration(
                labelText: 'Macho Semental (Padre)',
                prefixIcon: const Icon(Icons.male, color: Colors.blue),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10))),
            items: males
                .map((m) => DropdownMenuItem(
                    value: m, child: Text('${m.name} (${m.earTagNumber})')))
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
            onPressed: (_selectedMother != null && _selectedFather != null)
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

  Widget _buildSimulationResult(double herdAvgWeaning, double herdAvgBirth) {
    String? inbreedingAlert =
        _checkInbreeding(_selectedMother!, _selectedFather!);

    double mBW = _selectedMother!.birthWeight ?? herdAvgBirth;
    double fBW = _selectedFather!.birthWeight ?? herdAvgBirth;
    double predictedBirthWeight = (mBW + fBW) / 2;

    double mWW = _selectedMother!.weaningWeight ?? herdAvgWeaning;
    double fWW = _selectedFather!.weaningWeight ?? herdAvgWeaning;
    double predictedWeaningWeight = (mWW + fWW) / 2;

    double predictedDEP = predictedWeaningWeight - herdAvgWeaning;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
              color: inbreedingAlert != null ? Colors.red : Colors.green,
              width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('PRONÓSTICO DE LA CRÍA',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        inbreedingAlert != null ? Colors.red : Colors.green)),
            const Divider(thickness: 2),
            const SizedBox(height: 10),
            if (inbreedingAlert != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(inbreedingAlert,
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 30),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'Cruza Segura: Baja probabilidad de consanguinidad.',
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            _buildStatRow('Peso al Nacer Estimado:',
                '${predictedBirthWeight.toStringAsFixed(1)} kg',
                isHighlight: true),
            const SizedBox(height: 10),
            _buildStatRow('Peso Destete Estimado:',
                '${predictedWeaningWeight.toStringAsFixed(1)} kg',
                isHighlight: true),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('DEP Proyectado:',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  '${predictedDEP >= 0 ? '+' : ''}${predictedDEP.toStringAsFixed(1)} kg vs Rancho',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: predictedDEP >= 0 ? Colors.green : Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // REFACTORIZADO: Evita el overflow usando "Expanded"
  Widget _buildStatRow(String label, String value, {bool isHighlight = false}) {
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
                  fontWeight:
                      isHighlight ? FontWeight.bold : FontWeight.normal)),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right, // Alinea el texto a la derecha
            style: TextStyle(
                color: isHighlight ? const Color(0xFFc99450) : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
