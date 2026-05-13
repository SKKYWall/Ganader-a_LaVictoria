// lib/services/quota_service.dart
//
// Estructura en Firestore  →  users/{uid}.quota (Map)
// {
//   monthKey:         "2025-04"        ← mes actual (yyyy-MM)
//   monthlyUsed:      7                ← gratuitas usadas este mes
//   premiumMonthKey:  "2025-04"        ← mes del contador invisible premium
//   premiumMonthUsed: 42               ← uso premium este mes
//   isPremium:        false
//   premiumExpiry:    Timestamp|null
//
//   paidBatches: [                     ← lista de lotes comprados
//     { amount: 50,  expiry: Timestamp, purchased: Timestamp },
//     { amount: 100, expiry: Timestamp, purchased: Timestamp },
//   ]
// }
//
// MIGRACIÓN AUTOMÁTICA: si un usuario tenía el campo legacy 'paidConsults'
// (número entero), se convierte automáticamente a un lote con 12 meses
// desde la primera vez que abre la app con esta versión.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo: lote de consultas pagadas
// ─────────────────────────────────────────────────────────────────────────────
class PaidBatch {
  final int amount;
  final DateTime expiry;
  final DateTime purchased;

  const PaidBatch({
    required this.amount,
    required this.expiry,
    required this.purchased,
  });

