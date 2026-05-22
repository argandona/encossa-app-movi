import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/inventario.dart';

class CrearInventarioScreen extends StatefulWidget {
  const CrearInventarioScreen({super.key});
  @override
  State<CrearInventarioScreen> createState() => _CrearInventarioScreenState();
}

class _CrearInventarioScreenState extends State<CrearInventarioScreen> {
  static const _verde = Color(0xFF2E7D32);

  // ── Fase 1: selección de camión ──────────────────────────────────────────
  int _fase = 1;
  List<Map<String, dynamic>> _camiones     = [];
  Map<String, dynamic>?      _camionSel;
  bool                       _loadingCamiones = true;

  // ── Fase 2: conteo ───────────────────────────────────────────────────────
  Inventario? _inventario;
  // detalleId → TextEditingController con cantidad_fisica actual
  final Map<int, TextEditingController> _ctrls = {};
  int?       _materialActivo;          // idDetalle del material en edición
  final Set<int> _revisados = {};      // idDetalle marcados como revisados
  bool _loadingInventario = false;
  bool _guardando         = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCamiones();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _cargarCamiones() async {
    setState(() { _loadingCamiones = true; _error = null; });
    try {
      final data = await ApiService().getCamiones();
      setState(() {
        _camiones  = data;
        _camionSel = data.isNotEmpty ? data.first : null;
      });
    } catch (e) {
      setState(() => _error = 'Error al cargar camiones: $e');
    } finally {
      setState(() => _loadingCamiones = false);
    }
  }

  Future<void> _iniciar() async {
    if (_camionSel == null) return;
    final usuario = context.read<AuthProvider>().usuario!;
    setState(() { _loadingInventario = true; _error = null; });
    try {
      final inv = await ApiService().iniciarInventario(
        camionId:  _camionSel!['id_camion'],
        usuarioId: usuario.idUsuario,
      );
      _inicializarCtrls(inv);
      setState(() { _inventario = inv; _fase = 2; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingInventario = false);
    }
  }

  void _inicializarCtrls(Inventario inv) {
    for (final c in _ctrls.values) c.dispose();
    _ctrls.clear();
    _revisados.clear();
    _materialActivo = null;
    for (final d in inv.detalles) {
      _ctrls[d.idDetalle] = TextEditingController(text: '${d.cantidadFisica}');
    }
  }

  Future<void> _guardarBorrador() async {
    if (_inventario == null) return;
    setState(() { _guardando = true; _error = null; });
    try {
      final detalles = _detallesPayload();
      final updated  = await ApiService()
          .guardarConteoInventario(_inventario!.idInventario, detalles);
      _inicializarCtrls(updated);
      setState(() => _inventario = updated);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador guardado'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _guardando = false);
    }
  }

  void _irAResumen() {
    // Cambia de fase inmediatamente — sin llamada de red
    setState(() { _fase = 3; _error = null; });
  }

  Future<void> _cerrar() async {
    if (_inventario == null) return;

    // Todos los materiales deben estar marcados como revisados
    final sinRevisar = _inventario!.detalles
        .where((d) => !_revisados.contains(d.idDetalle))
        .toList();
    if (sinRevisar.isNotEmpty) {
      setState(() => _error =
          'Debes marcar como revisados todos los materiales antes de cerrar '
          '(faltan ${sinRevisar.length}).');
      return;
    }

    setState(() { _guardando = true; _error = null; });
    try {
      // Guarda el conteo actual y luego cierra
      await ApiService()
          .guardarConteoInventario(_inventario!.idInventario, _detallesPayload());
      await ApiService().cerrarInventario(_inventario!.idInventario);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Inventario cerrado correctamente'),
              backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _guardando = false);
    }
  }

  List<Map<String, dynamic>> _detallesPayload() {
    return _inventario!.detalles.map((d) => {
      'id_detalle_inventario': d.idDetalle,
      'cantidad_fisica': int.tryParse(_ctrls[d.idDetalle]?.text ?? '') ?? d.cantidadFisica,
    }).toList();
  }

