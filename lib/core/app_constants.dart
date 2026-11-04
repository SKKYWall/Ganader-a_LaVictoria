// lib/core/app_constants.dart
//
// Valores que debes configurar antes de publicar en Play Store / App Store.
// Busca los comentarios "TODO:" para saber qué cambiar.

class AppConstants {
  // ── Soporte ────────────────────────────────────────────────────────────────

  /// Número de WhatsApp de soporte (formato internacional sin +).
  /// TODO: reemplaza con tu número real antes de publicar.
  static const String supportWhatsApp = '521XXXXXXXXXX'; // TODO: pon tu número

  /// Mensaje predeterminado al abrir el chat de soporte.
  static const String supportWhatsAppMessage =
      'Hola, necesito ayuda con Manual Ganadero Pro';

  /// URL completa de WhatsApp de soporte.
  static String get supportWhatsAppUrl =>
      'https://wa.me/$supportWhatsApp?text=${Uri.encodeComponent(supportWhatsAppMessage)}';

  /// Correo electrónico de soporte.
  static const String supportEmail = 'soportemanualganadero@gmail.com';

  // ── Legal ──────────────────────────────────────────────────────────────────

  /// URL pública de la Política de Privacidad.
  /// Registrada también en Play Console → Configuración del app.
  static const String privacyPolicyUrl =
      'https://sites.google.com/view/politicasprivacidad-manualg/p%C3%A1gina-principal';

  /// URL pública de los Términos y Condiciones.
  static const String termsUrl =
      'https://sites.google.com/view/terminosycondiciones-manualg/p%C3%A1gina-principal';

  // ── App Store / Play Store ─────────────────────────────────────────────────

  /// Enlace directo a la app en Play Store.
  /// Apunta al applicationId real del proyecto (com.lavictoria.ganaderia).
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.lavictoria.ganaderia';

  /// Enlace directo a la app en App Store.
  /// TODO: reemplaza con el enlace real una vez publicada.
  static const String appStoreUrl =
      'https://apps.apple.com/app/manual-ganadero/idXXXXXXXXX';

  // ── Versión ────────────────────────────────────────────────────────────────
  static const String appVersion = '1.0.0';
}
