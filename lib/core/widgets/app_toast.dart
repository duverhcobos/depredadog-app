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

  static void _show(
    BuildContext context,
    String message, {
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