  bool get isValid => expiry.isAfter(DateTime.now()) && amount > 0;

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'expiry': Timestamp.fromDate(expiry),
        'purchased': Timestamp.fromDate(purchased),
      };

  static PaidBatch fromMap(Map<String, dynamic> m) => PaidBatch(
        amount: m['amount'] as int? ?? 0,
        expiry: m['expiry'] is Timestamp
            ? (m['expiry'] as Timestamp).toDate()
            : DateTime.now(),
        purchased: m['purchased'] is Timestamp
            ? (m['purchased'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado de cuota del usuario
// ─────────────────────────────────────────────────────────────────────────────
class QuotaStatus {
  final int monthlyUsed;
  final int monthlyFree;
  final List<PaidBatch> paidBatches;
  final bool isPremium;
  final DateTime? premiumExpiry;
  final int premiumMonthUsed;

  const QuotaStatus({
    required this.monthlyUsed,
    required this.monthlyFree,
    required this.paidBatches,
    required this.isPremium,
    this.premiumExpiry,
    this.premiumMonthUsed = 0,
  });

  bool get premiumActive =>
      isPremium &&
      premiumExpiry != null &&
      premiumExpiry!.isAfter(DateTime.now());

  /// Consultas gratuitas restantes este mes
  int get monthlyRemaining => (monthlyFree - monthlyUsed).clamp(0, monthlyFree);

  /// Total de consultas pagadas vigentes (suma de lotes no vencidos)
  int get paidConsults =>
      paidBatches.where((b) => b.isValid).fold(0, (s, b) => s + b.amount);

  /// Lotes vigentes ordenados por el que vence más pronto primero
  List<PaidBatch> get activeBatches =>
      (paidBatches.where((b) => b.isValid).toList()
        ..sort((a, b) => a.expiry.compareTo(b.expiry)));

  /// Fecha de vencimiento del lote más próximo a expirar
  DateTime? get nearestPaidExpiry =>
      activeBatches.isNotEmpty ? activeBatches.first.expiry : null;

  /// ¿Puede enviar un mensaje?
  bool get canSend {
    if (premiumActive) {
      return premiumMonthUsed < QuotaService.kPremiumMonthlyLimit;
    }
    return monthlyRemaining > 0 || paidConsults > 0;
  }

  ConsultSource get nextSource {
    if (premiumActive && premiumMonthUsed < QuotaService.kPremiumMonthlyLimit) {
      return ConsultSource.premium;
    }
    if (monthlyRemaining > 0) return ConsultSource.monthly;
    if (paidConsults > 0) return ConsultSource.paid;
    return ConsultSource.none;
  }

  String get statusLabel {
    if (premiumActive) return '∞ Premium activo';
    final parts = <String>[];
    if (monthlyRemaining > 0) parts.add('$monthlyRemaining gratis este mes');
    if (paidConsults > 0) parts.add('$paidConsults pagadas');
    if (parts.isEmpty) return 'Sin consultas disponibles';
    return parts.join(' · ');
  }

  String get usageDetail {
    if (premiumActive) return 'Sin límite';
    return '$monthlyUsed/$monthlyFree usadas este mes';
  }
}

enum ConsultSource { premium, monthly, paid, none }

// ─────────────────────────────────────────────────────────────────────────────
// QuotaService
// ─────────────────────────────────────────────────────────────────────────────
class QuotaService {
  /// Consultas gratuitas mensuales (plan free)
  static const int kMonthlyFree = 15;

  /// Límite invisible mensual para Premium
  /// 1500/mes ≈ 50/día → protege de abuso sin afectar uso real de un ganadero
  static const int kPremiumMonthlyLimit = 1500;

  /// Meses de caducidad de los paquetes pagados
  static const int kPaidExpiryMonths = 12;

  static String _monthKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  static DocumentReference<Map<String, dynamic>> _userRef() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  // ── Leer estado actual ─────────────────────────────────────────────────────
  static Future<QuotaStatus> getStatus() async {
    try {
      final doc = await _userRef().get();
      final data = doc.data() ?? {};
      final quota = data['quota'] as Map<String, dynamic>? ?? {};

      final currentMonth = _monthKey();

      // Cuota gratuita mensual
      final savedMonth = quota['monthKey'] as String? ?? '';
      final monthlyUsed =
          savedMonth == currentMonth ? (quota['monthlyUsed'] as int? ?? 0) : 0;

      // Premium
      final isPremium = quota['isPremium'] as bool? ?? false;
      final premiumTs = quota['premiumExpiry'];
      final premiumExpiry = premiumTs is Timestamp ? premiumTs.toDate() : null;

      // Contador invisible premium (se resetea cada mes)
      final premiumMonthKey = quota['premiumMonthKey'] as String? ?? '';
      final premiumMonthUsed = premiumMonthKey == currentMonth
          ? (quota['premiumMonthUsed'] as int? ?? 0)
          : 0;

      // Lotes de consultas pagadas
      final List<PaidBatch> batches = [];

      // Migración automática: campo legacy 'paidConsults' como número entero
      final legacyPaid = quota['paidConsults'];
      if (legacyPaid is int && legacyPaid > 0) {
        final expiry = DateTime.now().add(const Duration(days: 365));
        batches.add(PaidBatch(
          amount: legacyPaid,
          expiry: expiry,
          purchased: DateTime.now(),
        ));
        // Migrar en background (sin await para no bloquear la UI)
        _migrateLegacyPaidConsults(legacyPaid, expiry);
      } else {
        final rawBatches = quota['paidBatches'];
        if (rawBatches is List) {
          for (final item in rawBatches) {
            if (item is Map<String, dynamic>) {
              final b = PaidBatch.fromMap(item);
              if (b.isValid) batches.add(b);
            }
          }
        }
      }

      return QuotaStatus(
        monthlyUsed: monthlyUsed,
        monthlyFree: kMonthlyFree,
        paidBatches: batches,
        isPremium: isPremium,
        premiumExpiry: premiumExpiry,
        premiumMonthUsed: premiumMonthUsed,
      );
    } catch (_) {
      // Sin conexión → bloquear todo por seguridad
      return QuotaStatus(
        monthlyUsed: kMonthlyFree,
        monthlyFree: kMonthlyFree,
        paidBatches: const [],
        isPremium: false,
        premiumMonthUsed: kPremiumMonthlyLimit,
      );
    }
  }

  // ── Migración silenciosa del campo legacy ─────────────────────────────────
  static Future<void> _migrateLegacyPaidConsults(
      int amount, DateTime expiry) async {
    try {
      await _userRef().set({
        'quota': {
          'paidConsults': FieldValue.delete(),
          'paidBatches': FieldValue.arrayUnion([
            {
              'amount': amount,
              'expiry': Timestamp.fromDate(expiry),
              'purchased': Timestamp.fromDate(DateTime.now()),
            }
          ]),
        }
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Consumir una consulta (llamar DESPUÉS de respuesta exitosa de la IA) ───
  static Future<bool> consumeConsult() async {
    final status = await getStatus();
    if (!status.canSend) return false;

    final currentMonth = _monthKey();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final ref = _userRef();
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final quota = Map<String, dynamic>.from(data['quota'] as Map? ?? {});

      final savedMonth = quota['monthKey'] as String? ?? '';
      final currentMonthlyUsed =
          savedMonth == currentMonth ? (quota['monthlyUsed'] as int? ?? 0) : 0;

      final isPremium = quota['isPremium'] as bool? ?? false;
      final premiumTs = quota['premiumExpiry'];
      final premiumActive = isPremium &&
          premiumTs is Timestamp &&
          premiumTs.toDate().isAfter(DateTime.now());

      if (premiumActive) {
        // Premium: incrementar contador mensual invisible
        final premiumMonthKey = quota['premiumMonthKey'] as String? ?? '';
        final currentPremiumUsed = premiumMonthKey == currentMonth
            ? (quota['premiumMonthUsed'] as int? ?? 0)
            : 0;
        if (currentPremiumUsed >= kPremiumMonthlyLimit) return; // bloqueado
        quota['premiumMonthKey'] = currentMonth;
        quota['premiumMonthUsed'] = currentPremiumUsed + 1;
      } else if (currentMonthlyUsed < kMonthlyFree) {
        // Gratuitas mensuales
        quota['monthKey'] = currentMonth;
        quota['monthlyUsed'] = currentMonthlyUsed + 1;
      } else {
        // Consultas pagadas: descontar del lote que vence más pronto
        final rawBatches = quota['paidBatches'];
        if (rawBatches is! List || rawBatches.isEmpty) return;

        final now = DateTime.now();
        final batches = rawBatches
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();

        // Ordenar: el que vence antes, primero
        batches.sort((a, b) {
          final ea = a['expiry'] is Timestamp
              ? (a['expiry'] as Timestamp).toDate()
              : DateTime(2000);
          final eb = b['expiry'] is Timestamp
              ? (b['expiry'] as Timestamp).toDate()
              : DateTime(2000);
          return ea.compareTo(eb);
        });

        bool consumed = false;
        for (final batch in batches) {
          final expiry = batch['expiry'] is Timestamp
              ? (batch['expiry'] as Timestamp).toDate()
              : DateTime(2000);
          final amount = batch['amount'] as int? ?? 0;
          if (expiry.isAfter(now) && amount > 0) {
            batch['amount'] = amount - 1;
            consumed = true;
            break;
          }
        }
        if (!consumed) return;

        // Filtrar lotes vacíos o vencidos
        quota['paidBatches'] = batches
            .where((b) =>
                (b['amount'] as int? ?? 0) > 0 &&
                b['expiry'] is Timestamp &&
                (b['expiry'] as Timestamp).toDate().isAfter(now))
            .toList();

        quota['monthKey'] = currentMonth;
        quota['monthlyUsed'] = currentMonthlyUsed;
      }

      tx.set(ref, {'quota': quota}, SetOptions(merge: true));
    });

    return true;
  }

  // ── Agregar lote de consultas pagadas con caducidad de 12 meses ───────────
  static Future<void> addPaidConsults(int amount) async {
    final now = DateTime.now();
    // Calcular exactamente 12 meses adelante (respeta fin de mes correctamente)
    final expiryMonth = now.month + kPaidExpiryMonths;
    final expiry = DateTime(
      now.year + ((expiryMonth - 1) ~/ 12),
      ((expiryMonth - 1) % 12) + 1,
      now.day,
    );

    await _userRef().set({
      'quota': {
        'paidBatches': FieldValue.arrayUnion([
          {
            'amount': amount,
            'expiry': Timestamp.fromDate(expiry),
            'purchased': Timestamp.fromDate(now),
          }
        ]),
      }
    }, SetOptions(merge: true));
  }

  // ── Activar/renovar premium ────────────────────────────────────────────────
  static Future<void> activatePremium({int months = 1}) async {
    final expiry = DateTime.now().add(Duration(days: 30 * months));
    await _userRef().set({
      'quota': {
        'isPremium': true,
        'premiumExpiry': Timestamp.fromDate(expiry),
      }
    }, SetOptions(merge: true));
  }

  // ── Verificar y limpiar premium vencido ───────────────────────────────────
  static Future<void> checkPremiumExpiry() async {
    try {
      final doc = await _userRef().get();
      final quota = doc.data()?['quota'] as Map<String, dynamic>? ?? {};
      final isPremium = quota['isPremium'] as bool? ?? false;
      final premiumTs = quota['premiumExpiry'];
      if (isPremium &&
          premiumTs is Timestamp &&
          premiumTs.toDate().isBefore(DateTime.now())) {
        await _userRef().set({
          'quota': {'isPremium': false}
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // ── Limpiar lotes vencidos de Firestore ───────────────────────────────────
  // Llamar al abrir la app o al detectar que el mes cambió.
  // No es crítico — getStatus() los ignora automáticamente — pero mantiene
  // el documento limpio en Firestore.
  static Future<void> cleanExpiredBatches() async {
    try {
      final doc = await _userRef().get();
      final quota = doc.data()?['quota'] as Map<String, dynamic>? ?? {};
      final rawBatches = quota['paidBatches'];
      if (rawBatches is! List) return;

      final now = DateTime.now();
      final valid = rawBatches
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where((b) =>
              (b['amount'] as int? ?? 0) > 0 &&
              b['expiry'] is Timestamp &&
              (b['expiry'] as Timestamp).toDate().isAfter(now))
          .toList();

      if (valid.length < rawBatches.length) {
        await _userRef().set({
          'quota': {'paidBatches': valid}
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}
