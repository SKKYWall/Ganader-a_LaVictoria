// lib/screens/finance/add_edit_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    hide Transaction; // Oculta la clase Transaction de cloud_firestore
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:manual_ganadero_flutter/models/transaction.dart'; // Importa tu modelo Transaction

class AddEditTransactionScreen extends StatefulWidget {
  final Transaction? transaction; // Si es null, añadir; si no, editar

  const AddEditTransactionScreen({super.key, this.transaction});

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _dateController = TextEditingController();

  String _transactionType = 'expense'; // Default a egreso
  String? _selectedCategory;
  String? _selectedSubCategory;
  DateTime? _selectedDate;

  // Definición de categorías y subcategorías
  final Map<String, List<String>> _incomeCategories = {
    'Venta de Animales': ['Bovinos', 'Ovinos / Caprinos', 'Cerdos'],
    'Otros Ingresos': [
      'Subsidios',
      'Intereses',
      'Venta de Productos Lácteos',
      'Venta de Carne'
    ],
  };

  final Map<String, List<String>> _expenseCategories = {
    'Alimentación': ['Alimento balanceado', 'Forraje / silo', 'Suplementos'],
    'Salud': ['Vacunas', 'Medicamentos', 'Material Médico'],
    'Personal': ['Sueldos', 'Bonos'],
    'Mantenimiento e Infraestructura': [
      'Reparaciones',
      'Nuevas construcciones',
      'Herramientas'
    ],
    'Servicios': ['Luz', 'Agua', 'Internet', 'Combustible'],
    'Otros Egresos': ['Seguros', 'Impuestos', 'Transporte', 'Gastos Bancarios'],
  };

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _transactionType = widget.transaction!.type;
      _amountController.text = widget.transaction!.amount.toString();
      _notesController.text = widget.transaction!.notes ?? '';
      _selectedCategory = widget.transaction!.category;
      _selectedSubCategory = widget.transaction!.subCategory;
      _selectedDate = widget.transaction!.date;
      _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
    } else {
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  List<String> _getCurrentCategories() {
    return _transactionType == 'income'
        ? _incomeCategories.keys.toList()
        : _expenseCategories.keys.toList();
  }

  List<String> _getCurrentSubCategories(String category) {
    if (_transactionType == 'income') {
      return _incomeCategories[category] ?? [];
    } else {
      return _expenseCategories[category] ?? [];
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una categoría.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no autenticado.')),
      );
      return;
    }

    try {
      final transactionsCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions');

      final transactionData = Transaction(
        id: widget.transaction?.id ?? '',
        type: _transactionType,
        amount: double.parse(_amountController.text.trim()),
        category: _selectedCategory!,
        subCategory: _selectedSubCategory,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        date: _selectedDate!,
      ).toFirestore();

      if (widget.transaction == null) {
        await transactionsCollection.add(transactionData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transacción agregada con éxito!')),
          );
        }
      } else {
        await transactionsCollection
            .doc(widget.transaction!.id)
            .update(transactionData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transacción actualizada con éxito!')),
          );
        }
      }
      if (mounted) {
        Navigator.pop(context, true); // Regresar y refrescar
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la transacción: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary:
                  Color(0xFFc99450), // Consistent color for date picker header
              onPrimary: Colors.white,
              onSurface: Color(0xFF5e3a1c),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6b4226),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFfbf6ec), // Consistent app bar background
        elevation: 0, // Consistent elevation
        leading: IconButton(
          // Added leading icon for back navigation
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          widget.transaction == null
              ? 'Añadir Transacción'
              : 'Editar Transacción',
          style: const TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
            fontSize: 24, // Consistent title size
          ),
        ),
        centerTitle: true, // Consistent title centering
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Consistent stretch
            children: [
              // Selector de Tipo de Transacción (estilo similar a radio buttons en el otro form)
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Ingreso',
                          style: TextStyle(
                              color: Color(0xFF5e3a1c),
                              fontWeight: FontWeight.bold)), // Bold text
                      value: 'income',
                      groupValue: _transactionType,
                      onChanged: (String? value) {
                        setState(() {
                          _transactionType = value!;
                          _selectedCategory = null; // Reset category
                          _selectedSubCategory = null; // Reset subcategory
                        });
                      },
                      activeColor: Colors.green, // Color para ingreso
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Egreso',
                          style: TextStyle(
                              color: Color(0xFF5e3a1c),
                              fontWeight: FontWeight.bold)), // Bold text
                      value: 'expense',
                      groupValue: _transactionType,
                      onChanged: (String? value) {
                        setState(() {
                          _transactionType = value!;
                          _selectedCategory = null; // Reset category
                          _selectedSubCategory = null; // Reset subcategory
                        });
                      },
                      activeColor: Colors.red, // Color para egreso
                    ),
                  ),
                ],
              ),
              // No SizedBox after each, as Padding in _buildTextField/DropdownFormField will handle vertical spacing

              _buildTextField(
                controller: _amountController,
                label: 'Monto', // Changed labelText to label
                icon: Icons.attach_money, // Added icon
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa el monto';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Ingresa un número válido';
                  }
                  return null;
                },
              ),

              _buildDropdownFormField<String>(
                // Renamed to _buildDropdownFormField
                label: 'Categoría',
                icon: Icons.category, // Added icon
                value: _selectedCategory,
                items: _getCurrentCategories(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                    _selectedSubCategory = null; // Reset subcategory
                  });
                },
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor selecciona una categoría'
                    : null,
              ),

              if (_selectedCategory != null &&
                  _getCurrentSubCategories(_selectedCategory!).isNotEmpty)
                _buildDropdownFormField<String>(
                  // Renamed to _buildDropdownFormField
                  label: 'Subcategoría (Opcional)',
                  icon: Icons.subtitles, // Added icon
                  value: _selectedSubCategory,
                  items: _getCurrentSubCategories(_selectedCategory!),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSubCategory = newValue;
                    });
                  },
                  validator: null, // Subcategoría es opcional
                ),

              _buildTextField(
                controller: _notesController,
                label: 'Observaciones (Opcional)',
                icon: Icons.notes, // Added icon
                maxLines: 3,
                validator: null, // Notas son opcionales
              ),

              _buildDateFormField(
                // Renamed to _buildDateFormField
                controller: _dateController,
                label: 'Fecha',
                icon: Icons.calendar_today, // Added icon
                onTap: () => _selectDate(context),
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor selecciona la fecha'
                    : null,
              ),
              const SizedBox(height: 30),

              Center(
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF5e3a1c), // Consistent button color
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    widget.transaction == null
                        ? 'Añadir Transacción'
                        : 'Guardar Cambios',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold), // Bold text
                  ),
                ),
              ),
              const SizedBox(height: 40), // Extra space at the bottom
            ],
          ),
        ),
      ),
    );
  }

  // REFACTORIZADO: _buildTextField para el nuevo estilo
  Widget _buildTextField({
    required TextEditingController controller,
    required String label, // Changed from labelText
    required IconData icon, // Added icon parameter
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 0.0,
          vertical: 8.0), // No horizontal padding here, handled by parent
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon,
              color: const Color(0xFF5e3a1c)), // Icon for consistency
          border: InputBorder.none, // No border for the field itself
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c)),
          floatingLabelBehavior:
              FloatingLabelBehavior.never, // Consistent label behavior
        ),
        validator: validator,
        style: const TextStyle(color: Colors.black87), // Consistent text style
      ),
    );
  }

  // REFACTORIZADO: _buildDropdownFormField para el nuevo estilo
  Widget _buildDropdownFormField<T>({
    required String label, // Changed from labelText
    required IconData icon, // Added icon parameter
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator, // Changed validator to accept T?
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon,
              color: const Color(0xFF5e3a1c)), // Icon for consistency
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c)),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          suffixIcon: const Icon(Icons.chevron_right,
              color: Colors.grey), // Chevron icon
        ),
        icon: const SizedBox.shrink(), // Oculta el icono de flecha por defecto
        items: items.map<DropdownMenuItem<T>>((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString(),
                style: const TextStyle(
                    color: Colors.black87)), // Consistent text style
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(color: Colors.black87), // Consistent text style
      ),
    );
  }

  // REFACTORIZADO: _buildDateFormField para el nuevo estilo
  Widget _buildDateFormField({
    required TextEditingController controller,
    required String label, // Changed from labelText
    required IconData icon, // Added icon parameter
    required VoidCallback onTap,
    String? Function(String?)? validator, // Changed validator to accept String?
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon,
              color: const Color(0xFF5e3a1c)), // Icon for consistency
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c)),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          suffixIcon: const Icon(Icons.chevron_right,
              color: Colors.grey), // Chevron icon
        ),
        validator: validator,
        style: const TextStyle(color: Colors.black87), // Consistent text style
      ),
    );
  }
}
