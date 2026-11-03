import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/app_toast.dart';

/// Cabecera fija del shell autenticado (§016): imagotipo a la izquierda,
/// acciones a la derecha. Las acciones son PROVISIONALES — toast
/// "Disponible próximamente" hasta que existan sus módulos
/// (notificaciones / carrito). El badge del carrito es count mock=2
/// PROVISIONAL para la revisión visual — en producción se dibuja solo
/// cuando count>0 y el módulo carrito lo alimenta.
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Image.asset(
              // Variante HORIZONTAL del brand kit (isotipo + wordmark) —
              // el imagotipo vertical deja el tagline ilegible en banda.
              'assets/images/imagotipo_horizontal_blanco.png',
              height: 40,
              fit: BoxFit.contain,
              semanticLabel: l10n.appName,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: l10n.shellNotificationsTooltip,
              onPressed: () => AppToast.info(context, l10n.comingSoon),
            ),
            IconButton(
              // PROVISIONAL: badge con count mock=2 solo para la revisión
              // visual (decisión del usuario). En producción el badge se
              // dibuja cuando count>0 y el módulo carrito lo alimenta.
              icon: Badge(
                label: const Text('2'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                textColor: Theme.of(context).colorScheme.onPrimary,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              tooltip: l10n.shellCartTooltip,
              onPressed: () => AppToast.info(context, l10n.comingSoon),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
