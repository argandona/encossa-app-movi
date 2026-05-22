class Sst {
  final int     idSst;
  final String  sst;
  final String  codigo;
  final String  distrito;
  final String? actividadNombre;
  final String  empresaNombre;
  final String? fechaInicio;
  final String? fechaTermino;
  final String  montoSst;

  const Sst({
    required this.idSst,
    required this.sst,
    required this.codigo,
    required this.distrito,
    this.actividadNombre,
    required this.empresaNombre,
    this.fechaInicio,
    this.fechaTermino,
    required this.montoSst,
  });

  factory Sst.fromJson(Map<String, dynamic> j) => Sst(
    idSst:           j['id_sst'] as int,
    sst:             j['sst'] as String? ?? '',
    codigo:          j['codigo'] as String? ?? '',
    distrito:        j['distrito'] as String? ?? '',
    actividadNombre: j['actividad_nombre'] as String?,
    empresaNombre:   j['empresa_nombre'] as String? ?? '',
    fechaInicio:     j['fecha_inicio'] as String?,
    fechaTermino:    j['fecha_termino'] as String?,
    montoSst:        j['monto_sst'] as String? ?? '0.00',
  );
}

class SuministroSst {
  final int    idSstSuministro;
  final int    idSuministro;
  final String numeroSuministro;
  final String medidor;
  final String distrito;
  final String montoSum;
  final String estado;

  const SuministroSst({
    required this.idSstSuministro,
    required this.idSuministro,
    required this.numeroSuministro,
    required this.medidor,
    required this.distrito,
    required this.montoSum,
    required this.estado,
  });

  factory SuministroSst.fromJson(Map<String, dynamic> j) => SuministroSst(
    idSstSuministro:  j['id_sst_suministro'] as int,
    idSuministro:     j['id_suministro'] as int,
    numeroSuministro: j['numero_suministro'] as String? ?? '',
    medidor:          j['medidor'] as String? ?? '',
    distrito:         j['distrito'] as String? ?? '',
    montoSum:         j['monto_sum'] as String? ?? '0.00',
    estado:           j['estado'] as String? ?? '',
  );
}

class TipoTrabajoConPartidas {
  final int    idTipoTrabajo;
  final String nombre;
  final String actividadNombre;
  final List<PartidaTipoTrabajo>   partidas;
  final List<MaterialTipoTrabajo>  materiales;

  const TipoTrabajoConPartidas({
    required this.idTipoTrabajo,
    required this.nombre,
    required this.actividadNombre,
    required this.partidas,
    required this.materiales,
  });

  factory TipoTrabajoConPartidas.fromJson(Map<String, dynamic> j) =>
      TipoTrabajoConPartidas(
        idTipoTrabajo:   j['id_tipo_trabajo'] as int,
        nombre:          j['nombre'] as String? ?? '',
        actividadNombre: j['actividad_nombre'] as String? ?? '',
        partidas: (j['partidas'] as List? ?? [])
            .map((p) => PartidaTipoTrabajo.fromJson(p as Map<String, dynamic>))
            .toList(),
        materiales: (j['materiales'] as List? ?? [])
            .map((m) => MaterialTipoTrabajo.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class PartidaTipoTrabajo {
  final int    idManoDeObra;
  final String partida;
  final String descripcion;
  final String precio;

  const PartidaTipoTrabajo({
    required this.idManoDeObra,
    required this.partida,
    required this.descripcion,
    required this.precio,
  });

  factory PartidaTipoTrabajo.fromJson(Map<String, dynamic> j) =>
      PartidaTipoTrabajo(
        idManoDeObra: j['id_mano_de_obra'] as int,
        partida:      j['partida'] as String? ?? '',
        descripcion:  j['descripcion'] as String? ?? '',
        precio:       j['precio'] as String? ?? '0.00',
      );
}

class MaterialTipoTrabajo {
  final int    idMaterial;
  final String matricula;
  final String descripcion;
  final String cantidad;

  const MaterialTipoTrabajo({
    required this.idMaterial,
    required this.matricula,
    required this.descripcion,
    required this.cantidad,
  });

  factory MaterialTipoTrabajo.fromJson(Map<String, dynamic> j) =>
      MaterialTipoTrabajo(
        idMaterial:  j['id_material'] as int,
        matricula:   j['matricula']   as String? ?? '',
        descripcion: j['descripcion'] as String? ?? '',
        cantidad:    j['cantidad']    as String? ?? '0.00',
      );
}
