import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import 'profile_loyalty_info_dialog.dart';

/// Tarjeta de fidelidad del Perfil (§030.1 — reemplaza a la tarjeta de
/// referido §030): headline de puntos (titleLarge w800 mostaza) + copy
/// de voz "Tu manada te premia" + el código para la manada con botón
/// copiar (Clipboard nativo + AppToast — idéntico patrón §030) + la
/// línea de referidos "N personas ya se sumaron con tu código". Datos
/// mock en fase 1 — el módulo loyalty del backend aún no existe, los
/// campos del state ya tienen la forma real.
class ProfileLoyaltyCard extends StatelessWidget {
  const ProfileLoyaltyCard({
    required this.code,
    required this.points,
    required this.referredCount,
    super.key,
  });

  /// Código de referido propio (mock — el User lo gana en
  /// integración). Nullable: un usuario con puntos pero sin código
  /// vería la card sin la fila del código (revisor-ui §030.1).
  final String? code;

  /// Puntos acumulados — el headline de la card.
  final int points;

  /// Personas que entraron con el código — la línea social proof.
  final int referredCount;

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: code ?? ''));
    if (!context.mounted) return;
    AppToast.success(context, l10n.profileCopiedToast);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, c) => Padding(
          padding: EdgeInsets.only(
            left: c.maxWidth * kSignatureStripFraction * kCardStripInset,
            right: blackZoneMargin(c.maxWidth),
          ),
          child: Card(
            margin: EdgeInsets.zero,
            color: colors.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.profileLoyaltyPoints(points),
                          style: text.titleLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      // Ícono info — abre el diálogo "¿Cómo funciona
                      // la manada?" (puntos + referidos, §030.1).
                      IconButton(
                        tooltip: l10n.profileLoyaltyInfoTooltip,
                        onPressed: () => showProfileLoyaltyInfoDialog(context),
                        icon: Icon(
                          Icons.info_outline,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l10n.profileLoyaltyCopy,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (code != null && code!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    // Mini-label del código — misma convención w600 del
                    // label "Horario" de El local (revisor-ui §030.1).
                    Text(
                      l10n.profileReferralTitle,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            code!,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.profileCopyCode,
                          onPressed: () => _copy(context),
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  Text(
                    l10n.profileLoyaltyReferred(referredCount),
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
