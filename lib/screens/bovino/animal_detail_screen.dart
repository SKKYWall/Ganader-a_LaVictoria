// lib/screens/animal_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Para la gráfica
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Firebase
import 'package:firebase_auth/firebase_auth.dart'; // Para obtener el UID del usuario
import 'package:manual_ganadero_flutter/models/animal.dart'; // ¡Importa tu modelo de Animal!
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:manual_ganadero_flutter/screens/bovino/edit_animal_screen.dart'; // Asegúrate de importar tu EditAnimalScreen
import 'package:manual_ganadero_flutter/screens/bovino/register_animal_screen.dart';
import 'package:manual_ganadero_flutter/models/animal_stat.dart';
import 'package:manual_ganadero_flutter/widgets/animal_exit_dialog.dart';
import 'package:manual_ganadero_flutter/core/withdrawal_utils.dart';
import 'package:manual_ganadero_flutter/core/reproductive_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/transaction.dart' as fin;
import 'package:manual_ganadero_flutter/core/finance_categories.dart';

class AnimalDetailScreen extends StatefulWidget {
  final String animalId; // Recibimos el ID del animal

  const AnimalDetailScreen({super.key, required this.animalId});

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  Animal? _animal;
  bool _isLoading = true;
  String? _currentRanchId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadAnimalData();
    _cleanExpiredVaccines();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAnimalData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // --- INICIO DE MODIFICACIÓN MULTI-RANCHO ---
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      String? currentRanchId =
          (userDoc.data() as Map<String, dynamic>?)?['currentRanchId'];

