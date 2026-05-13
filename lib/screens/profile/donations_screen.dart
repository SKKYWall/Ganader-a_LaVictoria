// lib/screens/profile/donations_screen.dart
//
// ════════════════════════════════════════════════════════════════
//  SETUP REQUERIDO ANTES DE USAR:
//
//  1. pubspec.yaml → ya incluido:
//     in_app_purchase: ^3.2.0
//     in_app_purchase_android: ^0.3.5
//
//  2. Play Console → Monetización → Productos en la aplicación:
//
//     Tipo CONSUMABLE (se puede comprar varias veces):
//       consults_pack_50   → MX$49.00  → "50 Consultas IA"
//       consults_pack_100  → MX$99.00  → "100 Consultas IA"
//       consults_pack_150  → MX$120.00 → "150 Consultas IA"
//
//     Tipo SUSCRIPCIÓN (mensual):
//       premium_monthly    → MX$150.00/mes → "Premium Ilimitado"
//
//  3. Play Console → Configuración → Licencias:
//     Agrega tu correo como "Licenciante de prueba" para
//     probar sin cobro real en un dispositivo físico.
//
//  4. Sube al menos un APK/AAB firmado al track de Prueba Interna
//     antes de que las IAP funcionen.
//
//  5. Reglas de Firebase → agregar la subcollección purchases:
//     match /users/{userId}/purchases/{purchaseId} {
//       allow read, write: if request.auth != null && request.auth.uid == userId;
//     }
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:manual_ganadero_flutter/services/quota_service.dart';

