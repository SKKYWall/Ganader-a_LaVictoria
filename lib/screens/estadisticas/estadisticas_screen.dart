import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    hide Transaction; // Hide Transaction to avoid conflict
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // ¡NUEVA IMPORTACIÓN para FontAwesomeIcons!

// Importa todos los modelos necesarios
import 'package:manual_ganadero_flutter/models/animal.dart';
import 'package:manual_ganadero_flutter/models/calendar.dart'; // CalendarEvent
import 'package:manual_ganadero_flutter/models/transaction.dart'; // Transaction
import 'package:manual_ganadero_flutter/models/product.dart'; // Product for Inventory
import 'package:manual_ganadero_flutter/models/marketplace_listing.dart'; // MarketplaceListing

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  String _errorMessage = '';

  // Data for Bovinos
  int _totalAnimals = 0;
  int _maleAnimals = 0;
  int _femaleAnimals = 0;
  Map<String, int> _animalsByBreed = {};
  Map<String, int> _animalsByStage = {}; // Asumiendo un campo 'stage' en Animal
  Map<String, int> _animalsByAgeGroup = {};

  // Data for Finanzas
  double _totalIncomeYear = 0.0;
  double _totalExpensesYear = 0.0;
  Map<int, double> _monthlyIncome = {};
  Map<int, double> _monthlyExpenses = {};
  Map<String, double> _expensesByCategory = {};

  // Data for Inventario
  int _inventoryTotalItems = 0;
  Map<String, int> _inventoryStockStatus = {
    'En Stock': 0,
    'Bajo Stock': 0,
    'Agotado': 0
  };
  // Map<String, int> _topUsedItems = {}; // Removed: Requires a field 'timesUsed' or 'quantitySold' in Product/Transaction

  // Data for Calendario
  int _totalUpcomingEvents = 0;
  Map<String, int> _upcomingEventsByType = {};

  // Data for Marketplace
  int _totalMarketplaceListings = 0;
  Map<String, int> _marketplaceListingsByAnimalBreed =
      {}; // Agrupado por raza de animal
  Map<String, int> _marketplaceListingsByStatus = {};

  // Data for IA
  int _totalAnalysisRecords = 0;
  Map<String, int> _aiResultsDistribution =
      {}; // Distribución de las etiquetas de resultados de IA

  @override
  void initState() {
    super.initState();
    _loadAllStatistics();
  }

  Future<void> _loadAllStatistics() async {
    if (_currentUser == null) {
      setState(() {
        _errorMessage = 'Usuario no autenticado.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await Future.wait([
        _loadBovinoStats(),
        _loadFinanceStats(),
        _loadInventoryStats(),
        _loadCalendarStats(),
        _loadMarketplaceStats(),
        _loadAIStats(), // Carga de estadísticas de IA
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar estadísticas: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBovinoStats() async {
    final animalSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('animals')
        .get();

    int males = 0;
    int females = 0;
    Map<String, int> breeds = {};
    Map<String, int> stages = {}; // Asumo un campo 'stage' en el modelo Animal.
    Map<String, int> ageGroups = {
      '0-6 meses': 0,
      '7-12 meses': 0,
      '1-2 años': 0,
      '+2 años': 0
    };

    for (var doc in animalSnapshot.docs) {
      final animal = Animal.fromFirestore(doc.data(), doc.id);

      if (animal.sex == 'Macho') {
        males++;
      } else if (animal.sex == 'Hembra') {
        females++;
      }

      final breed = animal.breed ?? 'Desconocida';
      breeds.update(breed, (value) => value + 1, ifAbsent: () => 1);

      // Si tienes un campo 'stage' en tu modelo Animal, úsalo aquí.
      // Por ahora, lo dejo como un placeholder.
      String animalStage =
          'No Definido'; // Placeholder si 'stage' no existe en Animal.dart o no está en Firestore
      // Ejemplo si tuvieras un campo 'stage':
      // final stageFromModel = data['stage'] as String?;
      // if (stageFromModel != null && stageFromModel.isNotEmpty) {
      //   animalStage = stageFromModel;
      // } else {
      //   // Podrías inferir la etapa de la edad si no hay un campo directo
      //   if (animal.age != null) {
      //     if (animal.age! <= 6) animalStage = 'Cría';
      //     else if (animal.age! <= 18) animalStage = 'Crecimiento';
      //     else animalStage = 'Adulto';
      //   }
      // }
      stages.update(animalStage, (value) => value + 1, ifAbsent: () => 1);

      // Calcular grupo de edad
      if (animal.birthDate != null) {
        final ageInDays = DateTime.now().difference(animal.birthDate!).inDays;
        final ageInMonths = ageInDays ~/ 30.4375; // Aproximado

        if (ageInMonths <= 6) {
          ageGroups['0-6 meses'] = (ageGroups['0-6 meses'] ?? 0) + 1;
        } else if (ageInMonths <= 12) {
          ageGroups['7-12 meses'] = (ageGroups['7-12 meses'] ?? 0) + 1;
        } else if (ageInMonths <= 24) {
          // 1-2 años
          ageGroups['1-2 años'] = (ageGroups['1-2 años'] ?? 0) + 1;
        } else {
          ageGroups['+2 años'] = (ageGroups['+2 años'] ?? 0) + 1;
        }
      }
    }

    if (mounted) {
      setState(() {
        _totalAnimals = animalSnapshot.docs.length;
        _maleAnimals = males;
        _femaleAnimals = females;
        _animalsByBreed = breeds;
        _animalsByStage = stages;
        _animalsByAgeGroup = ageGroups;
      });
    }
  }

  Future<void> _loadFinanceStats() async {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

    final financeSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: startOfYear)
        .where('date', isLessThanOrEqualTo: endOfYear)
        .get();

    double incomeYear = 0.0;
    double expensesYear = 0.0;
    Map<int, double> monthlyInc = {};
    Map<int, double> monthlyExp = {};
    Map<String, double> expByCategory = {};

    // Initialize monthly data for the current year to 0.0
    for (int i = 1; i <= 12; i++) {
      final monthKey = i + (now.year * 100);
      monthlyInc[monthKey] = 0.0;
      monthlyExp[monthKey] = 0.0;
    }

    for (var doc in financeSnapshot.docs) {
      final transaction = Transaction.fromFirestore(doc.data(), doc.id);

      final monthKey = transaction.date.month + (transaction.date.year * 100);
      if (transaction.type == 'income') {
        incomeYear += transaction.amount;
        monthlyInc[monthKey] =
            (monthlyInc[monthKey] ?? 0.0) + transaction.amount;
      } else if (transaction.type == 'expense') {
        expensesYear += transaction.amount;
        monthlyExp[monthKey] =
            (monthlyExp[monthKey] ?? 0.0) + transaction.amount;
        expByCategory.update(
            transaction.category, (value) => value + transaction.amount,
            ifAbsent: () => transaction.amount);
      }
    }

    if (mounted) {
      setState(() {
        _totalIncomeYear = incomeYear;
        _totalExpensesYear = expensesYear;
        _monthlyIncome = monthlyInc;
        _monthlyExpenses = monthlyExp;
        _expensesByCategory = expByCategory;
      });
    }
  }

  Future<void> _loadInventoryStats() async {
    final inventorySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection(
            'products') // Asumo 'products' como colección para el modelo Product
        .get();

    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;
    int totalItems = 0;
    // Map<String, int> _topUsedItems = {}; // Removed: Esto requeriría un seguimiento específico, placeholder por ahora

    for (var doc in inventorySnapshot.docs) {
      final product = Product.fromFirestore(doc.data(), doc.id);
      totalItems++;

      // Define un umbral simple para 'Bajo Stock' si no está explícitamente en el modelo
      // Para demostración, 'bajo stock' es <= 5 unidades.
      final minStockLevel = 5; // Umbral por defecto para bajo stock

      if (product.quantity <= 0) {
        outOfStock++;
      } else if (product.quantity <= minStockLevel) {
        lowStock++;
      } else {
        inStock++;
      }
      // Top Used Items: Esto requiere un campo como 'timesUsed' o 'quantitySold' en Product,
      // o un registro de ventas/uso separado. Por ahora, lo mantendré como un placeholder.
    }

    if (mounted) {
      setState(() {
        _inventoryTotalItems = totalItems;
        _inventoryStockStatus = {
          'En Stock': inStock,
          'Bajo Stock': lowStock,
          'Agotado': outOfStock
        };
      });
    }
  }

  Future<void> _loadCalendarStats() async {
    final now = DateTime.now();
    final sixMonthsFromNow = DateTime(
        now.year, now.month + 6, now.day); // Mirar 6 meses hacia adelante

    final calendarSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('calendarEvents') // Colección para CalendarEvent
        .where('date', isGreaterThanOrEqualTo: now)
        .where('date', isLessThanOrEqualTo: sixMonthsFromNow)
        .get();

    Map<String, int> eventTypes = {};
    int totalEvents = 0;

    for (var doc in calendarSnapshot.docs) {
      final calendarEvent = CalendarEvent.fromFirestore(doc.data(), doc.id);
      totalEvents++;
      final category = calendarEvent.category;
      eventTypes.update(category, (value) => value + 1, ifAbsent: () => 1);
    }

    if (mounted) {
      setState(() {
        _totalUpcomingEvents = totalEvents;
        _upcomingEventsByType = eventTypes;
      });
    }
  }

  Future<void> _loadMarketplaceStats() async {
    print(
        '[MARKETPLACE STATS DEBUG] Iniciando carga de estadísticas de Marketplace...');
    // Se filtra directamente por 'status' igual a 'activo' en Firestore
    final marketplaceSnapshot = await FirebaseFirestore.instance
        .collection('marketplace_listings')
        .where('status', whereIn: [
          'activo',
          'Activo',
          'active',
          'Active'
        ]) // Filtra por las variaciones comunes
        .where('ownerId',
            isEqualTo: _currentUser!.uid) // FILTRAR POR EL USUARIO ACTUAL
        .get();

    print(
        '[MARKETPLACE STATS DEBUG] Total documentos encontrados (filtrado por variaciones de "activo" y ownerId): ${marketplaceSnapshot.docs.length}');

    int totalListings = 0;
    Map<String, int> listingsByAnimalBreed = {};
    Map<String, int> listingsByStatus = {
      'activo': 0,
      'vendido': 0,
      'pausado': 0
    };

    for (var doc in marketplaceSnapshot.docs) {
      final listingData = doc.data();
      final status = listingData['status'] as String? ?? 'estado_desconocido';
      final animalId = listingData['animalId'] as String?;
      final ownerId = listingData['ownerId'] as String?;

      print(
          '[MARKETPLACE STATS DEBUG] Documento ID: ${doc.id}, Status en Firestore: "$status", Animal ID: "$animalId", Owner ID: "$ownerId"');

      // Solo contar como "activo" para las estadísticas si el status es EXACTAMENTE 'activo'
      if (status == 'activo') {
        totalListings++;
        listingsByStatus.update('activo', (value) => value + 1,
            ifAbsent: () => 1); // Contar como 'activo'
      } else if (status == 'vendido') {
        listingsByStatus.update('vendido', (value) => value + 1,
            ifAbsent: () => 1);
      } else if (status == 'pausado') {
        listingsByStatus.update('pausado', (value) => value + 1,
            ifAbsent: () => 1);
      } else {
        print(
            '[MARKETPLACE STATS DEBUG] Listing ${doc.id} con status "$status" (no es uno de los estados esperados).');
      }

      // Para obtener la raza, necesitamos cargar los datos del animal
      if (animalId != null && ownerId != null) {
        try {
          final animalDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(ownerId)
              .collection('animals')
              .doc(animalId)
              .get();
          if (animalDoc.exists) {
            final animal = Animal.fromFirestore(animalDoc.data()!,
                animalId); // Pass animalId as ID for consistency
            final breed = animal.breed ?? 'Desconocida';
            listingsByAnimalBreed.update(breed, (value) => value + 1,
                ifAbsent: () => 1);
            print(
                '[MARKETPLACE STATS DEBUG] Animal asociado encontrado para listing ${doc.id}: Raza "$breed"');
          } else {
            print(
                '[MARKETPLACE STATS DEBUG] No se encontró documento de animal para listing: ${doc.id} (animalId: $animalId)');
          }
        } catch (e) {
          print(
              '[MARKETPLACE STATS DEBUG] Error al obtener animal para listing ${doc.id}: $e');
        }
      } else {
        print(
            '[MARKETPLACE STATS DEBUG] Listing ${doc.id} no tiene animalId o ownerId, no se puede obtener la raza.');
      }
    }

    print(
        '[MARKETPLACE STATS DEBUG] Conteo final de publicaciones ACTIVAS: $totalListings');
    print(
        '[MARKETPLACE STATS DEBUG] Distribución final por estado: $listingsByStatus');
    print(
        '[MARKETPLACE STATS DEBUG] Distribución final por raza de animal (solo activos): $listingsByAnimalBreed');

    if (mounted) {
      setState(() {
        _totalMarketplaceListings = totalListings;
        _marketplaceListingsByAnimalBreed = listingsByAnimalBreed;
        _marketplaceListingsByStatus = listingsByStatus;
      });
    }
  }

  Future<void> _loadAIStats() async {
    // Asumiendo una colección 'analysis_records' dentro del documento del usuario
    final analysisSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection(
            'analysis_records') // De tu archivo intelligence_screen.dart
        .get();

    int totalRecords = 0;
    Map<String, int> resultsDistribution = {};

    for (var doc in analysisSnapshot.docs) {
      final data = doc.data();
      totalRecords++;
      final aiResult = data['aiResult'] as String? ?? 'Sin Clasificar';
      // A menudo los resultados de IA tienen porcentajes. Simplifiquemos la etiqueta para el conteo
      final cleanResult = aiResult
          .split(' (')[0]
          .replaceFirst('Detectado: ', ''); // "Detectado: X (YY%)" -> "X"
      resultsDistribution.update(cleanResult, (value) => value + 1,
          ifAbsent: () => 1);
    }

    if (mounted) {
      setState(() {
        _totalAnalysisRecords = totalRecords;
        _aiResultsDistribution = resultsDistribution;
      });
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return formatter.format(amount);
  }

  String _formatNumber(int number) {
    final formatter = NumberFormat('#,##0', 'es_MX');
    return formatter.format(number);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5e3a1c),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    IconData? icon,
    Color? iconColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5e3a1c),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      color: iconColor ?? const Color(0xFFc99450), size: 24),
                  const SizedBox(width: 8),
                ],
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6b4226),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartCard(
      String title, Map<String, int> data, List<Color> colors) {
    if (data.isEmpty || data.values.every((element) => element == 0)) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: Colors.white,
        child: SizedBox(
          height: 250,
          child: Center(
            child: Text('No hay datos de $title disponibles.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    final total = data.values.fold(0, (sum, item) => sum + item);
    List<PieChartSectionData> sections = [];
    int i = 0;
    data.forEach((key, value) {
      if (value > 0) {
        // Solo añadir secciones con valor > 0
        final percentage = (value / total * 100);
        sections.add(
          PieChartSectionData(
            color: colors[i % colors.length],
            value: value.toDouble(),
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: _buildPieChartBadge(key, colors[i % colors.length]),
            badgePositionPercentageOffset: 1.0,
          ),
        );
      }
      i++;
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c),
              ),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.5,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          return;
                        }
                        // Aquí puedes añadir lógica para mostrar detalles al tocar
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 5,
              children: data.entries.map((entry) {
                int index = data.keys.toList().indexOf(entry.key);
                if (entry.value > 0) {
                  // Solo mostrar leyenda si el valor es > 0
                  return _buildLegendItem(
                      colors[index % colors.length], entry.key);
                }
                return const SizedBox.shrink();
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBarChartCard(
    String title,
    Map<int, double> incomeData,
    Map<int, double> expenseData,
    List<String> monthLabels, // Ej: ['Ene', 'Feb', 'Mar']
  ) {
    // Recopilar todas las claves de mes de los datos de ingresos y gastos
    Set<int> allMonthKeys = {};
    allMonthKeys.addAll(incomeData.keys);
    allMonthKeys.addAll(expenseData.keys);
    List<int> sortedMonthKeys = allMonthKeys.toList();
    sortedMonthKeys.sort((a, b) {
      final yearA = a ~/ 100;
      final monthA = a % 100;
      final yearB = b ~/ 100;
      final monthB = b % 100;
      if (yearA != yearB) return yearA.compareTo(yearB);
      return monthA.compareTo(monthB);
    });

    if (sortedMonthKeys.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: Colors.white,
        child: SizedBox(
          height: 300,
          child: Center(
            child: Text('No hay datos de $title disponibles.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    double maxYValue = 0;
    for (var value in incomeData.values) {
      if (value > maxYValue) maxYValue = value;
    }
    for (var value in expenseData.values) {
      if (value > maxYValue) maxYValue = value;
    }

    if (maxYValue <= 0) {
      maxYValue = 100;
    } else {
      maxYValue = (maxYValue * 1.2).ceilToDouble();
    }

    List<BarChartGroupData> barGroups = [];
    double groupWidth = 14; // Ancho por defecto por grupo

    // Ajustar groupWidth según el número de meses
    if (sortedMonthKeys.length > 6) {
      groupWidth = 10;
    }
    if (sortedMonthKeys.length > 9) {
      groupWidth = 8;
    }

    for (int i = 0; i < sortedMonthKeys.length; i++) {
      final monthKey = sortedMonthKeys[i];
      final income = incomeData[monthKey] ?? 0.0;
      final expenses = expenseData[monthKey] ?? 0.0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: income,
              color: Colors.green,
              width: groupWidth /
                  2, // La mitad del ancho del grupo para cada barra
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: expenses,
              color: Colors.red,
              width: groupWidth / 2,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c),
              ),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.70,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Color(0xffececec),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < monthLabels.length) {
                            return SideTitleWidget(
                              space: 8,
                              meta: meta,
                              child: Text(monthLabels[index],
                                  style: const TextStyle(
                                      color: Color(0xff72719b),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (maxYValue / 4 > 0
                            ? (maxYValue / 4).ceilToDouble()
                            : 25),
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            space: 8,
                            meta: meta,
                            child: Text(
                              _formatCurrency(value),
                              style: const TextStyle(
                                  color: Color(0xff72719b),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10),
                              textAlign: TextAlign.left,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) =>
                          Colors.blueGrey.withOpacity(0.9),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label = (group.x.toInt() >= 0 &&
                                group.x.toInt() < monthLabels.length)
                            ? monthLabels[group.x.toInt()]
                            : '';
                        String value = _formatCurrency(rod.toY);
                        String type = rodIndex == 0 ? 'Ingreso' : 'Egreso';
                        Color textColor = rodIndex == 0
                            ? Colors.lightGreenAccent
                            : Colors.redAccent;

                        return BarTooltipItem(
                          '$label\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: '$type: $value',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  minY: 0,
                  maxY: maxYValue,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green, 'Ingresos'),
                const SizedBox(width: 20),
                _buildLegendItem(Colors.red, 'Egresos'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleBarChartCard(
      String title, Map<String, int> data, Color barColor) {
    // Modificación: Verifica si data está vacío o si todos los valores son cero.
    // Esto asegura que el gráfico no se muestre si no hay datos significativos.
    if (data.isEmpty || data.values.every((element) => element == 0)) {
      return const SizedBox.shrink(); // No renderiza nada si no hay datos
    }

    List<BarChartGroupData> barGroups = [];
    List<String> labels = data.keys.toList();
    labels
        .sort(); // Ordenar etiquetas alfabéticamente para un orden de barras consistente
    double maxY = 0;

    for (var entry in data.entries) {
      final value = entry.value.toDouble();
      if (value > maxY) maxY = value;
    }

    for (int i = 0; i < labels.length; i++) {
      final value = data[labels[i]]!.toDouble();

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: barColor,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY + (maxY * 0.1), // Ajustar la altura del fondo
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
          ],
        ),
      );
    }

    if (maxY <= 0) {
      maxY = 10; // Max Y por defecto si no hay datos
    } else {
      maxY = (maxY * 1.2).ceilToDouble(); // Añadir 20% de padding
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5e3a1c),
              ),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.70,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Color(0xffececec),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < labels.length) {
                            return SideTitleWidget(
                              space: 8,
                              meta: meta,
                              child: Text(labels[index],
                                  style: const TextStyle(
                                      color: Color(0xff72719b),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval:
                            (maxY / 4 > 0 ? (maxY / 4).ceilToDouble() : 2),
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            space: 8,
                            meta: meta,
                            child: Text(
                              _formatNumber(value.toInt()),
                              style: const TextStyle(
                                  color: Color(0xff72719b),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10),
                              textAlign: TextAlign.left,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) =>
                          Colors.blueGrey.withOpacity(0.9),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label = (group.x.toInt() >= 0 &&
                                group.x.toInt() < labels.length)
                            ? labels[group.x.toInt()]
                            : '';
                        String value = _formatNumber(rod.toY.toInt());
                        return BarTooltipItem(
                          '$label: $value',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                  ),
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF5e3a1c), fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colores para gráficos de pastel y barras
    final List<Color> pieChartColors = [
      Colors.blue.shade300,
      Colors.pink.shade300,
      Colors.green.shade300,
      Colors.orange.shade300,
      Colors.purple.shade300,
      Colors.teal.shade300,
      Colors.brown.shade300,
      Colors.cyan.shade300,
      Colors.indigo.shade300,
      Colors.lime.shade300,
    ];

    final List<String> financeMonthLabels = List.generate(12, (index) {
      return DateFormat('MMM').format(DateTime(2023, index + 1));
    });

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Estadísticas',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          backgroundColor: const Color(0xFFf5f0e1),
          iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
        ),
        body: const Center(
          child: Text(
            'Por favor, inicia sesión para ver las estadísticas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF5e3a1c)),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Estadísticas',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          backgroundColor: const Color(0xFFf5f0e1),
          iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6b4226)),
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Estadísticas',
              style: TextStyle(color: Color(0xFF5e3a1c))),
          backgroundColor: const Color(0xFFf5f0e1),
          iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
        ),
        body: Center(
          child: Text(_errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        title: const Text(
          'Estadísticas Generales',
          style: TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFf5f0e1),
        iconTheme: const IconThemeData(color: Color(0xFF5e3a1c)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Bovinos
            _buildSectionTitle('Estadísticas de Bovinos'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildInfoCard(
                  title: 'Total Animales',
                  value: _formatNumber(_totalAnimals),
                  icon: FontAwesomeIcons.cow, // ¡ICONO CAMBIADO!
                  iconColor: const Color(0xFF6b4226),
                ),
                _buildInfoCard(
                  title: 'Machos',
                  value: _formatNumber(_maleAnimals),
                  icon: Icons.male,
                  iconColor: Colors.blue.shade700,
                ),
                _buildInfoCard(
                  title: 'Hembras',
                  value: _formatNumber(_femaleAnimals),
                  icon: Icons.female,
                  iconColor: Colors.pink.shade700,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildPieChartCard(
                'Distribución por Raza', _animalsByBreed, pieChartColors),
            const SizedBox(height: 20),
            // Eliminada la gráfica de "Animales por Etapa"
            // if (_animalsByStage.isNotEmpty && !_animalsByStage.values.every((element) => element == 0))
            //   Column(
            //     children: [
            //       _buildSimpleBarChartCard(
            //           'Animales por Etapa', _animalsByStage, Colors.teal),
            //       const SizedBox(height: 20),
            //     ],
            //   ),
            _buildSimpleBarChartCard('Animales por Grupo de Edad',
                _animalsByAgeGroup, Colors.orange),

            // Sección de Finanzas
            _buildSectionTitle('Estadísticas de Finanzas'),
            // Reemplazado GridView.count por Column para que cada tarjeta ocupe su propia línea
            _buildInfoCard(
              title: 'Ingresos Anuales',
              value: _formatCurrency(_totalIncomeYear),
              icon: Icons.arrow_downward,
              iconColor: Colors.green,
            ),
            const SizedBox(height: 16), // Espacio entre las tarjetas
            _buildInfoCard(
              title: 'Egresos Anuales',
              value: _formatCurrency(_totalExpensesYear),
              icon: Icons.arrow_upward,
              iconColor: Colors.red,
            ),
            const SizedBox(height: 16), // Espacio entre las tarjetas
            _buildInfoCard(
              title: 'Ganancia Neta Anual',
              value: _formatCurrency(_totalIncomeYear - _totalExpensesYear),
              icon: (_totalIncomeYear - _totalExpensesYear) >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
              iconColor: (_totalIncomeYear - _totalExpensesYear) >= 0
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
            const SizedBox(height: 20), // Espacio antes del siguiente gráfico
            _buildBarChartCard('Ingresos vs. Egresos Mensuales (Año Actual)',
                _monthlyIncome, _monthlyExpenses, financeMonthLabels),
            const SizedBox(height: 20),
            _buildPieChartCard(
                'Gastos por Categoría',
                _expensesByCategory
                    .map((key, value) => MapEntry(key, value.toInt())),
                pieChartColors),

            // Sección de Inventario
            _buildSectionTitle('Estadísticas de Inventario'),
            _buildInfoCard(
              title: 'Total Ítems en Inventario',
              value: _formatNumber(_inventoryTotalItems),
              icon: Icons.inventory_2,
              iconColor: const Color(0xFF6b4226),
            ),
            const SizedBox(height: 20),
            _buildSimpleBarChartCard('Estado del Inventario',
                _inventoryStockStatus, Colors.blueAccent),
            // Si implementas Top 5 ítems, puedes usar _topUsedItems aquí
            // const SizedBox(height: 20),
            // _buildSimpleBarChartCard(
            //     'Top 5 Ítems Más Utilizados', _topUsedItems, Colors.purple),

            // Sección de Calendario
            _buildSectionTitle('Estadísticas de Calendario'),
            _buildInfoCard(
              title: 'Total Eventos Próximos',
              value: _formatNumber(_totalUpcomingEvents),
              icon: Icons.event,
              iconColor: const Color(0xFFc99450),
            ),
            const SizedBox(height: 20),
            _buildSimpleBarChartCard('Eventos Próximos por Tipo',
                _upcomingEventsByType, Colors.lightBlue),

            // Sección de Marketplace
            _buildSectionTitle('Estadísticas de Marketplace'),
            _buildInfoCard(
              title: 'Total Publicaciones Activas',
              value: _formatNumber(_totalMarketplaceListings),
              icon: Icons.store,
              iconColor: Colors.amber.shade700,
            ),
            const SizedBox(height: 20),
            _buildPieChartCard('Publicaciones por Raza de Animal',
                _marketplaceListingsByAnimalBreed, pieChartColors),
            const SizedBox(height: 20),
            _buildSimpleBarChartCard('Publicaciones por Estado',
                _marketplaceListingsByStatus, Colors.deepPurple),

            // Sección de IA
            _buildSectionTitle('Estadísticas de IA'),
            _buildInfoCard(
              title: 'Total Análisis Realizados',
              value: _formatNumber(_totalAnalysisRecords),
              icon: Icons.bar_chart,
              iconColor: Colors.indigo.shade700,
            ),
            const SizedBox(height: 20),
            _buildSimpleBarChartCard('Distribución de Resultados AI',
                _aiResultsDistribution, Colors.purple),

            // Sección de Sugerencia de Cruces (IA Avanzada)
            _buildSectionTitle('Sugerencia de Cruces (Próximamente)'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              color: Colors.white,
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Esta funcionalidad te permitirá obtener recomendaciones de cruces óptimos para tus animales.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF5e3a1c)),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Requiere un modelo de Inteligencia Artificial avanzado que considere factores como genética, historial de producción y objetivos de mejora. Estamos trabajando para integrar esta característica.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    SizedBox(height: 10),
                    Icon(Icons.insights, color: Color(0xFFc99450), size: 40),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
