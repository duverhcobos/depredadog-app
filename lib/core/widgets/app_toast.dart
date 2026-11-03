import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// SOLID (SRP): único punto que llama a fluttertoast — toda la app
/// muestra feedback efímero por acá, nunca SnackBar directo (decisión del
/// usuario — reemplaza el estándar anterior de ui-design-standard).
class AppToast {
  AppToast._();

  static void error(BuildContext context, String message) => _show(
    context,
    message,
    backgroundColor: Theme.of(context).colorScheme.error,
    textColor: Theme.of(context).colorScheme.onError,
  );

  static void success(BuildContext context, String message) => _show(
    context,
    message,
    backgroundColor: Theme.of(context).colorScheme.primary,
    textColor: Theme.of(context).colorScheme.onPrimary,
  );

  /// Variante neutral (§016) para feedback que no es éxito ni error —
  /// p. ej. "Disponible próximamente": fondo surfaceContainerHighest +
  /// texto onSurface. El ícono semántico es `info_outline`; fluttertoast
  /// nativo no dibuja íconos — queda declarado en la firma de `_show`
  /// para cuando el toast migre a widget propio.
  static void info(BuildContext context, String message) => _show(
    context,
    message,
    icon: Icons.info_outline,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    textColor: Theme.of(context).colorScheme.onSurface,
  );

  static void _show(
    BuildContext context,
    String message, {
    // Fluttertoast.showToast no tiene parámetro de ícono — se declara la
    // semántica de cada variante para la futura migración a toast custom.
    IconData? icon,
    required Color backgroundColor,
    required Color textColor,
  }) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: textColor,
      toastLength: Toast.LENGTH_LONG,
    );
  }
}
