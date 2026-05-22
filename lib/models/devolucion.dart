class DetalleDevolucion {
  final int    idDetalle;
  final int    material;
  final String materialDescripcion;
  final String materialMatricula;
  final int    cantidadSolicitada;
  final int    cantidadAprobada;

  DetalleDevolucion({
    required this.idDetalle,
    required this.material,
    required this.materialDescripcion,
    required this.materialMatricula,
    required this.cantidadSolicitada,
    required this.cantidadAprobada,
  });

  factory DetalleDevolucion.fromJson(Map<String, dynamic> j) => DetalleDevolucion(
    idDetalle:           j['id_detalle_devolucion'],
    material:            j['material'],
    materialDescripcion: j['material_descripcion'] ?? '',
    materialMatricula:   j['material_matricula'] ?? '',
    cantidadSolicitada:  j['cantidad_solicitada'],
    cantidadAprobada:    j['cantidad_aprobada'] ?? 0,
  );
}

class Devolucion {
  final int     idDevolucion;
  final int     camion;
  final String  camionPlaca;
  final int     usuario;
  final String  usuarioNombre;
  final String  estado;
  final String  observacion;
  final String  fecha;
  final List<DetalleDevolucion> detalles;

  Devolucion({
    required this.idDevolucion,
    required this.camion,
    required this.camionPlaca,
    required this.usuario,
    required this.usuarioNombre,
    required this.estado,
    required this.observacion,
    required this.fecha,
    required this.detalles,
  });

  factory Devolucion.fromJson(Map<String, dynamic> j) => Devolucion(
    idDevolucion:  j['id_devolucion'],
    camion:        j['camion'],
    camionPlaca:   j['camion_placa'] ?? '',
    usuario:       j['usuario'],
    usuarioNombre: j['usuario_nombre'] ?? '',
    estado:        j['estado'],
    observacion:   j['observacion'] ?? '',
    fecha:         j['fecha'] ?? '',
    detalles:      (j['detalles'] as List? ?? [])
                     .map((d) => DetalleDevolucion.fromJson(d))
                     .toList(),
  );
}
