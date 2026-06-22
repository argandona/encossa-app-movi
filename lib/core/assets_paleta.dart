/// Definición de los assets SVG disponibles en la paleta.
/// Para agregar más elementos: añade un ItemPaleta a kPaleta
/// y coloca el archivo SVG correspondiente en assets/svg/.
class ItemPaleta {
  final String id;      // identificador (= nombre de archivo sin extensión)
  final String path;    // ruta al asset
  final String nombre;  // etiqueta visible en la paleta

  const ItemPaleta({
    required this.id,
    required this.path,
    required this.nombre,
  });
}

const List<ItemPaleta> kPaleta = [
  ItemPaleta(id: 'retenida',       path: 'assets/svg/Retenida.svg',       nombre: 'Retenida'),
  ItemPaleta(id: 'caais2x16',      path: 'assets/svg/Caais 2x16.svg',     nombre: 'Caais 2x16'),
  ItemPaleta(id: 'mensula_simple', path: 'assets/svg/Mensula_simple.svg', nombre: 'Ménsula simple'),
  ItemPaleta(id: 'mensula_doble',  path: 'assets/svg/mensula_doble.svg',  nombre: 'Ménsula doble'),
  ItemPaleta(id: 'poste',          path: 'assets/svg/Poste.svg',          nombre: 'Poste'),
];

/// Retorna el path del asset para un assetId dado.
String pathParaAsset(String assetId) =>
    kPaleta.firstWhere(
      (i) => i.id == assetId,
      orElse: () => kPaleta.first,
    ).path;