  int get _totalDiferencias {
    if (_inventario == null) return 0;
    return _inventario!.detalles.where((d) {
      final fis = int.tryParse(_ctrls[d.idDetalle]?.text ?? '') ?? d.cantidadFisica;
      return fis != d.cantidadTeorica;
    }).length;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _verde,
        foregroundColor: Colors.white,
        title: Text(_titulo),
        leading: _fase > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() { _fase--; _error = null; }),
              )
            : null,
      ),
      body: switch (_fase) {
        1 => _buildSeleccion(),
        2 => _buildConteo(),
        3 => _buildResumen(),
        _ => const SizedBox(),
      },
    );
  }

  String get _titulo => switch (_fase) {
    1 => 'Nuevo Inventario',
    2 => 'Conteo — ${_camionSel?['placa'] ?? ''}',
    3 => 'Resumen — ${_camionSel?['placa'] ?? ''}',
    _ => 'Inventario',
  };

  // ── Fase 1 ────────────────────────────────────────────────────────────────

  Widget _buildSeleccion() {
    if (_loadingCamiones) return const Center(child: CircularProgressIndicator());
    if (_camiones.isEmpty) {
      return const Center(child: Text('No hay camiones registrados'));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selecciona el camión a inventariar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          // Lista de camiones como cards seleccionables
          Expanded(
            child: ListView.builder(
              itemCount: _camiones.length,
              itemBuilder: (_, i) {
                final c       = _camiones[i];
                final sel     = _camionSel?['id_camion'] == c['id_camion'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: sel ? _verde : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => setState(() => _camionSel = c),
                    leading: CircleAvatar(
                      backgroundColor:
                          sel ? _verde : Colors.grey.shade200,
                      child: Icon(Icons.local_shipping,
                          color: sel ? Colors.white : Colors.grey),
                    ),
                    title: Text(c['placa'] ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: sel ? _verde : null)),
                    subtitle: Text(c['descripcion'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                    trailing: sel
                        ? Icon(Icons.check_circle, color: _verde)
                        : null,
                  ),
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _camionSel == null || _loadingInventario
                  ? null
                  : _iniciar,
              icon: _loadingInventario
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: const Text('Iniciar Inventario',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fase 2 ────────────────────────────────────────────────────────────────

  Widget _buildConteo() {
    final inv = _inventario;
    if (inv == null) return const Center(child: CircularProgressIndicator());

    final esBorrador  = inv.estado == 'borrador';
    final difs        = _totalDiferencias;
    final totalItems  = inv.detalles.length;
    final revisados   = _revisados.length;

    return Column(
      children: [
        // Barra de estado
        Container(
          color: inv.estado == 'cerrado'
              ? Colors.grey.shade200
              : Colors.green.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(
              inv.estado == 'cerrado' ? Icons.lock_outline : Icons.edit_note,
              size: 18,
              color: inv.estado == 'cerrado' ? Colors.grey : _verde,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                inv.estado == 'cerrado'
                    ? 'Inventario cerrado — solo lectura'
                    : esBorrador && totalItems > 0
                        ? 'Toca un material para contarlo  •  $revisados/$totalItems revisados'
                        : 'Borrador',
                style: TextStyle(
                    fontSize: 12,
                    color: inv.estado == 'cerrado'
                        ? Colors.grey
                        : Colors.green.shade800),
              ),
            ),
            if (difs > 0)
              Chip(
                label: Text('$difs dif.',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: Colors.orange,
                padding: EdgeInsets.zero,
              ),
          ]),
        ),
        // Encabezado columnas
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            const Expanded(
                flex: 4,
                child: Text('Material',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey))),
            SizedBox(
                width: 56,
                child: const Text('Teórico',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey))),
            SizedBox(
                width: 72,
                child: const Text('Físico',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey))),
            SizedBox(
                width: 40,
                child: Icon(Icons.check_circle_outline,
                    size: 16, color: Colors.grey.shade500)),
          ]),
        ),
        // Lista de materiales
        Expanded(
          child: inv.detalles.isEmpty
              ? const Center(
                  child: Text('Sin materiales en este camión',
                      style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  itemCount: inv.detalles.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (_, i) {
                    final d        = inv.detalles[i];
                    final ctrl     = _ctrls[d.idDetalle];
                    final esActivo = _materialActivo == d.idDetalle;
                    final esRev    = _revisados.contains(d.idDetalle);
                    final fis      = int.tryParse(ctrl?.text ?? '') ?? d.cantidadFisica;
                    final dif      = fis - d.cantidadTeorica;

                    return InkWell(
                      onTap: esBorrador
                          ? () => setState(() => _materialActivo = d.idDetalle)
                          : null,
                      child: Container(
                        color: esActivo
                            ? _verde.withOpacity(0.07)
                            : esRev
                                ? Colors.green.withOpacity(0.04)
                                : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(children: [
                          // Material
                          Expanded(
                            flex: 4,
                            child: Row(children: [
                              // Indicador de activo
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 4,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: esActivo ? _verde : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.materialDescripcion,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: esRev && !esActivo
                                                ? Colors.grey.shade500
                                                : null)),
                                    Text(d.materialMatricula,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                          // Teórico
                          SizedBox(
                            width: 56,
                            child: Column(children: [
                              Text('${d.cantidadTeorica}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              if (dif != 0)
                                Text(
                                  dif > 0 ? '+$dif' : '$dif',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: dif > 0 ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold),
                                ),
                            ]),
                          ),
                          // Físico
                          SizedBox(
                            width: 72,
                            child: esActivo && esBorrador
                                ? TextField(
                                    controller: ctrl,
                                    autofocus: true,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    textAlign: TextAlign.center,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                            color: dif != 0
                                                ? Colors.orange
                                                : _verde,
                                            width: 2),
                                      ),
                                      filled: true,
                                      fillColor: dif != 0
                                          ? Colors.orange.shade50
                                          : Colors.green.shade50,
                                    ),
                                  )
                                : Text(
                                    ctrl?.text ?? '${d.cantidadFisica}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: !esBorrador
                                          ? null
                                          : esActivo
                                              ? _verde
                                              : Colors.grey.shade400,
                                    ),
                                  ),
                          ),
                          // Checkbox revisado
                          SizedBox(
                            width: 40,
                            child: esBorrador
                                ? Checkbox(
                                    value: esRev,
                                    activeColor: _verde,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (val) => setState(() {
                                      if (val == true) {
                                        _revisados.add(d.idDetalle);
                                      } else {
                                        _revisados.remove(d.idDetalle);
                                      }
                                    }),
                                  )
                                : esRev
                                    ? Icon(Icons.check_circle,
                                        size: 20, color: _verde)
                                    : const SizedBox(),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        // Footer
        if (esBorrador)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, -2))
              ],
            ),
            child: Column(children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _verde,
                        side: const BorderSide(color: Color(0xFF2E7D32))),
                    onPressed: _guardando ? null : _guardarBorrador,
                    icon: _guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Guardar borrador'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(builder: (context) {
                    final total      = _inventario?.detalles.length ?? 0;
                    final todosRev   = _revisados.length >= total && total > 0;
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: todosRev ? _verde : Colors.grey,
                          foregroundColor: Colors.white),
                      onPressed: _guardando
                          ? null
                          : todosRev
                              ? _irAResumen
                              : () => setState(() => _error =
                                  'Marca todos los materiales como revisados '
                                  '(${_revisados.length}/$total).'),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(todosRev
                          ? 'Ver resumen'
                          : 'Ver resumen (${_revisados.length}/$total)'),
                    );
                  }),
                ),
              ]),
            ]),
          ),
      ],
    );
  }

  // ── Fase 3: Resumen ───────────────────────────────────────────────────────

  // Devuelve la cantidad física actual (desde el controlador) para un detalle
  int _fisActual(DetalleInventario d) =>
      int.tryParse(_ctrls[d.idDetalle]?.text ?? '') ?? d.cantidadFisica;

  Widget _buildResumen() {
    final inv    = _inventario!;
    final conDif = inv.detalles
        .where((d) => _fisActual(d) != d.cantidadTeorica)
        .toList();
    final sinDif = inv.detalles.length - conDif.length;

    return Column(
      children: [
        // Resumen numérico
        Container(
          color: Colors.green.shade50,
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ResumenChip(
                  label: 'Sin diferencia',
                  valor: sinDif,
                  color: Colors.green),
              _ResumenChip(
                  label: 'Con diferencia',
                  valor: conDif.length,
                  color: conDif.isEmpty ? Colors.grey : Colors.orange),
            ],
          ),
        ),
        // Detalle diferencias
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (conDif.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 56, color: Colors.green.shade400),
                      const SizedBox(height: 8),
                      const Text('Todo el stock coincide',
                          style: TextStyle(
                              fontSize: 15, color: Colors.green)),
                    ],
                  ),
                )
              else ...[
                Text('Materiales con diferencia (${conDif.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.orange)),
                const SizedBox(height: 8),
                ...conDif.map((d) {
                  final fis = _fisActual(d);
                  final dif = fis - d.cantidadTeorica;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(d.materialDescripcion,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(d.materialMatricula,
                          style: const TextStyle(fontSize: 11)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Teórico: ${d.cantidadTeorica}',
                              style: const TextStyle(fontSize: 11)),
                          Text('Físico: $fis',
                              style: const TextStyle(fontSize: 11)),
                          Text(dif > 0 ? '+$dif' : '$dif',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: dif > 0
                                      ? Colors.blue
                                      : Colors.red)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, -2))
            ],
          ),
          child: Column(children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style:
                        const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _guardando
                      ? null
                      : () => setState(() { _fase = 2; _error = null; }),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Seguir editando'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _verde,
                      foregroundColor: Colors.white),
                  onPressed: _guardando ? null : _cerrar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.lock, size: 18),
                  label: const Text('Cerrar inventario'),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
  }
}

class _ResumenChip extends StatelessWidget {
  final String label;
  final int    valor;
  final Color  color;
  const _ResumenChip(
      {required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text('$valor',
          style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: color)),
      Text(label,
          style: TextStyle(fontSize: 12, color: color)),
    ]);
  }
}
