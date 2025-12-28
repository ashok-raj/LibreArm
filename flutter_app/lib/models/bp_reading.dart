class BPReading {
  final double sys;
  final double dia;
  final double? map;
  final double? hr;

  BPReading({
    required this.sys,
    required this.dia,
    this.map,
    this.hr,
  });

  bool get isPlausible {
    if (!sys.isFinite || !dia.isFinite) return false;
    return (sys >= 60 && sys <= 260) && (dia >= 40 && dia <= 160);
  }

  @override
  String toString() => 'BPReading(sys: $sys, dia: $dia, map: $map, hr: $hr)';
}
