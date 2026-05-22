import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/devolucion.dart';

class AprobacionDevolucionesScreen extends StatefulWidget {
  const AprobacionDevolucionesScreen({super.key});
  @override
  State<AprobacionDevolucionesScreen> createState() => _AprobacionDevolucionesScreenState();
}

class _AprobacionDevolucionesScreenState extends State<AprobacionDevolucionesScreen> {
  List<Devolucion>           _devoluciones = [];
  List<Map<String, dynamic>> _almacenes    = [];
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
        ApiService().getDevoluciones(estado: 'pendiente'),
        ApiService().getAlmacenes(),
      ]);
      _devoluciones = results[0] as List<Devolucion>;
      _almacenes    = results[1] as List<Map<String, dynamic>>;
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _aprobar(Devolucion dev) async {
    final usuario = context.read<AuthProvider>().usuario!;

    if (_almacenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay almacenes disponibles'), backgroundColor: Colors.red));
      return;
    }

    Map<String, dynamic>? almacenSeleccionado = _almacenes.first;
    final obsCtrl = TextEditingController();
    final cantCtrls = {
      for (final d in dev.detalles)
        d.material: TextEditingController(text: '${d.cantidadSolicitada}')
    };

    try {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Aprobar Devolución #${dev.idDevolucion}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Camión: ${dev.camionPlaca}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text('Devuelto por: ${dev.usuarioNombre}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                const Text('Almacén destino:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: almacenSeleccionado,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: _almacenes.map((a) => DropdownMenuItem(
                    value: a,
                    child: Text(a['nombre']),
                  )).toList(),
                  onChanged: (v) => setS(() => almacenSeleccionado = v),
                ),
                const SizedBox(height: 12),
                const Text('Cantidad a aprobar por material:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...dev.detalles.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.materialDescripcion, style: const TextStyle(fontSize: 13)),
                        Text('Solicitado: ${d.cantidadSolicitada} unid.',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: TextField(
                        controller: cantCtrls[d.material],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          suffixText: 'u',
                        ),
                      ),
                    ),
                  ]),
                )),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true || almacenSeleccionado == null) return;

    try {
      await ApiService().aprobarDevolucion(
        dev.idDevolucion,
        usuarioApruebaId: usuario.idUsuario,
        almacenDestinoId: almacenSeleccionado!['id_almacen'],
        observacion:      obsCtrl.text,
        detalles: dev.detalles.map((d) => {
          'material':            d.material,
          'cantidad_solicitada': d.cantidadSolicitada,
          'cantidad_aprobada':   int.tryParse(cantCtrls[d.material]?.text ?? '0') ?? 0,
        }).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devolución aprobada'), backgroundColor: Colors.green));
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

  Future<void> _rechazar(Devolucion dev) async {
    final usuario = context.read<AuthProvider>().usuario!;
    final obsCtrl = TextEditingController();

    try {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rechazar Devolución #${dev.idDevolucion}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Rechazar la devolución de ${dev.usuarioNombre}?'),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ApiService().rechazarDevolucion(
        dev.idDevolucion,
        usuarioApruebaId: usuario.idUsuario,
        observacion:      obsCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devolución rechazada'), backgroundColor: Colors.orange));
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
        title: const Text('Devoluciones por Aprobar'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devoluciones.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade300),
                    const SizedBox(height: 12),
                    const Text('No hay devoluciones pendientes',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _devoluciones.length,
                    itemBuilder: (_, i) {
                      final dev = _devoluciones[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8EAF6),
                                child: Icon(Icons.assignment_return, color: Color(0xFF1A237E)),
                              ),
                              title: Text('Devolución #${dev.idDevolucion}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Devuelto por: ${dev.usuarioNombre}'),
                                  Text('Camión: ${dev.camionPlaca}  •  ${dev.fecha}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            ...dev.detalles.map((d) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              child: Row(children: [
                                const Icon(Icons.circle, size: 6, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(d.materialDescripcion,
                                    style: const TextStyle(fontSize: 13))),
                                Text('${d.cantidadSolicitada} unid.',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ]),
                            )),
                            if (dev.observacion.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                                child: Text('Obs: ${dev.observacion}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey,
                                        fontStyle: FontStyle.italic)),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red)),
                                    onPressed: () => _rechazar(dev),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Rechazar'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white),
                                    onPressed: () => _aprobar(dev),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Aprobar'),
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
