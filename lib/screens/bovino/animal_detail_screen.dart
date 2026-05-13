// lib/screens/animal_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Para la gráfica
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Firebase
import 'package:firebase_auth/firebase_auth.dart'; // Para obtener el UID del usuario
import 'package:manual_ganadero_flutter/models/animal.dart'; // ¡Importa tu modelo de Animal!
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:manual_ganadero_flutter/screens/bovino/edit_animal_screen.dart'; // Asegúrate de importar tu EditAnimalScreen
import 'package:firebase_storage/firebase_storage.dart'; // Importar para Firebase Storage para eliminar imagen
import 'package:manual_ganadero_flutter/models/animal_stat.dart';

class AnimalDetailScreen extends StatefulWidget {
  final String animalId; // Recibimos el ID del animal

  const AnimalDetailScreen({super.key, required this.animalId});

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  Animal? _animal;
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage =
      FirebaseStorage.instance; // Instancia de Firebase Storage

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
      print('Error loading animal data: $e');
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

  Future<void> _confirmDeleteAnimal() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado.')),
      );
      return;
    }

    // --- LÓGICA: Verificar si el animal está publicado en el Marketplace (Colección Global) ---
    String? marketplaceListingId;
    try {
      final marketplaceQuery = await _firestore
          .collection('marketplace_listings')
          .where('ownerId', isEqualTo: user.uid)
          .where('originalAnimalId', isEqualTo: widget.animalId)
          .limit(1)
          .get();

      if (marketplaceQuery.docs.isNotEmpty) {
        marketplaceListingId = marketplaceQuery.docs.first.id;
      }
    } catch (e) {
      print('Error al verificar publicación en Marketplace: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al verificar publicación: ${e.toString()}')),
      );
      return; // Salir si hay un error al verificar
    }

    String confirmationMessage =
        '¿Estás seguro de que quieres eliminar este animal? Esta acción no se puede deshacer.';
    if (marketplaceListingId != null) {
      confirmationMessage +=
          '\n\n¡Advertencia! Este animal también está publicado en el Marketplace y su publicación será eliminada.';
    }

    // Mostrar un diálogo de confirmación
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Animal',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          content: Text(
            confirmationMessage,
            style: const TextStyle(color: Colors.black87),
          ),
          backgroundColor: const Color(0xFFfbf6ec),
          surfaceTintColor: const Color(0xFFfbf6ec),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // No confirmar
              },
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF6b4226))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(true); // Confirmar
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Botón de confirmación en rojo
              ),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Antes de eliminar el documento del animal, eliminar su imagen de perfil si existe
        if (_animal?.profileImageUrl != null) {
          try {
            final ref = _storage.refFromURL(_animal!.profileImageUrl!);
            await ref.delete();
            print('Imagen de perfil eliminada de Storage.');
          } catch (e) {
            print(
                'Advertencia: No se pudo eliminar la imagen de perfil de Storage: ${e.toString()}');
            // No lanzar el error, solo advertir, para que el documento en Firestore se elimine.
          }
        }

        // --- LÓGICA: Eliminar la publicación del Marketplace si existe (Colección Global) ---
        if (marketplaceListingId != null) {
          try {
            await _firestore
                .collection('marketplace_listings')
                .doc(marketplaceListingId)
                .delete();
            print('Publicación de Marketplace eliminada.');
          } catch (e) {
            print(
                'Advertencia: No se pudo eliminar la publicación del Marketplace: ${e.toString()}');
            // No lanzar el error, solo advertir
          }
        }

        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        String? currentRanchId =
            (userDoc.data() as Map<String, dynamic>?)?['currentRanchId'];

        if (currentRanchId != null) {
          // Eliminar el documento del animal
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('ranches') // <-- NUEVO
              .doc(currentRanchId) // <-- NUEVO
              .collection('animals')
              .doc(widget.animalId)
              .delete();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Animal eliminado y su publicación de Marketplace (si existía) también.')), // Mensaje más claro
        );
        Navigator.of(context).pop(); // Volver a la pantalla anterior
      } catch (e) {
        print('Error al eliminar animal o publicación: ${e.toString()}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: ${e.toString()}')),
        );
      }
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
                            Theme.of(context).primaryColor.withOpacity(0.3),
                            Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.3),
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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red));
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
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _confirmDeleteAnimal,
            tooltip: 'Eliminar Animal',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      color: Colors.grey.withOpacity(0.3),
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
                              _animal!.pregnancyDate != null)
                            _buildDetailRow(
                              'Fecha de Preñez',
                              DateFormat('dd/MM/yyyy')
                                  .format(_animal!.pregnancyDate!),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
            if (_animal!.stats.isNotEmpty) _buildWeightChart(_animal!.stats),
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
                          String name = med.name ?? 'Tratamiento';

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
