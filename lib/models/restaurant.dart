class Restaurant {
  final int? id;
  final String name;
  final String ruc;
  final double latitude;
  final double longitude;
  final String comment;
  final String? photo1;
  final String? photo2;
  final String? photo3;
  final DateTime? photo1CaptureTime;
  final DateTime? photo2CaptureTime;
  final DateTime? photo3CaptureTime;
  final DateTime createdAt;
  final bool isSynced;

  Restaurant({
    this.id,
    required this.name,
    required this.ruc,
    required this.latitude,
    required this.longitude,
    required this.comment,
    this.photo1,
    this.photo2,
    this.photo3,
    this.photo1CaptureTime,
    this.photo2CaptureTime,
    this.photo3CaptureTime,
    required this.createdAt,
    this.isSynced = false, // Valor por defecto para nuevos restaurantes
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ruc': ruc,
      'latitude': latitude,
      'longitude': longitude,
      'comment': comment,
      'photo1': photo1,
      'photo2': photo2,
      'photo3': photo3,
      'photo1CaptureTime': photo1CaptureTime?.toIso8601String(),
      'photo2CaptureTime': photo2CaptureTime?.toIso8601String(),
      'photo3CaptureTime': photo3CaptureTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    // Validar name
    final String name = map['name']?.toString() ?? '';
    if (name.isEmpty) {
      throw Exception('El campo "name" no puede estar vacío en el mapa: $map');
    }

    // Validar ruc
    final String ruc = map['ruc']?.toString() ?? '';
    if (ruc.isEmpty) {
      throw Exception('El campo "ruc" no puede estar vacío en el mapa: $map');
    }

    // Validar latitude y longitude
    final double latitude = map['latitude']?.toDouble() ?? 0.0;
    final double longitude = map['longitude']?.toDouble() ?? 0.0;

    if (latitude < -90 || latitude > 90) {
      throw Exception('La latitud debe estar entre -90 y 90: $latitude');
    }
    if (longitude < -180 || longitude > 180) {
      throw Exception('La longitud debe estar entre -180 y 180: $longitude');
    }

    return Restaurant(
      id: map['id'],
      name: name,
      ruc: ruc,
      latitude: latitude,
      longitude: longitude,
      comment: map['comment']?.toString() ?? '', // Comentario puede estar vacío
      photo1: map['photo1'],
      photo2: map['photo2'],
      photo3: map['photo3'],
      photo1CaptureTime: map['photo1CaptureTime'] != null
          ? DateTime.parse(map['photo1CaptureTime'])
          : null,
      photo2CaptureTime: map['photo2CaptureTime'] != null
          ? DateTime.parse(map['photo2CaptureTime'])
          : null,
      photo3CaptureTime: map['photo3CaptureTime'] != null
          ? DateTime.parse(map['photo3CaptureTime'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      isSynced: map['isSynced'] == 1,
    );
  }

  @override
  String toString() {
    return 'Restaurant(id: $id, name: $name, ruc: $ruc, latitude: $latitude, longitude: $longitude, comment: $comment, photo1: $photo1, photo2: $photo2, photo3: $photo3, photo1CaptureTime: $photo1CaptureTime, photo2CaptureTime: $photo2CaptureTime, photo3CaptureTime: $photo3CaptureTime, createdAt: $createdAt, isSynced: $isSynced)';
  }
}