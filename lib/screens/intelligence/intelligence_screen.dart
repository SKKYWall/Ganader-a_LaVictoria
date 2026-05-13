// lib/screens/principal/intelligence_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/models/calendar.dart';
import 'package:manual_ganadero_flutter/services/quota_service.dart';
import 'package:manual_ganadero_flutter/screens/profile/donations_screen.dart';

// ─────────────────────────────────────────────
// MODELO DE MENSAJE
// ─────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final File? image;
  final String? documentName;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.image,
    this.documentName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─────────────────────────────────────────────
// RAG ENGINE
// ─────────────────────────────────────────────
class _RagEngine {
  static bool isRanchQuery({
    required String query,
    required Animal? selectedAnimal,
    required List<Animal> animals,
  }) {
    if (selectedAnimal != null) return true;
    final q = query.toLowerCase();
    final ranchKeywords = [
      'mi ',
      'mis ',
      'mi hato',
      'mi rancho',
      'mis vacas',
      'mis animales',
      'mis bovinos',
      'mi ganado',
      'el rancho',
      'el hato',
      'tengo',
      'tenemos',
      'cuáles de',
      'cuales de',
      'los míos',
      'las mías',
      'mi vaca',
      'mi toro',
      'mi ternero',
      'próximos eventos',
      'mi agenda',
      'mi calendario',
    ];
    if (ranchKeywords.any((k) => q.contains(k))) return true;
    if (animals.any((a) => q.contains(a.name.toLowerCase()))) return true;
    return false;
  }

  static Set<String> detectIntent(String query, String mode) {
    final q = query.toLowerCase();
    final intents = <String>{};
    switch (mode) {
      case 'Veterinario':
        if (_matches(q, ['vacun', 'inmuniz', 'dosis', 'refuerzo']))
          intents.add('vaccinations');
        if (_matches(
            q, ['enferm', 'síntom', 'diagnos', 'trata', 'medic', 'antibiótic']))
          intents.add('health');
        if (_matches(q, ['retiro', 'carencia'])) intents.add('withdrawal');
        if (_matches(q, ['preña', 'embaraz', 'parto', 'gestac']))
          intents.add('pregnancy');
        break;
      case 'Genética':
        if (_matches(q, ['padre', 'madre', 'linea', 'cruza', 'semen', 'toro']))
          intents.add('lineage');
        if (_matches(q, ['marcador', 'genétic', 'dna', 'hereda']))
          intents.add('genetics');
        if (_matches(q, ['raza', 'fenotip'])) intents.add('breed');
        break;
      case 'Nutrición':
        if (_matches(q, ['peso', 'kg', 'kilogram', 'crecer', 'ganancia']))
          intents.add('weight');
        if (_matches(q, [
          'dieta',
          'ración',
          'aliment',
          'forraje',
          'suplemento',
          'mineral'
        ])) intents.add('diet');
        if (_matches(q, ['preña', 'lactanc', 'leche']))
          intents.add('reproductive_nutrition');
        break;
      default:
        intents.add('summary');
        if (_matches(q, ['event', 'calend', 'próxim', 'agenda']))
          intents.add('events');
    }
    if (_matches(q, ['todos', 'hato', 'rancho', 'rebaño', 'ganado']))
      intents.add('herd_summary');
    if (_matches(q, ['event', 'calend', 'próxim', 'agenda']))
      intents.add('events');
    if (intents.isEmpty) intents.add('summary');
    return intents;
  }

