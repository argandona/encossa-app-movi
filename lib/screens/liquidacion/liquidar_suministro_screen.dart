import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/sst.dart';

class LiquidarSuministroScreen extends StatefulWidget {
  final SuministroSst suministro;
  final Sst           sst;

  const LiquidarSuministroScreen({
    super.key,
    required this.suministro,
    required this.sst,
  });

  @override
  State<LiquidarSuministroScreen> createState() =>
      _LiquidarSuministroScreenState();
}

class _LiquidarSuministroScreenState extends State<LiquidarSuministroScreen> {
  List<TipoTrabajoConPartidas> _tipos     = [];
  bool    _cargando   = true;
  String? _errorCarga;

  TipoTrabajoConPartidas? _tipoSeleccionado;

  // controllers por id_mano_de_obra
  final Map<int, TextEditingController> _moControllers  = {};
  // controllers por id_material
  final Map<int, TextEditingController> _matControllers = {};

  final TextEditingController _obsController = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _moControllers.values)  c.dispose();
    for (final c in _matControllers.values) c.dispose();
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _errorCarga = null; });
    try {
      final tipos = await ApiService().getTiposTrabajoSuministro(widget.suministro.idSuministro);
      if (mounted) {
        setState(() {
          _tipos    = tipos;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _errorCarga = e is ApiException ? e.message : 'Error de conexión: $e';
        _cargando   = false;
      });
    }
  }

  void _onTipoChanged(TipoTrabajoConPartidas? tipo) {
    for (final c in _moControllers.values)  c.dispose();
    for (final c in _matControllers.values) c.dispose();
    _moControllers.clear();
    _matControllers.clear();

    if (tipo != null) {
      for (final p in tipo.partidas) {
        _moControllers[p.idManoDeObra] = TextEditingController();
      }
      for (final m in tipo.materiales) {
        _matControllers[m.idMaterial] = TextEditingController(text: m.cantidad);
      }
    }
    setState(() => _tipoSeleccionado = tipo);
  }

  Future<void> _guardar() async {
    if (_tipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona un tipo de trabajo.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final partidas = <Map<String, dynamic>>[];
    for (final p in _tipoSeleccionado!.partidas) {
      final texto    = _moControllers[p.idManoDeObra]?.text.trim() ?? '';
      if (texto.isEmpty) continue;
      final cantidad = double.tryParse(texto.replaceAll(',', '.'));
      if (cantidad == null || cantidad <= 0) continue;
      partidas.add({'mano_de_obra': p.idManoDeObra, 'cantidad': cantidad});
    }

    if (partidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa al menos una cantidad mayor a cero.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final materiales = <Map<String, dynamic>>[];
    for (final m in _tipoSeleccionado!.materiales) {
      final texto    = _matControllers[m.idMaterial]?.text.trim() ?? '';
      if (texto.isEmpty) continue;
      final cantidad = double.tryParse(texto.replaceAll(',', '.'));
      if (cantidad == null || cantidad <= 0) continue;
      materiales.add({'material': m.idMaterial, 'cantidad': cantidad});
    }

    setState(() => _guardando = true);
    try {
      final usuario = context.read<AuthProvider>().usuario!;
      await ApiService().crearLiquidacion(
        suministroId:  widget.suministro.idSuministro,
        usuarioId:     usuario.idUsuario,
        tipoTrabajoId: _tipoSeleccionado!.idTipoTrabajo,
        observacion:   _obsController.text.trim(),
        partidas:      partidas,
        materiales:    materiales,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Suministro liquidado correctamente.'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suministro;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Liquidar ${s.numeroSuministro}',
                style: const TextStyle(fontSize: 16)),
            Text(
              s.medidor.isNotEmpty ? 'Medidor: ${s.medidor}' : s.distrito,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _errorCarga != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorCarga!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // ── Info suministro ──────────────────────────────
                          _InfoCard(suministro: s, sst: widget.sst),
                          const SizedBox(height: 16),

                          // ── Selector tipo de trabajo ─────────────────────
                          _seccion('Tipo de trabajo'),
                          const SizedBox(height: 8),
                          if (_tipos.isEmpty)
                            const Text(
                              'No hay tipos de trabajo configurados.',
                              style: TextStyle(color: Colors.black45),
                            )
                          else
                            DropdownButtonFormField<TipoTrabajoConPartidas>(
                              value: _tipoSeleccionado,
                              hint: const Text('Selecciona un tipo de trabajo'),
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              items: _tipos
                                  .map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t.nombre),
                                      ))
                                  .toList(),
                              onChanged: _onTipoChanged,
                            ),

                          // ── Partidas de mano de obra ─────────────────────
                          if (_tipoSeleccionado != null) ...[
                            const SizedBox(height: 20),
                            _seccion('Mano de obra'),
                            const SizedBox(height: 8),
                            if (_tipoSeleccionado!.partidas.isEmpty)
                              const Text(
                                'Este tipo de trabajo no tiene partidas configuradas.',
                                style: TextStyle(color: Colors.black45),
                              )
                            else
                              ...(_tipoSeleccionado!.partidas.map((p) => _PartidaRow(
                                    partida:     p.partida,
                                    descripcion: p.descripcion,
                                    precio:      p.precio,
                                    controller:  _moControllers[p.idManoDeObra]!,
                                  ))),

                            // ── Materiales ───────────────────────────────────
                            const SizedBox(height: 20),
                            _seccion('Material'),
                            const SizedBox(height: 8),
                            if (_tipoSeleccionado!.materiales.isEmpty)
                              const Text(
                                'Este tipo de trabajo no tiene materiales configurados.',
                                style: TextStyle(color: Colors.black45),
                              )
                            else
                              ...(_tipoSeleccionado!.materiales.map((m) => _MaterialRow(
                                    matricula:   m.matricula,
                                    descripcion: m.descripcion,
                                    controller:  _matControllers[m.idMaterial]!,
                                  ))),
                          ],

                          // ── Observación ──────────────────────────────────
                          const SizedBox(height: 20),
                          _seccion('Observación'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _obsController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Opcional...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),

                    // ── Botón guardar ────────────────────────────────────────
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _guardando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save_outlined),
                            label: Text(_guardando
                                ? 'Guardando...'
                                : 'Registrar liquidación'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _seccion(String texto) => Text(
        texto,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 0.5),
      );
}

