import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_service.dart';
import '../core/auth_provider.dart';
import '../core/num_utils.dart';
import 'login_screen.dart';
import 'pedidos/pedidos_screen.dart';
import 'pedidos/aprobacion_pedidos_screen.dart';
import 'devoluciones/devoluciones_screen.dart';
import 'devoluciones/aprobacion_devoluciones_screen.dart';
import 'inventarios/inventarios_screen.dart';
import 'saldos/saldos_screen.dart';
import 'liquidacion/liquidacion_screen.dart';
import 'planos/planos_sst_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int>? _pendientes;

  // Pedido: solo si el encargado tiene camión asignado HOY (dentro del rango).
  bool _tieneCamionHoy = false;
  // Devolución: solo si el camión del encargado tiene saldo (> 0).
  bool _camionConSaldo = false;

  @override
  void initState() {
    super.initState();
    _recargarTodo();
  }

  Future<void> _recargarTodo() async {
    await Future.wait([_cargarContadores(), _cargarFlags()]);
  }

  Future<void> _cargarContadores() async {
    final usuario = context.read<AuthProvider>().usuario!;
    if (!usuario.puedeAprobarPedido && !usuario.puedeAprobarDevolucion) return;
    try {
      final data = await ApiService().getPendientesConteo();
      if (mounted) setState(() => _pendientes = data);
    } catch (_) {}
  }

  /// Carga los flags que controlan la visibilidad de Pedido y Devolución.
  Future<void> _cargarFlags() async {
    final usuario = context.read<AuthProvider>().usuario!;
    // Pedido depende del camión asignado HOY (dentro del rango de fechas).
    if (usuario.puedeHacerPedido) {
      try {
        final camion = await ApiService().getCamionActivo(usuario.idUsuario);
        if (mounted) setState(() => _tieneCamionHoy = camion != null);
      } catch (_) {}
    }
    // Devolución depende de que el camión tenga saldo (> 0).
    if (usuario.puedeHacerDevolucion) {
      try {
        final camiones =
            await ApiService().getStockPorCamion(usuarioId: usuario.idUsuario);
        final haySaldo = camiones.any((c) =>
            (c['items'] as List? ?? []).any((i) => numFrom(i['cantidad']) > 0));
        if (mounted) setState(() => _camionConSaldo = haySaldo);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuario!;

    final opciones = <Map<String, dynamic>>[
      if (usuario.puedeVerSaldosPropios) {
        'titulo': 'Mis Saldos',
        'icono':  Icons.account_balance_wallet_outlined,
        'color':  Colors.teal,
        'screen': const SaldosScreen(soloMios: true),
      },
      if (usuario.puedeVerSaldosTodos) {
        'titulo': 'Saldos Camiones',
        'icono':  Icons.account_balance_wallet_outlined,
        'color':  Colors.teal,
        'screen': const SaldosScreen(soloMios: false),
      },
      // Pedido: solo dentro del rango de fechas de la asignación del camión.
      if (usuario.puedeHacerPedido && _tieneCamionHoy) {
        'titulo': 'Pedidos',
        'icono':  Icons.shopping_cart_outlined,
        'color':  Colors.blue,
        'screen': const PedidosScreen(),
      },
      // Devolución: solo si el camión tiene saldo.
      if (usuario.puedeHacerDevolucion && _camionConSaldo) {
        'titulo': 'Devoluciones',
        'icono':  Icons.assignment_return_outlined,
        'color':  Colors.orange,
        'screen': const DevolucionesScreen(),
      },
      if (usuario.puedeAprobarPedido) {
        'titulo':  'Pedidos por Despachar',
        'icono':   Icons.local_shipping_outlined,
        'color':   const Color(0xFF1A237E),
        'screen':  const AprobacionPedidosScreen(),
        'badgeKey': 'pedidos',
      },
      if (usuario.puedeAprobarDevolucion) {
        'titulo':  'Devoluciones por Aprobar',
        'icono':   Icons.assignment_return_outlined,
        'color':   Colors.deepPurple,
        'screen':  const AprobacionDevolucionesScreen(),
        'badgeKey': 'devoluciones',
      },
      if (usuario.puedeLiquidar) {
        'titulo': 'Liquidación',
        'icono':  Icons.receipt_long_outlined,
        'color':  Colors.deepOrange,
        'screen': const LiquidacionScreen(),
      },
      if (usuario.puedeVerInventario) {
        'titulo': 'Inventarios',
        'icono':  Icons.inventory_2_outlined,
        'color':  Colors.green,
        'screen': const InventariosScreen(),
      },
      if (usuario.puedeDibujar) {
        'titulo': 'Planos',
        'icono':  Icons.map_outlined,
        'color':  Colors.purple,
        'screen': const PlanosSstScreen(),
      },
    ];

    final mostrarDashboard = usuario.puedeAprobarPedido || usuario.puedeAprobarDevolucion;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Control Almacén'),
        actions: [
          if (mostrarDashboard)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar contadores',
              onPressed: _cargarContadores,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _recargarTodo,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tarjeta de usuario
            Card(
              color: const Color(0xFFE8EAF6),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1A237E),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(usuario.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${usuario.rol}  •  ${usuario.empresa ?? "Sin empresa"}'),
              ),
            ),

            // Dashboard de pendientes
            if (mostrarDashboard) ...[
              const SizedBox(height: 16),
              const Text('Pendientes de gestión',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 8),
              Row(children: [
                if (usuario.puedeAprobarPedido)
                  Expanded(
                    child: _ContadorCard(
                      label:  'Pedidos',
                      icono:  Icons.local_shipping_outlined,
                      color:  const Color(0xFF1A237E),
                      count:  _pendientes?['pedidos'],
                      onTap:  () async {
                        await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AprobacionPedidosScreen()));
                        _cargarContadores();
                      },
                    ),
                  ),
                if (usuario.puedeAprobarPedido && usuario.puedeAprobarDevolucion)
                  const SizedBox(width: 12),
                if (usuario.puedeAprobarDevolucion)
                  Expanded(
                    child: _ContadorCard(
                      label: 'Devoluciones',
                      icono: Icons.assignment_return_outlined,
                      color: Colors.deepPurple,
                      count: _pendientes?['devoluciones'],
                      onTap: () async {
                        await Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AprobacionDevolucionesScreen()));
                        _cargarContadores();
                      },
                    ),
                  ),
              ]),
            ],

            const SizedBox(height: 24),
            const Text('Módulos disponibles',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 12),

            opciones.isEmpty
                ? const Center(
                    child: Text('No tienes módulos asignados para tu rol.'))
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: opciones.map((op) {
                      final badgeKey = op['badgeKey'] as String?;
                      final badge = badgeKey != null ? (_pendientes?[badgeKey] ?? 0) : 0;
                      return _ModuloCard(
                        titulo: op['titulo'],
                        icono:  op['icono'],
                        color:  op['color'],
                        badge:  badge,
                        onTap:  () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => op['screen']),
                          );
                          if (badgeKey != null) _cargarContadores();
                        },
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de contador para el dashboard ─────────────────────────────────────
class _ContadorCard extends StatelessWidget {
  final String    label;
  final IconData  icono;
  final Color     color;
  final int?      count;
  final VoidCallback onTap;

  const _ContadorCard({
    required this.label,
    required this.icono,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(icono, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              count == null
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Text(
                      '$count pendiente${count != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: count! > 0 ? color : Colors.grey,
                      ),
                    ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Tarjeta de módulo ─────────────────────────────────────────────────────────
class _ModuloCard extends StatelessWidget {
  final String   titulo;
  final IconData icono;
  final Color    color;
  final int      badge;
  final VoidCallback onTap;

  const _ModuloCard({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: color.withOpacity(0.15),
                    child: Icon(icono, size: 32, color: color),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