  static bool _matches(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  static String retrieve({
    required String query,
    required String mode,
    required String ranchName,
    required List<Animal> allAnimals,
    required List<CalendarEvent> events,
    required Animal? selectedAnimal,
  }) {
    final intents = detectIntent(query, mode);
    final buf = StringBuffer();
    final fmt = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();

    buf.writeln('RANCHO:$ranchName|${allAnimals.length} animales');

    if (selectedAnimal != null) {
      final a = selectedAnimal;
      buf.writeln('\n[ANIMAL FOCO:${a.name}]');
      buf.writeln(
          'Arete:${a.earTagNumber}|Raza:${a.breed ?? "N/A"}|Sexo:${a.sex ?? "N/A"}');
      if (a.birthDate != null) {
        final months = now.difference(a.birthDate!).inDays ~/ 30;
        buf.writeln('Edad:${months}m (${fmt.format(a.birthDate!)})');
      }
      if (a.location.isNotEmpty && a.location != 'N/A')
        buf.writeln('Ubicación:${a.location}');
      if (a.purpose != null) buf.writeln('Propósito:${a.purpose}');

      if (intents.contains('vaccinations') || mode == 'Veterinario') {
        if (a.vaccinations != null && a.vaccinations!.isNotEmpty) {
          buf.writeln('Vacunas:');
          for (final v in a.vaccinations!) {
            buf.writeln(
                '  ${v.name}|${fmt.format(v.date)}|hace ${now.difference(v.date).inDays}d');
          }
        } else {
          buf.writeln('Vacunas:SIN REGISTRO');
        }
      }

      if (intents.contains('withdrawal') || intents.contains('health')) {
        if (a.withdrawalDate != null) {
          final left = a.withdrawalDate!.difference(now).inDays;
          buf.writeln(
              'Retiro medicamento:${fmt.format(a.withdrawalDate!)} (${left > 0 ? "faltan ${left}d" : "VENCIDO"})');
        }
        if (a.diseaseResistance != null)
          buf.writeln('Resistencia:${a.diseaseResistance}');
      }

      if (intents.contains('pregnancy') ||
          intents.contains('reproductive_nutrition')) {
        if (a.isPregnant == true) {
          buf.write('Estado:PREÑADA');
          if (a.pregnancyDate != null) {
            final gestDays = now.difference(a.pregnancyDate!).inDays;
            final estimatedBirth =
                a.pregnancyDate!.add(const Duration(days: 283));
            final toCalving = estimatedBirth.difference(now).inDays;
            buf.writeln(
                '|Gestación:${gestDays}d|Parto est.:${fmt.format(estimatedBirth)}(en ${toCalving}d)');
          }
        } else {
          buf.writeln('Estado:No preñada');
        }
      }

      if (intents.contains('weight') || intents.contains('diet')) {
        if (a.birthWeight != null) buf.writeln('Peso nacer:${a.birthWeight}kg');
        if (a.weaningWeight != null)
          buf.writeln('Peso destete:${a.weaningWeight}kg');
        if (a.stats.isNotEmpty) {
          final recent = a.stats.length > 3
              ? a.stats.sublist(a.stats.length - 3)
              : a.stats;
          buf.writeln('Historial peso:');
          for (final s in recent)
            buf.writeln('  ${fmt.format(s.date)}:${s.value}kg');
          if (recent.length >= 2) {
            final gain = recent.last.value - recent.first.value;
            final days = recent.last.date.difference(recent.first.date).inDays;
            if (days > 0)
              buf.writeln('  GDP:${(gain / days).toStringAsFixed(3)}kg/d');
          }
        }
      }

      if (intents.contains('lineage') ||
          intents.contains('genetics') ||
          intents.contains('breed')) {
        if (a.father != null) buf.writeln('Padre:${a.father}');
        if (a.mother != null) buf.writeln('Madre:${a.mother}');
        if (a.geneticMarkers != null)
          buf.writeln('Marcadores:${a.geneticMarkers}');
        if (a.fertilityInfo != null)
          buf.writeln('Fertilidad:${a.fertilityInfo}');
      }

      if (a.description != null && a.description!.isNotEmpty)
        buf.writeln('Notas:${a.description}');
    } else {
      if (intents.contains('herd_summary') || intents.contains('summary')) {
        final machos = allAnimals.where((a) => a.sex == 'Macho').length;
        final hembras = allAnimals.where((a) => a.sex == 'Hembra').length;
        final prenadas = allAnimals.where((a) => a.isPregnant == true).length;
        final breeds = allAnimals
            .where((a) => a.breed != null)
            .map((a) => a.breed!)
            .toSet();
        buf.writeln('Machos:$machos|Hembras:$hembras|Preñadas:$prenadas');
        if (breeds.isNotEmpty) buf.writeln('Razas:${breeds.join(",")}');
      }

      List<Animal> relevant = [];
      if (mode == 'Veterinario') {
        if (intents.contains('vaccinations')) {
          relevant = allAnimals
              .where((a) {
                if (a.vaccinations == null || a.vaccinations!.isEmpty)
                  return true;
                final last = a.vaccinations!
                    .map((v) => v.date)
                    .reduce((a, b) => a.isAfter(b) ? a : b);
                return now.difference(last).inDays > 180;
              })
              .take(10)
              .toList();
          buf.writeln('\n[Animales sin vacuna o >6 meses:]');
        } else if (intents.contains('pregnancy')) {
          relevant =
              allAnimals.where((a) => a.isPregnant == true).take(10).toList();
          buf.writeln('\n[Animales preñados:]');
        } else if (intents.contains('withdrawal')) {
          relevant = allAnimals
              .where((a) =>
                  a.withdrawalDate != null && a.withdrawalDate!.isAfter(now))
              .take(10)
              .toList();
          buf.writeln('\n[En período de retiro:]');
        } else {
          relevant = allAnimals.take(8).toList();
          buf.writeln('\n[Animales del hato:]');
        }
      } else if (mode == 'Genética') {
        if (intents.contains('breed')) {
          final byBreed = <String, List<Animal>>{};
          for (final a in allAnimals) {
            if (a.breed != null) byBreed.putIfAbsent(a.breed!, () => []).add(a);
          }
          buf.writeln('\n[Distribución por raza:]');
          byBreed.forEach((breed, list) {
            buf.writeln(
                '  $breed:${list.length}(M:${list.where((a) => a.sex == "Macho").length} H:${list.where((a) => a.sex == "Hembra").length})');
          });
        }
        relevant = allAnimals
            .where((a) =>
                a.father != null ||
                a.mother != null ||
                a.geneticMarkers != null)
            .take(8)
            .toList();
        if (relevant.isEmpty) relevant = allAnimals.take(6).toList();
        buf.writeln('\n[Con datos genéticos:]');
      } else if (mode == 'Nutrición') {
        relevant = allAnimals
            .where((a) => a.stats.isNotEmpty || a.birthWeight != null)
            .take(8)
            .toList();
        if (relevant.isEmpty) relevant = allAnimals.take(6).toList();
        final prenadas = allAnimals
            .where((a) => a.isPregnant == true && !relevant.contains(a))
            .take(3)
            .toList();
        relevant.addAll(prenadas);
        buf.writeln('\n[Con datos de peso:]');
      } else {
        relevant = allAnimals.take(10).toList();
        buf.writeln('\n[Animales:]');
      }

      for (final a in relevant) {
        final age = a.birthDate != null
            ? '${now.difference(a.birthDate!).inDays ~/ 30}m'
            : '';
        final preg = a.isPregnant == true ? '|PREÑADA' : '';
        buf.write(
            '  ${a.name}|${a.earTagNumber}|${a.breed ?? "N/A"}|${a.sex ?? "N/A"}|$age$preg');
        if (mode == 'Veterinario') {
          if (a.vaccinations != null && a.vaccinations!.isNotEmpty) {
            final last = a.vaccinations!
                .map((v) => v.date)
                .reduce((x, y) => x.isAfter(y) ? x : y);
            buf.write('|últ.vacc:${DateFormat('MM/yy').format(last)}');
          } else {
            buf.write('|SIN VACUNA');
          }
        } else if (mode == 'Genética') {
          if (a.father != null) buf.write('|padre:${a.father}');
          if (a.geneticMarkers != null) buf.write('|gen:${a.geneticMarkers}');
        } else if (mode == 'Nutrición') {
          if (a.stats.isNotEmpty)
            buf.write('|peso:${a.stats.last.value}kg');
          else if (a.weaningWeight != null)
            buf.write('|destete:${a.weaningWeight}kg');
        }
        buf.writeln();
      }
      if (allAnimals.length > relevant.length) {
        buf.writeln(
            '  ...y ${allAnimals.length - relevant.length} animales más');
      }
    }

    if ((intents.contains('events') || mode == 'Veterinario') &&
        events.isNotEmpty) {
      var evList = mode == 'Veterinario'
          ? events
              .where((e) => ['vacun', 'cita', 'medic', 'parto']
                  .any((k) => e.category.toLowerCase().contains(k)))
              .take(5)
              .toList()
          : events.take(5).toList();
      if (evList.isEmpty) evList = events.take(5).toList();
      if (evList.isNotEmpty) {
        buf.writeln('\n[EVENTOS PRÓXIMOS:]');
        for (final e in evList) {
          final d = e.date.difference(now).inDays;
          buf.writeln(
              '  ${DateFormat('dd/MM').format(e.date)}(en ${d}d)|${e.category}:${e.title}');
          if (e.description.isNotEmpty) buf.writeln('    →${e.description}');
        }
      }
    }

    return buf.toString();
  }
}

// ─────────────────────────────────────────────
// PROMPTS ESPECIALIZADOS
// ─────────────────────────────────────────────
class _ModePrompts {
  static String build({
    required String mode,
    required String ragContext,
    required String query,
    required String history,
    required String docText,
    required Animal? selectedAnimal,
    required bool hasImage,
  }) {
    final animalCtx = selectedAnimal != null
        ? '\nANIMAL EN FOCO: ${selectedAnimal.name} (${selectedAnimal.breed ?? ""} ${selectedAnimal.sex ?? ""})'
        : '';
    final imageCtx =
        hasImage ? '\nEl usuario adjuntó una imagen para análisis visual.' : '';
    final contextBlock = ragContext.isNotEmpty
        ? 'DATOS DEL RANCHO (RAG):\n$ragContext$animalCtx$imageCtx'
        : 'CONTEXTO: Consulta técnica general (sin datos de rancho específico).$imageCtx';

    const lengthRule =
        '- LONGITUD ESTRICTA: Máximo 3 párrafos cortos. Termina la idea de forma natural antes de los 1400 tokens. Sin saludos ni despedidas.';

    switch (mode) {
      case 'Veterinario':
        return '''Eres médico veterinario bovino con 20 años de experiencia en campo. Diagnóstico rápido, medicina preventiva y tratamiento práctico.

$contextBlock

REGLAS:
- Urgencia médica: marca con ⚠️ al inicio
- Síntomas: diagnósticos diferenciales en orden de probabilidad
- Tratamientos: dosis, vía, duración y retiro
- Vacunación: calcula refuerzo si hay registros
- Imagen: hallazgos clínicos (color, textura, inflamación, lesiones)
- Termina la idea de forma natural antes de los 1400 tokens.

$lengthRule

HISTORIAL:
$history

CONSULTA: $query$docText''';

      case 'Genética':
        return '''Eres genetista bovino experto en cruzamientos y mejora genómica para América Latina.

$contextBlock

REGLAS:
- Cruces: complementariedad racial, vigor híbrido, adaptación climática
- Menciona DEP cuando sea relevante
- Contexto: México/Latinoamérica, clima, mercado local
- Imagen: conformación y fenotipo
- Termina la idea de forma natural antes de los 1400 tokens.
$lengthRule

HISTORIAL:
$history

CONSULTA: $query$docText''';

      case 'Nutrición':
        return '''Eres nutricionista bovino certificado, especializado en formulación de dietas para México y Latinoamérica.

$contextBlock

REGLAS:
- Usa pesos para calcular requerimientos (estándar NRC)
- Calcula GDP si hay múltiples registros
- Raciones con cantidades en kg/día, ingredientes accesibles en México
- Imagen: condición corporal escala 1-5
- Termina la idea de forma natural antes de los 1400 tokens.
$lengthRule

HISTORIAL:
$history

CONSULTA: $query$docText''';

      default:
        return '''Eres asesor ganadero integral: administración de ranchos, finanzas ganaderas, manejo del hato en México.

$contextBlock

REGLAS:
- Usa datos reales del rancho, no respondas genéricamente
- Eventos próximos: ayuda a priorizar
- Preguntas financieras: referencias del mercado mexicano
- Termina la idea de forma natural antes de los 1400 tokens.
$lengthRule

HISTORIAL:
$history

CONSULTA: $query$docText''';
    }
  }
}

// ─────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────
class IntelligenceScreen extends StatefulWidget {
  const IntelligenceScreen({super.key});

