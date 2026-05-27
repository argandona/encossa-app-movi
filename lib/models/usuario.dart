class RolId {
  static const int superAdmin        = 1;
  static const int adminEmpresa      = 2;
  static const int encargado         = 3;
  static const int capataz           = 4;
  static const int liquidador        = 5;
  static const int encargadoAlmacen  = 6;
}

class Usuario {
  final int    idUsuario;
  final String nombre;
  final String email;
  final int    rolId;
  final String rol;
  final int?   empresaId;
  final String? empresa;

  Usuario({
    required this.idUsuario,
    required this.nombre,
    required this.email,
    required this.rolId,
    required this.rol,
    this.empresaId,
    this.empresa,
  });

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
    idUsuario: j['id_usuario'],
    nombre:    j['nombre'],
    email:     j['email'],
    rolId:     j['rol_id'],
    rol:       j['rol'] ?? '',
    empresaId: j['empresa_id'],
    empresa:   j['empresa'],
  );

  bool get puedeHacerPedido       => rolId == RolId.encargado      || rolId == RolId.capataz;
  bool get puedeHacerDevolucion   => rolId == RolId.encargado      || rolId == RolId.capataz;
  bool get puedeVerInventario     => rolId == RolId.liquidador      || rolId == RolId.encargadoAlmacen;
  bool get puedeHacerInventario   => rolId == RolId.encargadoAlmacen;
  bool get puedeAprobarPedido     => rolId == RolId.encargadoAlmacen || rolId == RolId.superAdmin;
  bool get puedeAprobarDevolucion => rolId == RolId.encargadoAlmacen || rolId == RolId.superAdmin;
  bool get puedeVerSaldosPropios  => rolId == RolId.encargado      || rolId == RolId.capataz;
  bool get puedeVerSaldosTodos    => rolId == RolId.encargadoAlmacen || rolId == RolId.superAdmin;
  bool get puedeLiquidar          => rolId == RolId.encargado      || rolId == RolId.liquidador;
}
