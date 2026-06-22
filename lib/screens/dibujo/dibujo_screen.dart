import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../models/elemento_canvas.dart';
import 'lienzo_widget.dart';
import 'paleta_widget.dart';

class DibujoScreen extends StatefulWidget {
  /// Código del SST al que pertenece el plano. Si es null, el lienzo es libre
  /// (no se carga ni se guarda en el servidor).
  final String? sstCodigo;
  /// Etiqueta del SST para mostrar en la barra (ej: "SST 12345").
  final String? sstLabel;

  const DibujoScreen({super.key, this.sstCodigo, this.sstLabel});

  @override
  State<DibujoScreen> createState() => _DibujoScreenState();
}

class _DibujoScreenState extends State<DibujoScreen> {
  // ── Estado del lienzo ───────────────────────────────────────────────────────
  final List<ElementoCanvas> _elementos     = [];
  String?                    _seleccionadoId;
  final GlobalKey            _repaintKey    = GlobalKey();
  bool                       _exportando    = false;
  bool                       _cargando      = false;
  bool                       _guardando     = false;

  // Valores base del elemento al inicio de cada gesto de escala/rotación
  double _gestEscalaBase   = 1.0;
  double _gestRotacionBase = 0.0;

  bool get _ligadoASst => widget.sstCodigo != null && widget.sstCodigo!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_ligadoASst) _cargarPlano();
  }

  Future<void> _cargarPlano() async {
    setState(() => _cargando = true);
    try {
      final els = await ApiService().getPlano(widget.sstCodigo!);
      if (!mounted) return;
      setState(() {
        _elementos
          ..clear()
          ..addAll(els);
        _seleccionadoId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cargar el plano: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarPlano() async {
    if (!_ligadoASst) return;
    final usuario = context.read<AuthProvider>().usuario!;
    setState(() { _seleccionadoId = null; _guardando = true; });
    try {
      await ApiService().guardarPlano(
        widget.sstCodigo!,
        usuario.idUsuario,
        _elementos,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plano guardado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

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
        title: Text(widget.sstLabel ?? 'Dibujo'),
        actions: [
          if (_ligadoASst)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: (_guardando || _cargando) ? null : _guardarPlano,
                icon: _guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                label: Text(
                  _guardando ? 'Guardando…' : 'Guardar',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
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

          // Overlay de carga inicial del plano
          if (_cargando)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
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
