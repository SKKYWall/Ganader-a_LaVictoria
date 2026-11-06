import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/screens/bovino/animal_detail_screen.dart';
import 'package:manual_ganadero_flutter/core/medication_catalog.dart';
import 'package:manual_ganadero_flutter/core/withdrawal_utils.dart';
import 'package:manual_ganadero_flutter/models/sanitary_plan.dart';

class SanidadScreen extends StatefulWidget {
  const SanidadScreen({super.key});

  @override
  State<SanidadScreen> createState() => _SanidadScreenState();
}

class _SanidadScreenState extends State<SanidadScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String? _currentRanchId;
  bool _isLoadingRanch = true;

  final TextEditingController _medNameController = TextEditingController();
  final TextEditingController _withdrawalDaysController =
      TextEditingController();

  // Variables para Recordatorio
  bool _scheduleReminder = false;
  final TextEditingController _monthsController = TextEditingController();
  bool _confirmNoWithdrawal = false;

  String _selectedType = 'Vacuna';
  final List<String> _medTypes = [
    'Vacuna',
    'Desparasitante',
    'Antibiótico',
    'Vitamina',
    'Tratamiento'
  ];

  String _filterPurpose = 'Todos';
  final List<String> _purposes = [
    'Todos',
    'Leche',
    'Carne',
    'Genética',
    'Engorda',
    'Reproductora'
  ];
  Set<String> _selectedAnimals = {};

  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentRanchId();
  }

  Future<void> _loadCurrentRanchId() async {
    if (_currentUser == null) return;
    try {
      final doc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (mounted) {
        setState(() {
          _currentRanchId = doc.data()?['currentRanchId'];
          _isLoadingRanch = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar rancho: $e");
      if (mounted) setState(() => _isLoadingRanch = false);
    }
  }

  Stream<QuerySnapshot> _getAllAnimals() {
    if (_currentUser == null) return const Stream.empty();
    return _firestore
        .collection('users') // <-- AGREGADO
        .doc(_currentUser!.uid) // <-- AGREGADO
        .collection('ranches')
        .doc(_currentRanchId)
        .collection('animals')
        .snapshots();
  }

  // --- NUEVA FUNCIÓN: DIÁLOGO DE CONFIRMACIÓN Y RECORDATORIO ---
  Future<void> _showConfirmationDialog() async {
    if (_medNameController.text.trim().isEmpty) {
      _showSnackBar('Ingresa el nombre del medicamento', Colors.red);
      return;
    }
    if (_selectedAnimals.isEmpty) {
      _showSnackBar('Selecciona al menos un animal', Colors.red);
      return;
    }

    // Reiniciamos las variables cada vez que se abre el diálogo
    _scheduleReminder = false;
    _monthsController.clear();
    _confirmNoWithdrawal = false;
    final int withdrawalDays =
        int.tryParse(_withdrawalDaysController.text.trim()) ?? 0;

    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) {
          return StatefulBuilder(builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Confirmar Tratamiento',
                  style: TextStyle(
                      color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Se aplicará $_selectedType: "${_medNameController.text.trim()}" a ${_selectedAnimals.length} animales.'),
                    if (withdrawalDays == 0) ...[
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                            'Confirmo que este tratamiento no requiere periodo de retiro para carne o leche',
                            style: TextStyle(
                                fontSize: 13, color: Colors.orange)),
                        value: _confirmNoWithdrawal,
                        activeColor: Colors.orange,
                        onChanged: (val) {
                          setStateDialog(
                              () => _confirmNoWithdrawal = val ?? false);
                        },
                      ),
                    ],
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 5),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                          'Auto-Eliminar en el futuro y programar recordatorio en calendario',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal)),
                      value: _scheduleReminder,
                      activeColor: Colors.teal,
                      onChanged: (val) {
                        setStateDialog(() => _scheduleReminder = val ?? false);
                      },
                    ),
                    if (_scheduleReminder)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: TextFormField(
                          controller: _monthsController,
                          maxLength: 4,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Meses para caducar (ej. 6)',
                            prefixIcon: const Icon(Icons.calendar_month,
                                color: Colors.teal, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    if (_scheduleReminder &&
                        _monthsController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Ingresa la cantidad de meses'),
                          backgroundColor: Colors.red));
                      return;
                    }
                    if (withdrawalDays == 0 && !_confirmNoWithdrawal) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text(
                              'Confirma que no hay periodo de retiro, o ingresa los días correspondientes'),
                          backgroundColor: Colors.red));
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Aplicar Ahora',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          });
        });

    if (confirm == true) {
      _applyMassTreatment();
    }
  }

  Future<void> _applyMassTreatment() async {
    setState(() => _isApplying = true);

    try {
      WriteBatch batch = _firestore.batch();

      // 1. Días de retiro (Cuarentena)
      int withdrawalDays = int.tryParse(_withdrawalDaysController.text) ?? 0;
      DateTime? releaseDate = withdrawalDays > 0
          ? DateTime.now().add(Duration(days: withdrawalDays))
          : null;

      // 2. Meses para eliminación automática y recordatorio
      DateTime? expirationDate;
      if (_scheduleReminder && _monthsController.text.isNotEmpty) {
        int months = int.tryParse(_monthsController.text) ?? 0;
        if (months > 0) {
          expirationDate = DateTime.now().add(Duration(days: months * 30));

          // ¡AQUÍ ESTÁ LA SOLUCIÓN AL ERROR DE FIREBASE!
          // Cambiamos "calendar" por "calendarEvents" para coincidir con tus Reglas de Firebase
          DocumentReference eventRef = _firestore
              .collection('users') // <-- AGREGADO
              .doc(_currentUser!.uid) // <-- AGREGADO
              .collection('ranches')
              .doc(_currentRanchId)
              .collection('calendarEvents')
              .doc();
          batch.set(eventRef, {
            'title': 'Re-aplicar: ${_medNameController.text.trim()}',
            'description':
                'Aplicar nuevamente. Se aplicó por última vez hace $months meses a ${_selectedAnimals.length} animales.',
            'date': Timestamp.fromDate(expirationDate),
            'category': 'Sanidad',
          });
        }
      }

      for (String animalId in _selectedAnimals) {
        DocumentReference animalRef = _firestore
            .collection('users') // <-- AGREGADO
            .doc(_currentUser!.uid) // <-- AGREGADO
            .collection('ranches')
            .doc(_currentRanchId)
            .collection('animals')
            .doc(animalId);

        // Armar el registro de la vacuna
        final medRecord = {
          'name': '$_selectedType: ${_medNameController.text.trim()}',
          'date': Timestamp.now(),
        };
        // Si hay fecha de eliminación, la adjuntamos ocultamente
        if (expirationDate != null) {
          medRecord['expiresAt'] = Timestamp.fromDate(expirationDate);
        }

        Map<String, dynamic> updateData = {
          'vaccinations': FieldValue.arrayUnion([medRecord]),
        };

        if (releaseDate != null) {
          // No sobrescribir una cuarentena más larga ya en curso (p. ej. un
          // desparasitante de 45 días vigente no debe acortarse a 6 días
          // porque se aplicó después una penicilina de acción corta).
          DateTime finalReleaseDate = releaseDate;
          final currentSnap = await animalRef.get();
          final currentWithdrawal =
              (currentSnap.data() as Map<String, dynamic>?)?['withdrawalDate'];
          if (currentWithdrawal is Timestamp) {
            final currentDate = currentWithdrawal.toDate();
            if (currentDate.isAfter(finalReleaseDate)) {
              finalReleaseDate = currentDate;
            }
          }
          updateData['withdrawalDate'] = Timestamp.fromDate(finalReleaseDate);
        }

        batch.update(animalRef, updateData);
      }

      await batch.commit();

      if (mounted) {
        _showSnackBar('¡Tratamiento aplicado correctamente!', Colors.green);
        setState(() {
          _selectedAnimals.clear();
          _medNameController.clear();
          _withdrawalDaysController.clear();
          _monthsController.clear();
          _scheduleReminder = false;
          _selectedType = 'Vacuna';
        });
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  // Chips de referencia para precargar los días de retiro sugeridos del
  // catálogo (editable, nunca autoridad — ver medication_catalog.dart).
  Widget _buildMedicationSuggestions() {
    final suggestions = medicationCatalog[_selectedType];
    if (suggestions == null || suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sugerencias de referencia (días en carne):',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: suggestions.map((ref) {
              return ActionChip(
                label: Text(
                    '${ref.name}: ${ref.suggestedWithdrawalDaysMeat}d',
                    style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.orange.shade50,
                onPressed: () {
                  setState(() {
                    _withdrawalDaysController.text =
                        ref.suggestedWithdrawalDaysMeat.toString();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ref.note),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 4)));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          const Text(medicationCatalogDisclaimer,
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRanch) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.teal)));
    }

    if (_currentRanchId == null) {
      return const Scaffold(
          body: Center(child: Text("Selecciona un rancho primero")));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          backgroundColor: const Color(0xFFfbf6ec),
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
              onPressed: () => Navigator.of(context).pop()),
          title: const Text('Manejo Sanitario',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5e3a1c))),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.vaccines), text: "Aplicación Masiva"),
              Tab(
                  icon: Icon(Icons.warning_amber_rounded),
                  text: "En Cuarentena (Retiro)"),
              Tab(icon: Icon(Icons.assignment), text: "Planes Sanitarios"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _getAllAnimals(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.teal));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text('No tienes animales registrados.',
                      style: TextStyle(color: Colors.grey)));
            }

            final allDocs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['status'] as String? ?? 'activo') == 'activo';
            }).toList();

            if (allDocs.isEmpty) {
              return const Center(
                  child: Text('No tienes animales registrados.',
                      style: TextStyle(color: Colors.grey)));
            }

            List<DocumentSnapshot> quarantinedDocs = [];
            List<DocumentSnapshot> availableDocs = [];

            for (var doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data.containsKey('withdrawalDate') &&
                  data['withdrawalDate'] != null) {
                DateTime releaseDate =
                    (data['withdrawalDate'] as Timestamp).toDate();
                if (isInWithdrawal(releaseDate)) {
                  quarantinedDocs.add(doc);
                } else {
                  availableDocs.add(doc);
                }
              } else {
                availableDocs.add(doc);
              }
            }

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF26A69A)]),
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.teal.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat(
                          'Total Hato', allDocs.length.toString()),
                      Container(width: 1, height: 40, color: Colors.white54),
                      _buildSummaryStat(
                          'Sanos / Libres', availableDocs.length.toString()),
                      Container(width: 1, height: 40, color: Colors.white54),
                      _buildSummaryStat(
                          'En Retiro', quarantinedDocs.length.toString(),
                          color: Colors.yellowAccent),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildMassApplicationTab(allDocs),
                      _buildQuarantineTab(quarantinedDocs),
                      _buildPlansTab(),
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

  Widget _buildMassApplicationTab(List<DocumentSnapshot> allDocs) {
    List<DocumentSnapshot> filteredDocs = allDocs.where((doc) {
      if (_filterPurpose == 'Todos') return true;
      final data = doc.data() as Map<String, dynamic>;
      return data['purpose'] == _filterPurpose;
    }).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5.0),
            children: [
              Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedType,
                        decoration: InputDecoration(
                            labelText: 'Tipo de Tratamiento',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10)),
                        items: _medTypes
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t,
                                    style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedType = val!),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _medNameController,
                        maxLength: 30,
                        decoration: InputDecoration(
                            labelText: 'Nombre / Marca del medicamento',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10)),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _withdrawalDaysController,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText:
                                'Días de Retiro (Carne/Leche) - Opcional',
                            prefixIcon: const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 20),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10)),
                      ),
                      _buildMedicationSuggestions(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterPurpose,
                          style: const TextStyle(
                              color: Colors.teal, fontWeight: FontWeight.bold),
                          icon:
                              const Icon(Icons.filter_list, color: Colors.teal),
                          items: _purposes
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (val) => setState(() {
                            _filterPurpose = val!;
                            _selectedAnimals.clear();
                          }),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        if (_selectedAnimals.length == filteredDocs.length) {
                          _selectedAnimals.clear();
                        } else {
                          _selectedAnimals =
                              filteredDocs.map((d) => d.id).toSet();
                        }
                      }),
                      icon: Icon(
                          _selectedAnimals.length == filteredDocs.length &&
                                  filteredDocs.isNotEmpty
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colors.teal),
                      label: const Text('Sel. Todos',
                          style: TextStyle(
                              color: Colors.teal, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              ...filteredDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                bool isSelected = _selectedAnimals.contains(doc.id);
                return Card(
                  color: isSelected ? Colors.teal.shade50 : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                          color: isSelected ? Colors.teal : Colors.transparent,
                          width: 2)),
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: CheckboxListTile(
                    activeColor: Colors.teal,
                    title: Text(data['name'] ?? 'Sin nombre',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Arete: ${data['earTagNumber']} | ${data['purpose']}'),
                    secondary: CircleAvatar(
                        backgroundColor: Colors.teal.withValues(alpha: 0.1),
                        child: const Icon(FontAwesomeIcons.cow,
                            color: Colors.teal, size: 20)),
                    value: isSelected,
                    onChanged: (checked) => setState(() {
                      checked == true
                          ? _selectedAnimals.add(doc.id)
                          : _selectedAnimals.remove(doc.id);
                    }),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
        if (_selectedAnimals.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5))
            ]),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: _isApplying
                        ? const SizedBox()
                        : const Icon(Icons.vaccines, color: Colors.white),
                    label: _isApplying
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text('Aplicar a ${_selectedAnimals.length} animales',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                    onPressed: _isApplying ? null : _showConfirmationDialog,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.assignment, size: 18),
                    label: Text(
                        'Asignar Plan Sanitario a ${_selectedAnimals.length} animales'),
                    onPressed: _isApplying ? null : _showAssignPlanDialog,
                  ),
                ),
              ],
            ),
          )
      ],
    );
  }

  Widget _buildQuarantineTab(List<DocumentSnapshot> quarantinedDocs) {
    if (quarantinedDocs.isEmpty) {
      return const Center(
          child: Text('¡Excelente! No hay animales en periodo de retiro.',
              style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: quarantinedDocs.length,
      itemBuilder: (context, index) {
        final doc = quarantinedDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        DateTime releaseDate = (data['withdrawalDate'] as Timestamp).toDate();
        int daysLeft = daysUntilRelease(releaseDate);

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          color: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
              side: const BorderSide(color: Colors.redAccent, width: 1.5)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(15.0),
            leading: CircleAvatar(
                backgroundColor: Colors.red.shade50,
                radius: 25,
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 28)),
            title: Text(data['name'] ?? 'Sin nombre',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Arete: ${data['earTagNumber']}',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(5)),
                  child: Text('Faltan $daysLeft días para consumo',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AnimalDetailScreen(animalId: doc.id))),
          ),
        );
      },
    );
  }

  // ─── Planes sanitarios preconfigurados ─────────────────────────────────
  CollectionReference get _plansRef => _firestore
      .collection('users')
      .doc(_currentUser!.uid)
      .collection('ranches')
      .doc(_currentRanchId)
      .collection('sanitaryPlans');

  Widget _buildPlansTab() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _plansRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.teal));
            }
            final plans = (snapshot.data?.docs ?? [])
                .map((d) => SanitaryPlan.fromFirestore(
                    d.data() as Map<String, dynamic>, d.id))
                .toList();
            if (plans.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                      'No tienes planes sanitarios. Crea uno para programar '
                      'de un jalón los recordatorios de vacunación/desparasitación '
                      'de una categoría completa de animales.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    leading: const Icon(Icons.assignment, color: Colors.teal),
                    title: Text(plan.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${plan.steps.length} paso(s)'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      tooltip: 'Eliminar plan',
                      onPressed: () => _plansRef.doc(plan.id).delete(),
                    ),
                    children: plan.steps
                        .map((s) => ListTile(
                              dense: true,
                              leading:
                                  const Icon(Icons.circle, size: 8),
                              title: Text('${s.type}: ${s.label}'),
                              subtitle: Text('Día +${s.offsetDays}'
                                  '${s.suggestedWithdrawalDays != null ? ' · Retiro sugerido: ${s.suggestedWithdrawalDays}d' : ''}'),
                            ))
                        .toList(),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            backgroundColor: Colors.teal,
            icon: const Icon(Icons.add),
            label: const Text('Crear Plan'),
            onPressed: _showCreatePlanDialog,
          ),
        ),
      ],
    );
  }

  Future<void> _showCreatePlanDialog() async {
    final nameController = TextEditingController();
    final List<Map<String, dynamic>> steps = [];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          final labelController = TextEditingController();
          final offsetController = TextEditingController();
          final withdrawalController = TextEditingController();
          String stepType = 'Vacuna';

          return AlertDialog(
            backgroundColor: const Color(0xFFfbf6ec),
            title: const Text('Crear Plan Sanitario',
                style: TextStyle(
                    color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    maxLength: 60,
                    decoration: const InputDecoration(
                        labelText: 'Nombre del plan (ej. "Becerros 0-6 meses")'),
                  ),
                  const Divider(),
                  if (steps.isNotEmpty)
                    ...steps.asMap().entries.map((e) => ListTile(
                          dense: true,
                          title: Text('${e.value['type']}: ${e.value['label']}'),
                          subtitle: Text('Día +${e.value['offsetDays']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setStateDialog(() => steps.removeAt(e.key)),
                          ),
                        )),
                  const SizedBox(height: 8),
                  const Text('Agregar paso:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  DropdownButtonFormField<String>(
                    initialValue: stepType,
                    isExpanded: true,
                    items: _medTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) => setStateDialog(() => stepType = val!),
                  ),
                  TextFormField(
                    controller: labelController,
                    maxLength: 40,
                    decoration:
                        const InputDecoration(labelText: 'Nombre / producto'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: offsetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Día (desde asignación)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: withdrawalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Retiro sugerido (días)'),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar paso'),
                      onPressed: () {
                        if (labelController.text.trim().isEmpty ||
                            offsetController.text.trim().isEmpty) {
                          return;
                        }
                        setStateDialog(() {
                          steps.add({
                            'type': stepType,
                            'label': labelController.text.trim(),
                            'offsetDays':
                                int.tryParse(offsetController.text.trim()) ?? 0,
                            'suggestedWithdrawalDays':
                                int.tryParse(withdrawalController.text.trim()),
                          });
                          labelController.clear();
                          offsetController.clear();
                          withdrawalController.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  if (nameController.text.trim().isEmpty || steps.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content:
                            Text('Ingresa un nombre y al menos un paso'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  final plan = SanitaryPlan(
                    id: '',
                    name: nameController.text.trim(),
                    steps: steps
                        .map((s) => SanitaryPlanStep(
                              type: s['type'] as String,
                              label: s['label'] as String,
                              offsetDays: s['offsetDays'] as int,
                              suggestedWithdrawalDays:
                                  s['suggestedWithdrawalDays'] as int?,
                            ))
                        .toList(),
                  );
                  await _plansRef.add(plan.toFirestore());
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child:
                    const Text('Guardar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  // Asignar un plan NO aplica el tratamiento directamente — programa un
  // evento de calendario por cada paso × animal seleccionado, fechado
  // hoy + offsetDays del paso, reutilizando el sistema de
  // calendario/notificaciones que ya existe. El usuario confirma y aplica
  // el tratamiento real (vía "Aplicación Masiva") cuando llegue la fecha.
  Future<void> _showAssignPlanDialog() async {
    final snap = await _plansRef.get();
    final plans = snap.docs
        .map((d) =>
            SanitaryPlan.fromFirestore(d.data() as Map<String, dynamic>, d.id))
        .toList();

    if (plans.isEmpty) {
      _showSnackBar('No tienes planes sanitarios creados todavía', Colors.red);
      return;
    }
    if (!mounted) return;

    final selectedPlan = await showDialog<SanitaryPlan>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Elige un plan sanitario'),
        children: plans
            .map((p) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, p),
                  child: Text('${p.name} (${p.steps.length} pasos)'),
                ))
            .toList(),
      ),
    );

    if (selectedPlan == null) return;

    try {
      final today = DateTime.now();
      final selectedIds = _selectedAnimals.toList();
      final animalsSnap = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('ranches')
          .doc(_currentRanchId)
          .collection('animals')
          .get();
      final namesById = {
        for (final d in animalsSnap.docs)
          d.id: (d.data())['name'] as String? ?? 'Animal'
      };

      WriteBatch batch = _firestore.batch();
      for (final animalId in selectedIds) {
        final animalName = namesById[animalId] ?? 'Animal';
        for (final step in selectedPlan.steps) {
          final eventRef = _firestore
              .collection('users')
              .doc(_currentUser!.uid)
              .collection('ranches')
              .doc(_currentRanchId)
              .collection('calendarEvents')
              .doc();
          batch.set(eventRef, {
            'title': '${step.type}: ${step.label} — $animalName',
            'description': 'Paso del plan "${selectedPlan.name}"'
                '${step.suggestedWithdrawalDays != null ? ' · Retiro sugerido: ${step.suggestedWithdrawalDays} días' : ''}',
            'date': Timestamp.fromDate(
                today.add(Duration(days: step.offsetDays))),
            'category': 'Sanidad',
            'animalId': animalId,
          });
        }
      }
      await batch.commit();

      if (mounted) {
        setState(() => _selectedAnimals.clear());
        _showSnackBar(
            'Plan "${selectedPlan.name}" asignado — recordatorios programados en el calendario.',
            Colors.teal);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', Colors.red);
    }
  }

  Widget _buildSummaryStat(String label, String value,
      {Color color = Colors.white}) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
