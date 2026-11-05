// lib/core/finance_categories.dart
//
// Única fuente de verdad de categorías/subcategorías financieras. Antes
// estaban copiadas carácter por carácter en add_edit_transaction_screen.dart
// y transaction_history_screen.dart — si solo una se editaba, los nombres
// podían divergir con el tiempo.
const Map<String, List<String>> incomeCategories = {
  'Venta de Animales': ['Bovinos', 'Ovinos / Caprinos', 'Cerdos'],
  'Otros Ingresos': [
    'Subsidios',
    'Intereses',
    'Venta de Productos Lácteos',
    'Venta de Carne',
  ],
};

const Map<String, List<String>> expenseCategories = {
  'Alimentación': ['Alimento balanceado', 'Forraje / silo', 'Suplementos'],
  'Salud': ['Vacunas', 'Medicamentos', 'Material Médico'],
  'Personal': ['Sueldos', 'Bonos'],
  'Mantenimiento e Infraestructura': [
    'Reparaciones',
    'Nuevas construcciones',
    'Herramientas',
  ],
  'Servicios': ['Luz', 'Agua', 'Internet', 'Combustible'],
  'Otros Egresos': ['Seguros', 'Impuestos', 'Transporte', 'Gastos Bancarios'],
};

/// Categorías cuyo gasto se considera directamente atribuible a mantener un
/// animal (usado para el KPI "costo por cabeza" en finance_screen.dart).
const List<String> perAnimalExpenseCategories = ['Alimentación', 'Salud'];

String formatCurrencyMXN(double amount) {
  final abs = amount.abs();
  final sign = amount < 0 ? '-' : '';
  if (abs >= 1000000) {
    return '$sign\$${(abs / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    return '$sign\$${(abs / 1000).toStringAsFixed(1)}k';
  }
  return '$sign\$${abs.toStringAsFixed(0)}';
}
