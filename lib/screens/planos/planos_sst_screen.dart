import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../dibujo/dibujo_screen.dart';

/// Lista los SSTs programados de la semana (datos de Render) agrupados por
/// fecha de programación. Al tocar un SST abre su plano (lienzo) para editar.
class PlanosSstScreen extends StatefulWidget {
  const PlanosSstScreen({super.key});

  @override
  State<PlanosSstScreen> createState() => _PlanosSstScreenState();
}

class _PlanosSstScreenState extends State<PlanosSstScreen> {
  SemanaPlanos? _semana;
  String?       _error;
  bool          _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final usuario = context.read<AuthProvider>().usuario!;
      final semana  = await ApiService().getSemanaPlanos(usuario.idUsuario);
      if (mounted) setState(() { _semana = semana; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error   = e is ApiException ? e.message : 'Error de conexión: $e';
        _loading = false;
      });
    }
  }

  Future<void> _abrirPlano(SstPlanoResumen sst) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DibujoScreen(
          sstCodigo: sst.sstCodigo,
          sstLabel:  'SST ${sst.sstCodigo}',
        ),
      ),
    );
    _cargar(); // refrescar badges al volver
  }

  String _formatearFecha(String fecha) {
    if (fecha.isEmpty) return '';
    try {
      final dt    = DateTime.parse(fecha);
      const dias  = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      const meses = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                     'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
      return '${dias[dt.weekday - 1]} ${dt.day} de ${meses[dt.month]}';
    } catch (_) {
      return fecha;
    }
  }

  bool _esHoy(String fecha) {
    if (fecha.isEmpty) return false;
    final hoy = DateTime.now();
    return fecha == '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Planos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(mensaje: _error!, onRetry: _cargar)
              : _semana == null || _semana!.dias.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.map_outlined, size: 64, color: Colors.green),
                            SizedBox(height: 16),
                            Text(
                              'Sin SSTs programados esta semana.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _SemanaHeader(semana: _semana!),
                          const SizedBox(height: 12),
                          for (final dia in _semana!.dias) ...[
                            _DiaHeader(
                              label: _formatearFecha(dia.fecha),
                              esHoy: _esHoy(dia.fecha),
                              count: dia.ssts.length,
                            ),
                            const SizedBox(height: 6),
                            for (final sst in dia.ssts)
                              _SstCard(sst: sst, onTap: () => _abrirPlano(sst)),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
    );
  }
}

// ── Header de la semana ───────────────────────────────────────────────────────
class _SemanaHeader extends StatelessWidget {
  final SemanaPlanos semana;
  const _SemanaHeader({required this.semana});

  String _fmt(String iso) {
    if (iso.isEmpty) return '';
    final p = iso.split('-');
    if (p.length < 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final total = semana.dias.fold<int>(0, (s, d) => s + d.ssts.length);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: Color(0xFF1A237E), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_fmt(semana.desde)}  –  ${_fmt(semana.hasta)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A237E)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$total SST${total == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cabecera de día ───────────────────────────────────────────────────────────
class _DiaHeader extends StatelessWidget {
  final String label;
  final bool   esHoy;
  final int    count;
  const _DiaHeader({required this.label, required this.esHoy, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: esHoy ? const Color(0xFF1A237E) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: esHoy ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count SST${count == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
      ],
    );
  }
}

// ── Tarjeta de SST ────────────────────────────────────────────────────────────
class _SstCard extends StatelessWidget {
  final SstPlanoResumen sst;
  final VoidCallback    onTap;
  const _SstCard({required this.sst, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tienePlano = sst.tienePlano;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: tienePlano
                    ? const Color(0xFFE8EAF6)
                    : Colors.grey.shade100,
                child: Icon(
                  tienePlano ? Icons.edit_note : Icons.add,
                  size: 22,
                  color: tienePlano ? const Color(0xFF1A237E) : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SST ${sst.sstCodigo}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (sst.distrito.isNotEmpty)
                      Text(sst.distrito,
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    if (sst.actividad.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sst.actividad,
                          style: TextStyle(fontSize: 11, color: Colors.indigo.shade700),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tienePlano ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tienePlano ? 'Con plano' : 'Sin plano',
                  style: TextStyle(
                    fontSize: 11,
                    color: tienePlano ? Colors.green.shade700 : Colors.orange.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vista de error ────────────────────────────────────────────────────────────
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
