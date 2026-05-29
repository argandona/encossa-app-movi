import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/elemento_canvas.dart';
import '../../core/assets_paleta.dart';

/// Tamaño base de cada elemento antes de aplicar escala (px lógicos).
const double kBaseSize = 80.0;

/// Lienzo de dibujo. Stateless: todo el estado vive en DibujoScreen.
class LienzoWidget extends StatelessWidget {
  final List<ElementoCanvas>                     elementos;
  final String?                                  seleccionadoId;
  final GlobalKey                                repaintKey;

  final void Function(String id)                       onSeleccionar;
  final VoidCallback                                   onDeseleccionar;
  final void Function(String id, ScaleStartDetails d)  onScaleStart;
  final void Function(String id, ScaleUpdateDetails d) onScaleUpdate;
  /// Callback cuando el usuario suelta un ítem de la paleta sobre el lienzo.
  final void Function(String assetId, Offset posicion) onSoltar;

  const LienzoWidget({
    super.key,
    required this.elementos,
    required this.seleccionadoId,
    required this.repaintKey,
    required this.onSeleccionar,
    required this.onDeseleccionar,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onSoltar,
  });

  @override
  Widget build(BuildContext context) {
    // Renderizar de menor a mayor z (mayor z queda encima)
    final ordenados = [...elementos]..sort((a, b) => a.z.compareTo(b.z));

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        // Convertir posición global a coordenadas locales del lienzo
        final box = repaintKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        onSoltar(details.data, box.globalToLocal(details.offset));
      },
      builder: (context, candidateData, _) {
        final isDragOver = candidateData.isNotEmpty;

        return GestureDetector(
          // Tap sobre el fondo del lienzo deselecciona el elemento activo
          onTap: onDeseleccionar,
          child: RepaintBoundary(
            key: repaintKey,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: isDragOver
                    ? Border.all(color: Colors.blue.shade300, width: 2)
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // Fondo blanco explícito (capturado en el PNG exportado)
                  Positioned.fill(child: Container(color: Colors.white)),

                  // Elementos ordenados por z
                  for (final el in ordenados)
                    _ElementoWidget(
                      el:            el,
                      esSeleccionado: el.id == seleccionadoId,
                      onTap:         () => onSeleccionar(el.id),
                      onScaleStart:  (d) => onScaleStart(el.id, d),
                      onScaleUpdate: (d) => onScaleUpdate(el.id, d),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget que representa un elemento individual en el lienzo.
class _ElementoWidget extends StatelessWidget {
  final ElementoCanvas el;
  final bool           esSeleccionado;
  final VoidCallback   onTap;
  final void Function(ScaleStartDetails)  onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;

  const _ElementoWidget({
    required this.el,
    required this.esSeleccionado,
    required this.onTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final path     = pathParaAsset(el.assetId);
    // El área de tap/arrastre crece con la escala para que siempre coincida
    // con el tamaño visual del elemento
    final hitSize  = (kBaseSize * el.escala).clamp(kBaseSize * 0.3, kBaseSize * 5.0);
    final half     = hitSize / 2;

    return Positioned(
      left:   el.x - half,
      top:    el.y - half,
      width:  hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        child: Transform.rotate(
          angle:     el.rotacion,
          alignment: Alignment.center,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset(path, fit: BoxFit.contain),
              // Borde de selección (se escala inversamente para grosor constante)
              if (esSeleccionado)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue.shade400,
                      width: (2.5 / el.escala).clamp(0.8, 4.0),
                    ),
                    borderRadius: BorderRadius.circular(4 / el.escala),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
