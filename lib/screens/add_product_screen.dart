// lib/screens/add_product_screen.dart
//
// FASE 2 — Clean Architecture:
// El método _guardarProducto ya no accede a FirebaseFirestore.instance.
// Delega el upsert a ProductProvider.saveProduct(), que centraliza
// la lógica de "crear o acumular" en un solo lugar.
// Todo lo demás (notificaciones, imagen, cámara, permisos) permanece.
// exactamente igual que en Fase 1. Los bugs #1 #2 #4 siguen corregidos.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../domain/entities/food_category.dart';
import '../presentation/providers/product_provider.dart';
import '../presentation/utils/food_category_ui.dart';

class AddProductScreen extends StatefulWidget {
  final String? scannedCode;
  final List<Map<String, dynamic>> existingProducts;
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? initialProduct;
  final bool isManualAdd;

  const AddProductScreen({
    super.key,
    this.scannedCode,
    required this.existingProducts,
    required this.onSave,
    this.initialProduct,
    this.isManualAdd = false,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  bool _isSaving = false;
  final TextEditingController _barcodeController = TextEditingController();
  bool _isManualAdd = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  String _selectedUnit = 'unidad';
  File? _imageFile;
  DateTime? _expiryDate;
  DateTime? _storedAt; // FASE 3: fecha de almacenamiento en nevera
  FoodCategory _selectedCategory = FoodCategory.otros; // PASO 2
  final TextEditingController _minStockController =
      TextEditingController(); // PASO 2: stock mínimo (opcional)
  final picker = ImagePicker();
  final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();
  final List<String> _units = ['unidad', 'kg', 'g', 'L', 'ml', 'lbs', 'oz'];

  static const _kAlarmPermAsked = 'exact_alarm_permission_asked';

  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    _initializeNotificationPlugin();
    _checkExactAlarmPermission();

    if (widget.initialProduct != null) {
      _nameController.text = widget.initialProduct!['name'] ?? '';
      _barcodeController.text = widget.initialProduct!['barcode'] ?? '';
      _quantityController.text = widget.initialProduct!['quantity'] ?? '1';
      _selectedUnit = widget.initialProduct!['unit'] ?? 'unidad';

      final imagePath =
          widget.initialProduct!['imagePath'] as String? ??
          widget.initialProduct!['image'] as String?;
      if (imagePath != null && imagePath.isNotEmpty) {
        final f = File(imagePath);
        if (f.existsSync()) _imageFile = f;
      }

      if (widget.initialProduct!['expirationDate'] != null) {
        _expiryDate = DateTime.tryParse(
          widget.initialProduct!['expirationDate'],
        );
      }
      // FASE 3: cargar storedAt al editar
      if (widget.initialProduct!['storedAt'] != null) {
        _storedAt = DateTime.tryParse(widget.initialProduct!['storedAt']);
      }
      // PASO 2: cargar categoría y stock mínimo al editar
      _selectedCategory = FoodCategory.fromName(
        widget.initialProduct!['category'] as String?,
      );
      final minStock = widget.initialProduct!['minStock'];
      if (minStock != null) {
        _minStockController.text = minStock.toString();
      }
    } else if (widget.scannedCode != null) {
      _barcodeController.text = widget.scannedCode!;
    } else {
      _isManualAdd = widget.isManualAdd;
    }
  }

  // FIX #H1: liberar los TextEditingControllers para evitar memory leak
  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotificationPlugin() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );
    await _notifPlugin.initialize(settings);
  }

  // BUG #1 FIX: usa DeviceInfoPlugin para el API level real
  Future<bool> _isAndroid12OrHigher() async {
    if (!Platform.isAndroid) return false;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt >= 31;
  }

  // BUG #1 FIX: guard con SharedPreferences
  Future<void> _checkExactAlarmPermission() async {
    if (!await _isAndroid12OrHigher()) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_kAlarmPermAsked) ?? false;
    if (alreadyAsked) return;
    await prefs.setBool(_kAlarmPermAsked, true);
    if (!mounted) return;

    final goToSettings = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Permisos de notificación'),
            content: const Text(
              'Para avisarte cuando un producto está por vencer, '
              'Fresc(o)rden necesita permiso para programar alarmas exactas. '
              '¿Ir a configuración para activarlo?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Ahora no'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ir a configuración'),
              ),
            ],
          ),
    );

    if (goToSettings == true) {
      try {
        await const AndroidIntent(
          action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        ).launch();
      } catch (e) {
        debugPrint('No se pudo abrir configuración de alarmas exactas: $e');
      }
    }
  }

  // BUG #2 FIX: se elimina matchDateTimeComponents → disparo único
  Future<void> _scheduleNotification(
    String productName,
    DateTime expiryDate,
  ) async {
    final notificationTime = expiryDate.subtract(const Duration(days: 3));
    if (!notificationTime.isAfter(DateTime.now())) return;

    try {
      await _notifPlugin.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Producto por vencer',
        'El producto "$productName" vencerá en 3 días.',
        tz.TZDateTime.from(notificationTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vencimiento_channel',
            'Notificaciones de Vencimiento',
            channelDescription:
                'Avisos de productos cercanos a su fecha de vencimiento',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Error al programar la notificación: $e');
    }
  }

  // BUG #4 FIX: copia la imagen al directorio permanente
  Future<File> _copyImageToPermanentStorage(File tempFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/product_images');
    if (!imagesDir.existsSync()) {
      await imagesDir.create(recursive: true);
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return tempFile.copy('${imagesDir.path}/$fileName');
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;
    // FIX #H2: mounted check después de awaits para evitar setState en widget descartado
    try {
      final permanentFile = await _copyImageToPermanentStorage(
        File(pickedFile.path),
      );
      if (!mounted) return;
      setState(() => _imageFile = permanentFile);
    } catch (e) {
      debugPrint('Error al guardar imagen: $e');
      if (!mounted) return;
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  // ─── FASE 2: _guardarProducto ya no toca Firestore directamente ──────────
  Future<void> _guardarProducto() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final quantity = _quantityController.text.trim();
    final barcode = _barcodeController.text.trim();

    if (FirebaseAuth.instance.currentUser == null) {
      _showSnack('Debes iniciar sesión para guardar un producto');
      setState(() => _isSaving = false);
      return;
    }

    if (name.isEmpty || quantity.isEmpty || int.tryParse(quantity) == null) {
      _showSnack('Por favor, completa todos los campos correctamente');
      setState(() => _isSaving = false);
      return;
    }

    if (_expiryDate == null) {
      _showSnack('Por favor, selecciona una fecha de vencimiento');
      setState(() => _isSaving = false);
      return;
    }

    // PASO 2: el stock mínimo es opcional, pero si se escribe algo debe ser
    // un entero válido y no negativo.
    final minStockText = _minStockController.text.trim();
    int? minStock;
    if (minStockText.isNotEmpty) {
      minStock = int.tryParse(minStockText);
      if (minStock == null || minStock < 0) {
        _showSnack('El stock mínimo debe ser un número entero válido');
        setState(() => _isSaving = false);
        return;
      }
    }

    try {
      final productoMap = {
        if (widget.initialProduct?['id'] != null)
          'id': widget.initialProduct!['id'],
        'name': name,
        'barcode': barcode.isNotEmpty ? barcode : null,
        'quantity': quantity,
        'unit': _selectedUnit,
        'imagePath': _imageFile?.path,
        'expirationDate': _expiryDate?.toIso8601String(),
        if (_storedAt != null) // FASE 3
          'storedAt': _storedAt!.toIso8601String(),
        'category': _selectedCategory.name, // PASO 2
        if (minStock != null) 'minStock': minStock, // PASO 2
      };

      // Delegar al provider (Fase 2) — sin Firestore directo
      await context.read<ProductProvider>().saveProduct(productoMap);

      // Notificación: lógica de presentación, se mantiene aquí
      await _scheduleNotification(name, _expiryDate!);

      // Callback opcional (inicio_screen ya no lo usa para Firestore,
      // pero se mantiene por si otras pantallas dependen de él)
      widget.onSave(productoMap);

      _showSnack(
        widget.initialProduct != null
            ? 'Producto actualizado correctamente'
            : 'Producto guardado correctamente',
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error al guardar producto: $e');
      _showSnack('Error al guardar el producto. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildExpiryDatePicker() {
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () async {
              final now = DateTime.now();
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: _expiryDate ?? now,
                firstDate: now,
                lastDate: DateTime(now.year + 5),
              );
              if (selectedDate != null) {
                setState(() => _expiryDate = selectedDate);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
              ),
              child: Text(
                _expiryDate == null
                    ? 'Seleccionar fecha de vencimiento'
                    : 'Vence el: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                style: TextStyle(
                  fontSize: 16,
                  color: _expiryDate == null ? Colors.grey : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Producto'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nombre del producto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Ej: Leche deslactosada',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 16),
            if (!_isManualAdd)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Código de barras',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      hintText: 'Ej: 7701234567890',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            const Text(
              'Cantidad',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Ej: 3',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedUnit,
                  items:
                      _units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedUnit = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── PASO 2: Categoría del alimento ────────────────────────────────
            const Text(
              'Categoría',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.shade100,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<FoodCategory>(
                  isExpanded: true,
                  value: _selectedCategory,
                  items:
                      FoodCategory.values
                          .map(
                            (cat) => DropdownMenuItem(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(cat.icon, size: 18, color: Colors.green),
                                  const SizedBox(width: 10),
                                  Text(cat.label),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── PASO 2: Alerta de Stock mínimo (opcional) ─────────────────────
            const Text(
              'Stock mínimo (opcional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Te avisaremos en la lista cuando la cantidad llegue a este valor',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _minStockController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Ej: 2',
                prefixIcon: const Icon(Icons.warning_amber_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Fecha de vencimiento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildExpiryDatePicker(),
            const SizedBox(height: 16),

            // ── FASE 3: Fecha de almacenamiento ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.kitchen, color: Colors.blueGrey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha de almacenamiento (opcional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Para saber cuántos días lleva guardado',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _storedAt ?? now,
                            firstDate: now.subtract(const Duration(days: 365)),
                            lastDate: now,
                          );
                          if (picked != null) {
                            setState(() => _storedAt = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _storedAt == null
                                    ? 'Seleccionar fecha de entrada al hogar'
                                    : 'Guardado el: ${_storedAt!.day}/${_storedAt!.month}/${_storedAt!.year}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      _storedAt == null
                                          ? Colors.grey
                                          : Colors.black87,
                                ),
                              ),
                              if (_storedAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(${DateTime.now().difference(_storedAt!).inDays} días)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _storedAt = null),
                                  child: const Icon(
                                    Icons.clear,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Foto del producto (opcional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar Foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (_imageFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _imageFile!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _guardarProducto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child:
                    _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Guardar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
