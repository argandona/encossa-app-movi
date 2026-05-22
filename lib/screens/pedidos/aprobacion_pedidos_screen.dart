import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/pedido.dart';

class AprobacionPedidosScreen extends StatefulWidget {
  const AprobacionPedidosScreen({super.key});
  @override
  State<AprobacionPedidosScreen> createState() => _AprobacionPedidosScreenState();
}

class _AprobacionPedidosScreenState extends State<AprobacionPedidosScreen> {
  List<Pedido>               _pedidos   = [];
  List<Map<String, dynamic>> _almacenes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService().getPedidos(estado: 'pendiente'),
        ApiService().getAlmacenes(),
      ]);
      _pedidos   = results[0] as List<Pedido>;
      _almacenes = results[1] as List<Map<String, dynamic>>;
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _aprobar(Pedido pedido) async {
    final usuario = context.read<AuthProvider>().usuario!;

    if (_almacenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay almacenes disponibles'), backgroundColor: Colors.red));
      return;
    }

    Map<String, dynamic>? almacenSeleccionado = _almacenes.first;
    final obsCtrl = TextEditingController();
    final cantCtrls = {
      for (final d in pedido.detalles)
        d.material: TextEditingController(text: '${d.cantidadSolicitada}')
    };

    for (final ctrl in cantCtrls.values) {
      ctrl.addListener(() {});
    }

    try {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          // Detectar cuántos materiales tienen cantidad modificada
          final modificados = pedido.detalles.where((d) {
            final val = int.tryParse(cantCtrls[d.material]?.text ?? '') ?? 0;
            return val != d.cantidadSolicitada;
          }).toList();
          final hayModificaciones = modificados.isNotEmpty;

          return AlertDialog(
            title: Text('Despachar Pedido #${pedido.idPedido}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Camión: ${pedido.camionPlaca}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Text('Solicitado por: ${pedido.usuarioNombre}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  const Text('Almacén de despacho:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: almacenSeleccionado,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), isDense: true),
                    items: _almacenes
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text(a['nombre']),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() => almacenSeleccionado = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('Cantidad a despachar por material:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...pedido.detalles.map((d) {
                    final val = int.tryParse(cantCtrls[d.material]?.text ?? '') ?? 0;
                    final itemModificado = val != d.cantidadSolicitada;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  if (itemModificado)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.warning_amber_rounded,
                                          size: 14, color: Colors.orange),
                                    ),
                                  Expanded(
                                    child: Text(d.materialDescripcion,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ]),
                                Text(
                                  'Solicitado: ${d.cantidadSolicitada} unid.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: itemModificado
                                        ? Colors.orange.shade700
                                        : Colors.grey,
                                    fontWeight: itemModificado
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ]),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: cantCtrls[d.material],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: itemModificado ? Colors.orange : null,
                              fontWeight: itemModificado
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: itemModificado
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: itemModificado
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              suffixText: 'u',
                            ),
                            onChanged: (_) => setS(() {}),
                          ),
                        ),
                      ]),
                    );
                  }),
                  // Banner de advertencia si hay modificaciones
                  if (hayModificaciones)
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${modificados.length} material${modificados.length > 1 ? 'es' : ''} con cantidad modificada. '
                            'El encargado verá la diferencia en su pedido.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange.shade800),
                          ),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: obsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observación (opcional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hayModificaciones ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(hayModificaciones
                    ? 'Despachar con cambios'
                    : 'Confirmar Despacho'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmar != true || almacenSeleccionado == null) return;

    try {
      await ApiService().aprobarPedido(
        pedido.idPedido,
        usuarioApruebaId: usuario.idUsuario,
        almacenId:        almacenSeleccionado!['id_almacen'],
        observacion:      obsCtrl.text,
        detalles: pedido.detalles.map((d) => {
          'material':            d.material,
          'cantidad_solicitada': d.cantidadSolicitada,
          'cantidad_aprobada':   int.tryParse(cantCtrls[d.material]?.text ?? '0') ?? 0,
        }).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido despachado correctamente'), backgroundColor: Colors.green));
        _cargar();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    } finally {
      obsCtrl.dispose();
      for (final ctrl in cantCtrls.values) ctrl.dispose();
    }
  }

  Future<void> _rechazar(Pedido pedido) async {
    final usuario = context.read<AuthProvider>().usuario!;
    final obsCtrl = TextEditingController();

    try {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rechazar Pedido #${pedido.idPedido}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Rechazar el pedido de ${pedido.usuarioNombre}?'),
            const SizedBox(height: 12),
            TextField(
              controller: obsCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo de rechazo (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ApiService().rechazarPedido(
        pedido.idPedido,
        usuarioApruebaId: usuario.idUsuario,
        observacion:      obsCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido rechazado'), backgroundColor: Colors.orange));
        _cargar();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    } finally {
      obsCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Pedidos por Despachar'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pedidos.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade300),
                    const SizedBox(height: 12),
                    const Text('No hay pedidos pendientes', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pedidos.length,
                    itemBuilder: (_, i) {
                      final p = _pedidos[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8EAF6),
                                child: Icon(Icons.shopping_cart, color: Color(0xFF1A237E)),
                              ),
                              title: Text('Pedido #${p.idPedido}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Solicitado por: ${p.usuarioNombre}'),
                                  Text('Camión: ${p.camionPlaca}  •  ${p.fecha}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            // Materiales
                            ...p.detalles.map((d) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle, size: 6, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(d.materialDescripcion, style: const TextStyle(fontSize: 13))),
                                  Text('${d.cantidadSolicitada} unid.',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            )),
                            if (p.observacion.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                child: Text('Obs: ${p.observacion}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                              ),
                            // Botones
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red)),
                                    onPressed: () => _rechazar(p),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Rechazar'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    onPressed: () => _aprobar(p),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Despachar'),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
