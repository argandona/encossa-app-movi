import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/sst.dart';
import 'liquidar_suministro_screen.dart';

class LiquidacionScreen extends StatefulWidget {
  const LiquidacionScreen({super.key});

  @override
  State<LiquidacionScreen> createState() => _LiquidacionScreenState();
}

class _LiquidacionScreenState extends State<LiquidacionScreen> {
  List<Sst>? _ssts;
  String?    _error;
  bool       _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final usuario = context.read<AuthProvider>().usuario!;
      final ssts = await ApiService().getMisSst(usuario.idUsuario);
      if (mounted) setState(() { _ssts = ssts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e is ApiException ? e.message : 'Error de conexión: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Liquidación'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(mensaje: _error!, onRetry: _cargar)
              : _ssts!.isEmpty
                  ? const Center(
                      child: Text('No tienes SSTs asignados.',
                          style: TextStyle(color: Colors.black54)))
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _ssts!.length,
                        itemBuilder: (context, i) => _SstCard(
                          sst: _ssts![i],
                          onSuministroLiquidado: _cargar,
                        ),
                      ),
                    ),
    );
  }
}

// ── Tarjeta SST con suministros expandibles ───────────────────────────────────
class _SstCard extends StatefulWidget {
  final Sst          sst;
  final VoidCallback onSuministroLiquidado;

  const _SstCard({required this.sst, required this.onSuministroLiquidado});

  @override
  State<_SstCard> createState() => _SstCardState();
}

class _SstCardState extends State<_SstCard> {
  List<SuministroSst>? _suministros;
  bool _cargando = false;
  bool _expandido = false;

  Future<void> _cargarSuministros() async {
    if (_suministros != null) return; // ya cargados
    setState(() => _cargando = true);
    try {
      final lista = await ApiService().getSuministrosSst(widget.sst.idSst);
      if (mounted) setState(() { _suministros = lista; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _suministros = []; _cargando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sst = widget.sst;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8EAF6),
          child: Icon(Icons.assignment_outlined, color: Color(0xFF1A237E)),
        ),
        title: Text(
          sst.sst.isNotEmpty ? 'SST ${sst.sst}' : sst.codigo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sst.codigo.isNotEmpty && sst.sst.isNotEmpty)
              Text(sst.codigo,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(sst.distrito, style: const TextStyle(fontSize: 13)),
            if (sst.actividadNombre != null)
              Text(sst.actividadNombre!,
                  style: const TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
        onExpansionChanged: (expanded) {
          setState(() => _expandido = expanded);
          if (expanded) _cargarSuministros();
        },
        children: [
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_suministros == null || _suministros!.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text('Sin suministros asignados.',
                  style: TextStyle(color: Colors.black45)),
            )
          else
            ...(_suministros!.map((s) => _SuministroTile(
                  suministro: s,
                  sst: sst,
                  onLiquidado: () {
                    // refrescar suministros de esta SST
                    setState(() => _suministros = null);
                    _cargarSuministros();
                    widget.onSuministroLiquidado();
                  },
                ))),
        ],
      ),
    );
  }
}

// ── Fila de suministro dentro de la SST ──────────────────────────────────────
class _SuministroTile extends StatelessWidget {
  final SuministroSst  suministro;
  final Sst            sst;
  final VoidCallback   onLiquidado;

  const _SuministroTile({
    required this.suministro,
    required this.sst,
    required this.onLiquidado,
  });

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'ejecutado': return Colors.green;
      case 'devuelto':  return Colors.orange;
      default:          return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s       = suministro;
    final activo  = s.estado == 'asignado';

    return InkWell(
      onTap: activo
          ? () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LiquidarSuministroScreen(
                    suministro: s,
                    sst: sst,
                  ),
                ),
              );
              onLiquidado();
            }
          : null,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: activo
                ? _colorEstado(s.estado).withOpacity(0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.electrical_services_outlined,
              color: activo ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.numeroSuministro,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: activo ? Colors.black87 : Colors.black45)),
                  if (s.medidor.isNotEmpty)
                    Text('Medidor: ${s.medidor}',
                        style: TextStyle(
                            fontSize: 12,
                            color: activo ? Colors.black54 : Colors.black38)),
                  if (s.distrito.isNotEmpty)
                    Text(s.distrito,
                        style: TextStyle(
                            fontSize: 12,
                            color: activo ? Colors.black54 : Colors.black38)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _colorEstado(s.estado).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _colorEstado(s.estado).withOpacity(0.4)),
                  ),
                  child: Text(
                    s.estado.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _colorEstado(s.estado)),
                  ),
                ),
                if (activo)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.chevron_right,
                        size: 16, color: Colors.black38),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String       mensaje;
  final VoidCallback onRetry;
  const _ErrorView({required this.mensaje, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(mensaje, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
}