  @override
  State<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends State<IntelligenceScreen> {
  static const String _apiKey = 'AIzaSyAkZoz1w2vzl9lEMGqKP0fzBnhUXvoq94w';

  // ── LÍMITE DE TOKENS POR RESPUESTA ───────────────────────────────────────
  // 1500 tokens ≈ 1100 palabras → respuestas completas sin cortarse
  // (500 era demasiado poco; Gemini cortaba a mitad de oración)
  static const int _maxOutputTokens = 1500;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isLoadingContext = true;
  File? _selectedImage;
  String? _documentContent;
  String? _documentName;

  String? _currentRanchId;
  String? _currentRanchName;
  List<Animal> _animals = [];
  List<CalendarEvent> _upcomingEvents = [];
  Animal? _selectedAnimal;

  // ── CUOTA ────────────────────────────────────────────────────────────────
  QuotaStatus? _quotaStatus;
  bool _isLoadingQuota = true;

  String _selectedMode = 'Veterinario';
  final List<Map<String, dynamic>> _modes = [
    {
      'label': 'Veterinario',
      'icon': FontAwesomeIcons.stethoscope,
      'color': Color(0xFFe57373)
    },
    {
      'label': 'Genética',
      'icon': FontAwesomeIcons.dna,
      'color': Color(0xFF9575cd)
    },
    {
      'label': 'Nutrición',
      'icon': FontAwesomeIcons.wheatAwn,
      'color': Color(0xFF4db6ac)
    },
    {
      'label': 'General',
      'icon': FontAwesomeIcons.cow,
      'color': Color(0xFFc99450)
    },
  ];

  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);
  static const Color _cream = Color(0xFFfbf6ec);

