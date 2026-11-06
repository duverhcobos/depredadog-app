import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';

/// "Ghost card" al final del carrito no-vacío (decisión del usuario
/// — DIRECCION revisor-estetico §020): invitación tenue a seguir
/// pidiendo. Borde punteado radius 14 en la posición straddle de las
/// cards + '¿Se te antoja algo más?' → menú. Es decoración de
/// cierre de lista, NO una fila de ítem (no va en Dismissible).
class CartBrowseMoreCard extends StatelessWidget {
  const CartBrowseMoreCard({super.key});

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
          child: Semantics(
            button: true,
            label: l10n.cartBrowseMore,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.go(AuthGuard.homeRoute),
                child: CustomPaint(
                  painter: _DashedRRectPainter(
                    color: colors.outlineVariant,
                    radius: 14,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: colors.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.cartBrowseMore,
                          style: text.bodyMedium?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja el contorno del ghost: trazo punteado (6px línea / 4px
/// gap) siguiendo el RRect — la punteada es la firma "fantasma"
/// frente al borde sólido de las cards reales.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    const dash = 6.0, gap = 4.0;
    for (final metric in outline.computeMetrics()) {
      var pos = 0.0;
      while (pos < metric.length) {
        canvas.drawPath(
          metric.extractPath(pos, (pos + dash).clamp(0.0, metric.length)),
          paint,
        );
        pos += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
