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
  ItemPaleta(id: 'casa',    path: 'assets/svg/casa.svg',    nombre: 'Casa'),
  ItemPaleta(id: 'arbol',   path: 'assets/svg/arbol.svg',   nombre: 'Árbol'),
  ItemPaleta(id: 'auto',    path: 'assets/svg/auto.svg',    nombre: 'Auto'),
  ItemPaleta(id: 'persona', path: 'assets/svg/persona.svg', nombre: 'Persona'),
  ItemPaleta(id: 'sol',     path: 'assets/svg/sol.svg',     nombre: 'Sol'),
];

/// Retorna el path del asset para un assetId dado.
String pathParaAsset(String assetId) =>
    kPaleta.firstWhere(
      (i) => i.id == assetId,
      orElse: () => kPaleta.first,
    ).path;
