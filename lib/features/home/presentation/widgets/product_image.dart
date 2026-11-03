import 'package:flutter/material.dart';

/// Imagen de producto flotante (§017): va a caballo del borde
/// izquierdo de la card (sobre el mostaza afuera, sobre la card
/// adentro). Ocupa el 90% del tile para el respiro visual.
///
/// Los assets de producción serán 16:9 — al llegar, pasar
/// `aspectRatio: 16 / 9` en los call sites (el tile se vuelve
/// apaisado conservando la altura; revisar el aire con el texto).
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.asset,
    required this.size,
    this.aspectRatio = 1,
    super.key,
  });

  final String asset;

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
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}
