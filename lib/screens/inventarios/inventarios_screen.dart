import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/inventario.dart';
import 'crear_inventario_screen.dart';

class InventariosScreen extends StatelessWidget {
  const InventariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          title: const Text('Inventarios'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.bar_chart), text: 'Stock'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventarios'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StockTab(),
            _InventariosTab(),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Resumen stock por material ────────────────────────────────────────

class _StockTab extends StatefulWidget {
  const _StockTab();
  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _items = await ApiService().getResumenStock();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _verDetalle(Map<String, dynamic> item) {
    final int pedidos     = item['total_pedidos']     as int? ?? 0;
    final int devol       = item['total_devoluciones'] as int? ?? 0;
    final int consumos    = item['total_consumos']    as int? ?? 0;
    final int saldo       = item['saldo_actual']      as int? ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: Colors.green.shade50,
                child: Icon(Icons.construction, color: Colors.green.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['descripcion'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(item['matricula'] ?? '',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ]),
              ),
            ]),
            const Divider(height: 24),
            _FilaDetalle(
              label: 'Total pedidos (aprobados)',
              valor: pedidos,
              icono: Icons.add_circle_outline,
              color: Colors.blue,
            ),
            _FilaDetalle(
              label: 'Total devoluciones (aprobadas)',
              valor: devol,
              icono: Icons.remove_circle_outline,
              color: Colors.orange,
            ),
            _FilaDetalle(
              label: 'Total consumos (aprobados)',
              valor: consumos,
              icono: Icons.remove_circle_outline,
              color: Colors.red.shade300,
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saldo actual',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: saldo > 0
                        ? Colors.green.shade50
                        : saldo < 0
                            ? Colors.red.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: saldo > 0
                          ? Colors.green.shade400
                          : saldo < 0
                              ? Colors.red.shade400
                              : Colors.grey.shade400,
                    ),
                  ),
                  child: Text(
                    '$saldo unidades',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: saldo > 0
                          ? Colors.green.shade700
                          : saldo < 0
                              ? Colors.red.shade700
                              : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo real registrado en sistema (incluye ajustes por inventario físico).',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bar_chart, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('Sin movimientos registrados',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                ]),
              )
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item  = _items[i];
                    final saldo = item['saldo_actual'] as int? ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _verDetalle(item),
                        leading: CircleAvatar(
                          backgroundColor: saldo > 0
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          child: Icon(Icons.construction,
                              color: saldo > 0
                                  ? Colors.green.shade700
                                  : Colors.grey),
                        ),
                        title: Text(item['descripcion'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(item['matricula'] ?? '',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: saldo > 0
                                    ? Colors.green.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: saldo > 0
                                      ? Colors.green.shade300
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                '$saldo u.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: saldo > 0
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text('toca para detalle',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
  }
}

class _FilaDetalle extends StatelessWidget {
  final String   label;
  final int      valor;
  final IconData icono;
  final Color    color;

  const _FilaDetalle({
    required this.label,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            '$valor unidades',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Inventarios físicos ────────────────────────────────────────────────

class _InventariosTab extends StatefulWidget {
  const _InventariosTab();
  @override
  State<_InventariosTab> createState() => _InventariosTabState();
}

class _InventariosTabState extends State<_InventariosTab>
    with AutomaticKeepAliveClientMixin {
  List<Inventario> _inventarios = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _inventarios = await ApiService().getInventarios();
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final usuario = context.read<AuthProvider>().usuario!;
    return Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _inventarios.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No hay inventarios registrados',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                      itemCount: _inventarios.length,
                      itemBuilder: (_, i) =>
                          _InventarioCard(inventario: _inventarios[i]),
                    ),
                  ),
        if (usuario.puedeHacerInventario)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo inventario'),
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CrearInventarioScreen()),
                );
                if (ok == true) _cargar();
              },
            ),
          ),
      ],
    );
  }
}

class _InventarioCard extends StatefulWidget {
  final Inventario inventario;
  const _InventarioCard({required this.inventario});
  @override
  State<_InventarioCard> createState() => _InventarioCardState();
}

class _InventarioCardState extends State<_InventarioCard> {
  bool _descargando = false;

  Future<void> _descargarPdf() async {
    setState(() => _descargando = true);
    try {
      final bytes = await ApiService()
          .descargarPdfInventario(widget.inventario.idInventario);

      final dir  = await getTemporaryDirectory();
      final placa = widget.inventario.camionPlaca.isNotEmpty
          ? widget.inventario.camionPlaca
          : 'almacen';
      final nombre =
          'inventario_${placa}_${widget.inventario.mes}_${widget.inventario.anio}.pdf';
      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Acta de Inventario — $placa',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cerrado = widget.inventario.estado == 'cerrado';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor:
              cerrado ? Colors.grey.shade200 : Colors.green.shade50,
          child: Icon(Icons.inventory_2,
              color: cerrado ? Colors.grey : Colors.green.shade700),
        ),
        title: Text(
          widget.inventario.camion != null
              ? 'Camión: ${widget.inventario.camionPlaca}'
              : 'Almacén: ${widget.inventario.almacenNombre}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            '${_mes(widget.inventario.mes)} ${widget.inventario.anio}  •  ${widget.inventario.usuarioNombre}'),
        trailing: cerrado
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Chip(
                  label: Text(widget.inventario.estado,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.grey,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                _descargando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.picture_as_pdf,
                            color: Colors.green),
                        tooltip: 'Descargar PDF',
                        onPressed: _descargarPdf,
                      ),
              ])
            : Chip(
                label: Text(widget.inventario.estado,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: Colors.green.shade700,
                padding: EdgeInsets.zero,
              ),
        children: [
          if (widget.inventario.detalles.isEmpty)
            const ListTile(dense: true, title: Text('Sin detalles'))
          else
            ...widget.inventario.detalles.map((d) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(d.materialDescripcion),
                  subtitle: Text(d.materialMatricula),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Físico: ${d.cantidadFisica}',
                          style: const TextStyle(fontSize: 12)),
                      Text('Teórico: ${d.cantidadTeorica}',
                          style: const TextStyle(fontSize: 12)),
                      Text('Dif: ${d.diferencia}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: d.diferencia == 0
                                  ? Colors.green
                                  : Colors.red)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  String _mes(int m) => const [
        '',
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ][m];
}
