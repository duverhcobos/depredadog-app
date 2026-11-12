import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../routes/auth_guard.dart';

/// Muro de auth compartido (§031 — auth por demanda): lo que ve el
/// invitado donde hace falta cuenta. Familia de las pantallas de
/// estado de la casa (module_placeholder / catalog_states): ícono
/// 80px primary + título titleMedium + subtítulo bodyMedium α0.7
/// centrado + CTA primario a login + link a registro.
///
/// `fromRoute` viaja en el `?from=` del login/register — el éxito
/// devuelve al usuario al punto donde se pidió la sesión.
///
/// Layout-neutral (una Column min): el host decide la cuna — centrado
/// como estado del tab en Pedidos, dentro de una straddle card en el
/// Perfil.
class AuthRequiredView extends StatelessWidget {
  const AuthRequiredView({
    required this.icon,
    required this.title,
    required this.message,
    required this.fromRoute,
    this.iconSize = 80,
    super.key,
  });

  /// Ícono de la sección bloqueada (recibo / persona).
  final IconData icon;

  /// Título del muro — "Inicia sesión para ver tus pedidos".
  final String title;

  /// Cuerpo del muro — qué le espera tras la cuenta.
  final String message;

  /// Ruta donde se pidió la sesión — viaja como `?from=` (encodeado).
  final String fromRoute;

  /// Tamaño del ícono — 80 es canon de pantalla de estado; en una
  /// card acotada (Perfil invitado) 64 respira mejor (revisor-
  /// estetico §031).
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final from = Uri.encodeComponent(fromRoute);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: colors.primary),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: text.titleMedium),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        // push, no go: el back nativo también regresa al tab donde
        // quedó el invitado — no solo el retorno post-login (§031).
        // 48dp + ancho mínimo: la única acción del muro no puede ser
        // la píldora más tímida de la composición (revisor-estetico).
        SizedBox(
          height: 48,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(180, 48)),
            onPressed: () => context.push('${AuthGuard.loginRoute}?from=$from'),
            child: Text(l10n.loginButton),
          ),
        ),
        // Gap explícito entre CTA y link — no depender del padding
        // interno del TextButton (revisor-ui §031).
        const SizedBox(height: 4),
        TextButton(
          onPressed: () =>
              context.push('${AuthGuard.registerRoute}?from=$from'),
          child: Text.rich(
            TextSpan(
              // "¿No tienes cuenta? " + "Regístrate" — mismo par de
              // claves del footer del login (sin claves nuevas).
              text: l10n.loginNoAccount,
              style: text.bodyMedium?.copyWith(color: colors.onSurface),
              children: [
                TextSpan(
                  text: l10n.loginRegisterLink,
                  style: text.bodyMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
