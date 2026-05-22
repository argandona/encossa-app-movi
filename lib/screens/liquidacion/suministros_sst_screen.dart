import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../models/sst.dart';
import 'liquidar_suministro_screen.dart';

class SuministrosSstScreen extends StatefulWidget {
  final Sst sst;
  const SuministrosSstScreen({super.key, required this.sst});

  @override
  State<SuministrosSstScreen> createState() => _SuministrosSstScreenState();
}

class _SuministrosSstScreenState extends State<SuministrosSstScreen> {
  List<SuministroSst>? _suministros;
  String? _error;
  bool    _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final lista = await ApiService().getSuministrosSst(widget.sst.idSst);
      if (mounted) setState(() { _suministros = lista; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sst = widget.sst;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sst.sst.isNotEmpty ? 'SST ${sst.sst}' : sst.codigo,
                style: const TextStyle(fontSize: 16)),
            Text(sst.distrito,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : _suministros!.isEmpty
                  ? const Center(
                      child: Text('Este SST no tiene suministros asignados.',
                          style: TextStyle(color: Colors.black54)))
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _suministros!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = _suministros![i];
                          return _SuministroCard(
                            suministro: s,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiquidarSuministroScreen(
                                  suministro: s,
                                  sst: sst,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _SuministroCard extends StatelessWidget {
  final SuministroSst  suministro;
  final VoidCallback   onTap;

  const _SuministroCard({required this.suministro, required this.onTap});

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'ejecutado': return Colors.green;
      case 'devuelto':  return Colors.orange;
      default:          return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = suministro;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.electrical_services_outlined, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.numeroSuministro,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (s.medidor.isNotEmpty)
                      Text('Medidor: ${s.medidor}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    if (s.distrito.isNotEmpty)
                      Text(s.distrito,
                          style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _colorEstado(s.estado).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _colorEstado(s.estado).withOpacity(0.4)),
                          ),
                          child: Text(
                            s.estado.toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _colorEstado(s.estado)),
                          ),
                        ),
                        const Spacer(),
                        Text('S/ ${s.montoSum}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
