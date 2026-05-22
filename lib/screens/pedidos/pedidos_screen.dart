import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/pedido.dart';
import 'crear_pedido_screen.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  List<Pedido> _pedidos  = [];
  bool         _loading  = true;
  String?      _filtro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _pedidos = await ApiService().getPedidos(estado: _filtro);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Pedidos'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) { _filtro = v; _cargar(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: null,        child: Text('Todos')),
              PopupMenuItem(value: 'pendiente', child: Text('Pendientes')),
              PopupMenuItem(value: 'aprobado',  child: Text('Aprobados')),
              PopupMenuItem(value: 'rechazado', child: Text('Rechazados')),
            ],
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _pedidos.isEmpty
          ? const Center(child: Text('No hay pedidos'))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: _pedidos.length,
                itemBuilder: (_, i) => _PedidoCard(
                  pedido: _pedidos[i],
                  onDeleted: _cargar,
                ),
              ),
            ),
      floatingActionButton: usuario.puedeHacerPedido
        ? FloatingActionButton.extended(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo pedido'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearPedidoScreen()));
              _cargar();
            },
          )
        : null,
    );
  }
}

class _PedidoCard extends StatelessWidget {
  final Pedido    pedido;
  final VoidCallback onDeleted;
  const _PedidoCard({required this.pedido, required this.onDeleted});

  Color get _estadoColor => switch (pedido.estado) {
    'aprobado'  => Colors.green,
    'rechazado' => Colors.red,
    _           => Colors.orange,
  };

  Future<void> _eliminar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: Text('¿Eliminar el Pedido #${pedido.idPedido}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ApiService().eliminarPedido(pedido.idPedido);
      onDeleted();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _estadoColor.withOpacity(0.15),
          child: Icon(Icons.shopping_cart, color: _estadoColor),
        ),
        title: Text('Pedido #${pedido.idPedido}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${pedido.camionPlaca}  •  ${pedido.fecha}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(pedido.estado, style: const TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: _estadoColor,
              padding: EdgeInsets.zero,
            ),
            if (pedido.estado == 'pendiente')
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Eliminar pedido',
                onPressed: () => _eliminar(context),
              ),
          ],
        ),
        children: pedido.detalles.map((d) {
          final aprobado   = pedido.estado == 'aprobado';
          final modificado = aprobado && d.cantidadAprobada != d.cantidadSolicitada;
          return ListTile(
            dense: true,
            leading: Icon(Icons.circle, size: 8,
                color: modificado ? Colors.orange : Colors.grey),
            title: Text(d.materialDescripcion),
            subtitle: Text(d.materialMatricula),
            trailing: aprobado
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (modificado)
                        Text('Solicitado: ${d.cantidadSolicitada}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (modificado)
                          const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(Icons.warning_amber_rounded,
                                size: 14, color: Colors.orange),
                          ),
                        Text(
                          '${d.cantidadAprobada} unid.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: modificado ? Colors.orange : Colors.green,
                          ),
                        ),
                      ]),
                    ],
                  )
                : Text('${d.cantidadSolicitada} unid.'),
          );
        }).toList(),
      ),
    );
  }
}
