/// Display `3XX XXX XXXX` del celular (contacto del pedido §024,
/// usuario del perfil §030) — máscara simple; cualquier otro largo
/// se muestra tal cual.
String formatPhone(String p) => p.length == 10
    ? '${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6)}'
    : p;
