// lib/screens/inventario/add_edit_product_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/models/product.dart';
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:manual_ganadero_flutter/services/notification_service.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product; // Si es null, estamos agregando; si no, editando

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _entryDateController = TextEditingController();
  final _expirationDateController = TextEditingController();

  String? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedUnit; // Almacena la unidad seleccionada

  DateTime? _entryDate;
  DateTime? _expirationDate;

  // Definición de categorías, subcategorías y unidades permitidas
  // La clave es la Categoría, el valor es un mapa de Subcategoría a Lista de Unidades
  final Map<String, Map<String, List<String>>> _nestedCategoriesAndUnits = {
    'Salud': {
      'Vacunas': ['unidades'],
      'Fiebre aftosa': ['unidades'],
      'Carbón sintomático': ['unidades'],
      'Brucelosis': ['unidades'],
      'Rabia': ['unidades'],
      'Medicamentos': ['ml', 'mg', 'cajas', 'unidades'],
      'Antibióticos': ['ml', 'mg', 'cajas', 'unidades'],
      'Antiparasitarios (internos y externos)': [
        'ml',
        'mg',
        'cajas',
        'unidades'
      ],
      'Antiinflamatorios': ['ml', 'mg', 'cajas', 'unidades'],
      'Vitaminas': ['ml', 'mg', 'cajas', 'unidades'],
      'Material Médico': ['unidades', 'cajas', 'paquetes'],
      'Jeringas': ['unidades', 'cajas'],
      'Agujas': ['unidades', 'cajas'],
      'Termómetros': ['unidades'],
      'Guantes': ['pares', 'cajas'],
      'Alcohol yodado': ['litros', 'ml'],
      'Vendas': ['rollos', 'unidades'],
    },
    'Alimentación': {
      'Alimento balanceado': ['kg', 'bultos'],
      'Costales de alimento para engorda': ['kg', 'bultos'],
      'Costales para mantenimiento': ['kg', 'bultos'],
      'Alimento para crías': ['kg', 'bultos'],
      'Suplementos': ['kg', 'litros', 'unidades'],
      'Minerales': ['kg', 'unidades'],
      'Sales': ['kg', 'unidades'],
      'Vitaminas': ['ml', 'mg', 'unidades'],
      'Alternativas': ['kg', 'unidades', 'pacas'],
      'Sustituto de leche': ['kg', 'litros'],
      'Biberones': ['unidades'],
      'Pasto seco / silo / forraje': ['kg', 'pacas', 'toneladas'],
    },
    'Herramientas y equipo': {
      'Herramientas de trabajo': ['unidades'],
      'Palas': ['unidades'],
      'Machetes': ['unidades'],
      'Hachas': ['unidades'],
      'Martillos': ['unidades'],
      'Equipo de mantenimiento': ['unidades'],
      'Bombas para fumigar': ['unidades'],
      'Tinacos': ['unidades'],
      'Cuchillos para castrar': ['unidades'],
      'Afiladores': ['unidades'],
      'Cercado y contención': ['metros', 'unidades', 'rollos'],
      'Alambre de púas': ['rollos', 'metros'],
      'Postes': ['unidades'],
      'Mallas': ['metros', 'rollos'],
      'Pinzas para cercas': ['unidades'],
      'Electrificadores de cercas': ['unidades'],
    },
    'Suministros y consumibles': {
      'Bolsas de plástico': ['rollos', 'unidades'],
      'Cuerdas': ['metros', 'rollos'],
      'Cubetas': ['unidades'],
      'Cajas para transporte': ['unidades'],
      'Bolsas para ordeña': ['unidades', 'paquetes'],
    },
    'Documentación y registros': {
      'Registros de vacunas': ['carpetas', 'unidades'],
      'Registros de partos': ['carpetas', 'unidades'],
      'Cartillas sanitarias': ['unidades'],
      'Pedigrees / genealogía': ['documentos', 'unidades'],
      'Guías de tránsito': ['documentos', 'unidades'],
    },
    'Tecnología y automatización': {
      'Termómetros digitales': ['unidades'],
      'Chips de rastreo': ['unidades'],
      'Lectores de aretes RFID': ['unidades'],
      'Básculas digitales': ['unidades'],
      'Cámaras de vigilancia': ['unidades'],
    },
    'Maquinaria': {
      'Tractores': ['unidades'],
      'Remolques': ['unidades'],
      'Bebederos automáticos': ['unidades'],
      'Ordeñadoras': ['unidades'],
      'Comederos automáticos': ['unidades'],
    },
  };

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _quantityController.text = widget.product!.quantity.toString();
      _priceController.text = widget.product!.price?.toString() ?? '';
      _notesController.text = widget.product!.notes ?? '';
      _selectedCategory = widget.product!.category;
      _selectedSubCategory = widget.product!.subCategory;
      _selectedUnit = widget.product!.unit;
      _entryDate = widget.product!.entryDate;
      _entryDateController.text = DateFormat('dd/MM/yyyy').format(_entryDate!);
      _expirationDate = widget.product!.expirationDate;
      if (_expirationDate != null) {
        _expirationDateController.text =
            DateFormat('dd/MM/yyyy').format(_expirationDate!);
      }
    } else {
      // Para nuevos productos, la fecha de entrada es hoy por defecto
      _entryDate = DateTime.now();
      _entryDateController.text = DateFormat('dd/MM/yyyy').format(_entryDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _entryDateController.dispose();
    _expirationDateController.dispose();
    super.dispose();
  }

  // Determina el tipo de teclado para la cantidad
  TextInputType _getQuantityKeyboardType() {
    final unitsRequiringDecimal = ['kg', 'litros', 'ml', 'mg', 'toneladas'];
    if (_selectedUnit != null &&
        unitsRequiringDecimal.contains(_selectedUnit!)) {
      return const TextInputType.numberWithOptions(decimal: true);
    }
    return TextInputType.number;
  }

  // --- SOLUCIÓN: GUARDAR EN LA RUTA DEL RANCHO ---
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null ||
        _selectedSubCategory == null ||
        _selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Por favor, selecciona la categoría, subcategoría y unidad.')),
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
      // Obtenemos el Rancho Actual
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final currentRanchId = userDoc.data()?['currentRanchId'];

      if (currentRanchId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: No tienes un rancho seleccionado.')),
        );
        return;
      }

      // La referencia ahora apunta a ranches -> [rancho_id] -> products
      final productsCollection = FirebaseFirestore.instance
          .collection('users') // <-- NUEVO
          .doc(user.uid) // <-- NUEVO
          .collection('ranches')
          .doc(currentRanchId)
          .collection('products');

      final productData = Product(
        id: widget.product?.id ?? '', // Si es edición, usa el ID existente
        name: _nameController.text.trim(),
        category: _selectedCategory!,
        subCategory: _selectedSubCategory!,
        quantity: double.parse(_quantityController.text.trim()),
        unit: _selectedUnit!,
        price: _priceController.text.isNotEmpty
            ? double.parse(_priceController.text.trim())
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        entryDate: _entryDate!,
        expirationDate: _expirationDate,
      ).toFirestore();

      if (widget.product == null) {
        // Añadir nuevo producto
        await productsCollection.add(productData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto agregado con éxito!')),
          );
        }
      } else {
        // Actualizar producto existente
        await productsCollection.doc(widget.product!.id).update(productData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto actualizado con éxito!')),
          );
        }
      }

      // --- NUEVO: ALERTA INMEDIATA DE INVENTARIO BAJO ---
      double cantidadActual =
          double.tryParse(_quantityController.text.trim()) ?? 0;

      // Si la cantidad es 5 o menor, disparamos la alerta
      if (cantidadActual <= 5) {
        // Leemos la preferencia de notificaciones del userDoc que ya habías consultado arriba
        bool notificationsEnabled =
            userDoc.data()?['notificationsEnabled'] ?? true;

        if (notificationsEnabled) {
          await NotificationService().showImmediateNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: '⚠️ Inventario Bajo',
            body:
                'Te quedan solo $cantidadActual ${_selectedUnit ?? 'unidades'} de ${_nameController.text.trim()}. ¡Es hora de resurtir!',
          );
        }
      }
      // --- FIN NUEVO CÓDIGO ---

      if (mounted) {
        Navigator.pop(context, true); // Regresar y refrescar la lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el producto: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isEntryDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isEntryDate
          ? (_entryDate ?? DateTime.now())
          : (_expirationDate ?? DateTime.now().add(const Duration(days: 365))),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFc99450), // Color del encabezado del calendario
              onPrimary: Colors.white, // Color del texto del encabezado
              onSurface: Color(0xFF5e3a1c), // Color del texto de los días
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(
                    0xFF6b4226), // Color de los botones "Cancelar", "OK"
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isEntryDate) {
          _entryDate = picked;
          _entryDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _expirationDate = picked;
          _expirationDateController.text =
              DateFormat('dd/MM/yyyy').format(picked);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFfbf6ec),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfbf6ec),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF5e3a1c)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          widget.product == null ? 'Agregar Producto' : 'Editar Producto',
          style: const TextStyle(
            color: Color(0xFF5e3a1c),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Nombre del Producto',
                icon: Icons.inventory,
                maxLength: 15, // <-- LÍMITE AGREGADO
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor ingresa el nombre del producto'
                    : null,
              ),
              _buildDropdownFormField<String>(
                label: 'Categoría',
                icon: Icons.category,
                value: _selectedCategory,
                items: _nestedCategoriesAndUnits.keys.toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                    _selectedSubCategory = null;
                    _selectedUnit = null;
                  });
                },
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor selecciona una categoría'
                    : null,
              ),
              if (_selectedCategory != null)
                _buildDropdownFormField<String>(
                  label: 'Subcategoría',
                  icon: Icons.subtitles,
                  value: _selectedSubCategory,
                  items: _nestedCategoriesAndUnits[_selectedCategory]
                          ?.keys
                          .toList() ??
                      [],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSubCategory = newValue;
                      _selectedUnit = null;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Por favor selecciona una subcategoría'
                      : null,
                ),
              if (_selectedSubCategory != null)
                _buildDropdownFormField<String>(
                  label: 'Unidad',
                  icon: Icons.scale,
                  value: _selectedUnit,
                  items: _nestedCategoriesAndUnits[_selectedCategory]![
                      _selectedSubCategory]!,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedUnit = newValue;
                    });
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Por favor selecciona una unidad'
                      : null,
                ),
              _buildTextField(
                controller: _quantityController,
                label: 'Cantidad',
                icon: Icons.numbers,
                maxLength: 10, // <-- LÍMITE AGREGADO
                keyboardType: _getQuantityKeyboardType(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor ingresa la cantidad'
                    : null,
              ),
              _buildTextField(
                controller: _priceController,
                label: 'Precio (Opcional)',
                maxLength: 10, // <-- LÍMITE AGREGADO
                icon: Icons.attach_money,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      double.tryParse(value) == null) {
                    return 'Ingresa un número válido para el precio';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _notesController,
                label: 'Notas Adicionales (Opcional)',
                maxLength: 250, // <-- LÍMITE AGREGADO
                icon: Icons.notes,
                maxLines: 3,
              ),
              _buildDateFormField(
                controller: _entryDateController,
                label: 'Fecha de Entrada',
                icon: Icons.calendar_today,
                onTap: () => _selectDate(context, true),
                validator: (value) => value == null || value.isEmpty
                    ? 'Por favor selecciona la fecha de entrada'
                    : null,
              ),
              _buildDateFormField(
                controller: _expirationDateController,
                label: 'Fecha de Caducidad (Opcional)',
                icon: Icons.calendar_month,
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5e3a1c),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.product == null
                      ? 'Agregar Producto'
                      : 'Guardar Cambios',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // REFACTORIZADO: _buildTextField para el nuevo estilo
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c)),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        validator: validator,
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }

  // REFACTORIZADO: _buildDropdownFormField para el nuevo estilo
  Widget _buildDropdownFormField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c)),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          suffixIcon: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
        icon: const SizedBox.shrink(),
        items: items.map<DropdownMenuItem<T>>((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(item.toString(),
                style: const TextStyle(color: Colors.black87)),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }

  // REFACTORIZADO: _buildDateFormField para el nuevo estilo
  Widget _buildDateFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF5e3a1c)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          labelStyle: const TextStyle(color: Color(0xFF5e3a1c)),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          suffixIcon: const Icon(Icons.chevron_right, color: Colors.grey),
        ),
        validator: validator,
        style: const TextStyle(color: Colors.black87),
      ),
    );
  }
}
