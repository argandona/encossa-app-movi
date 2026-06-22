/// Representa un elemento colocado en el lienzo de dibujo.
class ElementoCanvas {
  final String id;      // identificador único del elemento en el lienzo
  final String assetId; // id del asset en kPaleta (ej: 'casa')
  double x;             // centro X en coordenadas del lienzo (px lógicos)
  double y;             // centro Y
  double escala;        // factor de escala (1.0 = tamaño base)
  double rotacion;      // en radianes
  int    z;             // orden de capa (mayor = encima)

  ElementoCanvas({
    required this.id,
    required this.assetId,
    required this.x,
    required this.y,
    this.escala   = 1.0,
    this.rotacion = 0.0,
    this.z        = 0,
  });

  /// Serializa el elemento para persistirlo en el servidor.
  /// El `id` no se guarda: se regenera al reconstruir el lienzo.
  Map<String, dynamic> toJson() => {
    'assetId':  assetId,
    'x':        x,
    'y':        y,
    'escala':   escala,
    'rotacion': rotacion,
    'z':        z,
  };

  /// Reconstruye un elemento desde el JSON guardado.
  /// Requiere un `id` nuevo (único en el lienzo).
  factory ElementoCanvas.fromJson(Map<String, dynamic> j, {required String id}) =>
      ElementoCanvas(
        id:       id,
        assetId:  j['assetId'] as String? ?? '',
        x:        (j['x'] as num?)?.toDouble() ?? 0,
        y:        (j['y'] as num?)?.toDouble() ?? 0,
        escala:   (j['escala'] as num?)?.toDouble() ?? 1.0,
        rotacion: (j['rotacion'] as num?)?.toDouble() ?? 0.0,
        z:        (j['z'] as num?)?.toInt() ?? 0,
      );
}