// ── Tarjeta info suministro ───────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final SuministroSst suministro;
  final Sst           sst;
  const _InfoCard({required this.suministro, required this.sst});

  @override
  Widget build(BuildContext context) {
    final s = suministro;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.electrical_services_outlined,
                color: Color(0xFF1A237E), size: 18),
            const SizedBox(width: 8),
            Text(s.numeroSuministro,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          if (s.medidor.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Medidor: ${s.medidor}',
                  style: const TextStyle(fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${sst.sst.isNotEmpty ? "SST ${sst.sst}" : sst.codigo}  •  ${s.distrito.isNotEmpty ? s.distrito : sst.distrito}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fila de partida de mano de obra ──────────────────────────────────────────
class _PartidaRow extends StatelessWidget {
  final String                partida;
  final String                descripcion;
  final String                precio;
  final TextEditingController controller;

  const _PartidaRow({
    required this.partida,
    required this.descripcion,
    required this.precio,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partida,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(descripcion,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
                Text('S/ $precio c/u',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                labelText: 'Cant.',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fila de material ──────────────────────────────────────────────────────────
class _MaterialRow extends StatelessWidget {
  final String                matricula;
  final String                descripcion;
  final TextEditingController controller;

  const _MaterialRow({
    required this.matricula,
    required this.descripcion,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(matricula,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(descripcion,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                labelText: 'Cant.',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