  @override
  void initState() {
    super.initState();
    _loadRanchContext();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    if (!mounted) return;
    setState(() => _isLoadingQuota = true);
    await QuotaService.checkPremiumExpiry();
    final status = await QuotaService.getStatus();
    if (mounted) {
      setState(() {
        _quotaStatus = status;
        _isLoadingQuota = false;
      });
    }
  }

  Future<void> _loadRanchContext() async {
    setState(() => _isLoadingContext = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final ranchId = (userDoc.data()
          as Map<String, dynamic>?)?['currentRanchId'] as String?;
      if (ranchId == null) {
        setState(() => _isLoadingContext = false);
        return;
      }

      final ranchDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(ranchId)
          .get();
      final ranchName = (ranchDoc.data())?['name'] as String? ?? 'Mi Rancho';

      final animalsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(ranchId)
          .collection('animals')
          .limit(100)
          .get();
      final animals = animalsSnap.docs
          .map((d) => Animal.fromFirestore(d.data(), d.id))
          .toList();

      final now = DateTime.now();
      final eventsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ranches')
          .doc(ranchId)
          .collection('calendarEvents')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('date',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(now.add(const Duration(days: 60))))
          .limit(30)
          .get();
      final events = eventsSnap.docs
          .map((d) => CalendarEvent.fromFirestore(d.data(), d.id))
          .toList();

      setState(() {
        _currentRanchId = ranchId;
        _currentRanchName = ranchName;
        _animals = animals;
        _upcomingEvents = events;
        _isLoadingContext = false;
      });
    } catch (e) {
      setState(() => _isLoadingContext = false);
    }
  }

