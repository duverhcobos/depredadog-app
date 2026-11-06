/// "8 nov · 12:40 p. m." — formato de fecha corto es-CO para pedidos
/// (§023). La app no inicializa locales de `intl` (DateFormat('es')
/// lanzaría LocaleDataException), así que los meses cortos se declaran
/// acá — único archivo autorizado para formatear fechas de pedidos.
String formatOrderDate(DateTime date, {bool withYear = false}) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final ampm = date.hour < 12 ? 'a. m.' : 'p. m.';
  // Año solo si NO es el en curso — "8 nov · 12:40 p. m." basta para
  // pedidos de este año (revisor-ui §023: el año es ruido en el dato
  // más escaneado). `withYear` fuerza la inclusión si se necesita.
  final showYear = withYear || date.year != DateTime.now().year;
  final year = showYear ? ' ${date.year}' : '';
  return '${date.day} ${months[date.month - 1]}$year · $hour12:$minute $ampm';
}
