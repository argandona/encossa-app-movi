import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/num_utils.dart';

class SaldosScreen extends StatefulWidget {
  final bool soloMios; // true = encargado/capataz, false = enc. almacén
  const SaldosScreen({super.key, required this.soloMios});

  @override
  State<SaldosScreen> createState() => _SaldosScreenState();
}

class _SaldosScreenState extends State<SaldosScreen> {
  List<Map<String, dynamic>> _camiones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final usuario = context.read<AuthProvider>().usuario!;
      _camiones = await ApiService().getStockPorCamion(
        usuarioId: widget.soloMios ? usuario.idUsuario : null,
      );
    } catch (e) {
      debugPrint('Error al cargar saldos: $e');
    }
    setState(() => _loading = false);
  }

  num _totalItems(Map<String, dynamic> camion) {
    final items = camion['items'] as List? ?? [];
    // Para la vista del encargado el backend ya filtra cantidad>0, suma directa.
    // Para enc. almacén puede haber negativos; contamos solo los positivos.
    return items.fold<num>(
        0, (sum, i) => sum + numFrom(i['cantidad']).clamp(0, 999999));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Text(widget.soloMios ? 'Mis Saldos en Camión' : 'Saldos por Camión'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _camiones.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      widget.soloMios
                          ? 'No tienes materiales en tus camiones'
                          : 'No hay camiones con saldo',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _camiones.length,
                    itemBuilder: (_, i) => _CamionCard(
                      camion:    _camiones[i],
                      totalUnd:  _totalItems(_camiones[i]),
                      mostrarUsuario: !widget.soloMios,
                    ),
                  ),
                ),
    );
  }
}

class _CamionCard extends StatelessWidget {
  final Map<String, dynamic> camion;
  final num   totalUnd;
  final bool  mostrarUsuario;

  const _CamionCard({
    required this.camion,
    required this.totalUnd,
    required this.mostrarUsuario,
  });

  @override
  Widget build(BuildContext context) {
    final items = (camion['items'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8EAF6),
          child: const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
        ),
        title: Text(
          camion['placa'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mostrarUsuario)
              Text(
                camion['usuario_nombre'] ?? 'Sin asignar',
                style: const TextStyle(fontSize: 12),
              ),
            Text(
              '${items.length} material${items.length != 1 ? 'es' : ''} • ${fmtCant(totalUnd)} unidades totales',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Encabezado tabla
          Row(children: [
            Expanded(flex: 4, child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600))),
            Expanded(flex: 2, child: Text('Matrícula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600))),
            SizedBox(width: 60, child: Text('Cant.', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600))),
          ]),
          const SizedBox(height: 4),
          ...items.map((item) {
            final num cantidad = numFrom(item['cantidad']);
            final bool negativo = cantidad < 0;
            // El encargado (soloMios) nunca recibe negativos (backend los filtra).
            // Solo el enc. almacén ve negativos → mostrar aviso de reposición.
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(flex: 4, child: Text(item['descripcion'] ?? '', style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 2, child: Text(item['matricula'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                    SizedBox(
                      width: 70,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cantidad > 0 ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cantidad > 0 ? Colors.green.shade300 : Colors.orange.shade400,
                          ),
                        ),
                        child: Text(
                          negativo ? '${fmtCant(cantidad)} ⚠' : fmtCant(cantidad),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: cantidad > 0 ? Colors.green.shade700 : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ),
                  ]),
                  if (negativo)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, left: 2),
                      child: Text(
                        'Pendiente de reposición: ${cantidad.abs()} u.',
                        style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
