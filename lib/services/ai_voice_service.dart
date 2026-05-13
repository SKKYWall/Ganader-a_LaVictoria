// lib/services/ai_voice_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AIVoiceService {
  static const String _apiKey = 'AIzaSyAkZoz1w2vzl9lEMGqKP0fzBnhUXvoq94w';

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

═══════════════════════════════════════
DICCIONARIO DE INTENCIONES (Cómo deduce la acción)
═══════════════════════════════════════
- "crear_animal": "quiero registrar...", "agrega un...", "mete una vaca", "da de alta", "apunta este becerro", "nuevo animal".
- "editar_animal": "cámbiale el dato...", "corrige a...", "actualiza el", "me equivoqué, modifícalo".
- "eliminar_animal": "borra a...", "saca al...", "da de baja", "vendí al...", "se murió el...", "elimina".
- "registrar_peso": "pesó...", "dio en la báscula...", "anótale un peso de...", "pesa".
- "registrar_vacuna": "le puse la...", "apliqué...", "vacuné contra...", "inyecté".
- "registrar_evento": "parió", "se enfermó", "revisión", "lo castramos".

═══════════════════════════════════════
GUÍA DE EXTRACCIÓN Y VALORES POR DEFECTO
═══════════════════════════════════════
1. NOTACIÓN "SOBRE": Si dice "285 sobre 3", "285 diagonal 3" o "285 raya 3" -> arete=285, pierna=3. Nombre del animal="285/3".
2. ARETE / PIERNA: Si no menciona arete -> "Sin arete". Si no menciona pierna -> "Sin pierna".
3. SEXO (OBLIGATORIO): Si dice vaca, becerra, novilla -> "Hembra". Si dice toro, becerro, semental -> "Macho". Si no lo menciona o no es claro -> "Hembra" (Defecto).
4. RAZA (OBLIGATORIO): Valores permitidos: Nelore, Angus, Brangus, Brahman, Brahman Rojo, Hereford, Charolais, Simmental, Limousin, Holstein, Jersey, Suizo Pardo, Guzerat, Indubrasil, Beefmaster, Santa Gertrudis, Texas Longhorn, Cebú, Otro. Si no dice una de estas o no menciona -> "Otro" (Defecto).
5. PROPÓSITO (OBLIGATORIO): Valores permitidos: Leche, Carne, Genética, Engorda, Reproductora. Si no menciona -> "Reproductora" (Defecto).
6. FECHA DE NACIMIENTO: Si no menciona una fecha específica -> "$today".

═══════════════════════════════════════
ESTRUCTURA JSON DE RESPUESTA
═══════════════════════════════════════
{
  "accion": "crear_animal | editar_animal | eliminar_animal | registrar_peso | registrar_vacuna | registrar_evento",
  "animal": "nombre o identificador principal",
  "arete": "número exacto, o 'Sin arete'",
  "pierna": "número exacto, o 'Sin pierna'",
  "raza": "valor válido de la lista",
  "sexo": "Macho | Hembra",
  "proposito": "valor válido de la lista",
  "fecha_nacimiento": "dd/MM/yyyy o '$today'",
  "peso": "número en kg o vacío",
  "vacuna": "nombre de la vacuna o vacío",
  "evento": "descripción del evento o vacío",
  "detalles": "datos adicionales",
  "resumen_confirmacion": "Ejemplo: 'Voy a registrar un animal Nelore, arete 285, pierna 3'"
}

═══════════════════════════════════════
EJEMPLOS DE INTERPRETACIÓN DE MULETILLAS
═══════════════════════════════════════
Entrada: "Este... a ver, quiero que agregues un animal nuevo... mmm, ponle que es Nelore, de arete 285 sobre 3, para engorda."
Salida Esperada: {"accion":"crear_animal","animal":"285/3","arete":"285","pierna":"3","raza":"Nelore","sexo":"Hembra","proposito":"Engorda","fecha_nacimiento":"$today","peso":"","vacuna":"","evento":"","detalles":"","resumen_confirmacion":"Voy a registrar un animal Nelore para engorda, arete 285 y pierna 3"}

Entrada: "Fíjate que vendí al toro Angus número 45, dalo de baja por favor."
Salida Esperada: {"accion":"eliminar_animal","animal":"45","arete":"45","pierna":"Sin pierna","raza":"Angus","sexo":"Macho","proposito":"Reproductora","fecha_nacimiento":"$today","peso":"","vacuna":"","evento":"","detalles":"Vendido","resumen_confirmacion":"Voy a dar de baja al toro Angus con arete 45"}

Entrada: "Anota que pesamos a la vaca pinta de la pierna 12 y nos dio 450 kilos."
Salida Esperada: {"accion":"registrar_peso","animal":"12","arete":"Sin arete","pierna":"12","raza":"Otro","sexo":"Hembra","proposito":"Reproductora","fecha_nacimiento":"$today","peso":"450","vacuna":"","evento":"","detalles":"pinta","resumen_confirmacion":"Voy a registrar un peso de 450 kilos para la vaca de pierna 12"}

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
          },
        }),
      );

      if (resp.statusCode == 200) {
        final rawText = jsonDecode(resp.body)['candidates'][0]['content']
            ['parts'][0]['text'];

        // 🌟 EL LIMPIADOR MÁGICO: Quita las "```json" y "```" que provocan el FormatException
        final cleanText =
            rawText.replaceAll('```json', '').replaceAll('```', '').trim();

        try {
          return jsonDecode(cleanText);
        } catch (e) {
          print("💥 Error al convertir a JSON: $e");
          print("💥 Texto limpio que intentó convertir: $cleanText");
          return null;
        }
      } else {
        print("Error HTTP ${resp.statusCode}: ${resp.body}");
        return null;
      }
    } catch (e) {
      print("Excepción general en AIVoiceService: $e");
      return null;
    }
  }
}
