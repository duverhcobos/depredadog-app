/// 14000 → "$14.000" (COP con separador de miles por punto).
/// Movido del mock §017/018 — acepta num porque los precios del
/// backend llegan como numérico.
String formatCop(num price) {
  final s = price.toInt().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '\$$b';
}
