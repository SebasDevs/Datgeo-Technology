import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_helper.dart';
import '../models/restaurant.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:exif/exif.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  InAppWebViewController? _webViewController;
  double? _latitude;
  double? _longitude;
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rucController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String? _photo1Path;
  String? _photo2Path;
  String? _photo3Path;
  String? _photo1Type;
  String? _photo2Type;
  String? _photo3Type;
  DateTime? _photo1CaptureTime;
  DateTime? _photo2CaptureTime;
  DateTime? _photo3CaptureTime;
  List<Map<String, dynamic>> _photoTypes = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  int _totalRestaurants = 0;
  int _pendingRestaurants = 0;
  bool _isApiAvailable = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkApiHealth();
    _requestLocationPermission();
    _loadRestaurants();
    _downloadPhotoTypes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _rucController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> readExifData(String photoPath) async {
    try {
      final file = File(photoPath);
      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);
      if (exifData.isEmpty) {
        debugPrint('No se encontraron datos EXIF en la foto: $photoPath');
        return;
      }
      debugPrint('Datos EXIF de la foto: $photoPath');
      for (var entry in exifData.entries) {
        debugPrint('${entry.key}: ${entry.value}');
      }
    } catch (e) {
      debugPrint('Error al leer datos EXIF: $e');
    }
  }

  Future<void> _checkApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('https://r1m8m4698f.execute-api.us-east-1.amazonaws.com/sebastiangavonel/health-check'),
      );
      if (response.statusCode == 200) {
        debugPrint('API está disponible: ${response.body}');
        setState(() {
          _isApiAvailable = true;
        });
      } else {
        debugPrint('API no disponible: ${response.statusCode}');
        setState(() {
          _isApiAvailable = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La API no está disponible. Algunas funciones pueden no funcionar.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al verificar el estado de la API: $e');
      setState(() {
        _isApiAvailable = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al verificar el estado de la API. Revisa tu conexión.'),
          ),
        );
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permiso de ubicación denegado. No se puede usar el mapa.'),
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Permiso de ubicación denegado permanentemente. Por favor, habilítalo en los ajustes.'),
            action: SnackBarAction(
              label: 'Abrir Ajustes',
              onPressed: () {
                Geolocator.openAppSettings();
              },
            ),
          ),
        );
      }
      return;
    }

    print('Permiso de ubicación concedido');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Por favor, activa el servicio de ubicación para continuar.'),
            action: SnackBarAction(
              label: 'Activar',
              onPressed: () async {
                await Geolocator.openLocationSettings();
                _tryGetLocation();
              },
            ),
          ),
        );
      }
      return;
    }

    await _tryGetLocation();
  }

  Future<void> _tryGetLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El servicio de ubicación sigue desactivado.'),
          ),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      print('Ubicación obtenida: ${_latitude}, ${_longitude}');

      if (_webViewController != null) {
        await _webViewController!.evaluateJavascript(
          source: 'centerMap(${_latitude}, ${_longitude});',
        );
      }
    } catch (e) {
      print('Error al obtener la ubicación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener la ubicación: $e'),
          ),
        );
      }
    }
  }

  Future<void> _loadRestaurants() async {
    try {
      final restaurants = await _dbHelper.getRestaurants();
      final webViewController = _webViewController;

      setState(() {
        _totalRestaurants = restaurants.length;
        _pendingRestaurants = restaurants.where((r) => !r.isSynced).length;
      });
      debugPrint('Cargando restaurantes al iniciar: $restaurants');

      for (var restaurant in restaurants) {
        String color = restaurant.isSynced ? 'black' : 'red';
        await webViewController?.evaluateJavascript(
          source: 'addMarker(${restaurant.latitude}, ${restaurant.longitude}, "$color");',
        );
      }
    } catch (e) {
      debugPrint('Error al cargar restaurantes: $e');
      setState(() {
        _totalRestaurants = 0;
        _pendingRestaurants = 0;
      });
    }
  }

  Future<void> _pickImage(int photoNumber) async {
    var cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de cámara denegado. No se puede tomar fotos.'),
          ),
        );
      }
      return;
    }

    if (cameraStatus.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de cámara denegado permanentemente. Por favor, habilítalo en los ajustes.'),
          ),
        );
      }
      return;
    }

    print('Permiso de cámara concedido');

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      String photoPath = pickedFile.path;
      await readExifData(photoPath);

      setState(() {
        if (photoNumber == 1) {
          _photo1Path = photoPath;
          _photo1CaptureTime = DateTime.now();
        } else if (photoNumber == 2) {
          _photo2Path = photoPath;
          _photo2CaptureTime = DateTime.now();
        } else if (photoNumber == 3) {
          _photo3Path = photoPath;
          _photo3CaptureTime = DateTime.now();
        }
      });
    } else {
      print('No se seleccionó ninguna foto');
    }
  }

  Future<void> _saveRestaurant() async {
    if (_latitude == null || _longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha obtenido la ubicación. Por favor, verifica los permisos.'),
          ),
        );
      }
      return;
    }

    Restaurant restaurant = Restaurant(
      name: _nameController.text,
      ruc: _rucController.text,
      latitude: _latitude!,
      longitude: _longitude!,
      comment: _commentController.text,
      photo1: _photo1Path,
      photo2: _photo2Path,
      photo3: _photo3Path,
      photo1CaptureTime: _photo1CaptureTime,
      photo2CaptureTime: _photo2CaptureTime,
      photo3CaptureTime: _photo3CaptureTime,
      createdAt: DateTime.now(),
      isSynced: false,
    );

    await _dbHelper.insertRestaurant(restaurant);
    debugPrint('Restaurante guardado correctamente en la base de datos');

    List<Restaurant> restaurants = await _dbHelper.getRestaurants();
    setState(() {
      _totalRestaurants = restaurants.length;
      _pendingRestaurants = restaurants.where((r) => !r.isSynced).length;
    });
    debugPrint('Restaurantes guardados: $restaurants');

    await _webViewController?.evaluateJavascript(
      source: 'addMarker($_latitude, $_longitude, "red");',
    );

    // Sincronizar inmediatamente después de guardar
    await _syncRestaurants();

    _nameController.clear();
    _rucController.clear();
    _commentController.clear();
    _photo1Path = null;
    _photo2Path = null;
    _photo3Path = null;
    _photo1Type = null;
    _photo2Type = null;
    _photo3Type = null;
    _photo1CaptureTime = null;
    _photo2CaptureTime = null;
    _photo3CaptureTime = null;
    _tabController.index = 0;
  }

  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _downloadPhotoTypes() async {
    try {
      final response = await http.get(
        Uri.parse('https://r1m8m4698f.execute-api.us-east-1.amazonaws.com/sebastiangavonel/photo-types'),
        headers: {
          'x-api-key': 'sRSXSzo6I05igSKNvNlJJ5MHCMHUSYvT5Z9Dx6Dm',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint('Respuesta completa del endpoint: $data');
        final List<dynamic> photoTypesData = data['data'];
        debugPrint('photoTypesData: $photoTypesData');

        setState(() {
          _photoTypes = photoTypesData.map((item) => item as Map<String, dynamic>).toList();
        });
        debugPrint('Tipos de fotos descargados: $_photoTypes');
      } else {
        debugPrint('Error al descargar tipos de fotos: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al descargar tipos de fotos: $e');
    }
  }

  Future<void> _syncRestaurants() async {
    if (!await _isConnected()) {
      debugPrint('No hay conexión a internet');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay conexión a internet. Los restaurantes se sincronizarán cuando haya conexión.'),
          ),
        );
      }
      return;
    }

    try {
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'restaurants',
        where: 'isSynced = ?',
        whereArgs: [0],
      );
      List<Restaurant> unsyncedRestaurants = List.generate(maps.length, (i) {
        return Restaurant.fromMap(maps[i]);
      });

      for (var restaurant in unsyncedRestaurants) {
        try {
          if (restaurant.name == null || restaurant.name!.isEmpty) {
            debugPrint('Error: El nombre del restaurante no puede estar vacío para ${restaurant.id}');
            continue;
          }
          if (restaurant.ruc == null || restaurant.ruc!.isEmpty) {
            debugPrint('Error: El RUC del restaurante no puede estar vacío para ${restaurant.id}');
            continue;
          }
          if (!RegExp(r'^\d{11}$').hasMatch(restaurant.ruc!)) {
            debugPrint('Error: El RUC debe tener exactamente 11 dígitos numéricos para ${restaurant.id}');
            continue;
          }
          if (restaurant.latitude == null || restaurant.longitude == null) {
            debugPrint('Error: Las coordenadas no pueden ser nulas para ${restaurant.id}');
            continue;
          }

          final Map<String, dynamic> requestBody = {
            'name': restaurant.name,
            'ruc': restaurant.ruc,
            'latitude': restaurant.latitude.toString(),
            'longitude': restaurant.longitude.toString(),
            'comment': restaurant.comment ?? '',
          };

          debugPrint('Enviando requestBody: ${jsonEncode(requestBody)}');

          final response = await http.post(
            Uri.parse('https://r1m8m4698f.execute-api.us-east-1.amazonaws.com/sebastiangavonel/restaurants'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': 'sRSXSzo6I05igSKNvNlJJ5MHCMHUSYvT5Z9Dx6Dm',
            },
            body: jsonEncode(requestBody),
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body);
            debugPrint('Respuesta del servidor al registrar restaurante: ${response.body}');

            String? uuid = data['data']?['uuid']?.toString();
            if (uuid == null || uuid.isEmpty) {
              debugPrint('Error: La respuesta del servidor no contiene un uuid válido: ${response.body}');
              continue;
            }

            for (int i = 1; i <= 3; i++) {
              String? photoPath;
              String photoTypeId;

              if (i == 1) {
                photoPath = restaurant.photo1;
                photoTypeId = '1';
              } else if (i == 2) {
                photoPath = restaurant.photo2;
                photoTypeId = '2';
              } else {
                photoPath = restaurant.photo3;
                photoTypeId = '3';
              }

              if (photoPath != null) {
                final signedUrlResponse = await http.get(
                  Uri.parse(
                      'https://r1m8m4698f.execute-api.us-east-1.amazonaws.com/sebastiangavonel/signed-url?fileName=${restaurant.ruc}_$photoTypeId.jpg'),
                  headers: {'x-api-key': 'sRSXSzo6I05igSKNvNlJJ5MHCMHUSYvT5Z9Dx6Dm'},
                );

                if (signedUrlResponse.statusCode == 200) {
                  final signedUrlData = jsonDecode(signedUrlResponse.body);
                  final signedUrl = signedUrlData['signedUrl']?.toString();
                  if (signedUrl == null || signedUrl.isEmpty) {
                    debugPrint('Error: No se obtuvo una URL firmada válida para foto $i');
                    continue;
                  }

                  final file = File(photoPath);
                  final bytes = await file.readAsBytes();
                  final uploadResponse = await http.put(
                    Uri.parse(signedUrl),
                    body: bytes,
                    headers: {
                      'Content-Type': 'image/jpeg',
                    },
                  );

                  if (uploadResponse.statusCode == 200) {
                    debugPrint('Foto $i subida a S3 para restaurante ${restaurant.name}');
                  } else {
                    debugPrint('Error al subir foto $i a S3: ${uploadResponse.statusCode}');
                  }
                } else {
                  debugPrint('Error al obtener URL firmada para foto $i: ${signedUrlResponse.statusCode}');
                }
              }
            }

            await db.update(
              'restaurants',
              {'isSynced': 1},
              where: 'id = ?',
              whereArgs: [restaurant.id],
            );
            debugPrint('Restaurante sincronizado: ${restaurant.name}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Restaurante sincronizado: ${restaurant.name}'),
                ),
              );
            }

            await _webViewController?.evaluateJavascript(
              source: 'addMarker(${restaurant.latitude}, ${restaurant.longitude}, "black");',
            );
          } else {
            debugPrint('Error al sincronizar restaurante: ${response.statusCode}');
            debugPrint('Respuesta del servidor: ${response.body}');
            if (response.statusCode == 400 && response.body.contains('Este restaurante ya se encuentra registrado')) {
              await db.update(
                'restaurants',
                {'isSynced': 1},
                where: 'id = ?',
                whereArgs: [restaurant.id],
              );
              debugPrint('Restaurante marcado como sincronizado (ya registrado en el servidor): ${restaurant.name}');

              await _webViewController?.evaluateJavascript(
                source: 'addMarker(${restaurant.latitude}, ${restaurant.longitude}, "black");',
              );
            }
          }
        } catch (e) {
          debugPrint('Error al sincronizar restaurante: $e');
        }
      }
    } catch (e) {
      debugPrint('Error al obtener restaurantes no sincronizados: $e');
    }

    await _loadRestaurants();
  }

  void _showRestaurantForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 600,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  tabs: const [
                    Tab(text: 'Datos'),
                    Tab(text: 'Fotos'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTextField(
                            label: 'Nombre',
                            controller: _nameController,
                            hintText: 'Ingrese el nombre',
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'RUC',
                            controller: _rucController,
                            hintText: 'Ingrese el RUC (11 dígitos)',
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Latitud',
                            controller: TextEditingController(text: _latitude?.toString() ?? ''),
                            readOnly: true,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Longitud',
                            controller: TextEditingController(text: _longitude?.toString() ?? ''),
                            readOnly: true,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            label: 'Comentario',
                            controller: _commentController,
                            hintText: 'Ingrese un comentario',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPhotoSection(
                            label: 'Etiqueta foto 1',
                            photoPath: _photo1Path,
                            photoType: _photo1Type,
                            onTypeChanged: (value) => setState(() => _photo1Type = value),
                            onPickImage: () => _pickImage(1),
                          ),
                          const SizedBox(height: 16),
                          _buildPhotoSection(
                            label: 'Etiqueta foto 2',
                            photoPath: _photo2Path,
                            photoType: _photo2Type,
                            onTypeChanged: (value) => setState(() => _photo2Type = value),
                            onPickImage: () => _pickImage(2),
                          ),
                          const SizedBox(height: 16),
                          _buildPhotoSection(
                            label: 'Etiqueta foto 3',
                            photoPath: _photo3Path,
                            photoType: _photo3Type,
                            onTypeChanged: (value) => setState(() => _photo3Type = value),
                            onPickImage: () => _pickImage(3),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _nameController.clear();
                                    _rucController.clear();
                                    _commentController.clear();
                                    _photo1Path = null;
                                    _photo2Path = null;
                                    _photo3Path = null;
                                    _photo1Type = null;
                                    _photo2Type = null;
                                    _photo3Type = null;
                                    _photo1CaptureTime = null;
                                    _photo2CaptureTime = null;
                                    _photo3CaptureTime = null;
                                    _tabController.index = 0;
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[100],
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _saveRestaurant();
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[100],
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Guardar',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection({
    required String label,
    required String? photoPath,
    required String? photoType,
    required ValueChanged<String?> onTypeChanged,
    required VoidCallback onPickImage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: photoType,
                items: _photoTypes
                    .map((type) => DropdownMenuItem<String>(
                  value: type['name'] as String,
                  child: Text(type['name'] as String, style: const TextStyle(fontSize: 14)),
                ))
                    .toList(),
                onChanged: onTypeChanged,
                isExpanded: true,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  height: 100,
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: photoPath != null
                      ? Image.file(
                    File(photoPath),
                    fit: BoxFit.cover,
                  )
                      : const Center(child: Icon(Icons.image, color: Colors.grey)),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onPickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tomar foto',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('GeoRest'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Total: $_totalRestaurants',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Pendientes: $_pendingRestaurants',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: ElevatedButton(
                          onPressed: _downloadPhotoTypes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[100],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Descargar tipos\n de foto',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: ElevatedButton(
                          onPressed: _syncRestaurants,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[100],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Sincronizar',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri('file:///android_asset/flutter_assets/assets/map.html')),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                      _webViewController?.addJavaScriptHandler(
                        handlerName: "onMapClick",
                        callback: (args) {
                          double lat = args[0];
                          double lon = args[1];
                          setState(() {
                            _latitude = lat;
                            _longitude = lon;
                          });
                          _showRestaurantForm();
                          print("Formulario mostrado con latitud: $lat y longitud: $lon");
                        },
                      );
                    },
                    onLoadStop: (controller, url) async {
                      print('Página cargada: $url');
                      if (_latitude != null && _longitude != null) {
                        await controller.evaluateJavascript(
                          source: 'centerMap(${_latitude}, ${_longitude});',
                        );
                      }
                      await _loadRestaurants();
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      print(consoleMessage.message);
                      if (consoleMessage.message.startsWith('Clic en el mapa:')) {
                        final parts = consoleMessage.message.split(' ');
                        final lat = double.parse(parts[3]);
                        final lon = double.parse(parts[4]);
                        setState(() {
                          _latitude = lat;
                          _longitude = lon;
                        });
                        _showRestaurantForm();
                        print('Mostrando formulario con lat: $lat, lon: $lon');
                      } else if (consoleMessage.message.startsWith('Zoom in')) {
                        print('Zoom in');
                      } else if (consoleMessage.message.startsWith('Zoom out')) {
                        print('Zoom out');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}