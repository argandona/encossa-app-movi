import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/assets_paleta.dart';

/// Barra horizontal desplazable con los SVGs disponibles.
/// - Tap   → agrega el elemento centrado en el lienzo.
/// - Drag  → arrastra el elemento y lo suelta en el lienzo.
class PaletaWidget extends StatelessWidget {
  final void Function(String assetId) onTap;

  const PaletaWidget({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: kPaleta.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _ItemPaleta(item: kPaleta[i], onTap: onTap),
      ),
    );
  }
}

class _ItemPaleta extends StatelessWidget {
  final ItemPaleta                    item;
  final void Function(String assetId) onTap;

  const _ItemPaleta({required this.item, required this.onTap});

  Widget _preview({double size = 50}) => SvgPicture.asset(
        item.path,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );

  @override
  Widget build(BuildContext context) {
    final chip = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _preview(),
        ),
        const SizedBox(height: 3),
        Text(
          item.nombre,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
      ],
    );

    return Draggable<String>(
      data: item.id,
      // Imagen semitransparente que sigue al dedo mientras se arrastra
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.85, child: _preview(size: 72)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: GestureDetector(
        onTap: () => onTap(item.id),
        child: chip,
      ),
    );
  }
}
