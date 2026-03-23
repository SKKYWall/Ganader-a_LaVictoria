import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  // ==========================================
  // 1. REPORTE DE INVENTARIO ACTUAL
  // ==========================================
  Future<void> _generateInventoryReport() async {
    if (_currentUser == null) return;
    setState(() => _isGenerating = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('animals')
          .get();

      final animals = snapshot.docs
          .map((doc) => Animal.fromFirestore(doc.data(), doc.id))
          .toList();

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader('Reporte de Inventario General'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Arete',
                    'Nombre',
                    'Sexo',
                    'Propósito',
                    'Ubicación'
                  ],
                  data: animals
                      .map((a) => [
                            a.earTagNumber,
                            a.name,
                            a.sex ?? 'N/A',
                            a.purpose ?? 'N/A',
                            a.location,
                          ])
                      .toList(),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 2. REPORTE DE LECHE
  // ==========================================
  Future<void> _generateLecheReport() async {
    if (_currentUser == null) return;
    setState(() => _isGenerating = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('animals')
          .where('purpose', isEqualTo: 'Leche')
          .get();

      final animals = snapshot.docs
          .map((doc) => Animal.fromFirestore(doc.data(), doc.id))
          .toList();

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader('Reporte de Producción Lechera'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['Arete', 'Nombre', 'Estado', 'Último Parto'],
                  data: animals.map((a) {
                    // Lógica básica para determinar estado (puedes ajustarla según tu modelo)
                    String estado = a.isPregnant == true
                        ? 'Seca (Preñada)'
                        : 'En Lactancia';
                    String parto = a.birthDate != null
                        ? DateFormat('dd/MM/yyyy').format(a.birthDate!)
                        : 'N/A';
                    return [a.earTagNumber, a.name, estado, parto];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte lechero: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 3. REPORTE DE ENGORDA Y CARNE
  // ==========================================
  Future<void> _generateCarneReport() async {
    if (_currentUser == null) return;
    setState(() => _isGenerating = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('animals')
          .where('purpose', whereIn: ['Engorda', 'Carne']).get();

      final animals = snapshot.docs
          .map((doc) => Animal.fromFirestore(doc.data(), doc.id))
          .toList();

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader('Reporte de Engorda y Carne'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Arete',
                    'Nombre',
                    'Propósito',
                    'Último Peso (kg)',
                    'Canal Est. (58%)'
                  ],
                  data: animals.map((a) {
                    double ultimoPeso = 0.0;
                    if (a.stats.isNotEmpty) {
                      a.stats.sort((a, b) => b.date.compareTo(a.date));
                      ultimoPeso = a.stats.first.value;
                    }
                    double canalEst = ultimoPeso * 0.58;
                    return [
                      a.earTagNumber,
                      a.name,
                      a.purpose ?? 'N/A',
                      ultimoPeso > 0
                          ? ultimoPeso.toStringAsFixed(1)
                          : 'Sin registro',
                      ultimoPeso > 0 ? canalEst.toStringAsFixed(1) : '-',
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte de carne: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 4. REPORTE DE REPRODUCTORAS
  // ==========================================
  Future<void> _generateReproductorasReport() async {
    if (_currentUser == null) return;
    setState(() => _isGenerating = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('animals')
          .where('sex', isEqualTo: 'Hembra')
          .get();

      final animals = snapshot.docs
          .map((doc) => Animal.fromFirestore(doc.data(), doc.id))
          .toList();

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader('Reporte de Vientres y Reproductoras'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Arete',
                    'Nombre',
                    'Estado',
                    'Fecha Insem/Monta',
                    'Días Gestación'
                  ],
                  data: animals.map((a) {
                    String estado =
                        a.isPregnant == true ? 'Preñada' : 'Vacía / Cargando';
                    String fecha =
                        (a.isPregnant == true && a.pregnancyDate != null)
                            ? DateFormat('dd/MM/yyyy').format(a.pregnancyDate!)
                            : 'N/A';

                    String dias = '0';
                    if (a.isPregnant == true && a.pregnancyDate != null) {
                      dias = DateTime.now()
                          .difference(a.pregnancyDate!)
                          .inDays
                          .toString();
                    }

                    return [a.earTagNumber, a.name, estado, fecha, dias];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte reproductivo: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 5. REPORTE DE GENÉTICA
  // ==========================================
  Future<void> _generateGeneticaReport() async {
    if (_currentUser == null) return;
    setState(() => _isGenerating = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('animals')
          .get();

      final animals = snapshot.docs
          .map((doc) => Animal.fromFirestore(doc.data(), doc.id))
          .toList();

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader('Reporte de Calidad Genética'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Arete',
                    'Raza',
                    'Padre',
                    'Madre',
                    'Peso Nac.',
                    'Peso Destete'
                  ],
                  data: animals
                      .map((a) => [
                            a.earTagNumber,
                            a.breed ?? 'N/A',
                            a.father ?? 'N/A',
                            a.mother ?? 'N/A',
                            a.birthWeight != null ? '${a.birthWeight} kg' : '-',
                            a.weaningWeight != null
                                ? '${a.weaningWeight} kg'
                                : '-',
                          ])
                      .toList(),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      _showErrorSnackBar('Error al generar reporte genético: $e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ==========================================
  // 6. REPORTE DE SANIDAD Y RETIRO
  // ==========================================
  Future<void> _generateSanidadReport() async {
    if (_currentUser == null) return;
    setState(() => _isGenerating = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('animals')
          .get();

      final animals = snapshot.docs
          .map((doc) => Animal.fromFirestore(doc.data(), doc.id))
          .toList();

      // Filtrar animales que tienen fecha de retiro pendiente o futura
      final animalesEnTratamiento = animals.where((a) {
        // Asegúrate de que tu modelo Animal tenga la propiedad withdrawalDate expuesta
        // Si no la tiene directamente, la puedes agregar o usar un dummy para la UI
        return true; // Por ahora mostramos todos, puedes ajustar la lógica
      }).toList();

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader('Reporte de Sanidad y Tiempos de Retiro'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['Arete', 'Nombre', 'Última Vacuna', 'Propósito'],
                  data: animalesEnTratamiento.map((a) {
                    String ultimaVacuna = 'Sin registro';
                    /* Descomentar si usas la lista de vacunas en tu modelo:
                    if (a.vaccinations != null && a.vaccinations!.isNotEmpty) {
                      a.vaccinations!.sort((v1, v2) => v2.date.compareTo(v1.date));
                      ultimaVacuna = a.vaccinations!.first.name;
                    }
                    */
                    return [
                      a.earTagNumber,
                      a.name,
                      ultimaVacuna,
                      a.purpose ?? 'N/A'
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
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

  @override
  Widget build(BuildContext context) {
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
                    'Selecciona el módulo del que deseas exportar un documento PDF con la información actual.',
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
                    onTap: _generateInventoryReport,
                  ),
                  _buildReportCard(
                    title: 'Producción de Leche',
                    description:
                        'Estado de lactancia, vacas secas y últimos partos.',
                    icon: FontAwesomeIcons.glassWater,
                    color: Colors.blue,
                    onTap: _generateLecheReport,
                  ),
                  _buildReportCard(
                    title: 'Engorda y Carne',
                    description:
                        'Pesos actuales y proyecciones de rendimiento en canal.',
                    icon: FontAwesomeIcons.burger,
                    color: Colors.redAccent,
                    onTap: _generateCarneReport,
                  ),
                  _buildReportCard(
                    title: 'Vientres y Reproducción',
                    description:
                        'Hembras preñadas, días de gestación y vacías.',
                    icon: FontAwesomeIcons.venus,
                    color: Colors.pink,
                    onTap: _generateReproductorasReport,
                  ),
                  _buildReportCard(
                    title: 'Calidad Genética',
                    description:
                        'Genealogía, pesos al destete e información de raza.',
                    icon: FontAwesomeIcons.dna,
                    color: Colors.purple,
                    onTap: _generateGeneticaReport,
                  ),
                  _buildReportCard(
                    title: 'Sanidad y Retiro',
                    description:
                        'Tiempos de espera para consumo y vacunas recientes.',
                    icon: FontAwesomeIcons.kitMedical,
                    color: Colors.teal,
                    onTap: _generateSanidadReport,
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
                        Text('Generando PDF...',
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
