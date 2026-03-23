// lib/screens/bovino/import_animals_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- AGREGA ESTO

class ImportAnimalsScreen extends StatefulWidget {
  const ImportAnimalsScreen({super.key});

  @override
  State<ImportAnimalsScreen> createState() => _ImportAnimalsScreenState();
}

class _ImportAnimalsScreenState extends State<ImportAnimalsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Animal> _previewAnimals = [];
  bool _isLoading = false;
  String _statusMessage = 'Sube tu plantilla de Excel (.xlsx) para comenzar.';

  // Función para procesar fechas (porque Excel a veces las manda como texto y otras como objeto Date)
  DateTime? _parseExcelDate(dynamic cellValue) {
    if (cellValue == null) return null;

    // Si Excel lo detectó como fecha pura
    if (cellValue is DateTime) return cellValue;

    // Si viene como texto 'DD/MM/YYYY'
    String textDate = cellValue.toString().trim();
    if (textDate.isEmpty) return null;

    try {
      return DateFormat('dd/MM/yyyy').parse(textDate);
    } catch (e) {
      // Si falla, intentamos formato de base de datos 'YYYY-MM-DD'
      try {
        return DateTime.parse(textDate);
      } catch (e2) {
        return null; // Si no se puede leer, lo dejamos nulo para que no falle la app
      }
    }
  }