  Future<String> _callGemini(String prompt, {File? imageFile}) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$_apiKey',
      );
      final parts = <Map<String, dynamic>>[
        {"text": prompt}
      ];
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        final ext = imageFile.path.split('.').last.toLowerCase();
        parts.add({
          "inline_data": {
            "mime_type": ext == 'png' ? 'image/png' : 'image/jpeg',
            "data": base64Encode(bytes)
          }
        });
      }
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {"parts": parts}
          ],
          // ── LÍMITE FREEMIUM: 500 tokens por respuesta ──────────────────
          "generationConfig": {
            "temperature": 0.6,
            "maxOutputTokens": _maxOutputTokens
          },
        }),
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body)['candidates'][0]['content']['parts'][0]
            ['text'];
      }
      return "Error ${resp.statusCode}: ${resp.body}";
    } catch (e) {
      return "Error: $e";
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null && _documentContent == null)
      return;

    // ── VERIFICAR CUOTA ANTES DE ENVIAR ──────────────────────────────────
    // Si la cuota aún está cargando, esperar y re-verificar
    if (_isLoadingQuota) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Verificando cuota, intenta de nuevo...'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    // Si no hay status (error de red), intentar recargar antes de bloquear
    if (_quotaStatus == null) {
      await _loadQuota();
    }

    final quota = _quotaStatus;
    if (quota == null || !quota.canSend) {
      _showPaywall();
      return;
    }

    final userMsg = ChatMessage(
        text: text,
        isUser: true,
        image: _selectedImage,
        documentName: _documentName);
    File? tempImage = _selectedImage;

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _selectedImage = null;
      _documentName = null;
      _textController.clear();
    });
    _scrollToBottom();

    try {
      final recent = _messages.length > 8
          ? _messages.sublist(_messages.length - 8)
          : _messages;
      final history = recent
          .where((m) => m != userMsg)
          .map((m) => m.isUser ? 'U:${m.text}' : 'A:${m.text}')
          .join('\n');

      String docText = '';
      if (_documentContent != null) {
        final lim = _documentContent!.length > 4000
            ? _documentContent!.substring(0, 4000)
            : _documentContent!;
        docText = '\n\nDOC:\n$lim';
        _documentContent = null;
      }

      final bool useRanchContext = _currentRanchId != null &&
          _RagEngine.isRanchQuery(
              query: text, selectedAnimal: _selectedAnimal, animals: _animals);

      final ragContext = useRanchContext
          ? _RagEngine.retrieve(
              query: text,
              mode: _selectedMode,
              ranchName: _currentRanchName ?? '',
              allAnimals: _animals,
              events: _upcomingEvents,
              selectedAnimal: _selectedAnimal)
          : '';

      final prompt = _ModePrompts.build(
        mode: _selectedMode,
        ragContext: ragContext,
        query: text,
        history: history,
        docText: docText,
        selectedAnimal: _selectedAnimal,
        hasImage: tempImage != null,
      );

      final respuesta = await _callGemini(prompt, imageFile: tempImage);
      setState(
          () => _messages.add(ChatMessage(text: respuesta, isUser: false)));

      // ── CONSUMIR CUOTA DESPUÉS DE RESPUESTA EXITOSA ───────────────────
      await QuotaService.consumeConsult();
      await _loadQuota(); // Refrescar el banner

      _scrollToBottom();
    } catch (e) {
      setState(
          () => _messages.add(ChatMessage(text: 'Error: $e', isUser: false)));
      _scrollToBottom();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── MOSTRAR PAYWALL ───────────────────────────────────────────────────────
  void _showPaywall() {
    final quota = _quotaStatus;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          // Evita que el teclado tape el bottom sheet
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _gold.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock, color: _gold, size: 40)),
          const SizedBox(height: 16),
          const Text('Has usado tus consultas disponibles',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _brown)),
          const SizedBox(height: 8),
          // Muestra el estado actual de cuota
          if (quota != null)
            Text(
              quota.paidConsults > 0
                  ? 'Tienes ${quota.paidConsults} consultas pagadas pero agotaste las ${QuotaService.kMonthlyFree} gratuitas del mes.'
                  : 'Agotaste tus ${QuotaService.kMonthlyFree} consultas gratuitas del mes. Consigue más o activa Premium.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          const SizedBox(height: 24),

          // Opción 1: Comprar paquete
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _brown,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.shopping_bag, color: Colors.white),
              label: const Text('Ver paquetes de consultas',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DonationsScreen()),
                ).then((_) => _loadQuota()); // Recargar cuota al regresar
              },
            ),
          ),
          const SizedBox(height: 10),

          // Opción 2: Esperar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: _brown,
                  side: BorderSide(color: _brown.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.schedule),
              label: const Text('Esperar al próximo mes (gratis)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (img != null) setState(() => _selectedImage = File(img.path));
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'csv']);
      if (result != null) {
        final content = await File(result.files.single.path!).readAsString();
        setState(() {
          _documentContent = content;
          _documentName = result.files.single.name;
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Documento "$_documentName" cargado.'),
              backgroundColor: Colors.green));
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo leer el archivo.'),
            backgroundColor: Colors.red));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showAnimalSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AnimalSelectorSheet(
        animals: _animals,
        selectedAnimal: _selectedAnimal,
        onSelect: (a) {
          setState(() => _selectedAnimal = a);
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() => _selectedAnimal = null);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildModeSelector(),
          if (_currentRanchId != null) _buildRanchBanner(),
          _buildQuotaBanner(), // ← banner de cuota
          const Divider(height: 1, color: Color(0xFFe8d8c0)),
          Expanded(child: _buildMessageList()),
          if (_isLoading) _buildTypingIndicator(),
          if (_selectedImage != null || _documentName != null)
            _buildAttachmentPreview(),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── BANNER DE CUOTA ───────────────────────────────────────────────────────
  Widget _buildQuotaBanner() {
    if (_isLoadingQuota) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.grey.shade100,
        child: Row(children: [
          SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.grey.shade400)),
          const SizedBox(width: 8),
          Text('Verificando cuota...',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      );
    }

    if (_quotaStatus == null) return const SizedBox.shrink();
    final q = _quotaStatus!;

    if (q.premiumActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.green.shade50,
        child: Row(children: [
          const Icon(Icons.workspace_premium, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          const Text('Premium activo · consultas ilimitadas',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }

    final Color bannerColor = q.canSend
        ? (q.monthlyRemaining > 0 ? _gold : Colors.deepOrange)
        : Colors.red;

    return GestureDetector(
      onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DonationsScreen()))
          .then((_) => _loadQuota()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        color: bannerColor.withOpacity(0.08),
        child: Row(children: [
          Icon(q.canSend ? Icons.bolt : Icons.lock_outline,
              color: bannerColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text(q.statusLabel,
                  style: TextStyle(
                      fontSize: 11,
                      color: bannerColor,
                      fontWeight: FontWeight.w600))),
          Text('Obtener más →',
              style: TextStyle(
                  fontSize: 11,
                  color: bannerColor,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        backgroundColor: _brown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('IA Ganadera',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          if (_currentRanchName != null)
            Text(_currentRanchName!,
                style: const TextStyle(color: Color(0xFFd4a96a), fontSize: 12)),
        ]),
        actions: [
          if (_isLoadingContext)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
          else if (_currentRanchId != null)
            IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadRanchContext),
        ],
      );

  Widget _buildModeSelector() => Container(
        color: _brown,
        padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _modes.map((mode) {
              final isSelected = _selectedMode == mode['label'];
              return GestureDetector(
                onTap: () => setState(() => _selectedMode = mode['label']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? mode['color']
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSelected
                            ? mode['color']
                            : Colors.white.withOpacity(0.3),
                        width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    FaIcon(mode['icon'], color: Colors.white, size: 13),
                    const SizedBox(width: 6),
                    Text(mode['label'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      );

  Widget _buildRanchBanner() => GestureDetector(
        onTap: _animals.isNotEmpty ? _showAnimalSelector : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
              color: Color(0xFFf5ede0),
              border: Border(bottom: BorderSide(color: Color(0xFFe8d8c0)))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: _gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: FaIcon(
                  _selectedAnimal != null
                      ? FontAwesomeIcons.cow
                      : FontAwesomeIcons.houseChimney,
                  color: _gold,
                  size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _selectedAnimal != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text('Foco: ${_selectedAnimal!.name}',
                              style: TextStyle(
                                  color: _brown,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text(
                              '${_selectedAnimal!.breed ?? ""} · ${_selectedAnimal!.sex ?? ""} · ${_selectedAnimal!.earTagNumber}',
                              style: TextStyle(
                                  color: _brown.withOpacity(0.6),
                                  fontSize: 11)),
                        ])
                  : Text(
                      '${_animals.length} animales · Toca para enfocar en uno',
                      style: TextStyle(
                          color: _brown.withOpacity(0.7), fontSize: 12)),
            ),
            if (_selectedAnimal != null)
              GestureDetector(
                  onTap: () => setState(() => _selectedAnimal = null),
                  child: Icon(Icons.close,
                      color: _brown.withOpacity(0.5), size: 18))
            else if (_animals.isNotEmpty)
              Icon(Icons.chevron_right, color: _gold, size: 20),
          ]),
        ),
      );

  Widget _buildMessageList() {
    if (_messages.isEmpty) return _buildEmptyState();
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
    );
  }

  Widget _buildEmptyState() {
    final suggestions = <Map<String, String>>[];
    switch (_selectedMode) {
      case 'Veterinario':
        suggestions.addAll([
          {
            'label': '¿Qué animales necesitan vacuna?',
            'query':
                '¿Cuáles de mis animales necesitan vacunación próximamente?'
          },
          {
            'label': 'Mi vaca no come bien',
            'query':
                'Una de mis vacas lleva 2 días sin comer bien, ¿qué puede ser?'
          },
          {
            'label': 'Dosis ivermectina',
            'query': '¿Cuál es la dosis correcta de ivermectina para bovinos?'
          },
        ]);
        break;
      case 'Genética':
        suggestions.addAll([
          {
            'label': 'Mejor cruce para mi hato',
            'query': '¿Qué cruza recomiendas para mejorar la producción?'
          },
          {
            'label': 'Razas para clima cálido',
            'query': '¿Qué razas se adaptan mejor al clima cálido de México?'
          },
          {
            'label': 'Selección de toros',
            'query': '¿Qué DEPs debo priorizar al seleccionar un toro?'
          },
        ]);
        break;
      case 'Nutrición':
        suggestions.addAll([
          {
            'label': 'Dieta para vacas en lactancia',
            'query': '¿Qué dieta recomiendas para vacas en producción de leche?'
          },
          {
            'label': 'Suplementación mineral',
            'query': '¿Qué minerales son esenciales para bovinos en México?'
          },
          {
            'label': 'Calcular ración diaria',
            'query':
                '¿Cómo calculo la ración diaria para mis animales según su peso?'
          },
        ]);
        break;
      default:
        suggestions.addAll([
          {
            'label': 'Próximos eventos',
            'query': '¿Cuáles son mis próximos eventos del rancho?'
          },
          {
            'label': 'Resumen del hato',
            'query': '¿Cómo está mi hato actualmente?'
          },
          {
            'label': 'Análisis financiero',
            'query': '¿Cómo puedo mejorar la rentabilidad de mi rancho?'
          },
        ]);
    }

    final modeData = _modes.firstWhere((m) => m['label'] == _selectedMode);
    final modeColor = modeData['color'] as Color;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: modeColor.withOpacity(0.1), shape: BoxShape.circle),
            child: FaIcon(modeData['icon'], color: modeColor, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Asistente $_selectedMode',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _brown)),
          const SizedBox(height: 8),
          Text('Haz tu primera consulta o elige una sugerencia',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: suggestions
                .map((s) => _SuggestionChip(s['label']!, modeColor, onTap: () {
                      _textController.text = s['query']!;
                      _sendMessage();
                    }))
                .toList(),
          ),
        ]),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (msg.image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(msg.image!,
                  width: 200, height: 150, fit: BoxFit.cover),
            ),
          if (msg.documentName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade200)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.description, size: 14, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text(msg.documentName!,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ]),
            ),
          if (msg.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: _brown,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4))),
              child: Text(msg.text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.4)),
            ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 40),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(right: 8, top: 2),
          decoration: BoxDecoration(color: _gold, shape: BoxShape.circle),
          child: const Icon(Icons.psychology, color: Colors.white, size: 16),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]),
            child: Text(msg.text,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF333333), height: 1.5)),
          ),
        ),
      ]),
    );
  }

  Widget _buildTypingIndicator() => Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration:
                const BoxDecoration(color: _gold, shape: BoxShape.circle),
            child: const Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 4)
                ]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _dot(0),
              const SizedBox(width: 4),
              _dot(150),
              const SizedBox(width: 4),
              _dot(300),
            ]),
          ),
        ]),
      );

  Widget _dot(int delayMs) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 600 + delayMs),
        builder: (_, v, __) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
              color: _gold.withOpacity(0.4 + 0.6 * v), shape: BoxShape.circle),
        ),
      );

  Widget _buildAttachmentPreview() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Colors.white,
        child: Row(children: [
          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(_selectedImage!,
                  width: 48, height: 48, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
          ],
          if (_documentName != null) ...[
            const Icon(Icons.description, size: 16, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Expanded(
                child: Text(_documentName!,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis)),
          ] else
            const Spacer(),
          IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () => setState(() {
                    _selectedImage = null;
                    _documentName = null;
                    _documentContent = null;
                  })),
        ]),
      );

  Widget _buildInputArea() => Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ]),
        child: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(
                icon: FaIcon(FontAwesomeIcons.camera, color: _gold, size: 18),
                onPressed: _pickImage),
            IconButton(
                icon: FaIcon(FontAwesomeIcons.paperclip,
                    color: Colors.blueGrey, size: 18),
                onPressed: _pickDocument),
            if (_animals.isNotEmpty)
              IconButton(
                  icon: FaIcon(FontAwesomeIcons.cow,
                      color: _selectedAnimal != null ? _gold : Colors.blueGrey,
                      size: 18),
                  onPressed: _showAnimalSelector),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE0E0E0))),
                child: TextField(
                  controller: _textController,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      hintText: 'Escribe tu consulta...',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14)),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (_) {
                    if (!_isLoading) _sendMessage();
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: _isLoading ? Colors.grey.shade300 : _brown,
                    shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 4),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────
