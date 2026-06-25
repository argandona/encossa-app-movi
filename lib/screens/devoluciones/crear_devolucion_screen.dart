import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/num_utils.dart';

class CrearDevolucionScreen extends StatefulWidget {
  const CrearDevolucionScreen({super.key});
  @override
  State<CrearDevolucionScreen> createState() => _CrearDevolucionScreenState();
}

class _CrearDevolucionScreenState extends State<CrearDevolucionScreen> {
  static const _color = Colors.orange;

  final _obsCtrl = TextEditingController();

  // Camiones con saldo disponibles
  List<Map<String, dynamic>> _camiones    = [];
  Map<String, dynamic>?      _camionSel;

  // Items agregados a la devolución: {material_id, descripcion, matricula, stockDisponible, cantidad}
  final List<Map<String, dynamic>> _items = [];

  bool    _loading  = true;
  bool    _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarStock();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarStock() async {
    setState(() { _loading = true; _error = null; });
    final usuario = context.read<AuthProvider>().usuario!;
    try {
      final data = await ApiService().getStockPorCamion(usuarioId: usuario.idUsuario);
      // Solo camiones que tienen al menos un ítem con stock > 0
      final conStock = data.where((c) {
        final items = (c['items'] as List? ?? []);
        return items.any((i) => numFrom(i['cantidad']) > 0);
      }).toList();

      setState(() {
        _camiones   = conStock;
        _camionSel  = conStock.isNotEmpty ? conStock.first : null;
        _items.clear();
      });
    } catch (e) {
      setState(() => _error = 'Error al cargar stock: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Materiales del camión seleccionado con stock disponible > 0
  List<Map<String, dynamic>> get _stockCamion {
    if (_camionSel == null) return [];
    final lista = ((_camionSel!['items'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((i) {
          final total     = intFrom(i['cantidad']);
          final pendiente = intFrom(i['pendiente_devolucion']);
          return (total - pendiente) > 0;
        })
        .toList();
    lista.sort((a, b) =>
        (a['matricula'] as String? ?? '').compareTo(b['matricula'] as String? ?? ''));
    return lista;
  }

  // Cantidad ya agregada en la lista de items para un material
  int _cantidadAgregada(int materialId) {
    final found = _items.where((e) => e['material_id'] == materialId);
    return found.isEmpty ? 0 : intFrom(found.first['cantidad']);
  }

  // Disponible = stock - devoluciones pendientes previas - lo ya agregado en esta sesión
  int _stockDisponible(Map<String, dynamic> stockItem) {
    final total     = intFrom(stockItem['cantidad']);
    final pendiente = intFrom(stockItem['pendiente_devolucion']);
    final agregado  = _cantidadAgregada(stockItem['material_id'] as int);
    return total - pendiente - agregado;
  }

  Future<void> _agregarMaterial(Map<String, dynamic> stockItem) async {
    final disponible = _stockDisponible(stockItem);
    if (disponible <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya agregaste todo el stock disponible de este material')));
      return;
    }

    final cantCtrl = TextEditingController(text: '$disponible');
    final cantidad = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(stockItem['descripcion'] ?? '',
            style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Matrícula: ${stockItem['matricula'] ?? ''}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Stock disponible: $disponible unidades',
                style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: cantCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad a devolver',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _color, foregroundColor: Colors.white),
            onPressed: () {
              final n = int.tryParse(cantCtrl.text) ?? 0;
              if (n <= 0) return;
              if (n > disponible) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('Máximo $disponible unidades'),
                  backgroundColor: Colors.red,
                ));
                return;
              }
              Navigator.pop(ctx, n);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (cantidad == null) return;

    setState(() {
      final idx = _items.indexWhere(
          (e) => e['material_id'] == stockItem['material_id']);
      if (idx >= 0) {
        _items[idx]['cantidad'] = cantidad;
      } else {
        _items.add({
          'material_id':    stockItem['material_id'],
          'descripcion':    stockItem['descripcion'],
          'matricula':      stockItem['matricula'],
          'stock_camion':   stockItem['cantidad'],
          'cantidad':       cantidad,
        });
      }
    });
  }

  Future<void> _guardar() async {
    final usuario = context.read<AuthProvider>().usuario!;
    if (_camionSel == null) {
      setState(() => _error = 'No tienes camiones con saldo disponible.');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Agrega al menos un material a devolver.');
      return;
    }

    setState(() { _guardando = true; _error = null; });
    try {
      await ApiService().crearDevolucion(
        camion:      _camionSel!['camion_id'],
        usuario:     usuario.idUsuario,
        observacion: _obsCtrl.text,
        detalles:    _items.map((e) => {
          'material':            e['material_id'],
          'cantidad_solicitada': e['cantidad'],
        }).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Devolución enviada correctamente'),
              backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        foregroundColor: Colors.white,
        title: const Text('Nueva Devolución'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarStock,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _camiones.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No tienes materiales en tus camiones',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 15)),
                  ]),
                )
              : Column(
                  children: [
                    // ── Selector de camión ───────────────────────────────────
                    Container(
                      color: const Color(0xFFFFF3E0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.local_shipping, color: Colors.orange),
                        const SizedBox(width: 10),
                        const Text('Camión:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _camiones.length == 1
                              ? Text(
                                  _camionSel?['placa'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange),
                                )
                              : DropdownButton<Map<String, dynamic>>(
                                  value: _camionSel,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  onChanged: (v) => setState(() {
                                    _camionSel = v;
                                    _items.clear();
                                  }),
                                  items: _camiones
                                      .map((c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c['placa'] ?? ''),
                                          ))
                                      .toList(),
                                ),
                        ),
                      ]),
                    ),

                    // ── Encabezado lista de stock ────────────────────────────
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            'Materiales disponibles  (${_stockCamion.length})',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('Stock  /  A devolver',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                    ),

                    // ── Lista de materiales del camión ───────────────────────
                    Expanded(
                      child: _stockCamion.isEmpty
                          ? Center(
                              child: Text('Sin stock en este camión',
                                  style: TextStyle(color: Colors.grey.shade500)))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _stockCamion.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, indent: 56),
                              itemBuilder: (_, i) {
                                final item       = _stockCamion[i];
                                final stock      = intFrom(item['cantidad']);
                                final pendiente  = intFrom(item['pendiente_devolucion']);
                                final agregado   = _cantidadAgregada(item['material_id'] as int);
                                final disponible = stock - pendiente - agregado;

                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: agregado > 0
                                        ? Colors.orange.shade100
                                        : Colors.grey.shade100,
                                    child: Icon(Icons.construction,
                                        size: 18,
                                        color: agregado > 0
                                            ? Colors.orange.shade700
                                            : Colors.grey),
                                  ),
                                  title: Text(item['descripcion'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  subtitle: Text(item['matricula'] ?? '',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Stock disponible
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text('$disponible disp.',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: disponible > 0
                                                      ? Colors.grey.shade600
                                                      : Colors.red.shade300)),
                                          if (pendiente > 0)
                                            Text('$pendiente en trámite',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.orange
                                                        .shade700)),
                                          if (agregado > 0)
                                            Text('$agregado a devolver',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      // Botón agregar / quitar
                                      if (agregado > 0)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle,
                                              color: Colors.red),
                                          onPressed: () => setState(() =>
                                              _items.removeWhere((e) =>
                                                  e['material_id'] ==
                                                  item['material_id'])),
                                        )
                                      else
                                        IconButton(
                                          icon: Icon(Icons.add_circle,
                                              color: disponible > 0
                                                  ? Colors.orange
                                                  : Colors.grey),
                                          onPressed: disponible > 0
                                              ? () => _agregarMaterial(item)
                                              : null,
                                        ),
                                    ],
                                  ),
                                  onTap: disponible > 0
                                      ? () => _agregarMaterial(item)
                                      : null,
                                );
                              },
                            ),
                    ),

                    // ── Footer ──────────────────────────────────────────────
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
                        TextField(
                          controller: _obsCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Observación (opcional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13)),
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _items.isEmpty
                                  ? Colors.grey
                                  : _color,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _guardando ? null : _guardar,
                            icon: _guardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.assignment_return),
                            label: Text(
                              _items.isEmpty
                                  ? 'Selecciona materiales a devolver'
                                  : 'Enviar Devolución (${_items.length} material${_items.length != 1 ? 'es' : ''})',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
    );
  }
}