// Función para descargar la plantilla
  Future<void> _downloadTemplate() async {
    // Reemplaza este enlace con tu enlace real de Google Drive o Firebase
    final Uri url = Uri.parse(
        'https://docs.google.com/spreadsheets/d/1NLbFiBTwRiIFLecrjtR0rVXxc5lJB_1N/export?format=xlsx');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('No se pudo abrir el enlace para descargar la plantilla.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _pickAndParseExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'Leyendo archivo...';
        });

        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        List<Animal> parsedAnimals = [];

        // Asumimos que los datos están en la primera pestaña (hoja) del Excel
        String sheetName = excel.tables.keys.first;
        var table = excel.tables[sheetName]!;

        // Empezamos desde la fila 1 (saltando la fila 0 que son los encabezados)
        for (int i = 1; i < table.maxRows; i++) {
          var row = table.rows[i];

          // Si la fila no tiene la columna de Arete (índice 1), la saltamos
          if (row.length < 2 ||
              row[1]?.value == null ||
              row[1]!.value.toString().trim().isEmpty) continue;

          // Mapeo exacto a las 18 columnas de tu plantilla
          String name = row[0]?.value?.toString().trim() ?? '';
          String earTag = row[1]?.value?.toString().trim() ?? '';
          String? legNumber = row[2]?.value?.toString().trim();
          String breed = row[3]?.value?.toString().trim() ?? 'Otro';
          String sex = row[4]?.value?.toString().trim() ?? 'Hembra';
          String purpose = row[5]?.value?.toString().trim() ?? 'Carne';

          DateTime? birthDate = _parseExcelDate(row[6]?.value);
          String? regNumber = row[7]?.value?.toString().trim();

          double? birthWeight =
              double.tryParse(row[8]?.value?.toString().trim() ?? '');
          double? weaningWeight =
              double.tryParse(row[9]?.value?.toString().trim() ?? '');

          String? motherTag = row[10]?.value?.toString().trim();
          String? fatherTag = row[11]?.value?.toString().trim();

          // Lógica de Preñez (Solo si es hembra)
          bool isPregnant = false;
          DateTime? pregDate;
          if (sex.toLowerCase() == 'hembra') {
            String pregStr =
                row[12]?.value?.toString().trim().toLowerCase() ?? 'no';
            isPregnant =
                (pregStr == 'sí' || pregStr == 'si' || pregStr == 'yes');
            if (isPregnant) {
              pregDate = _parseExcelDate(row[13]?.value);
            }
          }

          String? diseaseRes =
              row.length > 14 ? row[14]?.value?.toString().trim() : null;
          String? fertility =
              row.length > 15 ? row[15]?.value?.toString().trim() : null;
          String? genetics =
              row.length > 16 ? row[16]?.value?.toString().trim() : null;
          String? desc =
              row.length > 17 ? row[17]?.value?.toString().trim() : null;

          // Creamos el modelo
          Animal newAnimal = Animal(
              id: '', // Firestore lo generará
              name: name.isEmpty ? 'Sin nombre' : name,
              earTagNumber: earTag,
              legNumber: legNumber ?? '',
              breed: breed,
              sex: sex,
              purpose: purpose,
              birthDate: birthDate,
              registrationNumber: regNumber?.isEmpty == true ? null : regNumber,
              birthWeight: birthWeight,
              weaningWeight: weaningWeight,
              mother: motherTag?.isEmpty == true ? null : motherTag,
              father: fatherTag?.isEmpty == true ? null : fatherTag,
              isPregnant: isPregnant,
              pregnancyDate: pregDate,
              diseaseResistance:
                  diseaseRes?.isEmpty == true ? null : diseaseRes,
              fertilityInfo: fertility?.isEmpty == true ? null : fertility,
              geneticMarkers: genetics?.isEmpty == true ? null : genetics,
              description: desc?.isEmpty == true ? null : desc,
              vaccinations: [], // Limpio para el módulo de Sanidad
              stats: [],
              location: 'N/A');

          parsedAnimals.add(newAnimal);
        }

        setState(() {
          _previewAnimals = parsedAnimals;
          _isLoading = false;
          _statusMessage =
              'Se encontraron ${parsedAnimals.length} animales listos para importar.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage =
            'Error al leer el archivo. Asegúrate de que sea tu formato de Excel.\nError técnico: $e';
      });
    }
  }

  Future<void> _uploadAnimalsToFirebase() async {
    if (_previewAnimals.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Guardando animales en la nube...';
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      WriteBatch batch = _firestore.batch();
      CollectionReference animalsRef =
          _firestore.collection('users').doc(user.uid).collection('animals');

      // Iteramos todos los animales de la lista previa y los preparamos para guardado masivo
      for (var animal in _previewAnimals) {
        DocumentReference docRef =
            animalsRef.doc(); // Crea un nuevo ID en Firebase
        var animalData = animal.toFirestore();
        batch.set(docRef, animalData);
      }

      await batch.commit(); // Dispara la orden de guardar todo de un golpe

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('¡Éxito! Todos los animales fueron subidos correctamente.'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context); // Cierra esta pantalla y regresa
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al subir a Firebase: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        title: const Text('Importar desde Excel',
            style: TextStyle(
                color: Color(0xFF5e3a1c), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarjeta Superior (Botón y Estatus)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [
                  const Icon(FontAwesomeIcons.fileExcel,
                      size: 50, color: Colors.green),
                  const SizedBox(height: 15),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  if (_previewAnimals.isEmpty) ...[
                    // NUEVO BOTÓN PARA DESCARGAR LA PLANTILLA
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5e3a1c),
                        side: const BorderSide(
                            color: Color(0xFF5e3a1c), width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('Descargar Plantilla Vacía',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      onPressed: _downloadTemplate,
                    ),
                    const SizedBox(height: 15), // Espacio entre los dos botones

                    // TU BOTÓN VERDE ORIGINAL PARA SUBIR
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.upload_file, color: Colors.white),
                      label: const Text('Seleccionar Archivo .xlsx',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      onPressed: _isLoading ? null : _pickAndParseExcel,
                    ),
                  ]
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Previsualización de los Animales leídos
            if (_previewAnimals.isNotEmpty) ...[
              const Text('Revisa tu hato antes de subir:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5e3a1c))),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _previewAnimals.length,
                  itemBuilder: (context, index) {
                    final animal = _previewAnimals[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: animal.sex == 'Macho'
                              ? Colors.blue.shade50
                              : Colors.pink.shade50,
                          child: Icon(FontAwesomeIcons.cow,
                              size: 18,
                              color: animal.sex == 'Macho'
                                  ? Colors.blue
                                  : Colors.pink),
                        ),
                        title: Text(
                            '${animal.name} (Arete: ${animal.earTagNumber})',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${animal.breed} | ${animal.purpose}'),
                        trailing: animal.isPregnant == true
                            ? const Icon(Icons.pregnant_woman,
                                color: Colors.pink, size: 20)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),

              // Botón de Confirmación para Mandar a Firebase
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5e3a1c),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _uploadAnimalsToFirebase,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Confirmar y Subir ${_previewAnimals.length} Animales',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