// CHIP DE SUGERENCIA
// ─────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SuggestionChip(this.label, this.color, {required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(20),
              color: color.withOpacity(0.06)),
          child: Text(label, style: TextStyle(color: color, fontSize: 12)),
        ),
      );
}

// ─────────────────────────────────────────────
// SELECTOR DE ANIMAL
// ─────────────────────────────────────────────
class _AnimalSelectorSheet extends StatefulWidget {
  final List<Animal> animals;
  final Animal? selectedAnimal;
  final ValueChanged<Animal> onSelect;
  final VoidCallback onClear;
  const _AnimalSelectorSheet(
      {required this.animals,
      required this.selectedAnimal,
      required this.onSelect,
      required this.onClear});

  @override
  State<_AnimalSelectorSheet> createState() => _AnimalSelectorSheetState();
}

class _AnimalSelectorSheetState extends State<_AnimalSelectorSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.animals
        .where((a) =>
            a.name.toLowerCase().contains(_search.toLowerCase()) ||
            a.earTagNumber.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            const Text('Enfocar animal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (widget.selectedAnimal != null)
              TextButton(
                  onPressed: widget.onClear,
                  child:
                      const Text('Ver todo', style: TextStyle(fontSize: 12))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
                hintText: 'Buscar por nombre o arete...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10)),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final a = filtered[i];
              final isSelected = widget.selectedAnimal?.id == a.id;
              final age = a.birthDate != null
                  ? '${DateTime.now().difference(a.birthDate!).inDays ~/ 30}m'
                  : '';
              return ListTile(
                onTap: () => widget.onSelect(a),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                tileColor: isSelected ? const Color(0xFFfff3e0) : null,
                leading: CircleAvatar(
                    backgroundColor: const Color(0xFFc99450).withOpacity(0.15),
                    child: Text(a.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF5e3a1c),
                            fontWeight: FontWeight.bold))),
                title: Text(a.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                    '${a.breed ?? "N/A"} · ${a.sex ?? "N/A"} · $age · ${a.earTagNumber}',
                    style: const TextStyle(fontSize: 11)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFFc99450))
                    : (a.isPregnant == true
                        ? const Text('🤰', style: TextStyle(fontSize: 16))
                        : null),
              );
            },
          ),
        ),
      ]),
    );
  }
}
