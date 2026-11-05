import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:manual_ganadero_flutter/screens/bovino/register_animal_screen.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/services/notification_service.dart';
import 'package:manual_ganadero_flutter/core/reproductive_utils.dart';
import 'package:manual_ganadero_flutter/widgets/animal_parent_picker.dart';

class ReproductoraScreen extends StatefulWidget {
  const ReproductoraScreen({super.key});

  @override
  State<ReproductoraScreen> createState() => _ReproductoraScreenState();
}

class _ReproductoraScreenState extends State<ReproductoraScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _currentRanchId;

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
        });
      }
    } catch (e) {
      debugPrint("Error cargando rancho: $e");
    }
  }

  // Obtenemos TODAS las hembras para poder filtrar localmente las preñadas y las reproductoras
  Stream<QuerySnapshot> _getHembras() {
    if (_currentUser == null || _currentRanchId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('ranches') // Nombre exacto de tu regla: 'ranches'
        .doc(_currentRanchId)
        .collection('animals')
        .where('sex', isEqualTo: 'Hembra')
        .snapshots();
  }

  // --- MÉTODOS DE DIÁLOGO ---

  // Registrar un servicio reproductivo (monta natural o inseminación
  // artificial), con el semental usado cuando se conoce. Guarda el evento
  // en el historial del animal (reproductiveEvents) y, como antes, marca
  // isPregnant/pregnancyDate y agenda el recordatorio de parto.
  Future<void> _showServiceDialog(Animal animal) async {
    String serviceType = 'Monta Natural';
    DateTime selectedDate = DateTime.now();
    String? sireValue;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFFfbf6ec),
            title: Text('Registrar Servicio: ${animal.name}',
                style: const TextStyle(
                    color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioGroup<String>(
                    groupValue: serviceType,
                    onChanged: (val) =>
                        setStateDialog(() => serviceType = val!),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Monta Natural'),
                          value: 'Monta Natural',
                          activeColor: Colors.pink,
                        ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Inseminación Artificial'),
                          value: 'Inseminación Artificial',
                          activeColor: Colors.pink,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimalParentPicker(
                    label: serviceType == 'Monta Natural'
                        ? 'Semental'
                        : 'Semental / Pajilla usada',
                    sexFilter: 'Macho',
                    currentRanchId: _currentRanchId,
                    excludeAnimalId: animal.id,
                    onChanged: (val) => sireValue = val,
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        helpText: 'FECHA DEL SERVICIO',
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
                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Colors.pink, size: 18),
                          const SizedBox(width: 10),
                          Text(
                              'Fecha del servicio: ${DateFormat('dd/MM/yyyy').format(selectedDate)}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );

    if (confirmed != true) return;

    try {
      final event = ReproductiveEvent(
        serviceType: serviceType,
        sireEarTag: sireValue,
        serviceDate: selectedDate,
      );
      final estimatedBirth = expectedCalvingDate(selectedDate);

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
        'reproductiveEvents': FieldValue.arrayUnion([event.toMap()]),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Servicio registrado y preñez agendada!'),
            backgroundColor: Colors.pink));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // Diagnóstico negativo o pérdida (aborto/muerte) — cierra el servicio
  // reproductivo abierto más reciente sin pasar por el registro de un
  // becerro, y limpia el estado de preñez.
  Future<void> _showNegativeOutcomeDialog(Animal animal) async {
    final outcome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFfbf6ec),
        title: Text('${animal.name}: diagnóstico negativo o pérdida',
            style: const TextStyle(
                color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
        content: const Text(
            'Esto marca a la vaca como vacía nuevamente y cierra el servicio reproductivo registrado. ¿Cuál fue el resultado?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'aborto'),
            child: const Text('Aborto',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600),
            onPressed: () => Navigator.pop(ctx, 'diagnostico_negativo'),
            child: const Text('Diagnóstico negativo',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (outcome == null) return;

    try {
      WriteBatch batch = _firestore.batch();
      DocumentReference animalRef = _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('ranches')
          .doc(_currentRanchId)
          .collection('animals')
          .doc(animal.id);

      final updateData = <String, dynamic>{
        'isPregnant': false,
        'pregnancyDate': FieldValue.delete(),
      };

      final events = animal.reproductiveEvents;
      if (events != null && events.isNotEmpty) {
        final openIndex =
            events.lastIndexWhere((e) => e.isOpen);
        if (openIndex != -1) {
          final closed = events[openIndex].copyWith(
            outcome: outcome == 'aborto' ? 'aborto' : 'muerto',
            outcomeDate: DateTime.now(),
          );
          final newEvents = List<ReproductiveEvent>.from(events);
          newEvents[openIndex] = closed;
          updateData['reproductiveEvents'] =
              newEvents.map((e) => e.toMap()).toList();
        }
      }

      batch.update(animalRef, updateData);

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
      await NotificationService().cancelNotification(animal.id.hashCode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Registro actualizado.'),
            backgroundColor: Colors.grey));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _showCalvingDialog(Animal animal) async {
    final screenContext = context;
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

                  final updateData = <String, dynamic>{
                    'isPregnant': false,
                    'pregnancyDate': FieldValue.delete(),
                  };

                  // Cierra el servicio reproductivo abierto más reciente
                  // como "vivo" para que el historial quede completo.
                  String? sireEarTag;
                  final events = animal.reproductiveEvents;
                  if (events != null && events.isNotEmpty) {
                    final openIndex = events.lastIndexWhere((e) => e.isOpen);
                    if (openIndex != -1) {
                      sireEarTag = events[openIndex].sireEarTag;
                      final closed = events[openIndex].copyWith(
                        outcome: 'vivo',
                        outcomeDate: DateTime.now(),
                      );
                      final newEvents =
                          List<ReproductiveEvent>.from(events);
                      newEvents[openIndex] = closed;
                      updateData['reproductiveEvents'] =
                          newEvents.map((e) => e.toMap()).toList();
                    }
                  }

                  batch.update(animalRef, updateData);

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

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('¡Parto registrado! Registra a la cría.'),
                        backgroundColor: Colors.green));
                  }

                  if (screenContext.mounted) {
                    Navigator.of(screenContext).push(
                      MaterialPageRoute(
                        builder: (_) => RegisterAnimalScreen(
                          initialMotherEarTag: animal.earTagNumber,
                          initialFatherEarTag: sireEarTag,
                          initialBreed: animal.breed,
                          initialPurpose: animal.purpose,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error: $e");
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6b4226)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text('No tienes hembras registradas.',
                      style: TextStyle(color: Colors.grey)));
            }

            // Obtenemos todas las hembras activas
            final allHembras = snapshot.data!.docs
                .map((d) => Animal.fromFirestore(
                    d.data() as Map<String, dynamic>, d.id))
                .where((a) => a.status == 'activo')
                .toList();

            if (allHembras.isEmpty) {
              return const Center(
                  child: Text('No tienes hembras registradas.',
                      style: TextStyle(color: Colors.grey)));
            }

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
              backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
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
              tooltip: 'Registrar Servicio Reproductivo',
              onPressed: () => _showServiceDialog(animal),
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
          DateTime estimatedBirth = expectedCalvingDate(animal.pregnancyDate!);
          int daysPregnant =
              DateTime.now().difference(animal.pregnancyDate!).inDays;
          int daysLeft = estimatedBirth.difference(DateTime.now()).inDays;
          progress = (daysPregnant / kGestationDays).clamp(0.0, 1.0);
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
                      backgroundColor: Colors.pink.withValues(alpha: 0.1),
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
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.child_care,
                              color: Colors.green, size: 32),
                          tooltip: 'Registrar Parto',
                          onPressed: () => _showCalvingDialog(animal),
                        ),
                        IconButton(
                          icon: const Icon(Icons.heart_broken,
                              color: Colors.grey, size: 20),
                          tooltip: 'Diagnóstico negativo / pérdida',
                          onPressed: () => _showNegativeOutcomeDialog(animal),
                        ),
                      ],
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
