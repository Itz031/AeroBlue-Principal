class PronosticoAire {
  final int aqi;
  final double temperatura;
  final String clasificacion;
  final String contaminantePrincipal;

  PronosticoAire({
    required this.aqi,
    required this.temperatura,
    required this.clasificacion,
    required this.contaminantePrincipal,
  });

  factory PronosticoAire.fromJson(Map<String, dynamic> json) {
    return PronosticoAire(
      aqi: json['aqi'] ?? 0,
      temperatura: json['temperatura']?.toDouble() ?? 0.0,
      clasificacion: json['clasificacion'] ?? 'Desconocido',
      contaminantePrincipal: json['contaminante_principal'] ?? 'N/A',
    );
  }
}