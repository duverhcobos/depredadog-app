import 'package:flutter/material.dart';

/// Imagen de producto flotante (§017): va a caballo del borde
/// izquierdo de la card (sobre el mostaza afuera, sobre la card
/// adentro). Ocupa el 90% del tile para el respiro visual.
///
/// §019: `imageUrl` (foto remota del backend) tiene prioridad cuando
/// llega; hoy es null → el asset local por slug manda, y queda de
/// fallback si la red falla (errorBuilder).
///
/// Los assets de producción serán 16:9 — al llegar, pasar
/// `aspectRatio: 16 / 9` en los call sites (el tile se vuelve
/// apaisado conservando la altura; revisar el aire con el texto).
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.asset,
    required this.size,
    this.imageUrl,
    this.aspectRatio = 1,
    super.key,
  });

  /// Asset local por slug (fallback mientras no haya fotos remotas).
  final String asset;

  /// URL remota de product_images (hoy null — pendientes backend/006).
  final String? imageUrl;

  /// Alto del tile — el caller lo calcula como 0.8 × alto de la card.
  final double size;

  /// Proporción ancho/alto del tile (1:1 con los mocks actuales).
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * aspectRatio,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * 0.05),
        child: imageUrl == null
            ? Image.asset(asset, fit: BoxFit.contain)
            : Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                // La remota falla o falta → asset local por slug.
                errorBuilder: (_, _, _) =>
                    Image.asset(asset, fit: BoxFit.contain),
              ),
      ),
    );
  }
}
