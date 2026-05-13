import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/services/notification_service.dart';

class ReproductoraScreen extends StatefulWidget {
  const ReproductoraScreen({super.key});

  @override
  State<ReproductoraScreen> createState() => _ReproductoraScreenState();
}

class _ReproductoraScreenState extends State<ReproductoraScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _currentRanchId;
  bool _isLoadingRanch = true;

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
      if (mounted) {
        setState(() {
          _currentRanchId = userDoc.data()?['currentRanchId'];
          _isLoadingRanch = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando rancho: $e");
      if (mounted) setState(() => _isLoadingRanch = false);
    }
  }

  // Obtenemos TODAS las hembras para poder filtrar localmente las preñadas y las reproductoras
  Stream<QuerySnapshot> _getHembras() {
    if (_currentUser == null || _currentRanchId == null)
      return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('ranches') // Nombre exacto de tu regla: 'ranches'
        .doc(_currentRanchId)
        .collection('animals')
        .where('sex', isEqualTo: 'Hembra')
        .snapshots();
  }

  // --- MÉTODOS DE DIÁLOGO (Mismos de antes, pero reutilizables) ---
  Future<void> _showInseminationDialog(Animal animal) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'SELECCIONA FECHA DE INSEMINACIÓN',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
                primary: Colors.pink,
                onPrimary: Colors.white,
                onSurface: Color(0xFF5e3a1c)),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      try {
        DateTime estimatedBirth = selectedDate.add(const Duration(days: 283));
        WriteBatch batch = _firestore.batch();
        DocumentReference animalRef = _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('ranches')
            .doc(_currentRanchId)
            .collection('animals')
            .doc(animal.id);

        batch.update(animalRef, {
          'isPregnant': true,
          'pregnancyDate': Timestamp.fromDate(selectedDate),
        });

        DocumentReference eventRef = _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('ranches')
            .doc(_currentRanchId)
            .collection('calendarEvents')
            .doc();
        batch.set(eventRef, {
          'title': 'Parto esperado: ${animal.name}',
          'description':
              'Fecha estimada de parto (Arete: ${animal.earTagNumber})',
          'date': Timestamp.fromDate(estimatedBirth),
          'category': 'Parto',
          'animalId': animal.id,
        });

        await batch.commit();
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(_currentUser!.uid).get();
        bool notificationsEnabled = (userDoc.data()
                as Map<String, dynamic>?)?['notificationsEnabled'] ??
            true;

        if (notificationsEnabled) {
          // La alerta sonará 7 días antes del parto estimado
          DateTime alertDate = estimatedBirth.subtract(const Duration(days: 7));

          if (alertDate.isAfter(DateTime.now())) {
            await NotificationService().scheduleNotification(
              id: animal.id.hashCode,
              title: '¡Parto Cercano! 🐄',
              body:
                  'La vaca ${animal.name} está a aprox. una semana de su fecha de parto.',
              scheduledDate: alertDate,
            );
          }
        }
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('¡Preñez agendada!'),
              backgroundColor: Colors.pink));
      } catch (e) {
        print("Error: $e");
      }
    }
  }

  Future<void> _showCalvingDialog(Animal animal) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFfbf6ec),
          title: Row(
            children: [
              const Icon(Icons.child_care, color: Colors.green, size: 35),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('¿Registrar parto de ${animal.name}?',
                      style: const TextStyle(
                          color: Color(0xFF5e3a1c),
                          fontWeight: FontWeight.bold))),
            ],
          ),
          content: const Text(
              'Al confirmar, la vaca pasará a "Vacía" y eliminaremos el evento del calendario.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  WriteBatch batch = _firestore.batch();
                  DocumentReference animalRef = _firestore
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .collection('ranches')
                      .doc(_currentRanchId)
                      .collection('animals')
                      .doc(animal.id);

                  batch.update(animalRef, {
                    'isPregnant': false,
                    'pregnancyDate': FieldValue.delete(),
                  });

                  QuerySnapshot eventSnapshot = await _firestore
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .collection('ranches')
                      .doc(_currentRanchId)
                      .collection('calendarEvents')
                      .where('animalId', isEqualTo: animal.id)
                      .where('category', isEqualTo: 'Parto')
                      .get();

                  for (var doc in eventSnapshot.docs) {
                    batch.delete(doc.reference);
                  }
                  await batch.commit();

                  await NotificationService()
                      .cancelNotification(animal.id.hashCode);

                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('¡Parto registrado!'),
                        backgroundColor: Colors.green));
                } catch (e) {
                  print("Error: $e");
                }
              },
              child: const Text('Confirmar Parto',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Implementamos un DefaultTabController para las 2 pestañas
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
          title: const Text('Vientres y Gestación',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5e3a1c))),
          centerTitle: true,
          // LAS PESTAÑAS
          bottom: const TabBar(
            labelColor: Colors.pink,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.pink,
            tabs: [
              Tab(icon: Icon(FontAwesomeIcons.venus), text: "Vientres Libres"),
              Tab(icon: Icon(Icons.pregnant_woman), text: "En Gestación"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _getHembras(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6b4226)));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return const Center(
                  child: Text('No tienes hembras registradas.',
                      style: TextStyle(color: Colors.grey)));

            // Obtenemos todas las hembras
            final allHembras = snapshot.data!.docs
                .map((d) => Animal.fromFirestore(
                    d.data() as Map<String, dynamic>, d.id))
                .toList();

            // Filtramos para la pestaña 1 (Vientres Libres): No están preñadas Y su propósito es Reproductora
            final vacias = allHembras
                .where((a) =>
                    (a.isPregnant == false || a.isPregnant == null) &&
                    a.purpose == 'Reproductora')
                .toList();

            // Filtramos para la pestaña 2 (Gestantes): Están preñadas (Sin importar si son de Leche, Carne o Reproductora)
            final prenadas =
                allHembras.where((a) => a.isPregnant == true).toList();

            return TabBarView(
              children: [
                // === VISTA 1: VIENTRES LIBRES (VACÍAS) ===
                _buildVaciasList(vacias),

                // === VISTA 2: GESTANTES (PREÑADAS) ===
                _buildPrenadasList(prenadas),
              ],
            );
          },
        ),
      ),
    );
  }

  // WIDGET PARA LA PESTAÑA DE VACÍAS
  Widget _buildVaciasList(List<Animal> vacias) {
    if (vacias.isEmpty) {
      return const Center(
          child: Text('No tienes vientres libres.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: vacias.length,
      itemBuilder: (context, index) {
        final animal = vacias[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 15.0),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(15.0),
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey.withOpacity(0.1),
              radius: 30,
              child: const Icon(FontAwesomeIcons.venus,
                  color: Colors.blueGrey, size: 25),
            ),
            title: Text(animal.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF5e3a1c))),
            subtitle:
                Text('Arete: ${animal.earTagNumber}\nEstado: Vacía / Abierta'),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.pink, size: 35),
              tooltip: 'Registrar Inseminación',
              onPressed: () => _showInseminationDialog(animal),
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

  // WIDGET PARA LA PESTAÑA DE PREÑADAS
  Widget _buildPrenadasList(List<Animal> prenadas) {
    if (prenadas.isEmpty) {
      return const Center(
          child: Text('No tienes animales en gestación.',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: prenadas.length,
      itemBuilder: (context, index) {
        final animal = prenadas[index];

        double progress = 0.0;
        String daysText = '';
        String statusText = 'Parto Desconocido';

        if (animal.pregnancyDate != null) {
          DateTime estimatedBirth =
              animal.pregnancyDate!.add(const Duration(days: 283));
          int daysPregnant =
              DateTime.now().difference(animal.pregnancyDate!).inDays;
          int daysLeft = estimatedBirth.difference(DateTime.now()).inDays;
          progress = (daysPregnant / 283).clamp(0.0, 1.0);
          statusText =
              'Parto: ${DateFormat('dd/MM/yy').format(estimatedBirth)}';
          daysText = daysLeft > 0 ? 'Faltan $daysLeft días' : '¡Posible parto!';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 15.0),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.pink.withOpacity(0.1),
                      radius: 30,
                      child: const Icon(Icons.pregnant_woman,
                          color: Colors.pink, size: 25),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(animal.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF5e3a1c))),
                          const SizedBox(height: 5),
                          Text(
                              'Arete: ${animal.earTagNumber} | Propósito: ${animal.purpose}',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.child_care,
                          color: Colors.green, size: 35),
                      tooltip: 'Registrar Parto',
                      onPressed: () => _showCalvingDialog(animal),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(statusText,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                    Text(daysText,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: progress >= 0.9 ? Colors.red : Colors.pink)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.pink.shade50,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 0.9 ? Colors.red : Colors.pink),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
