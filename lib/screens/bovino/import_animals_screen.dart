// lib/screens/bovino/import_animals_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- AGREGA ESTO
import 'package:manual_ganadero_flutter/services/notification_service.dart';

// Valores válidos — deben coincidir EXACTAMENTE con los de
// register_animal_screen.dart / edit_animal_screen.dart / voice_action_dialog.dart.
const _validSexes = ['Macho', 'Hembra'];
const _validPurposes = ['Leche', 'Carne', 'Genética', 'Engorda', 'Reproductora'];
const _validBreeds = [
  'Nelore', 'Angus', 'Brangus', 'Brahman', 'Brahman Rojo', 'Hereford',
  'Charolais', 'Simmental', 'Limousin', 'Holstein', 'Jersey', 'Suizo Pardo',
  'Guzerat', 'Indubrasil', 'Beefmaster', 'Santa Gertrudis', 'Texas Longhorn',
  'Cebú', 'Otro',
];
// Variantes/sinónimos habladas o mal escritas comunes -> valor canónico.
// Se comparan ya sin acentos y en minúsculas (ver _normalize).
const _breedAliases = {
  'cebu': 'Cebú',
  'indico': 'Cebú',
  'indicu': 'Cebú',
  'suizo': 'Suizo Pardo',
  'pardo suizo': 'Suizo Pardo',
  'holando': 'Holstein',
  'holandes': 'Holstein',
  'simental': 'Simmental',
  'si mental': 'Simmental',
  'limosin': 'Limousin',
  'limozin': 'Limousin',
  'beef master': 'Beefmaster',
  'brahman colorado': 'Brahman Rojo',
  'indu brasil': 'Indubrasil',
  'angus negro': 'Angus',
  'angus colorado': 'Angus',
  'angus rojo': 'Angus',
  'tejano': 'Texas Longhorn',
  'cuernos largos': 'Texas Longhorn',
  'criollo': 'Otro',
  'mestizo': 'Otro',
  'cruza': 'Otro',
  'revuelto': 'Otro',
};

// Firestore solo permite ~1MiB por documento y 500 escrituras por batch —
// un archivo corrupto o con decenas de miles de filas podría intentar
// escribir cientos de miles de documentos de un jalón. Ningún rancho real
// tiene esta cantidad de cabezas; este tope es solo una red de seguridad.
const _maxImportRows = 5000;

String _stripAccents(String s) {
  const from = 'áéíóúÁÉÍÓÚñÑ';
  const to = 'aeiouAEIOUnN';
  var r = s;
  for (int i = 0; i < from.length; i++) {
    r = r.replaceAll(from[i], to[i]);
  }
  return r;
}

String _normalize(String s) => _stripAccents(s).trim().toLowerCase();

