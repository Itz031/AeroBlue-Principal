class RegistroAire {
  final int? id;
  final String fecha;
  final int aqi;
  final String nivel;

  RegistroAire({this.id, required this.fecha, required this.aqi, required this.nivel});

  Map<String, dynamic> toMap() {
    return {'id': id, 'fecha': fecha, 'aqi': aqi, 'nivel': nivel};
  }

  factory RegistroAire.fromMap(Map<String, dynamic> map) {
    return RegistroAire(
      id: map['id'],
      fecha: map['fecha'],
      aqi: map['aqi'],
      nivel: map['nivel'],
    );
  }
}