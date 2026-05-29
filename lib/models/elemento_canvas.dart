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
}
