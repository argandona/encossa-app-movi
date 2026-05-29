import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/elemento_canvas.dart';
import 'lienzo_widget.dart';
import 'paleta_widget.dart';

class DibujoScreen extends StatefulWidget {
  const DibujoScreen({super.key});

  @override
  State<DibujoScreen> createState() => _DibujoScreenState();
}

class _DibujoScreenState extends State<DibujoScreen> {
  // ── Estado del lienzo ───────────────────────────────────────────────────────
  final List<ElementoCanvas> _elementos     = [];
  String?                    _seleccionadoId;
  final GlobalKey            _repaintKey    = GlobalKey();
  bool                       _exportando    = false;

  // Valores base del elemento al inicio de cada gesto de escala/rotación
  double _gestEscalaBase   = 1.0;
  double _gestRotacionBase = 0.0;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  ElementoCanvas? get _seleccionado {
    if (_seleccionadoId == null) return null;
    final matches = _elementos.where((e) => e.id == _seleccionadoId);
    return matches.isEmpty ? null : matches.first;
  }

  int get _maxZ =>
      _elementos.isEmpty ? 0 : _elementos.map((e) => e.z).reduce((a, b) => a > b ? a : b);

  int get _minZ =>
      _elementos.isEmpty ? 0 : _elementos.map((e) => e.z).reduce((a, b) => a < b ? a : b);

  // ── Gestión de elementos ────────────────────────────────────────────────────

  void _agregar(String assetId, {Offset? posicion}) {
    // Si no se recibe posición, centra en el lienzo
    final box    = _repaintKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box != null
        ? Offset(box.size.width / 2, box.size.height / 2)
        : const Offset(160, 280);
    final pos = posicion ?? center;

    setState(() {
      _elementos.add(ElementoCanvas(
        id:      '${assetId}_${DateTime.now().microsecondsSinceEpoch}',
        assetId: assetId,
        x:       pos.dx,
        y:       pos.dy,
        z:       _maxZ + 1,
      ));
    });
  }

  void _seleccionar(String id) => setState(() => _seleccionadoId = id);
  void _deseleccionar()        => setState(() => _seleccionadoId = null);

  void _eliminarSeleccionado() {
    if (_seleccionado == null) return;
    setState(() {
      _elementos.removeWhere((e) => e.id == _seleccionadoId);
      _seleccionadoId = null;
    });
  }

  void _traerAlFrente() {
    final el = _seleccionado;
    if (el == null) return;
    setState(() => el.z = _maxZ + 1);
  }

  void _enviarAtras() {
    final el = _seleccionado;
    if (el == null) return;
    setState(() => el.z = _minZ - 1);
  }

  void _limpiar() {
    if (_elementos.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpiar lienzo'),
        content: const Text('¿Eliminar todos los elementos del lienzo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _elementos.clear(); _seleccionadoId = null; });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportar() async {
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    // Quitar selección antes de capturar para que el borde no aparezca en el PNG
    setState(() { _seleccionadoId = null; _exportando = true; });
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final img   = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null || !mounted) return;

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/dibujo_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());

      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: 'Dibujo');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // ── Gestos sobre elementos ──────────────────────────────────────────────────

  void _onScaleStart(String id, ScaleStartDetails d) {
    final el = _elementos.where((e) => e.id == id).firstOrNull;
    if (el == null) return;
    setState(() {
      _seleccionadoId  = id;          // seleccionar al tocar
      _gestEscalaBase  = el.escala;
      _gestRotacionBase = el.rotacion;
    });
  }

  void _onScaleUpdate(String id, ScaleUpdateDetails d) {
    setState(() {
      final el = _elementos.where((e) => e.id == id).firstOrNull;
      if (el == null) return;

      // Siempre: mover según desplazamiento del punto focal
      el.x += d.focalPointDelta.dx;
      el.y += d.focalPointDelta.dy;

      // Solo con 2 dedos: escalar y rotar
      if (d.pointerCount >= 2) {
        el.escala   = (_gestEscalaBase   * d.scale).clamp(0.2, 4.0);
        el.rotacion =  _gestRotacionBase + d.rotation;
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final haySeleccion = _seleccionado != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Text('Dibujo'),
      ),
      body: Column(
        children: [
          // Barra de herramientas
          _BarraHerramientas(
            haySeleccion: haySeleccion,
            exportando:   _exportando,
            onEliminar:   _eliminarSeleccionado,
            onFrente:     _traerAlFrente,
            onAtras:      _enviarAtras,
            onLimpiar:    _limpiar,
            onExportar:   _exportando ? null : _exportar,
          ),

          // Lienzo
          Expanded(
            child: LienzoWidget(
              elementos:       _elementos,
              seleccionadoId:  _seleccionadoId,
              repaintKey:      _repaintKey,
              onSeleccionar:   _seleccionar,
              onDeseleccionar: _deseleccionar,
              onScaleStart:    _onScaleStart,
              onScaleUpdate:   _onScaleUpdate,
              onSoltar: (assetId, pos) => _agregar(assetId, posicion: pos),
            ),
          ),

          // Paleta de elementos
          PaletaWidget(onTap: _agregar),
        ],
      ),
    );
  }
}

// ── Barra de herramientas ─────────────────────────────────────────────────────
class _BarraHerramientas extends StatelessWidget {
  final bool          haySeleccion;
  final bool          exportando;
  final VoidCallback  onEliminar;
  final VoidCallback  onFrente;
  final VoidCallback  onAtras;
  final VoidCallback  onLimpiar;
  final VoidCallback? onExportar;

  const _BarraHerramientas({
    required this.haySeleccion,
    required this.exportando,
    required this.onEliminar,
    required this.onFrente,
    required this.onAtras,
    required this.onLimpiar,
    required this.onExportar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Acciones sobre el elemento seleccionado (habilitadas solo si hay selección)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
            color: Colors.red,
            onPressed: haySeleccion ? onEliminar : null,
          ),
          IconButton(
            icon: const Icon(Icons.flip_to_front),
            tooltip: 'Traer al frente',
            color: Colors.black54,
            onPressed: haySeleccion ? onFrente : null,
          ),
          IconButton(
            icon: const Icon(Icons.flip_to_back),
            tooltip: 'Enviar atrás',
            color: Colors.black54,
            onPressed: haySeleccion ? onAtras : null,
          ),

          const Spacer(),

          // Acciones globales
          TextButton.icon(
            onPressed: onLimpiar,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Limpiar'),
            style: TextButton.styleFrom(foregroundColor: Colors.black54),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: onExportar,
            icon: exportando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.ios_share, size: 18),
            label: Text(exportando ? 'Exportando…' : 'Exportar PNG'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
