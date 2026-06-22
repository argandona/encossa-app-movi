import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/pedido.dart';
import '../models/devolucion.dart';
import '../models/inventario.dart';
import '../models/sst.dart';
import '../models/elemento_canvas.dart';
export '../models/sst.dart'
    show SemanaTrabajo, DiaTrabajo, SuministroSemana,
         SemanaPlanos, DiaPlanos, SstPlanoResumen;
import 'constants.dart';

class ApiException implements Exception {
  final String message;
  final int?   statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  static const _kTimeout = Duration(seconds: 30);
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _refreshToken;

  Map<String, String> get _headers => {
    'Content-Type':  'application/json',
    'Accept':        'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Map<String, String> get _publicHeaders => {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

  Future<void> loadToken() async {
    _token        = await _storage.read(key: 'token');
    _refreshToken = await _storage.read(key: 'refresh_token');
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'token', value: token);
  }

  Future<void> _saveRefreshToken(String refresh) async {
    _refreshToken = refresh;
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> logout() async {
    _token        = null;
    _refreshToken = null;
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'refresh_token');
  }

  Uri _uri(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('$kBaseUrl$path');
    if (params == null || params.isEmpty) return uri;
    return uri.replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString())));
  }

  // Intenta renovar el access token usando el refresh token.
  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    try {
      final resp = await http.post(
        _uri('auth/refresh/'),
        headers: _publicHeaders,
        body: jsonEncode({'refresh': _refreshToken}),
      ).timeout(_kTimeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        await _saveToken(data['access'] as String);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Ejecuta cualquier request HTTP con reintento automático si el token expiró.
  Future<http.Response> _execute(Future<http.Response> Function() fn) async {
    http.Response resp;
    try {
      resp = await fn().timeout(_kTimeout);
    } on TimeoutException {
      throw ApiException('Sin respuesta del servidor. Verifica tu conexión.');
    }
    if (resp.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        try {
          return await fn().timeout(_kTimeout);
        } on TimeoutException {
          throw ApiException('Sin respuesta del servidor. Verifica tu conexión.');
        }
      }
    }
    return resp;
  }

  Future<http.Response> _get(Uri uri) =>
      _execute(() => http.get(uri, headers: _headers));

  Future<http.Response> _post(Uri uri, {String? body}) =>
      _execute(() => http.post(uri, headers: _headers, body: body));

  Future<http.Response> _patch(Uri uri, {String? body}) =>
      _execute(() => http.patch(uri, headers: _headers, body: body));

  Future<http.Response> _delete(Uri uri) =>
      _execute(() => http.delete(uri, headers: _headers));

  dynamic _parse(http.Response resp) {
    final body = utf8.decode(resp.bodyBytes);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body.isEmpty ? {} : jsonDecode(body);
    }
    String detail = 'Error ${resp.statusCode}';
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        detail = json['detail'] ?? json.values.first?.toString() ?? detail;
      }
    } catch (_) {}
    throw ApiException(detail, statusCode: resp.statusCode);
  }

  // ── Auth ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String clave) async {
    final resp = await _post(
      _uri('auth/login/'),
      body: jsonEncode({'email': email, 'clave': clave}),
    );
    final data = _parse(resp);
    await _saveToken(data['access'] as String);
    await _saveRefreshToken(data['refresh'] as String);
    return data['usuario'] as Map<String, dynamic>;
  }

  // ── Stock por camión ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStockPorCamion({int? usuarioId}) async {
    final resp = await _get(
      _uri('stock-camion/por_camion/', usuarioId != null ? {'usuario': usuarioId} : null),
    );
    return List<Map<String, dynamic>>.from(_parse(resp));
  }

  // ── Almacenes ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAlmacenes() async {
    final resp = await _get(_uri('almacenes/'));
    final data = _parse(resp);
    final items = data['results'] ?? data;
    return List<Map<String, dynamic>>.from(items);
  }

  // ── Aprobación pedidos ────────────────────────────────────────────────
  Future<void> aprobarPedido(int pedidoId, {
    required int usuarioApruebaId,
    required int almacenId,
    required List<Map<String, dynamic>> detalles,
    String observacion = '',
  }) async {
    final resp = await _post(
      _uri('pedidos/$pedidoId/aprobar/'),
      body: jsonEncode({
        'accion':           'aprobar',
        'usuario_aprueba':  usuarioApruebaId,
        'almacen':          almacenId,
        'observacion':      observacion,
        'detalles':         detalles,
      }),
    );
    _parse(resp);
  }

  Future<void> rechazarPedido(int pedidoId, {
    required int usuarioApruebaId,
    String observacion = '',
  }) async {
    final resp = await _post(
      _uri('pedidos/$pedidoId/aprobar/'),
      body: jsonEncode({
        'accion':          'rechazar',
        'usuario_aprueba': usuarioApruebaId,
        'observacion':     observacion,
      }),
    );
    _parse(resp);
  }

  // ── Resumen stock por material ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getResumenStock() async {
    final resp = await _get(_uri('materiales/resumen_stock/'));
    return List<Map<String, dynamic>>.from(_parse(resp));
  }

  // ── Materiales ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMateriales({String? q}) async {
    final resp = await _get(
      _uri('materiales/', q != null ? {'q': q} : null),
    );
    final data = _parse(resp);
    final items = data['results'] ?? data;
    return List<Map<String, dynamic>>.from(items);
  }

  // ── Camion activo ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getCamionActivo(int usuarioId) async {
    final resp = await _get(
      _uri('usuario-camion/camion_activo/', {'usuario': usuarioId}),
    );
    if (resp.statusCode == 404) return null;
    return _parse(resp);
  }

  // ── Pedidos ───────────────────────────────────────────────────────────
  Future<List<Pedido>> getPedidos({String? estado}) async {
    final resp = await _get(
      _uri('pedidos/', estado != null ? {'estado': estado} : null),
    );
    final data  = _parse(resp);
    final items = data['results'] ?? data;
    return (items as List).map((j) => Pedido.fromJson(j)).toList();
  }

  Future<void> eliminarPedido(int id) async {
    final resp = await _delete(_uri('pedidos/$id/'));
    _parse(resp);
  }

  Future<void> crearPedido({
    required int    camion,
    required int    usuario,
    required String observacion,
    required List<Map<String, dynamic>> detalles,
  }) async {
    final resp = await _post(
      _uri('pedidos/'),
      body: jsonEncode({
        'camion':      camion,
        'usuario':     usuario,
        'observacion': observacion,
        'detalles':    detalles,
      }),
    );
    _parse(resp);
  }

  // ── Devoluciones ──────────────────────────────────────────────────────
  Future<List<Devolucion>> getDevoluciones({String? estado}) async {
    final resp = await _get(
      _uri('devoluciones/', estado != null ? {'estado': estado} : null),
    );
    final data  = _parse(resp);
    final items = data['results'] ?? data;
    return (items as List).map((j) => Devolucion.fromJson(j)).toList();
  }

  Future<void> crearDevolucion({
    required int    camion,
    required int    usuario,
    required String observacion,
    required List<Map<String, dynamic>> detalles,
  }) async {
    final resp = await _post(
      _uri('devoluciones/'),
      body: jsonEncode({
        'camion':      camion,
        'usuario':     usuario,
        'observacion': observacion,
        'detalles':    detalles,
      }),
    );
    _parse(resp);
  }

  // ── FCM token ─────────────────────────────────────────────────────────────
  Future<void> updateFcmToken(String token) async {
    try {
      await _post(
        _uri('usuarios/fcm_token/'),
        body: jsonEncode({'token': token}),
      );
    } catch (_) {}
  }

  // ── Usuario autenticado ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async {
    final resp = await _get(_uri('usuarios/me/'));
    return Map<String, dynamic>.from(_parse(resp));
  }

  // ── Conteo pendientes (para dashboard) ────────────────────────────────────
  Future<Map<String, int>> getPendientesConteo() async {
    final results = await Future.wait([
      _get(_uri('pedidos/',      {'estado': 'pendiente'})),
      _get(_uri('devoluciones/', {'estado': 'pendiente'})),
    ]);
    int extract(http.Response r) {
      try {
        final d = _parse(r);
        if (d is Map && d.containsKey('count')) return d['count'] as int? ?? 0;
        if (d is List) return d.length;
      } catch (_) {}
      return 0;
    }
    return {
      'pedidos':      extract(results[0]),
      'devoluciones': extract(results[1]),
    };
  }

  // ── Aprobación devoluciones ────────────────────────────────────────────────
  Future<void> aprobarDevolucion(int devId, {
    required int usuarioApruebaId,
    required int almacenDestinoId,
    required List<Map<String, dynamic>> detalles,
    String observacion = '',
  }) async {
    final resp = await _post(
      _uri('devoluciones/$devId/aprobar/'),
      body: jsonEncode({
        'accion':          'aprobar',
        'usuario_aprueba': usuarioApruebaId,
        'almacen_destino': almacenDestinoId,
        'observacion':     observacion,
        'detalles':        detalles,
      }),
    );
    _parse(resp);
  }

  Future<void> rechazarDevolucion(int devId, {
    required int usuarioApruebaId,
    String observacion = '',
  }) async {
    final resp = await _post(
      _uri('devoluciones/$devId/aprobar/'),
      body: jsonEncode({
        'accion':          'rechazar',
        'usuario_aprueba': usuarioApruebaId,
        'observacion':     observacion,
      }),
    );
    _parse(resp);
  }

  // ── Camiones ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCamiones() async {
    final resp = await _get(_uri('camiones/'));
    final data = _parse(resp);
    final items = data['results'] ?? data;
    return List<Map<String, dynamic>>.from(items);
  }

  // ── Inventarios ───────────────────────────────────────────────────────
  Future<List<Inventario>> getInventarios({int? camion, int? almacen, int? mes, int? anio}) async {
    final params = <String, dynamic>{
      if (camion  != null) 'camion':  camion,
      if (almacen != null) 'almacen': almacen,
      if (mes     != null) 'mes':     mes,
      if (anio    != null) 'anio':    anio,
    };
    final resp = await _get(_uri('inventarios/', params));
    final data  = _parse(resp);
    final items = data['results'] ?? data;
    return (items as List).map((j) => Inventario.fromJson(j)).toList();
  }

  Future<Inventario> iniciarInventario({
    required int camionId,
    required int usuarioId,
  }) async {
    final resp = await _post(
      _uri('inventarios/iniciar_o_continuar/'),
      body: jsonEncode({'camion': camionId, 'usuario': usuarioId}),
    );
    return Inventario.fromJson(_parse(resp));
  }

  Future<Inventario> guardarConteoInventario(
      int inventarioId, List<Map<String, dynamic>> detalles) async {
    final resp = await _patch(
      _uri('inventarios/$inventarioId/guardar_conteo/'),
      body: jsonEncode({'detalles': detalles}),
    );
    return Inventario.fromJson(_parse(resp));
  }

  Future<void> cerrarInventario(int inventarioId) async {
    final resp = await _post(_uri('inventarios/$inventarioId/cerrar/'));
    _parse(resp);
  }

  Future<List<int>> descargarPdfInventario(int inventarioId) async {
    final resp = await _get(_uri('inventarios/$inventarioId/descargar_pdf/'));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException('Error al descargar PDF: ${resp.statusCode}');
    }
    return resp.bodyBytes.toList();
  }

  // ── Liquidación ───────────────────────────────────────────────────────────
  Future<List<Sst>> getMisSst(int usuarioId) async {
    final resp = await _get(_uri('ssts/mis_sst/', {'usuario': usuarioId}));
    final data  = _parse(resp);
    final items = data is List ? data : (data['results'] ?? data);
    return (items as List).map((j) => Sst.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<SuministroSst>> getSuministrosSst(int sstId) async {
    final resp = await _get(_uri('ssts/$sstId/suministros/'));
    final data  = _parse(resp);
    final items = data is List ? data : (data['results'] ?? data);
    return (items as List)
        .map((j) => SuministroSst.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<TipoTrabajoConPartidas>> getTiposTrabajoSuministro(int suministroId) async {
    final resp = await _get(_uri('suministros/$suministroId/tipos_trabajo/'));
    final data  = _parse(resp);
    final items = data is List ? data : (data['results'] ?? data);
    return (items as List)
        .map((j) => TipoTrabajoConPartidas.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getManoDeObraSuministro(int suministroId) async {
    final resp = await _get(_uri('suministros/$suministroId/mano_de_obra/'));
    final data  = _parse(resp);
    final items = data is List ? data : (data['results'] ?? data);
    return List<Map<String, dynamic>>.from(items as List);
  }

  Future<List<Map<String, dynamic>>> getStockCamionUsuario(int suministroId) async {
    final resp = await _get(_uri('suministros/$suministroId/stock_camion_usuario/'));
    final data  = _parse(resp);
    final items = data is List ? data : (data['results'] ?? data);
    return List<Map<String, dynamic>>.from(items as List);
  }

  // ── Semana de trabajo (suministros de Render filtrados por usuario/semana) ──
  Future<SemanaTrabajo> getSemanaTrabajoLiquidacion(int usuarioId) async {
    final resp = await _get(
      _uri('liquidaciones/semana_trabajo/', {'usuario': usuarioId}),
    );
    return SemanaTrabajo.fromJson(_parse(resp));
  }

  Future<void> crearLiquidacion({
    // Suministro local (Control_almacen)
    int?   suministroId,
    // Suministro externo (Render)
    String suministroExterno = '',
    String sstExterno        = '',
    required int    usuarioId,
    required int    tipoTrabajoId,
    required String observacion,
    required List<Map<String, dynamic>> partidas,
    List<Map<String, dynamic>> materiales = const [],
    // Estado a fijar en Render: 'EJECUTADO' o 'DEVUELTO'
    String estadoSuministro = 'EJECUTADO',
    // Motivo (obligatorio si DEVUELTO) → observacion_contratista en Render
    String motivo           = '',
    // id del suministro en Render (para reflejar estado/observación allá)
    int?   suministroRenderId,
  }) async {
    final body = <String, dynamic>{
      'usuario':           usuarioId,
      'tipo_trabajo':      tipoTrabajoId,
      'observacion':       observacion,
      'partidas':          partidas,
      'materiales':        materiales,
      'estado_suministro': estadoSuministro,
      'motivo':            motivo,
    };
    if (suministroId != null)          body['suministro']           = suministroId;
    if (suministroExterno.isNotEmpty)  body['suministro_externo']   = suministroExterno;
    if (sstExterno.isNotEmpty)         body['sst_externo']          = sstExterno;
    if (suministroRenderId != null)    body['suministro_render_id'] = suministroRenderId;

    final resp = await _post(_uri('liquidaciones/'), body: jsonEncode(body));
    _parse(resp);
  }

  // ── Planos por SST ──────────────────────────────────────────────────────
  /// SSTs programados de la semana, agrupados por fecha, con flag tiene_plano.
  Future<SemanaPlanos> getSemanaPlanos(int usuarioId) async {
    final resp = await _get(
      _uri('planos/semana_sst/', {'usuario': usuarioId}),
    );
    return SemanaPlanos.fromJson(_parse(resp));
  }

  /// Elementos del plano de un SST (lista vacía si aún no tiene plano).
  Future<List<ElementoCanvas>> getPlano(String sstCodigo) async {
    final resp = await _get(_uri('planos/', {'sst_codigo': sstCodigo}));
    final data = _parse(resp);
    final lista = data is Map ? (data['results'] as List? ?? []) : (data as List? ?? []);
    if (lista.isEmpty) return [];
    final elementos = (lista.first['elementos'] as List? ?? []);
    var i = 0;
    return elementos
        .map((e) => ElementoCanvas.fromJson(
              e as Map<String, dynamic>,
              id: 'plano_${i++}_${e['assetId']}',
            ))
        .toList();
  }

  /// Crea o actualiza (upsert) el plano de un SST.
  Future<void> guardarPlano(
    String sstCodigo,
    int usuarioId,
    List<ElementoCanvas> elementos,
  ) async {
    final resp = await _post(_uri('planos/'), body: jsonEncode({
      'sst_codigo': sstCodigo,
      'usuario':    usuarioId,
      'elementos':  elementos.map((e) => e.toJson()).toList(),
    }));
    _parse(resp);
  }

}
