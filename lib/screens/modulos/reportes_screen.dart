import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Modelos
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/models/transaction.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  bool _isGenerating = false;
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
      if (userDoc.exists && mounted) {
        setState(() {
          // Leer de forma segura
          final data = userDoc.data() as Map<String, dynamic>?;
          _currentRanchId = data?['currentRanchId'];
          _isLoadingRanch = false;
        });
      }
    } catch (e) {
      print('Error al cargar rancho: $e');
      if (mounted) setState(() => _isLoadingRanch = false);
    }
  }

  // Helper para obtener la colección de animales del rancho correcto
  CollectionReference get _animalsRef {
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('ranches')
        .doc(_currentRanchId)
        .collection('animals');
  }

  // ==========================================
  // FUNCIÓN MAESTRA DE EXPORTACIÓN (PDF / EXCEL)
  // ==========================================
  Future<void> _exportData({
    required String title,
    required List<String> headers,
    required List<List<dynamic>> data,
    required bool asPdf,
  }) async {
    try {
      if (asPdf) {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat:
                PdfPageFormat.a4.landscape, // Horizontal para más columnas
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildPdfHeader(title),
                  pw.SizedBox(height: 20),
                  pw.TableHelper.fromTextArray(
                    headers: headers,
                    data: data,
                    headerStyle: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
                ],
              );
            },
          ),
        );
        await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdf.save());
      } else {
        // EXPORTACIÓN A EXCEL (CSV con UTF-8 BOM para reconocer acentos)
        String csvContent = "\uFEFF";
        csvContent += "${headers.join(",")}\n";

        for (var row in data) {
          // Limpiar datos para evitar que comas internas rompan el Excel
          String rowString = row.map((e) {
            String cell = e?.toString().replaceAll('"', '""') ?? '';
            return '"$cell"';
          }).join(",");
          csvContent += "$rowString\n";
        }

        final directory = await getTemporaryDirectory();
        final String fileName =
            '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
        final String path = '${directory.path}/$fileName';
        final File file = File(path);

        await file.writeAsString(csvContent);

        // Compartir el archivo
        await Share.shareXFiles([XFile(path)],
            text: 'Aquí tienes el $title exportado.');
      }
    } catch (e) {
      _showErrorSnackBar('Error al exportar: $e');
    }
  }

  // ==========================================
  // 1. REPORTE DE INVENTARIO ACTUAL
  // ==========================================
  Future<void> _generateInventoryReport(bool asPdf) async {
    setState(() => _isGenerating = true);
    try {
      final snapshot = await _animalsRef.get();
      final animals = snapshot.docs
          .map((doc) =>
              Animal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      List<String> headers = [
        'Arete',
        'Num. Pierna',
        'Nombre',
        'Sexo',
        'Raza',
        'Propósito',
        'Fecha Nac.',
        'Ubicación'
      ];
      List<List<dynamic>> rows = animals
          .map((a) => [
                a.earTagNumber,
                a.legNumber ??
                    'N/A', // <-- Asegúrate de que legNumber exista en tu modelo
                a.name,
                a.sex ?? 'N/A',
                a.breed ?? 'N/A',
                a.purpose ?? 'N/A',
                a.birthDate != null
                    ? DateFormat('dd/MM/yyyy').format(a.birthDate!)
                    : 'N/A',
                a.location,
              ])
          .toList();

      await _exportData(
          title: 'Reporte de Inventario General',
          headers: headers,
          data: rows,
          asPdf: asPdf);
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 2. REPORTE DE LECHE
  // ==========================================
  Future<void> _generateLecheReport(bool asPdf) async {
    setState(() => _isGenerating = true);
    try {
      final snapshot =
          await _animalsRef.where('purpose', isEqualTo: 'Leche').get();
      final animals = snapshot.docs
          .map((doc) =>
              Animal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      List<String> headers = [
        'Arete',
        'Pierna',
        'Nombre',
        'Raza',
        'Estado',
        'Último Parto'
      ];
      List<List<dynamic>> rows = animals.map((a) {
        String estado =
            a.isPregnant == true ? 'Seca (Preñada)' : 'En Lactancia';
        String parto = a.birthDate != null
            ? DateFormat('dd/MM/yyyy').format(a.birthDate!)
            : 'N/A';
        return [
          a.earTagNumber,
          a.legNumber ?? 'N/A',
          a.name,
          a.breed ?? 'N/A',
          estado,
          parto
        ];
      }).toList();

      await _exportData(
          title: 'Reporte Producción Lechera',
          headers: headers,
          data: rows,
          asPdf: asPdf);
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte lechero: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 3. REPORTE DE ENGORDA Y CARNE
  // ==========================================
  Future<void> _generateCarneReport(bool asPdf) async {
    setState(() => _isGenerating = true);
    try {
      final snapshot = await _animalsRef
          .where('purpose', whereIn: ['Engorda', 'Carne']).get();
      final animals = snapshot.docs
          .map((doc) =>
              Animal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      List<String> headers = [
        'Arete',
        'Pierna',
        'Nombre',
        'Raza',
        'Propósito',
        'Último Peso (kg)',
        'Canal Est. (58%)'
      ];
      List<List<dynamic>> rows = animals.map((a) {
        double ultimoPeso = 0.0;
        if (a.stats.isNotEmpty) {
          a.stats.sort((s1, s2) => s2.date.compareTo(s1.date));
          ultimoPeso = a.stats.first.value;
        }
        double canalEst = ultimoPeso * 0.58;
        return [
          a.earTagNumber,
          a.legNumber ?? '-',
          a.name,
          a.breed ?? '-',
          a.purpose ?? 'N/A',
          ultimoPeso > 0 ? ultimoPeso.toStringAsFixed(1) : 'Sin registro',
          ultimoPeso > 0 ? canalEst.toStringAsFixed(1) : '-',
        ];
      }).toList();

      await _exportData(
          title: 'Reporte Engorda y Carne',
          headers: headers,
          data: rows,
          asPdf: asPdf);
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte de carne: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 4. REPORTE DE REPRODUCTORAS
  // ==========================================
  Future<void> _generateReproductorasReport(bool asPdf) async {
    setState(() => _isGenerating = true);
    try {
      final snapshot =
          await _animalsRef.where('sex', isEqualTo: 'Hembra').get();
      final animals = snapshot.docs
          .map((doc) =>
              Animal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      List<String> headers = [
        'Arete',
        'Pierna',
        'Nombre',
        'Raza',
        'Estado',
        'Fecha Insem/Monta',
        'Días Gestación'
      ];
      List<List<dynamic>> rows = animals.map((a) {
        String estado = a.isPregnant == true ? 'Preñada' : 'Vacía / Cargando';
        String fecha = (a.isPregnant == true && a.pregnancyDate != null)
            ? DateFormat('dd/MM/yyyy').format(a.pregnancyDate!)
            : 'N/A';
        String dias = '0';
        if (a.isPregnant == true && a.pregnancyDate != null) {
          dias = DateTime.now().difference(a.pregnancyDate!).inDays.toString();
        }
        return [
          a.earTagNumber,
          a.legNumber ?? '-',
          a.name,
          a.breed ?? '-',
          estado,
          fecha,
          dias
        ];
      }).toList();

      await _exportData(
          title: 'Reporte Vientres y Reproductoras',
          headers: headers,
          data: rows,
          asPdf: asPdf);
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte reproductivo: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 5. REPORTE DE GENÉTICA
  // ==========================================
  Future<void> _generateGeneticaReport(bool asPdf) async {
    setState(() => _isGenerating = true);
    try {
      final snapshot = await _animalsRef.get();
      final animals = snapshot.docs
          .map((doc) =>
              Animal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      List<String> headers = [
        'Arete',
        'Pierna',
        'Nombre',
        'Raza',
        'Padre',
        'Madre',
        'Peso Nac.',
        'Peso Destete'
      ];
      List<List<dynamic>> rows = animals
          .map((a) => [
                a.earTagNumber,
                a.legNumber ?? '-',
                a.name,
                a.breed ?? 'N/A',
                a.father ?? 'N/A',
                a.mother ?? 'N/A',
                a.birthWeight != null ? '${a.birthWeight} kg' : '-',
                a.weaningWeight != null ? '${a.weaningWeight} kg' : '-',
              ])
          .toList();

      await _exportData(
          title: 'Reporte Calidad Genética',
          headers: headers,
          data: rows,
          asPdf: asPdf);
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte genético: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 6. REPORTE DE SANIDAD Y RETIRO
  // ==========================================
  Future<void> _generateSanidadReport(bool asPdf) async {
    setState(() => _isGenerating = true);
    try {
      final snapshot = await _animalsRef.get();
      final animals = snapshot.docs
          .map((doc) =>
              Animal.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      List<String> headers = [
        'Arete',
        'Pierna',
        'Nombre',
        'Raza',
        'Última Vacuna',
        'Propósito'
      ];
      List<List<dynamic>> rows = animals.map((a) {
        String ultimaVacuna = 'Sin registro';
        // Puedes agregar aquí la lógica si tienes una lista de vacunas
        return [
          a.earTagNumber,
          a.legNumber ?? '-',
          a.name,
          a.breed ?? '-',
          ultimaVacuna,
          a.purpose ?? 'N/A'
        ];
      }).toList();

      await _exportData(
          title: 'Reporte Sanidad', headers: headers, data: rows, asPdf: asPdf);
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte de sanidad: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // --- Helper para Headers de PDF ---
  pw.Widget _buildPdfHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Manual Ganadero Pro',
            style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF5e3a1c))),
        pw.SizedBox(height: 5),
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 18, color: const PdfColor.fromInt(0xFFc99450))),
        pw.Divider(),
        pw.Text(
            'Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  // --- UI DIÁLOGO DE SELECCIÓN DE FORMATO ---
  void _showExportOptionsDialog(Function(bool isPdf) onExport) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        backgroundColor: const Color(0xFFfbf6ec),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Elegir Formato',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5e3a1c))),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(FontAwesomeIcons.filePdf,
                        color: Colors.redAccent, size: 30),
                    title: const Text('Exportar como Documento PDF',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      onExport(true);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(FontAwesomeIcons.fileCsv,
                        color: Colors.green, size: 30),
                    title: const Text('Exportar a Excel (CSV)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Ideal para editar y filtrar datos'),
                    onTap: () {
                      Navigator.pop(context);
                      onExport(false);
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRanch) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFc99450))));
    }

    if (_currentRanchId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportes')),
        body: const Center(
            child: Text('Por favor, selecciona un rancho primero.')),
      );
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
        title: const Text('Reportes Generales',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c))),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Centro de Reportes del Rancho',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5e3a1c)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Selecciona el módulo del que deseas exportar la información actual.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  _buildReportCard(
                    title: 'Inventario General',
                    description:
                        'Lista completa de todos los animales registrados.',
                    icon: FontAwesomeIcons.clipboardList,
                    color: Colors.brown,
                    onTap: () =>
                        _showExportOptionsDialog(_generateInventoryReport),
                  ),
                  _buildReportCard(
                    title: 'Producción de Leche',
                    description:
                        'Estado de lactancia, vacas secas y últimos partos.',
                    icon: FontAwesomeIcons.glassWater,
                    color: Colors.blue,
                    onTap: () => _showExportOptionsDialog(_generateLecheReport),
                  ),
                  _buildReportCard(
                    title: 'Engorda y Carne',
                    description:
                        'Pesos actuales y proyecciones de rendimiento en canal.',
                    icon: FontAwesomeIcons.burger,
                    color: Colors.redAccent,
                    onTap: () => _showExportOptionsDialog(_generateCarneReport),
                  ),
                  _buildReportCard(
                    title: 'Vientres y Reproducción',
                    description:
                        'Hembras preñadas, días de gestación y vacías.',
                    icon: FontAwesomeIcons.venus,
                    color: Colors.pink,
                    onTap: () =>
                        _showExportOptionsDialog(_generateReproductorasReport),
                  ),
                  _buildReportCard(
                    title: 'Calidad Genética',
                    description:
                        'Genealogía, pesos al destete e información de raza.',
                    icon: FontAwesomeIcons.dna,
                    color: Colors.purple,
                    onTap: () =>
                        _showExportOptionsDialog(_generateGeneticaReport),
                  ),
                  _buildReportCard(
                    title: 'Sanidad y Retiro',
                    description:
                        'Tiempos de espera para consumo y vacunas recientes.',
                    icon: FontAwesomeIcons.kitMedical,
                    color: Colors.teal,
                    onTap: () =>
                        _showExportOptionsDialog(_generateSanidadReport),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isGenerating)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFc99450)),
                        SizedBox(height: 15),
                        Text('Generando Documento...',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
      {required String title,
      required String description,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: _isGenerating ? null : onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5e3a1c))),
                    const SizedBox(height: 5),
                    Text(description,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.download, color: Color(0xFFc99450)),
            ],
          ),
        ),
      ),
    );
  }
}
