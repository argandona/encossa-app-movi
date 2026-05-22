class DetallePedido {
  final int    idDetalle;
  final int    material;
  final String materialDescripcion;
  final String materialMatricula;
  final int    cantidadSolicitada;
  final int    cantidadAprobada;

  DetallePedido({
    required this.idDetalle,
    required this.material,
    required this.materialDescripcion,
    required this.materialMatricula,
    required this.cantidadSolicitada,
    required this.cantidadAprobada,
  });

  factory DetallePedido.fromJson(Map<String, dynamic> j) => DetallePedido(
    idDetalle:           j['id_detalle_pedido'],
    material:            j['material'],
    materialDescripcion: j['material_descripcion'] ?? '',
    materialMatricula:   j['material_matricula'] ?? '',
    cantidadSolicitada:  j['cantidad_solicitada'],
    cantidadAprobada:    j['cantidad_aprobada'] ?? 0,
  );
}

class Pedido {
  final int     idPedido;
  final int     camion;
  final String  camionPlaca;
  final int     usuario;
  final String  usuarioNombre;
  final String  estado;
  final String  observacion;
  final String  fecha;
  final List<DetallePedido> detalles;

  Pedido({
    required this.idPedido,
    required this.camion,
    required this.camionPlaca,
    required this.usuario,
    required this.usuarioNombre,
    required this.estado,
    required this.observacion,
    required this.fecha,
    required this.detalles,
  });

  factory Pedido.fromJson(Map<String, dynamic> j) => Pedido(
    idPedido:     j['id_pedido'],
    camion:       j['camion'],
    camionPlaca:  j['camion_placa'] ?? '',
    usuario:      j['usuario'],
    usuarioNombre: j['usuario_nombre'] ?? '',
    estado:       j['estado'],
    observacion:  j['observacion'] ?? '',
    fecha:        j['fecha'] ?? '',
    detalles:     (j['detalles'] as List? ?? [])
                    .map((d) => DetallePedido.fromJson(d))
                    .toList(),
  );
}