/// Busca [raw] en [canonical] (sin importar acentos/mayúsculas) y, si no
/// coincide, en [aliases]. Devuelve el valor canónico exacto, o null si no
/// hay ninguna coincidencia razonable.
String? _matchCanonical(String? raw, List<String> canonical,
    [Map<String, String>? aliases]) {
  if (raw == null || raw.trim().isEmpty) return null;
  final norm = _normalize(raw);
  for (final c in canonical) {
    if (_normalize(c) == norm) return c;
  }
  if (aliases != null && aliases.containsKey(norm)) return aliases[norm];
  return null;
}

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
  // Filas con un problema que impidió importarlas (ej. arete duplicado,
  // sexo no reconocido) — se muestran para que el usuario pueda corregir
  // su archivo, en vez de fallar en silencio o importar datos incorrectos.
  List<String> _rowErrors = [];
  // Avisos no bloqueantes (ej. raza no reconocida -> se usó "Otro").
  List<String> _rowWarnings = [];

  // ─── Extractores robustos de celdas (excel 4.x) ───────────────────────────
  // En excel 4.x cada celda es un CellValue tipado. Clave: TextCellValue.value
  // es un TextSpan (no un String), por eso hay que usar toPlainText() o el texto
  // sale corrupto (ej. "TextSpan(...)"). Las fechas y números traen su propio tipo.

  String? _cellText(dynamic cell) {
    final v = cell?.value;
    if (v == null) return null;
    String s;
    if (v is TextCellValue) {
      // El TextSpan de excel sobreescribe toString() para devolver el texto plano.
      s = v.value.toString();
    } else if (v is IntCellValue) {
      s = v.value.toString();
    } else if (v is DoubleCellValue) {
      s = v.value.toString();
    } else if (v is BoolCellValue) {
      s = v.value.toString();
    } else if (v is DateCellValue) {
      s = v.asDateTimeLocal().toIso8601String();
    } else if (v is DateTimeCellValue) {
      s = v.asDateTimeLocal().toIso8601String();
    } else {
      s = v.toString();
    }
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  double? _cellDouble(dynamic cell) {
    final v = cell?.value;
    if (v is DoubleCellValue) return v.value;
    if (v is IntCellValue) return v.value.toDouble();
    final s = _cellText(cell);
    if (s == null) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  DateTime? _cellDate(dynamic cell) {
    final v = cell?.value;
    if (v is DateCellValue) return v.asDateTimeLocal();
    if (v is DateTimeCellValue) return v.asDateTimeLocal();
    final s = _cellText(cell);
    if (s == null) return null;
    try {
      return DateFormat('dd/MM/yyyy').parse(s);
    } catch (_) {}
    try {
      return DateTime.parse(s);
    } catch (_) {}
    return null;
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
          _rowErrors = [];
          _rowWarnings = [];
        });

        // Aretes ya existentes en el rancho actual — para detectar
        // duplicados contra animales ya registrados, no solo dentro del
        // mismo archivo.
        final Set<String> existingEarTags = {};
        final user = _auth.currentUser;
        if (user != null) {
          final userDoc =
              await _firestore.collection('users').doc(user.uid).get();
          final ranchId = userDoc.data()?['currentRanchId'];
          if (ranchId != null) {
            final existingSnap = await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('ranches')
                .doc(ranchId)
                .collection('animals')
                .get();
            for (final d in existingSnap.docs) {
              final tag = (d.data()['earTagNumber'] as String?)?.trim();
              if (tag != null && tag.isNotEmpty) existingEarTags.add(tag);
            }
          }
        }

        File file = File(result.files.single.path!);
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        List<Animal> parsedAnimals = [];
        final List<String> errors = [];
        final List<String> warnings = [];
        final Set<String> seenInFile = {};

        // Asumimos que los datos están en la primera pestaña (hoja) del Excel
        String sheetName = excel.tables.keys.first;
        var table = excel.tables[sheetName]!;

        int totalRows = table.maxRows - 1; // sin contar encabezado
        if (totalRows > _maxImportRows) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'El archivo tiene $totalRows filas — el máximo '
                'por importación es $_maxImportRows. Divide tu archivo en '
                'partes más pequeñas.';
          });
          return;
        }

        // Empezamos desde la fila 1 (saltando la fila 0 que son los encabezados)
        for (int i = 1; i < table.maxRows; i++) {
          var row = table.rows[i];
          final int excelRowNum = i + 1; // para mensajes legibles al usuario

          // Acceso seguro a una celda por índice (respeta filas cortas).
          dynamic cell(int idx) => idx < row.length ? row[idx] : null;

          // Si la fila no tiene Arete (col 1), es una fila vacía → la saltamos.
          final String? earTagRaw = _cellText(cell(1));
          if (earTagRaw == null) continue;

          final String earTag = earTagRaw.trim();

          // ── Duplicados: dentro del mismo archivo o contra el rancho ──
          if (seenInFile.contains(earTag)) {
            errors.add('Fila $excelRowNum: arete "$earTag" repetido en este '
                'mismo archivo — se omitió esta fila.');
            continue;
          }
          if (existingEarTags.contains(earTag)) {
            errors.add('Fila $excelRowNum: ya existe un animal con el arete '
                '"$earTag" en tu rancho — se omitió esta fila.');
            continue;
          }

          // Mapeo exacto a las 18 columnas de tu plantilla
          final String name = _cellText(cell(0)) ?? 'Sin nombre';
          final String? legNumber = _cellText(cell(2));

          final String? breedRaw = _cellText(cell(3));
          String breed = _matchCanonical(breedRaw, _validBreeds, _breedAliases) ??
              'Otro';
          if (breedRaw != null && breed == 'Otro' && breedRaw != 'Otro') {
            warnings.add('Fila $excelRowNum: raza "$breedRaw" no reconocida, '
                'se guardó como "Otro".');
          }

          final String? sexRaw = _cellText(cell(4));
          final String? sexMatch = _matchCanonical(sexRaw, _validSexes);
          if (sexMatch == null) {
            errors.add('Fila $excelRowNum: "Sexo" debe ser Macho o Hembra '
                '(se encontró "${sexRaw ?? "vacío"}") — se omitió esta fila.');
            continue;
          }
          final String sex = sexMatch;

          final String? purposeRaw = _cellText(cell(5));
          String purpose = _matchCanonical(purposeRaw, _validPurposes) ?? 'Carne';
          if (purposeRaw != null && !_validPurposes.contains(purpose)) {
            warnings.add('Fila $excelRowNum: propósito "$purposeRaw" no '
                'reconocido, se guardó como "Carne".');
          }

          final DateTime? birthDate = _cellDate(cell(6));
          final String? regNumber = _cellText(cell(7));

          final double? birthWeight = _cellDouble(cell(8));
          final double? weaningWeight = _cellDouble(cell(9));

          final String? motherTag = _cellText(cell(10));
          final String? fatherTag = _cellText(cell(11));

          // Lógica de Preñez (Solo si es hembra)
          bool isPregnant = false;
          DateTime? pregDate;
          if (sex == 'Hembra') {
            final String pregStr = (_cellText(cell(12)) ?? 'no').toLowerCase();
            isPregnant = (pregStr == 'sí' ||
                pregStr == 'si' ||
                pregStr == 'yes' ||
                pregStr == 'true' ||
                pregStr == '1');
            if (isPregnant) {
              pregDate = _cellDate(cell(13));
            }
          }

          final String? diseaseRes = _cellText(cell(14));
          final String? fertility = _cellText(cell(15));
          final String? genetics = _cellText(cell(16));
          final String? desc = _cellText(cell(17));

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

          seenInFile.add(earTag);
          parsedAnimals.add(newAnimal);
        }

        setState(() {
          _previewAnimals = parsedAnimals;
          _rowErrors = errors;
          _rowWarnings = warnings;
          _isLoading = false;
          _statusMessage = errors.isEmpty
              ? 'Se encontraron ${parsedAnimals.length} animales listos para importar.'
              : 'Se encontraron ${parsedAnimals.length} animales listos para '
                  'importar. ${errors.length} fila(s) se omitieron por '
                  'errores — revísalas abajo.';
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

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      String? currentRanchId =
          (userDoc.data() as Map<String, dynamic>?)?['currentRanchId'];

      // --- NUEVO: LEER PREFERENCIA DE NOTIFICACIONES ---
      bool notificationsEnabled =
          (userDoc.data() as Map<String, dynamic>?)?['notificationsEnabled'] ??
              true;

      if (currentRanchId == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error: No hay un rancho seleccionado.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No tienes un rancho seleccionado. Ve al inicio y selecciona uno.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      CollectionReference animalsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(currentRanchId)
          .collection('animals');

      // Lista temporal para guardar qué alarmas programar si el guardado es exitoso
      List<Map<String, dynamic>> pregnantAnimalsToSchedule = [];

      // Firestore solo permite 500 escrituras por lote. Partimos en bloques de 450
      // para que se puedan importar hatos grandes (cientos/miles) sin fallar.
      const int chunkSize = 450;
      WriteBatch batch = _firestore.batch();
      int opsInBatch = 0;

      for (var animal in _previewAnimals) {
        DocumentReference docRef =
            animalsRef.doc(); // Crea un nuevo ID en Firebase
        batch.set(docRef, animal.toFirestore());
        opsInBatch++;

        // --- PREPARAMOS LA ALARMA SI ESTÁ PREÑADA ---
        if (animal.isPregnant == true &&
            animal.pregnancyDate != null &&
            notificationsEnabled) {
          pregnantAnimalsToSchedule.add({
            'id': docRef.id.hashCode & 0x7fffffff, // ID seguro (31 bits)
            'name': animal.name,
            'pregnancyDate': animal.pregnancyDate
          });
        }

        // Al llegar al tope, confirmamos este lote y empezamos uno nuevo.
        if (opsInBatch >= chunkSize) {
          await batch.commit();
          batch = _firestore.batch();
          opsInBatch = 0;
        }
      }

      // Confirmamos el último lote pendiente (si quedó algo).
      if (opsInBatch > 0) {
        await batch.commit();
      }

      // --- NUEVO: PROGRAMAR LAS ALARMAS DESPUÉS DEL GUARDADO EXITOSO ---
      for (var pregnantAnimal in pregnantAnimalsToSchedule) {
        DateTime alertDate = pregnantAnimal['pregnancyDate']
            .add(const Duration(days: 276)); // 7 días antes
        if (alertDate.isAfter(DateTime.now())) {
          await NotificationService().scheduleNotification(
            id: pregnantAnimal['id'],
            title: '¡Parto Cercano! 🐄',
            body:
                'La vaca ${pregnantAnimal['name']} (importada) está a aprox. una semana de su fecha de parto.',
            scheduledDate: alertDate,
          );
        }
      }
      // --- FIN NUEVO CÓDIGO ---

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

            // Filas omitidas por error (arete duplicado, sexo no válido) —
            // se muestran siempre que existan, incluso si el resto del
            // archivo sí se pudo importar.
            if (_rowErrors.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_rowErrors.length} fila(s) omitidas:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700)),
                    const SizedBox(height: 6),
                    ..._rowErrors.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('• $e',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red.shade700)),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_rowWarnings.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_rowWarnings.length} aviso(s):',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800)),
                    const SizedBox(height: 6),
                    ..._rowWarnings.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('• $w',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange.shade800)),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

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
