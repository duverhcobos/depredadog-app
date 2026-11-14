import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../utils/format_elapsed.dart';

/// "Hace N min" que se re-computa solo — la cola admin vive ABIERTA
/// todo el día en el local: sin tick propio la frescura se congela y
/// el dato de operación miente en silencio (revisor-ui §034). Timer
/// de 60s pausado cuando el árbol no está visible (TickerMode: el
/// IndexedStack del shell deja los demás tabs deshabilitados).
/// Extraído de admin_order_card (§035) — lo comparten la card de la
/// cola y el header del detalle.
class AdminElapsedText extends StatefulWidget {
  const AdminElapsedText({required this.placedAt, this.style, super.key});

  final DateTime placedAt;

  /// Estilo del texto — la card pasa labelSmall en muted; el detalle
  /// puede pasar otro (null = labelSmall muted por defecto).
  final TextStyle? style;

  @override
  State<AdminElapsedText> createState() => _AdminElapsedTextState();
}

class _AdminElapsedTextState extends State<AdminElapsedText> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (enabled && _timer == null) {
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => setState(() {}),
      );
    } else if (!enabled) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      formatElapsed(widget.placedAt, l10n),
      style:
          widget.style ??
          Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.6),
          ),
    );
  }
}
