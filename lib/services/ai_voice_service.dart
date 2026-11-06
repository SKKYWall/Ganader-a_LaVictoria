// lib/services/ai_voice_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIVoiceService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<Map<String, dynamic>?> processCommand(String spokenText) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$_apiKey',
    );

    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final String prompt = '''
Eres un asistente experto en extracción de datos para una app ganadera mexicana.
El ganadero te hablará de forma natural, a veces dudando, corrigiéndose a sí mismo o usando modismos.
TU TAREA MÁS IMPORTANTE: Interpretar su intención real, ignorar la paja (como "este...", "eh...", "mmm", "a ver", "quiero que", "fíjate que") y extraer solo los datos limpios.

REGLA ABSOLUTA: Devuelve ÚNICAMENTE un objeto JSON válido. Cero texto extra, sin markdown, sin saludos.

REGLA ANTI-AMBIGÜEDAD: No adivines un dato que no se mencionó de forma razonable — usa el valor por defecto indicado abajo, y dilo explícitamente en "resumen_confirmacion" (ej. "no mencionaste la raza, pondré 'Otro'") para que el ganadero pueda corregirlo antes de guardar. Nunca presentes un valor por defecto como si el usuario lo hubiera dicho.

═══════════════════════════════════════
DICCIONARIO DE INTENCIONES (Cómo deduce la acción)
═══════════════════════════════════════
- "crear_animal": "quiero registrar...", "agrega un...", "mete una vaca", "da de alta", "apunta este becerro", "nuevo animal".
- "editar_animal": "cámbiale el dato...", "corrige a...", "actualiza el", "me equivoqué, modifícalo".
- "eliminar_animal" (esto es DAR DE BAJA, no un borrado permanente — la app pedirá confirmar el motivo exacto): "borra a...", "saca al...", "da de baja", "vendí al...", "se murió el...", "elimina", "ya no está", "se me fue".
- "registrar_peso": "pesó...", "dio en la báscula...", "anótale un peso de...", "pesa".
- "registrar_vacuna": "le puse la...", "apliqué...", "vacuné contra...", "inyecté", "desparasité" (usa el nombre del desparasitante como si fuera la vacuna).
- "registrar_servicio_reproductivo": "la monté con el toro...", "la aparté con el semental...", "la inseminé...", "le hice la inseminación...", "pajilla de...", "servicio con...".
- "registrar_evento": "parió", "se enfermó", "revisión", "lo castramos" (cualquier cosa que no encaje arriba).

═══════════════════════════════════════
GUÍA DE EXTRACCIÓN Y VALORES POR DEFECTO
═══════════════════════════════════════
1. NOTACIÓN "SOBRE": Si dice "285 sobre 3", "285 diagonal 3" o "285 raya 3" -> arete=285, pierna=3. Nombre del animal="285/3".
2. ARETE / PIERNA: Si no menciona arete -> "Sin arete". Si no menciona pierna -> "Sin pierna".
3. SEXO (OBLIGATORIO): Si dice vaca, becerra, novilla -> "Hembra". Si dice toro, becerro, semental -> "Macho". Si no lo menciona o no es claro -> "Hembra" (Defecto, decláralo en el resumen).
4. RAZA (OBLIGATORIO): Valores permitidos: Nelore, Angus, Brangus, Brahman, Brahman Rojo, Hereford, Charolais, Simmental, Limousin, Holstein, Jersey, Suizo Pardo, Guzerat, Indubrasil, Beefmaster, Santa Gertrudis, Texas Longhorn, Cebú, Otro.
   Sinónimos/variantes habladas comunes que debes normalizar al valor de la lista: "cebú"/"cebu"/"indico"/"indicu" -> Cebú; "suizo"/"pardo suizo"/"suizo pardo" -> Suizo Pardo; "holando"/"holandés" -> Holstein; "simental"/"si mental" -> Simmental; "limosin"/"limozin" -> Limousin; "beef master" -> Beefmaster; "brahman colorado"/"brahman rojo" -> Brahman Rojo; "indu brasil" -> Indubrasil; "angus negro"/"angus colorado"/"angus rojo" -> Angus; "tejano"/"cuernos largos" -> Texas Longhorn; "criollo"/"mestizo"/"cruza"/"revuelto" -> Otro.
   Si no dice una de estas ni un sinónimo reconocible -> "Otro" (Defecto, decláralo en el resumen).
5. PROPÓSITO (OBLIGATORIO): Valores permitidos: Leche, Carne, Genética, Engorda, Reproductora. Si no menciona -> "Reproductora" (Defecto, decláralo en el resumen).
6. FECHA DE NACIMIENTO: Si no menciona una fecha específica -> "$today".
7. TIPO DE SERVICIO REPRODUCTIVO (solo para "registrar_servicio_reproductivo"): "monta", "monté", "semental natural", "toro" -> "Monta Natural". "inseminé", "inseminación", "IA", "pajilla" -> "Inseminación Artificial". Si no es claro -> "Monta Natural" (Defecto, decláralo en el resumen).

═══════════════════════════════════════
ESTRUCTURA JSON DE RESPUESTA
═══════════════════════════════════════
{
  "accion": "crear_animal | editar_animal | eliminar_animal | registrar_peso | registrar_vacuna | registrar_servicio_reproductivo | registrar_evento",
  "animal": "nombre o identificador principal (la hembra, si es un servicio reproductivo)",
  "arete": "número exacto, o 'Sin arete'",
  "pierna": "número exacto, o 'Sin pierna'",
  "raza": "valor válido de la lista",
  "sexo": "Macho | Hembra",
  "proposito": "valor válido de la lista",
  "fecha_nacimiento": "dd/MM/yyyy o '$today'",
  "peso": "número en kg o vacío",
  "vacuna": "nombre de la vacuna o vacío",
  "tipo_servicio": "Monta Natural | Inseminación Artificial (solo si accion=registrar_servicio_reproductivo)",
  "semental": "nombre o arete del semental/pajilla (solo si accion=registrar_servicio_reproductivo)",
  "evento": "descripción del evento o vacío",
  "detalles": "datos adicionales",
  "resumen_confirmacion": "Ejemplo: 'Voy a registrar un animal Nelore, arete 285, pierna 3. No mencionaste el propósito, pondré Reproductora.'"
}

═══════════════════════════════════════
EJEMPLOS DE INTERPRETACIÓN DE MULETILLAS
═══════════════════════════════════════
Entrada: "Este... a ver, quiero que agregues un animal nuevo... mmm, ponle que es Nelore, de arete 285 sobre 3, para engorda."
Salida Esperada: {"accion":"crear_animal","animal":"285/3","arete":"285","pierna":"3","raza":"Nelore","sexo":"Hembra","proposito":"Engorda","fecha_nacimiento":"$today","peso":"","vacuna":"","evento":"","detalles":"","resumen_confirmacion":"Voy a registrar un animal Nelore para engorda, arete 285 y pierna 3. No mencionaste el sexo, pondré Hembra."}

Entrada: "Fíjate que vendí al toro Angus número 45, dalo de baja por favor."
Salida Esperada: {"accion":"eliminar_animal","animal":"45","arete":"45","pierna":"Sin pierna","raza":"Angus","sexo":"Macho","proposito":"Reproductora","fecha_nacimiento":"$today","peso":"","vacuna":"","evento":"","detalles":"Vendido","resumen_confirmacion":"Voy a dar de baja al toro Angus con arete 45 — te voy a pedir que confirmes el motivo exacto"}

Entrada: "Anota que pesamos a la vaca pinta de la pierna 12 y nos dio 450 kilos."
Salida Esperada: {"accion":"registrar_peso","animal":"12","arete":"Sin arete","pierna":"12","raza":"Otro","sexo":"Hembra","proposito":"Reproductora","fecha_nacimiento":"$today","peso":"450","vacuna":"","evento":"","detalles":"pinta","resumen_confirmacion":"Voy a registrar un peso de 450 kilos para la vaca de pierna 12"}

Entrada: "Apunta que a la vaca 20 la monté con el toro Brangus 7."
Salida Esperada: {"accion":"registrar_servicio_reproductivo","animal":"20","arete":"20","pierna":"Sin pierna","raza":"Otro","sexo":"Hembra","proposito":"Reproductora","fecha_nacimiento":"$today","peso":"","vacuna":"","tipo_servicio":"Monta Natural","semental":"7","evento":"","detalles":"","resumen_confirmacion":"Voy a registrar monta natural de la vaca 20 con el semental 7, hoy"}

TEXTO DEL GANADERO A PROCESAR:
"$spokenText"
''';

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 1000,
            // Fuerza a Gemini a responder SIEMPRE con JSON válido (sin markdown
            // ni texto extra). Esto elimina la causa #1 de fallos del asistente.
            "responseMimeType": "application/json",
          },
        }),
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);

        // Gemini puede no devolver candidatos (bloqueo de seguridad, respuesta
        // vacía, etc.). Validamos toda la cadena para no crashear.
        final candidates = body['candidates'];
        if (candidates is! List || candidates.isEmpty) {
          debugPrint("Sin candidatos en la respuesta: ${resp.body}");
          return null;
        }
        final parts = candidates[0]?['content']?['parts'];
        if (parts is! List || parts.isEmpty) {
          debugPrint("Respuesta sin contenido: ${resp.body}");
          return null;
        }
        final rawText = parts[0]?['text'];
        if (rawText is! String || rawText.trim().isEmpty) return null;

        // Con responseMimeType=application/json normalmente ya viene limpio,
        // pero dejamos el limpiador como red de seguridad por si acaso.
        final cleanText =
            rawText.replaceAll('```json', '').replaceAll('```', '').trim();

        try {
          final decoded = jsonDecode(cleanText);
          return decoded is Map<String, dynamic> ? decoded : null;
        } catch (e) {
          debugPrint("💥 Error al convertir a JSON: $e");
          debugPrint("💥 Texto que intentó convertir: $cleanText");
          return null;
        }
      } else {
        debugPrint("Error HTTP ${resp.statusCode}: ${resp.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Excepción general en AIVoiceService: $e");
      return null;
    }
  }
}
