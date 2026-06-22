import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/sst.dart';

class LiquidarSuministroScreen extends StatefulWidget {
  final SuministroSemana suministro;

  const LiquidarSuministroScreen({super.key, required this.suministro});

  @override
  State<LiquidarSuministroScreen> createState() =>
      _LiquidarSuministroScreenState();
}

class _LiquidarSuministroScreenState extends State<LiquidarSuministroScreen> {
  TipoTrabajoConPartidas? _tipoSeleccionado;

  final Map<int, TextEditingController> _moControllers  = {};
  final Map<int, TextEditingController> _matControllers = {};
  final TextEditingController _obsController    = TextEditingController();
  final TextEditingController _motivoController = TextEditingController();

  // Estado a registrar: 'EJECUTADO' (MO + materiales) o 'DEVUELTO' (solo MO)
  String _estado = 'EJECUTADO';
  bool get _esDevuelto => _estado == 'DEVUELTO';

  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _moControllers.values)  c.dispose();
    for (final c in _matControllers.values) c.dispose();
    _obsController.dispose();
    _motivoController.dispose();
    super.dispose();
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
        _matControllers[m.idMaterial] = TextEditingController();
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

    // Los materiales solo se liquidan si el suministro fue EJECUTADO.
    final materiales = <Map<String, dynamic>>[];
    if (!_esDevuelto) {
      for (final m in _tipoSeleccionado!.materiales) {
        final texto    = _matControllers[m.idMaterial]?.text.trim() ?? '';
        if (texto.isEmpty) continue;
        final cantidad = double.tryParse(texto.replaceAll(',', '.'));
        if (cantidad == null || cantidad <= 0) continue;
        materiales.add({'material': m.idMaterial, 'cantidad': cantidad});
      }
    }

    // Si es DEVUELTO, el motivo es obligatorio (se guarda en Render).
    final motivo = _motivoController.text.trim();
    if (_esDevuelto && motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa el motivo de la devolución.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _guardando = true);
    try {
      final usuario = context.read<AuthProvider>().usuario!;
      await ApiService().crearLiquidacion(
        suministroExterno:  widget.suministro.suministro,
        sstExterno:         widget.suministro.sstCodigo,
        usuarioId:          usuario.idUsuario,
        tipoTrabajoId:      _tipoSeleccionado!.idTipoTrabajo,
        observacion:        _obsController.text.trim(),
        partidas:           partidas,
        materiales:         materiales,
        estadoSuministro:   _estado,
        motivo:             motivo,
        suministroRenderId: widget.suministro.idExterno,
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
    final s    = widget.suministro;
    final tipos = s.tiposTrabajo;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Liquidar ${s.suministro}',
                style: const TextStyle(fontSize: 16)),
            Text(
              s.sstCodigo.isNotEmpty ? 'SST ${s.sstCodigo}' : s.distrito,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Info suministro ────────────────────────────────────────
                _InfoCard(suministro: s),
                const SizedBox(height: 16),

                // ── Selector tipo de trabajo ───────────────────────────────
                _seccion('Tipo de trabajo'),
                const SizedBox(height: 8),
                if (tipos.isEmpty)
                  const Text(
                    'No hay tipos de trabajo configurados para esta actividad.',
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
                    items: tipos
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.nombre),
                            ))
                        .toList(),
                    onChanged: _onTipoChanged,
                  ),

                // ── Estado del suministro ──────────────────────────────────
                if (_tipoSeleccionado != null) ...[
                  const SizedBox(height: 20),
                  _seccion('Estado del suministro'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ChipEstado(
                          valor:        'EJECUTADO',
                          color:        Colors.green.shade700,
                          icon:         Icons.check_circle_outline,
                          seleccionado: !_esDevuelto,
                          onTap: () => setState(() => _estado = 'EJECUTADO'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChipEstado(
                          valor:        'DEVUELTO',
                          color:        Colors.red.shade700,
                          icon:         Icons.assignment_return_outlined,
                          seleccionado: _esDevuelto,
                          onTap: () => setState(() => _estado = 'DEVUELTO'),
                        ),
                      ),
                    ],
                  ),

                  // ── Motivo (solo si DEVUELTO, obligatorio) ─────────────────
                  if (_esDevuelto) ...[
                    const SizedBox(height: 16),
                    _seccion('Motivo de la devolución *'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _motivoController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '¿Por qué se devuelve el suministro?',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.red.shade50,
                      ),
                    ),
                  ],

                  // ── Partidas de mano de obra ───────────────────────────────
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

                  // ── Materiales (solo si EJECUTADO) ─────────────────────────
                  if (!_esDevuelto) ...[
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
                ],

                // ── Observación ────────────────────────────────────────────
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

          // ── Botón guardar ──────────────────────────────────────────────────
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
                  label: Text(
                      _guardando ? 'Guardando...' : 'Registrar liquidación'),
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
  final SuministroSemana suministro;
  const _InfoCard({required this.suministro});

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
            Text(s.suministro,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          if (s.sstCodigo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('SST ${s.sstCodigo}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ),
          if (s.distrito.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(s.distrito,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
          if (s.actividad.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(s.actividad,
                    style: TextStyle(
                        fontSize: 12, color: Colors.indigo.shade800)),
              ),
            ),
          if (s.horaInicio != null && s.horaFin != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.access_time, size: 13, color: Colors.black45),
                const SizedBox(width: 4),
                Text(
                  '${s.horaInicio!.substring(0, 5)}  –  ${s.horaFin!.substring(0, 5)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

// ── Fila de partida ───────────────────────────────────────────────────────────
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
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
                Text('S/ $precio c/u',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black38)),
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
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
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

// ── Botón de estado (EJECUTADO / DEVUELTO) ────────────────────────────────────
class _ChipEstado extends StatelessWidget {
  final String   valor;
  final Color    color;
  final IconData icon;
  final bool     seleccionado;
  final VoidCallback onTap;

  const _ChipEstado({
    required this.valor,
    required this.color,
    required this.icon,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.12) : Colors.grey.shade50,
          border: Border.all(
            color: seleccionado ? color : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: seleccionado ? color : Colors.black38),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: seleccionado ? color : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
