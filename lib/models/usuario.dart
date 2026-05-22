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

  bool get puedeHacerPedido       => rolId == 3 || rolId == 4;
  bool get puedeHacerDevolucion   => rolId == 3 || rolId == 4;
  bool get puedeVerInventario     => rolId == 5 || rolId == 6;
  bool get puedeHacerInventario   => rolId == 6;
  bool get puedeAprobarPedido     => rolId == 6 || rolId == 1;
  bool get puedeAprobarDevolucion => rolId == 6 || rolId == 1;
  bool get puedeVerSaldosPropios  => rolId == 3 || rolId == 4;
  bool get puedeVerSaldosTodos    => rolId == 6 || rolId == 1;
  bool get puedeLiquidar          => rolId == 3 || rolId == 5; // encargado o liquidador
}
