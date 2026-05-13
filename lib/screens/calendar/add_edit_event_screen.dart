// lib/screens/calendar/add_edit_event_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:manual_ganadero_flutter/models/calendar.dart'; // Importa el modelo CalendarEvent
import 'package:intl/intl.dart'; // Para formatear la fecha
import 'package:manual_ganadero_flutter/services/notification_service.dart';

class AddEditEventScreen extends StatefulWidget {
  final CalendarEvent? event; // Si se pasa un evento, es para editar

  const AddEditEventScreen({super.key, this.event});

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController =
      TextEditingController(); // Nuevo controlador para la fecha
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'General'; // Categoría por defecto

  final List<String> _categories = [
    'General',
    'Vacunación',
    'Parto',
    'Cita',
    'Mantenimiento',
    'Medicación', // Añadidas categorías del calendario
    'Alimentación',
    'Reproducción',
    'Sanidad',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      // Si estamos editando, precarga los datos del evento
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description;
      _selectedDate = widget.event!.date;
      _selectedCategory = widget.event!.category;
    }
    // Inicializa el controlador de fecha con la fecha seleccionada
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose(); // Disponer el nuevo controlador de fecha
    super.dispose();
  }

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        // --- INICIO DE MODIFICACIÓN MULTI-RANCHO ---
        // 1. Obtener el rancho seleccionado actual
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        String? currentRanchId =
            (userDoc.data() as Map<String, dynamic>?)?['currentRanchId'];

        if (currentRanchId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('No hay rancho seleccionado para guardar el evento.'),
              backgroundColor: Colors.red,
            ));
          }
          return; // Detenemos el guardado si no hay rancho
        }

        final newEvent = CalendarEvent(
          id: widget.event?.id ??
              '', // ID vacío si es nuevo, si no, el ID existente
          title: _titleController.text,
          description: _descriptionController.text,
          date: _selectedDate,
          category: _selectedCategory,
        );

        // 2. Creamos la referencia a la base de datos apuntando al rancho actual
        // 2. Creamos la referencia a la base de datos apuntando al rancho actual
        CollectionReference eventsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('ranches')
            .doc(currentRanchId)
            .collection('calendarEvents');

        String eventIdToUse = '';

        if (widget.event == null) {
          // Añadir nuevo evento y guardar su ID
          DocumentReference docRef =
              await eventsRef.add(newEvent.toFirestore());
          eventIdToUse = docRef.id;
        } else {
          // Actualizar evento existente
          eventIdToUse = widget.event!.id;
          await eventsRef.doc(eventIdToUse).update(newEvent.toFirestore());
        }

        // --- NUEVO: PROGRAMAR ALERTA DE CALENDARIO ---
        try {
          bool notificationsEnabled = (userDoc.data()
                  as Map<String, dynamic>?)?['notificationsEnabled'] ??
              true;

          if (notificationsEnabled) {
            // Programar la alarma para las 8:00 AM del día del evento
            DateTime alertDate = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              8, 0, // 8:00 AM
            );

            if (alertDate.isAfter(DateTime.now())) {
              await NotificationService().scheduleNotification(
                id: eventIdToUse.hashCode,
                title: '📅 ${_titleController.text.trim()}',
                body: _descriptionController.text.trim().isNotEmpty
                    ? _descriptionController.text.trim()
                    : 'Tienes un evento programado para hoy en tu rancho.',
                scheduledDate: alertDate,
              );
            } else {
              // Si la fecha editada es del pasado, cancelamos cualquier alarma vieja
              await NotificationService()
                  .cancelNotification(eventIdToUse.hashCode);
            }
          } else {
            // Si el usuario desactivó las notificaciones en ajustes, cancelamos por si acaso
            await NotificationService()
                .cancelNotification(eventIdToUse.hashCode);
          }
        } catch (notificationError) {
          print(
              'Advertencia: No se pudo programar la alarma local del celular: $notificationError');
          // No hacemos return, dejamos que el código siga para que cierre la pantalla.
        }
        // --- FIN NUEVO CÓDIGO ---

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Evento ${widget.event == null ? 'añadido' : 'actualizado'} con éxito')),
          );
          Navigator.pop(
              context, true); // Regresa a la pantalla anterior y notifica éxito
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar evento: $e')),
          );
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFc99450), // Color principal del selector
              onPrimary: Colors.white, // Color del texto en el color principal
              onSurface: Color(0xFF5e3a1c), // Color del texto en la superficie
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    const Color(0xFF6b4226), // Color de los botones de texto
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
        _dateController.text =
            DateFormat('dd/MM/yyyy').format(picked); // Actualiza el controlador
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
          widget.event == null ? 'Añadir Evento' : 'Editar Evento',
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
              _buildTextField(
                controller: _titleController,
                label: 'Título del evento',
                maxLength: 30,
                icon: Icons.event_note, // Appropriate icon
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce un título';
                  }
                  return null;
                },
              ),
              _buildTextField(
                controller: _descriptionController,
                label: 'Descripción (opcional)',
                maxLength: 250,
                icon: Icons.description, // Appropriate icon
                maxLines: 3,
                validator: null, // Optional field
              ),
              _buildDateFormField(
                controller: _dateController,
                label: 'Fecha',
                icon: Icons.calendar_today, // Appropriate icon
                onTap: () => _selectDate(context),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecciona la fecha';
                  }
                  return null;
                },
              ),
              _buildDropdownFormField<String>(
                label: 'Categoría',
                icon: Icons.category, // Appropriate icon
                value: _selectedCategory,
                items: _categories,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecciona una categoría';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF5e3a1c), // Consistent button color
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)), // Rounded borders
                  ),
                  child: Text(
                    widget.event == null
                        ? 'Guardar Evento'
                        : 'Actualizar Evento',
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

  // --- Widgets Auxiliares (copiados del estilo unificado) ---
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
        icon: const SizedBox.shrink(), // Oculta el icono de flecha por defecto
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
}
