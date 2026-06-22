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

// ── Modelos para el endpoint planos/semana_sst ────────────────────────────────

class SstPlanoResumen {
  final String sstCodigo;
  final String distrito;
  final String actividad;
  final bool   tienePlano;

  const SstPlanoResumen({
    required this.sstCodigo,
    required this.distrito,
    required this.actividad,
    required this.tienePlano,
  });

  factory SstPlanoResumen.fromJson(Map<String, dynamic> j) => SstPlanoResumen(
    sstCodigo:  j['sst_codigo'] as String? ?? '',
    distrito:   j['distrito']   as String? ?? '',
    actividad:  j['actividad']  as String? ?? '',
    tienePlano: j['tiene_plano'] as bool? ?? false,
  );
}

class DiaPlanos {
  final String fecha;
  final List<SstPlanoResumen> ssts;
  const DiaPlanos({required this.fecha, required this.ssts});

  factory DiaPlanos.fromJson(Map<String, dynamic> j) => DiaPlanos(
    fecha: j['fecha'] as String? ?? '',
    ssts: (j['ssts'] as List? ?? [])
        .map((s) => SstPlanoResumen.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

class SemanaPlanos {
  final String desde;
  final String hasta;
  final List<DiaPlanos> dias;
  const SemanaPlanos({required this.desde, required this.hasta, required this.dias});

  factory SemanaPlanos.fromJson(Map<String, dynamic> j) => SemanaPlanos(
    desde: (j['semana'] as Map<String, dynamic>?)?['desde'] as String? ?? '',
    hasta: (j['semana'] as Map<String, dynamic>?)?['hasta'] as String? ?? '',
    dias: (j['dias'] as List? ?? [])
        .map((d) => DiaPlanos.fromJson(d as Map<String, dynamic>))
        .toList(),
  );
}


// ── Modelos para el endpoint semana_trabajo ───────────────────────────────────

class SuministroSemana {
  final int    idExterno;
  final String sstCodigo;
  final String suministro;
  final String direccion;
  final String distrito;
  final String actividad;
  final String? horaInicio;
  final String? horaFin;
  final List<TipoTrabajoConPartidas> tiposTrabajo;

  const SuministroSemana({
    required this.idExterno,
    required this.sstCodigo,
    required this.suministro,
    required this.direccion,
    required this.distrito,
    required this.actividad,
    this.horaInicio,
    this.horaFin,
    required this.tiposTrabajo,
  });

  factory SuministroSemana.fromJson(Map<String, dynamic> j) => SuministroSemana(
    idExterno:   j['id'] as int,
    sstCodigo:   j['sst_codigo'] as String? ?? '',
    suministro:  j['suministro'] as String? ?? '',
    direccion:   j['direccion'] as String? ?? '',
    distrito:    (j['distrito'] as Map<String, dynamic>?)?['nombre_distrito'] as String? ?? '',
    actividad:   (j['actividad'] as Map<String, dynamic>?)?['nombre_actividad'] as String? ?? '',
    horaInicio:  j['hora_inicio_programada'] as String?,
    horaFin:     j['hora_fin_programada'] as String?,
    tiposTrabajo: (j['tipos_trabajo_disponibles'] as List? ?? [])
        .map((t) => TipoTrabajoConPartidas.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

class DiaTrabajo {
  final String fecha;
  final List<SuministroSemana> suministros;
  const DiaTrabajo({required this.fecha, required this.suministros});

  factory DiaTrabajo.fromJson(Map<String, dynamic> j) => DiaTrabajo(
    fecha: j['fecha'] as String? ?? '',
    suministros: (j['suministros'] as List? ?? [])
        .map((s) => SuministroSemana.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

class SemanaTrabajo {
  final String desde;
  final String hasta;
  final List<DiaTrabajo> dias;
  const SemanaTrabajo({required this.desde, required this.hasta, required this.dias});

  factory SemanaTrabajo.fromJson(Map<String, dynamic> j) => SemanaTrabajo(
    desde: (j['semana'] as Map<String, dynamic>?)?['desde'] as String? ?? '',
    hasta: (j['semana'] as Map<String, dynamic>?)?['hasta'] as String? ?? '',
    dias: (j['dias'] as List? ?? [])
        .map((d) => DiaTrabajo.fromJson(d as Map<String, dynamic>))
        .toList(),
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

  const MaterialTipoTrabajo({
    required this.idMaterial,
    required this.matricula,
    required this.descripcion,
  });

  factory MaterialTipoTrabajo.fromJson(Map<String, dynamic> j) =>
      MaterialTipoTrabajo(
        idMaterial:  j['id_material'] as int,
        matricula:   j['matricula']   as String? ?? '',
        descripcion: j['descripcion'] as String? ?? '',
      );
}
