import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/devolucion.dart';
import 'crear_devolucion_screen.dart';

class DevolucionesScreen extends StatefulWidget {
  const DevolucionesScreen({super.key});

  @override
  State<DevolucionesScreen> createState() => _DevolucionesScreenState();
}

class _DevolucionesScreenState extends State<DevolucionesScreen> {
  List<Devolucion> _devoluciones = [];
  bool   _loading = true;
  String? _filtro;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      _devoluciones = await ApiService().getDevoluciones(estado: _filtro);
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
        title: const Text('Devoluciones'),
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
        : _devoluciones.isEmpty
          ? const Center(child: Text('No hay devoluciones'))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: _devoluciones.length,
                itemBuilder: (_, i) => _DevolucionCard(devolucion: _devoluciones[i]),
              ),
            ),
      floatingActionButton: usuario.puedeHacerDevolucion
        ? FloatingActionButton.extended(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nueva devolución'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CrearDevolucionScreen()));
              _cargar();
            },
          )
        : null,
    );
  }
}

class _DevolucionCard extends StatelessWidget {
  final Devolucion devolucion;
  const _DevolucionCard({required this.devolucion});

  Color get _estadoColor => switch (devolucion.estado) {
    'aprobado'  => Colors.green,
    'rechazado' => Colors.red,
    _           => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _estadoColor.withOpacity(0.15),
          child: Icon(Icons.assignment_return, color: _estadoColor),
        ),
        title: Text('Devolución #${devolucion.idDevolucion}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${devolucion.camionPlaca}  •  ${devolucion.fecha}'),
        trailing: Chip(
          label: Text(devolucion.estado, style: const TextStyle(color: Colors.white, fontSize: 11)),
          backgroundColor: _estadoColor,
          padding: EdgeInsets.zero,
        ),
        children: devolucion.detalles.map((d) => ListTile(
          dense: true,
          leading: const Icon(Icons.circle, size: 8),
          title: Text(d.materialDescripcion),
          subtitle: Text(d.materialMatricula),
          trailing: Text('${d.cantidadSolicitada} unid.'),
        )).toList(),
      ),
    );
  }
}
