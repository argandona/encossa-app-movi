class DetalleInventario {
  final int    idDetalle;
  final int    material;
  final String materialDescripcion;
  final String materialMatricula;
  final int    cantidadFisica;
  final int    cantidadTeorica;
  final int    diferencia;

  DetalleInventario({
    required this.idDetalle,
    required this.material,
    required this.materialDescripcion,
    required this.materialMatricula,
    required this.cantidadFisica,
    required this.cantidadTeorica,
    required this.diferencia,
  });

  factory DetalleInventario.fromJson(Map<String, dynamic> j) => DetalleInventario(
    idDetalle:           j['id_detalle_inventario'],
    material:            j['material'],
    materialDescripcion: j['material_descripcion'] ?? '',
    materialMatricula:   j['material_matricula'] ?? '',
    cantidadFisica:      j['cantidad_fisica'],
    cantidadTeorica:     j['cantidad_teorica'],
    diferencia:          j['diferencia'],
  );
}

class Inventario {
  final int     idInventario;
  final int?    camion;
  final String  camionPlaca;
  final int?    almacen;
  final String  almacenNombre;
  final int     usuario;
  final String  usuarioNombre;
  final int     mes;
  final int     anio;
  final String  estado;
  final String  observacion;
  final String  fecha;
  final List<DetalleInventario> detalles;

  Inventario({
    required this.idInventario,
    this.camion,
    required this.camionPlaca,
    this.almacen,
    required this.almacenNombre,
    required this.usuario,
    required this.usuarioNombre,
    required this.mes,
    required this.anio,
    required this.estado,
    required this.observacion,
    required this.fecha,
    required this.detalles,
  });

  factory Inventario.fromJson(Map<String, dynamic> j) => Inventario(
    idInventario: j['id_inventario'],
    camion:       j['camion'],
    camionPlaca:  j['camion_placa'] ?? '',
    almacen:      j['almacen'],
    almacenNombre: j['almacen_nombre'] ?? '',
    usuario:      j['usuario'],
    usuarioNombre: j['usuario_nombre'] ?? '',
    mes:          j['mes'],
    anio:         j['anio'],
    estado:       j['estado'],
    observacion:  j['observacion'] ?? '',
    fecha:        j['fecha'] ?? '',
    detalles:     (j['detalles'] as List? ?? [])
                    .map((d) => DetalleInventario.fromJson(d))
                    .toList(),
  );
}
