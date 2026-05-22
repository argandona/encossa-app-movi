import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';

class CrearPedidoScreen extends StatefulWidget {
  const CrearPedidoScreen({super.key});
  @override
  State<CrearPedidoScreen> createState() => _CrearPedidoScreenState();
}

class _CrearPedidoScreenState extends State<CrearPedidoScreen> {
  static const _color = Color(0xFF1A237E);

  final _obsCtrl    = TextEditingController();
  final _searchCtrl = TextEditingController();

  Map<String, dynamic>?            _camion;
  List<Map<String, dynamic>>       _sugerencias = [];
  final List<Map<String, dynamic>> _items       = [];

  bool    _loadingCamion = true;
  bool    _buscando      = false;
  bool    _guardando     = false;
  String? _error;
  Timer?  _debounce;

  @override
  void initState() {
    super.initState();
    _cargarCamion();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _obsCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCamion() async {
    final usuario = context.read<AuthProvider>().usuario!;
    try {
      _camion = await ApiService().getCamionActivo(usuario.idUsuario);
    } catch (_) {}
    setState(() => _loadingCamion = false);
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _sugerencias = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _buscando = true);
      try {
        final res = await ApiService().getMateriales(q: q.trim());
        setState(() => _sugerencias = res);
      } catch (_) {
        setState(() => _sugerencias = []);
      } finally {
        setState(() => _buscando = false);
      }
    });
  }

  Future<void> _seleccionarMaterial(Map<String, dynamic> material) async {
    final yaAgregado = _items.any((e) => e['material']['id_material'] == material['id_material']);
    if (yaAgregado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este material ya está en el pedido')));
      return;
    }

    final cantCtrl = TextEditingController(text: '1');
    try {
    final cantidad = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(material['descripcion'], style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Matrícula: ${material['matricula']}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: cantCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad solicitada',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white),
            onPressed: () {
              final n = int.tryParse(cantCtrl.text) ?? 0;
              if (n > 0) Navigator.pop(ctx, n);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (cantidad != null) {
      setState(() {
        _items.add({'material': material, 'cantidad': cantidad});
        _sugerencias = [];
        _searchCtrl.clear();
      });
    }
    } finally {
      cantCtrl.dispose();
    }
  }

  Future<void> _guardar() async {
    final usuario = context.read<AuthProvider>().usuario!;
    if (_camion == null) { setState(() => _error = 'No tienes un camión asignado.'); return; }
    if (_items.isEmpty)  { setState(() => _error = 'Agrega al menos un material.');  return; }

    setState(() { _guardando = true; _error = null; });
    try {
      await ApiService().crearPedido(
        camion:      _camion!['id_camion'],
        usuario:     usuario.idUsuario,
        observacion: _obsCtrl.text,
        detalles:    _items.map((e) => {
          'material':            e['material']['id_material'],
          'cantidad_solicitada': e['cantidad'],
        }).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido enviado correctamente'), backgroundColor: Colors.green));
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
        title: const Text('Nuevo Pedido'),
      ),
      body: _loadingCamion
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Camión ──────────────────────────────────────────────────
                Container(
                  color: const Color(0xFFE8EAF6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.local_shipping, color: _color),
                    const SizedBox(width: 8),
                    Text(
                      _camion != null ? 'Camión: ${_camion!['placa']}' : 'Sin camión asignado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _camion != null ? _color : Colors.red,
                      ),
                    ),
                  ]),
                ),

                // ── Buscador ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar material por nombre o matrícula…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buscando
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2)))
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),

                // ── Sugerencias ─────────────────────────────────────────────
                if (_sugerencias.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    constraints: const BoxConstraints(maxHeight: 210),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _sugerencias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final m = _sugerencias[i];
                        return ListTile(
                          dense: true,
                          title: Text(m['descripcion']),
                          subtitle: Text(m['matricula']),
                          trailing: const Icon(Icons.add_circle, color: _color),
                          onTap: () => _seleccionarMaterial(m),
                        );
                      },
                    ),
                  ),

                // ── Lista de items ──────────────────────────────────────────
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('Busca y agrega materiales al pedido',
                                style: TextStyle(color: Colors.grey.shade500)),
                          ]),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          itemCount: _items.length,
                          itemBuilder: (ctx, i) {
                            final mat = _items[i]['material'] as Map<String, dynamic>;
                            final qty = _items[i]['cantidad'] as int;
                            return Card(
                              child: ListTile(
                                title: Text(mat['descripcion']),
                                subtitle: Text(mat['matricula']),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _color,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('$qty',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => setState(() => _items.removeAt(i)),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                ),

                // ── Footer: observación + botón ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
                  ),
                  child: Column(children: [
                    TextField(
                      controller: _obsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Observación (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send),
                        label: Text(
                          _items.isEmpty
                              ? 'Enviar Pedido'
                              : 'Enviar Pedido (${_items.length} material${_items.length != 1 ? 'es' : ''})',
                          style: const TextStyle(fontSize: 16),
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
