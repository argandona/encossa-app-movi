// Utilidades para leer cantidades que el backend puede enviar como número
// (5, 5.5) o como texto ("5.00"), ya que los DecimalField de Django REST se
// serializan como String. Castear esos valores con `as int` lanza y deja las
// pantallas en blanco; estos helpers parsean de forma robusta sin lanzar.

/// Convierte cualquier valor a `num`. Nunca lanza; devuelve 0 si no se puede.
num numFrom(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString().trim()) ?? 0;
}

/// Igual que [numFrom] pero truncado a `int`, para lógicas que asumen enteros.
int intFrom(dynamic v) => numFrom(v).toInt();

/// Formatea una cantidad: sin decimales si es entera, con 2 si tiene fracción.
String fmtCant(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