      if (currentRanchId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay rancho seleccionado.')),
        );
        setState(() => _isLoading = false);
        return;
      }
      _currentRanchId = currentRanchId;

      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ranches') // <-- NUEVO
          .doc(currentRanchId) // <-- NUEVO
          .collection('animals')
          .doc(widget.animalId)
          .snapshots()
          .listen((docSnapshot) {
        // --- FIN DE MODIFICACIÓN ---
        if (!mounted) return;
        if (docSnapshot.exists && docSnapshot.data() != null) {
          setState(() {
            _animal = Animal.fromFirestore(
                docSnapshot.data() as Map<String, dynamic>, docSnapshot.id);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Animal no encontrado.')),
          );
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      debugPrint('Error loading animal data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al cargar datos del animal: ${e.toString()}')),
      );
    }
  }

  // Dar de baja (vendido/muerto/error de captura) — flujo compartido con
  // bovino_screen.dart, ver lib/widgets/animal_exit_dialog.dart.
  Future<void> _showExitDialog() async {
    if (_animal == null) return;
    final changed = await showAnimalExitDialog(context, _animal!);
    if (changed && mounted) {
      Navigator.of(context).pop();
    }
  }

  // Helper para construir las filas de detalles con un estilo consistente
  Widget _buildDetailRow(String label, String? value) {
    String displayValue =
        (value == null || value.isEmpty || value == 'null') ? 'N/A' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF5e3a1c),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // Helper para formatear fechas de tipo DateTime
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime != null) {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
    return 'N/A';
  }

  // Helper para formatear pesos
  String _formatWeight(double? weight) {
    return weight != null ? '${weight.toStringAsFixed(1)} kg' : 'N/A';
  }

  // Fecha estimada de parto a partir de la fecha de preñez.
  DateTime? get _expectedCalvingDate {
    final p = _animal?.pregnancyDate;
    if (p == null) return null;
    return expectedCalvingDate(p);
  }

  // Fila de "Parto estimado" con días restantes y color según cercanía.
  Widget _buildCalvingRow(DateTime calving) {
    final now = DateTime.now();
    final daysLeft = calving.difference(now).inDays;

    String estado;
    Color color;
    if (daysLeft < 0) {
      estado = 'Parto esperado (atrasado ${-daysLeft} día(s))';
      color = Colors.red.shade700;
    } else if (daysLeft <= 14) {
      estado = 'Faltan $daysLeft día(s) — ¡prepara el parto!';
      color = Colors.orange.shade800;
    } else {
      estado = 'Faltan $daysLeft día(s)';
      color = const Color(0xFF5e3a1c);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cake, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(
                    text: 'Parto estimado: ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF5e3a1c)),
                  ),
                  TextSpan(
                    text: DateFormat('dd/MM/yyyy').format(calving),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  TextSpan(
                    text: '  ($estado)',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Banner rojo de período de retiro (food-safety). Solo se muestra si el
  // animal está dentro del período de retiro por medicamentos.
  Widget _buildWithdrawalBanner() {
    final wd = _animal?.withdrawalDate;
    if (wd == null) return const SizedBox.shrink();
    if (!isInWithdrawal(wd)) return const SizedBox.shrink();

    final days = daysUntilRelease(wd);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.red.shade700, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EN PERÍODO DE RETIRO',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                      fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'No apto para venta ni sacrificio. Faltan $days día(s) '
                  '(hasta el ${DateFormat('dd/MM/yyyy').format(wd)}).',
                  style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para títulos de sección (añadido para consistencia visual)
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 15.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5e3a1c),
        ),
      ),
    );
  }

  // Suma los ingresos/egresos de Finanzas ya ligados a este animal
  // (campo animalId en Transaction — ver add_edit_transaction_screen.dart
  // y AnimalLifecycleService) para mostrar cuánto ha costado o generado.
  Widget _buildAnimalCostCard() {
    final user = _auth.currentUser;
    if (user == null || _currentRanchId == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(_currentRanchId)
          .collection('transactions')
          .where('animalId', isEqualTo: widget.animalId)
          .snapshots(),
      builder: (context, snapshot) {
        double income = 0, expense = 0;
        int count = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final t = fin.Transaction.fromFirestore(
                doc.data() as Map<String, dynamic>, doc.id);
            if (t.type == 'income') {
              income += t.amount;
            } else {
              expense += t.amount;
            }
            count++;
          }
        }
        return Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: count == 0
                ? const Text(
                    'Sin movimientos de Finanzas ligados a este animal. '
                    'Puedes asociarlos al registrar o editar una transacción.',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                          'Ingresos ligados', formatCurrencyMXN(income)),
                      _buildDetailRow(
                          'Egresos ligados', formatCurrencyMXN(expense)),
                      _buildDetailRow('Balance neto',
                          formatCurrencyMXN(income - expense)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // Widget para la gráfica de peso
  Widget _buildWeightChart(List<AnimalStat> stats) {
    // Ordenar estadísticas por fecha para asegurar la correcta visualización del gráfico
    stats.sort((a, b) => a.date.compareTo(b.date));

    // Convertir AnimalStat a FlSpot para el gráfico
    List<FlSpot> spots = stats.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(),
          entry.value.value); // Usar index como X, valor como Y
    }).toList();

    // Obtener los rangos min/max para el gráfico
    double minX = 0;
    final double maxX = (stats.length - 1).toDouble();
    final double minY =
        (stats.map((e) => e.value).reduce((a, b) => a < b ? a : b) - 5)
            .clamp(0.0, double.infinity); // Un poco de margen, no menos de 0
    final double maxY =
        stats.map((e) => e.value).reduce((a, b) => a > b ? a : b) +
            5; // Un poco de margen

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial de Peso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c),
              ),
            ),
            const SizedBox(height: 15),
            AspectRatio(
              aspectRatio: 1.70,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    getDrawingVerticalLine: (value) => const FlLine(
                      color: Color(0xffececec),
                      strokeWidth: 1,
                    ),
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: Color(0xffececec),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          // Asegura que el índice esté dentro de los límites de la lista de estadísticas
                          if (value.toInt() >= 0 &&
                              value.toInt() < stats.length) {
                            return SideTitleWidget(
                              space: 8,
                              meta: meta,
                              child: Text(
                                  DateFormat('dd/MM')
                                      .format(stats[value.toInt()].date),
                                  style: const TextStyle(
                                      color: Color(0xff72719b), fontSize: 10)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (maxY - minY) / 4,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            space: 8,
                            meta: meta,
                            child: Text('${value.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                    color: Color(0xff72719b), fontSize: 10)),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border:
                        Border.all(color: const Color(0xff37434d), width: 1),
                  ),
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(
                        show: true,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor.withValues(alpha: 0.3),
                            Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.3),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// --- NUEVA FUNCIÓN PARA BORRAR TRATAMIENTOS MÉDICOS ---
  // Cambiamos Map<String, dynamic> por "dynamic" o tu clase "VaccineRecord"
  Future<void> _deleteVaccination(dynamic medRecord) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar Tratamiento'),
            content: const Text(
                '¿Estás seguro de que deseas eliminar este tratamiento médico del historial de este animal?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        // Como tu modelo lo convirtió a Objeto, lo volvemos a hacer Mapa
        // para que Firebase entienda qué borrar exactamente.
        Map<String, dynamic> recordToRemove;

        // Verificamos si tu modelo tiene una función toMap(), si no, lo construimos manual:
        try {
          recordToRemove = medRecord.toMap();
        } catch (e) {
          recordToRemove = {
            'name': medRecord.name,
            // Reconstruimos el Timestamp si la fecha es un DateTime
            'date': medRecord.date is DateTime
                ? Timestamp.fromDate(medRecord.date)
                : medRecord.date,
          };
        }

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .get();
        String? currentRanchId =
            (userDoc.data() as Map<String, dynamic>?)?['currentRanchId'];

        if (currentRanchId != null) {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('ranches') // <-- NUEVO
              .doc(currentRanchId) // <-- NUEVO
              .collection('animals')
              .doc(widget.animalId)
              .update({
            'vaccinations': FieldValue.arrayRemove([recordToRemove])
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Registro médico eliminado'),
              backgroundColor: Colors.red));
          _loadAnimalData(); // Recarga la pantalla
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  // --- NUEVA FUNCIÓN: LIMPIEZA AUTOMÁTICA DE VACUNAS VENCIDAS ---
  Future<void> _cleanExpiredVaccines() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      String? currentRanchId =
          (userDoc.data() as Map<String, dynamic>?)?['currentRanchId'];
      if (currentRanchId == null) return;

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ranches') // <-- NUEVO
          .doc(currentRanchId) // <-- NUEVO
          .collection('animals')
          .doc(widget.animalId)
          .get();

      if (!doc.exists) return;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<dynamic> rawVaccinations = data['vaccinations'] ?? [];
      List<dynamic> vaccinesToRemove = [];

      // 2. Buscamos cuáles vacunas ya pasaron su fecha de caducidad
      for (var vac in rawVaccinations) {
        if (vac is Map<String, dynamic> && vac.containsKey('expiresAt')) {
          DateTime expiresAt = (vac['expiresAt'] as Timestamp).toDate();

          // Si la fecha de caducidad ya es "antes" de la fecha actual, está vencida
          if (expiresAt.isBefore(DateTime.now())) {
            vaccinesToRemove.add(vac);
          }
        }
      }

      // 3. Si encontramos vacunas vencidas, las borramos automáticamente
      if (vaccinesToRemove.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('ranches') // <-- NUEVO
            .doc(currentRanchId) // <-- NUEVO
            .collection('animals')
            .doc(widget.animalId)
            .update({'vaccinations': FieldValue.arrayRemove(vaccinesToRemove)});

        // Volvemos a cargar los datos para que la pantalla se actualice y desaparezcan visualmente
        _loadAnimalData();
      }
    } catch (e) {
      debugPrint("Error limpiando vacunas vencidas: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFfbf6ec),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
          ),
        ),
      );
    }

    if (_animal == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFfbf6ec),
        appBar: AppBar(
          backgroundColor: const Color(0xFFfbf6ec),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          title: const Text('Detalle del Animal',
              style: TextStyle(color: Color(0xFF5e3a1c))),
        ),
        body: const Center(
          child: Text(
            'Animal no encontrado.',
            style: TextStyle(fontSize: 16, color: Color(0xFF5e3a1c)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          _animal!.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5e3a1c),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_animal!.sex == 'Hembra')
            IconButton(
              icon: const Icon(Icons.child_care, color: Colors.green),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RegisterAnimalScreen(
                      initialMotherEarTag: _animal!.earTagNumber,
                      initialBreed: _animal!.breed,
                      initialPurpose: _animal!.purpose,
                    ),
                  ),
                );
              },
              tooltip: 'Registrar cría de esta madre',
            ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFFc99450)),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditAnimalScreen(
                    animalId: _animal!.id,
                  ),
                ),
              );
              if (result == true) {
                // Si la edición fue exitosa, recargar los datos
                _loadAnimalData();
              }
            },
            tooltip: 'Editar Animal',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _showExitDialog,
            tooltip: 'Dar de baja',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de período de retiro (food-safety) — siempre arriba.
            _buildWithdrawalBanner(),

            // Sección de la imagen del animal
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.0),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.3),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: _animal!.profileImageUrl != null &&
                          _animal!.profileImageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_animal!.profileImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _animal!.profileImageUrl == null ||
                        _animal!.profileImageUrl!.isEmpty
                    ? Icon(Icons.photo_size_select_actual,
                        size: 100, color: Colors.grey[400])
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Información General
            _buildSectionTitle('Información General'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Nombre', _animal!.name),
                    _buildDetailRow('Raza', _animal!.breed),
                    _buildDetailRow('Sexo', _animal!.sex),
                    _buildDetailRow('Fecha de Nacimiento',
                        _formatDateTime(_animal!.birthDate)),
                    _buildDetailRow('Número de Arete', _animal!.earTagNumber),
                    _buildDetailRow('Número de Pierna', _animal!.legNumber),
                    _buildDetailRow(
                        'Número de Registro', _animal!.registrationNumber),
                    _buildDetailRow('Propósito', _animal!.purpose),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Pesos y Parentesco
            _buildSectionTitle('Pesos y Parentesco'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Peso al Nacimiento',
                        _formatWeight(_animal!.birthWeight)),
                    _buildDetailRow('Peso al Destete',
                        _formatWeight(_animal!.weaningWeight)),
                    _buildDetailRow('Arete del Padre', _animal!.father),
                    _buildDetailRow('Arete de la Madre', _animal!.mother),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Salud y Genética
            _buildSectionTitle('Salud y Genética'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Resistencia a Enfermedades',
                        _animal!.diseaseResistance),
                    _buildDetailRow(
                        'Información de Fertilidad', _animal!.fertilityInfo),
                    _buildDetailRow(
                        'Marcadores Genéticos', _animal!.geneticMarkers),
                    if (_animal!.withdrawalDate != null)
                      _buildDetailRow(
                        'Fin de retiro de medicamentos',
                        _formatDateTime(_animal!.withdrawalDate),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Vacunación (AÑADIDA)
            _buildSectionTitle('Vacunación'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _animal!.vaccinations != null &&
                        _animal!.vaccinations!.isNotEmpty
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _animal!.vaccinations!.length,
                        itemBuilder: (context, index) {
                          final vaccine = _animal!.vaccinations![index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.vaccines,
                                    color: Color(0xFFc99450), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: DefaultTextStyle.of(context).style,
                                      children: <TextSpan>[
                                        TextSpan(
                                          text: '${vaccine.name}: ',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF5e3a1c)),
                                        ),
                                        TextSpan(
                                          text: DateFormat('dd/MM/yyyy')
                                              .format(vaccine.date),
                                          style: const TextStyle(
                                              color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          'No hay vacunas registradas.',
                          style: TextStyle(
                              fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Sección de Costos y Ventas ligados a este animal específico
            // (requiere que las transacciones se liguen con animalId, ver
            // add_edit_transaction_screen.dart y AnimalLifecycleService).
            _buildSectionTitle('Costos y Ventas Ligados'),
            _buildAnimalCostCard(),
            const SizedBox(height: 20),

            // Sección de Información de Reproducción (Preñez) - Solo si es Hembra (AÑADIDA)
            if (_animal!.sex == 'Hembra')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Información de Reproducción'),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'Preñada',
                            _animal!.isPregnant != null
                                ? (_animal!.isPregnant! ? 'Sí' : 'No')
                                : 'No especificado',
                          ),
                          if (_animal!.isPregnant == true &&
                              _animal!.pregnancyDate != null) ...[
                            _buildDetailRow(
                              'Fecha de Preñez',
                              DateFormat('dd/MM/yyyy')
                                  .format(_animal!.pregnancyDate!),
                            ),
                            if (_expectedCalvingDate != null)
                              _buildCalvingRow(_expectedCalvingDate!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_animal!.reproductiveEvents != null &&
                      _animal!.reproductiveEvents!.isNotEmpty) ...[
                    _buildSectionTitle('Historial Reproductivo'),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _animal!.reproductiveEvents!.length,
                          itemBuilder: (context, index) {
                            final events = _animal!.reproductiveEvents!
                                .reversed
                                .toList();
                            final event = events[index];
                            final outcomeLabel = switch (event.outcome) {
                              'vivo' => 'Parto exitoso',
                              'muerto' => 'Diagnóstico negativo',
                              'aborto' => 'Aborto',
                              _ => 'Pendiente',
                            };
                            final outcomeColor = switch (event.outcome) {
                              'vivo' => Colors.green,
                              'muerto' => Colors.grey,
                              'aborto' => Colors.orange,
                              _ => Colors.pink,
                            };
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                      event.serviceType == 'Monta Natural'
                                          ? FontAwesomeIcons.cow
                                          : Icons.science,
                                      color: const Color(0xFFc99450),
                                      size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${event.serviceType}${event.sireEarTag != null ? ' — ${event.sireEarTag}' : ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF5e3a1c)),
                                        ),
                                        Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(event.serviceDate),
                                          style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: outcomeColor
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(6)),
                                    child: Text(outcomeLabel,
                                        style: TextStyle(
                                            color: outcomeColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),

            // Sección de Descripción (anteriormente 'Otros Datos')
            _buildSectionTitle('Descripción'), // Cambiado el título
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Descripción', _animal!.description),
                    // REMOVIDO: Campo de precio
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Gráfica de peso (si hay estadísticas)
            if (_animal!.stats.any((s) => s.label == 'Peso' || s.label.startsWith('Peso ')))
              _buildWeightChart(_animal!.stats
                  .where((s) => s.label == 'Peso' || s.label.startsWith('Peso '))
                  .toList()),
            const SizedBox(height: 20),

            // --- NUEVA SECCIÓN: SANIDAD E HISTORIAL MÉDICO ---
            _buildSectionTitle('Sanidad e Historial Médico'),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _animal!.vaccinations != null &&
                        _animal!.vaccinations!.isNotEmpty
                    ? Column(
                        children: _animal!.vaccinations!.map((med) {
                          String name = med.name;

                          // CORRECCIÓN: Como tu modelo ya lo convirtió a DateTime, lo usamos directo
                          DateTime date = med.date;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.teal.shade100)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(Icons.vaccines, color: Colors.teal),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              subtitle: Text(
                                  'Aplicado el: ${DateFormat('dd/MM/yyyy').format(date)}',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                onPressed: () => _deleteVaccination(med),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: Center(
                          child: Text(
                            'El animal no tiene historial médico registrado.',
                            style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