const String kPack50 = 'consults_pack_50';
const String kPack100 = 'consults_pack_100';
const String kPack150 = 'consults_pack_150';
const String kPremiumMonthly = 'premium_monthly';
const Set<String> _kProductIds = {kPack50, kPack100, kPack150, kPremiumMonthly};
const Map<String, int> _kConsultsPerPack = {
  kPack50: 50,
  kPack100: 100,
  kPack150: 150,
};

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});
  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  static const Color _brown = Color(0xFF5e3a1c);
  static const Color _gold = Color(0xFFc99450);
  static const Color _cream = Color(0xFFfbf6ec);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _iapAvailable = false;
  bool _isLoadingProducts = true;
  String? _purchasingId;

  QuotaStatus? _quotaStatus;
  bool _isLoadingQuota = true;

  @override
  void initState() {
    super.initState();
    _initIAP();
    _loadQuota();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadQuota() async {
    final status = await QuotaService.getStatus();
    if (mounted) {
      setState(() {
        _quotaStatus = status;
        _isLoadingQuota = false;
      });
    }
  }

  Future<void> _initIAP() async {
    // Timeout de seguridad: si algo falla silenciosamente, mostrar pantalla igual
    try {
      await _initIAPInternal().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('IAP: timeout al inicializar, mostrando pantalla sin IAP');
          if (mounted) {
            setState(() {
              _iapAvailable = false;
              _isLoadingProducts = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('IAP: error general al inicializar: $e');
      if (mounted) {
        setState(() {
          _iapAvailable = false;
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _initIAPInternal() async {
    final available = await _iap.isAvailable();
    if (!available) {
      if (mounted) {
        setState(() {
          _iapAvailable = false;
          _isLoadingProducts = false;
        });
      }
      return;
    }

    // Suscribirse al stream de compras ANTES de cualquier operación
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (e) => debugPrint('IAP stream error: $e'),
    );

    // restorePurchases puede colgar en entornos sin Play Store real
    // lo hacemos con timeout propio para no bloquear la carga de productos
    try {
      await _iap.restorePurchases().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('IAP: restorePurchases falló o tardó demasiado: $e');
    }

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(_kProductIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
            '⚠️ IDs no encontrados en Play Console: ${response.notFoundIDs}\n'
            'Verifica que los productos estén publicados y el APK subido.');
      }

      if (mounted) {
        final ordered = response.productDetails.toList()
          ..sort((a, b) {
            final order = [kPack50, kPack100, kPack150, kPremiumMonthly];
            return order.indexOf(a.id).compareTo(order.indexOf(b.id));
          });
        setState(() {
          _iapAvailable = true;
          _isLoadingProducts = false;
          _products = ordered;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar productos IAP: $e');
      if (mounted) {
        setState(() {
          _iapAvailable = false;
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _purchasingId = purchase.productID);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final valid = await _verifyAndGrant(purchase);
          if (valid) {
            await _iap.completePurchase(purchase);
            if (mounted) {
              setState(() => _purchasingId = null);
              await _loadQuota();
              _showSuccessDialog(purchase.productID);
            }
          } else {
            // Completar igual para no dejar la compra pendiente
            await _iap.completePurchase(purchase);
            if (mounted) setState(() => _purchasingId = null);
          }
          break;

        case PurchaseStatus.error:
          if (mounted) {
            setState(() => _purchasingId = null);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Error en la compra: ${purchase.error?.message ?? "Inténtalo de nuevo"}'),
              backgroundColor: Colors.red,
            ));
          }
          await _iap.completePurchase(purchase);
          break;

        case PurchaseStatus.canceled:
          if (mounted) setState(() => _purchasingId = null);
          await _iap.completePurchase(purchase);
          break;
      }
    }
  }

  Future<bool> _verifyAndGrant(PurchaseDetails purchase) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Error: usuario no autenticado al otorgar compra');
        return false;
      }

      final productId = purchase.productID;
      final transactionId = purchase.purchaseID ?? 'unknown';
      final now = DateTime.now();

      if (_kConsultsPerPack.containsKey(productId)) {
        final amount = _kConsultsPerPack[productId]!;

        // Calcular fecha de caducidad: 12 meses exactos desde hoy
        final expiryMonth = now.month + QuotaService.kPaidExpiryMonths;
        final expiry = DateTime(
          now.year + ((expiryMonth - 1) ~/ 12),
          ((expiryMonth - 1) % 12) + 1,
          now.day,
        );

        // Agregar lote con caducidad al servicio de cuota
        await QuotaService.addPaidConsults(amount);

        // Registrar en historial con la fecha de vencimiento visible
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('purchases')
            .doc(transactionId)
            .set({
          'productId': productId,
          'consultsAdded': amount,
          'purchaseDate': FieldValue.serverTimestamp(),
          'expiryDate': Timestamp.fromDate(expiry),
          'transactionId': transactionId,
          'status': 'completed',
        });
      } else if (productId == kPremiumMonthly) {
        await QuotaService.activatePremium(months: 1);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('purchases')
            .doc(transactionId)
            .set({
          'productId': productId,
          'type': 'subscription',
          'purchaseDate': FieldValue.serverTimestamp(),
          'premiumLimit': QuotaService.kPremiumMonthlyLimit, // registrar límite
          'transactionId': transactionId,
          'status': 'completed',
        });
      } else {
        debugPrint('Producto desconocido: $productId');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error al otorgar compra: $e');
      return false;
    }
  }

  Future<void> _buy(ProductDetails product) async {
    if (_purchasingId != null) return;
    setState(() => _purchasingId = product.id);

    try {
      final isPremium = product.id == kPremiumMonthly;
      final param = PurchaseParam(productDetails: product);
      if (isPremium) {
        await _iap.buyNonConsumable(purchaseParam: param);
      } else {
        await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _purchasingId = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo iniciar la compra: $e'),
            backgroundColor: Colors.red));
      }
    }
    // NOTA: No limpiar _purchasingId aquí. Se limpia en _onPurchaseUpdate
    // cuando llegue la confirmación (purchased/error/canceled).
  }

  void _showSuccessDialog(String productId) {
    final isPremium = productId == kPremiumMonthly;
    final consults = _kConsultsPerPack[productId];

    // Calcular fecha de vencimiento para mostrar al usuario
    String expiryText = '';
    if (!isPremium && consults != null) {
      final now = DateTime.now();
      final expiryMonth = now.month + QuotaService.kPaidExpiryMonths;
      final expiry = DateTime(
        now.year + ((expiryMonth - 1) ~/ 12),
        ((expiryMonth - 1) % 12) + 1,
        now.day,
      );
      expiryText =
          'Válidas hasta el ${expiry.day}/${expiry.month}/${expiry.year}.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 40)),
          const SizedBox(height: 16),
          Text(isPremium ? '¡Premium activado!' : '¡Consultas agregadas!',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _brown)),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'Consultas ilimitadas por 30 días. ¡Disfruta!'
                : 'Se agregaron $consults consultas a tu cuenta.\n$expiryText',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('¡Listo!',
                style: TextStyle(color: _gold, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: _brown),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Consultas y Premium',
            style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoadingProducts
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuotaCard(),
                    const SizedBox(height: 24),

                    if (!_iapAvailable) ...[
                      _buildIapBanner(),
                      const SizedBox(height: 16),
                    ],

                    // ── Paquetes ──────────────────────────────────────────────
                    const Text('🛒 Paquetes de consultas',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _brown)),
                    const SizedBox(height: 4),
                    Text(
                        'Pago único · Sin caducidad · Sin renovación automática',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),

                    _buildPackage(
                        productId: kPack50,
                        consults: 50,
                        label: '50 Consultas',
                        description: 'Para uso ocasional',
                        popular: false),
                    const SizedBox(height: 10),
                    _buildPackage(
                        productId: kPack100,
                        consults: 100,
                        label: '100 Consultas',
                        description: 'El más comprado · Ahorra 25%',
                        popular: true),
                    const SizedBox(height: 10),
                    _buildPackage(
                        productId: kPack150,
                        consults: 150,
                        label: '150 Consultas',
                        description: 'Para ranchos grandes · Ahorra 40%',
                        popular: false),

                    const SizedBox(height: 28),

                    // ── Premium ───────────────────────────────────────────────
                    const Text('⭐ Suscripción Premium',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _brown)),
                    const SizedBox(height: 4),
                    Text('Consultas ilimitadas · Cancela cuando quieras',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    _buildPremiumCard(),

                    const SizedBox(height: 20),

                    // ── Nota legal ────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'Los pagos se procesan a través de Google Play. La suscripción '
                        'Premium se renueva cada mes automáticamente. Puedes cancelarla '
                        'en Ajustes de Google Play → Suscripciones.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ]),
            ),
    );
  }

  Widget _buildQuotaCard() {
    if (_isLoadingQuota) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    final q = _quotaStatus;
    if (q == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: q.premiumActive
              ? [Colors.green.shade700, Colors.green.shade500]
              : [_brown, const Color(0xFF8B5E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(q.premiumActive ? Icons.workspace_premium : Icons.psychology,
              color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(q.premiumActive ? 'Premium Activo' : 'Tu cuenta',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _statPill(
              '${q.monthlyRemaining}/${q.monthlyFree}', 'gratis este mes'),
          const SizedBox(width: 8),
          _statPill('${q.paidConsults}', 'pagadas'),
          if (q.premiumActive && q.premiumExpiry != null) ...[
            const SizedBox(width: 8),
            _statPill('hasta ${q.premiumExpiry!.day}/${q.premiumExpiry!.month}',
                'premium'),
          ],
        ]),
        // Mostrar vencimiento del lote más próximo si tiene consultas pagadas
        if (!q.premiumActive &&
            q.paidConsults > 0 &&
            q.nearestPaidExpiry != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.schedule, color: Colors.white54, size: 12),
            const SizedBox(width: 4),
            Text(
              'Consultas pagadas válidas hasta '
              '${q.nearestPaidExpiry!.day}/${q.nearestPaidExpiry!.month}/${q.nearestPaidExpiry!.year}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _statPill(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
      );

  Widget _buildPackage({
    required String productId,
    required int consults,
    required String label,
    required String description,
    required bool popular,
  }) {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    final isBuying = _purchasingId == productId;
    final price = product?.price ?? '...';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: popular ? _gold.withOpacity(0.07) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: popular ? _gold : Colors.grey.shade200,
            width: popular ? 2 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (popular)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: _gold, borderRadius: BorderRadius.circular(10)),
              child: const Text('MÁS POPULAR',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          Text(label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _brown)),
          Text(description,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ])),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(price,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _brown)),
          const Text('pago único',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 6),
          SizedBox(
            width: 90,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: popular ? _gold : _brown,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (product == null || isBuying || !_iapAvailable)
                  ? null
                  : () => _buy(product),
              child: isBuying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Comprar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildPremiumCard() {
    final product = _products.where((p) => p.id == kPremiumMonthly).firstOrNull;
    final isBuying = _purchasingId == kPremiumMonthly;
    final price = product?.price ?? '...';
    final alreadyPremium = _quotaStatus?.premiumActive ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF5e3a1c), Color(0xFF8B5E3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.workspace_premium, color: _gold, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Premium Mensual',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Text('Consultas ilimitadas',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(price,
                style: const TextStyle(
                    color: _gold, fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('/mes',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 14),
        _benefit('✓ Consultas ilimitadas de IA'),
        _benefit('✓ Sin límite diario'),
        _benefit('✓ Cancela cuando quieras desde Google Play'),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: alreadyPremium ? Colors.green : _gold,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed:
                alreadyPremium || product == null || isBuying || !_iapAvailable
                    ? null
                    : () => _buy(product),
            child: isBuying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(alreadyPremium ? '✓ Premium Activo' : 'Activar Premium',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _benefit(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      );

  Widget _buildIapBanner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Text('Compras disponibles en dispositivo Android',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Las compras con Google Play funcionan únicamente en un dispositivo '
            'Android real con la app instalada desde Play Store (o Prueba Interna). '
            'Si estás en web o emulador, los botones se mostrarán deshabilitados.',
            style: TextStyle(
                fontSize: 12, color: Colors.blue.shade900, height: 1.4),
          ),
        ]),
      );
}
