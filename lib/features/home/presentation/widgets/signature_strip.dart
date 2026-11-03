import 'package:flutter/material.dart';

/// Fracción del ancho de pantalla que ocupa la franja firma — 40%
/// (decisión del usuario §017). Las cards la usan para posicionar su
/// borde e imagen sobre el límite mostaza/negro.
const double kSignatureStripFraction = 0.4;

/// Posición del borde izquierdo de las cards dentro de la franja —
/// fracción de la franja (0.5 = la card arranca a mitad de camino del
/// límite mostaza/negro). Los márgenes laterales del conjunto derivan
/// de aquí (§017, decisión del usuario: márgenes compactos).
const double kCardStripInset = 0.5;

/// Sobrante de la imagen fuera de la card (§017 — decisión del
/// usuario). Con margen derecho = borde de card − overhang el
/// conjunto card+imagen queda centrado en pantalla.
const double kFrameOverhang = 44;

/// Aire entre el borde derecho del recuadro y el texto (§017 —
/// decisión del usuario: el texto se ancla al marco, no al límite
/// mostaza/negro).
const double kFrameTextGap = 14;

/// Margen derecho simétrico de la zona de contenido — iguala el
/// sobrante de la imagen a la izquierda para centrar el conjunto.
double blackZoneMargin(double width) =>
    width * kSignatureStripFraction * kCardStripInset - kFrameOverhang;

/// Franja vertical MOSTAZA — firma visual del home/lista de catálogo
/// (§017, referencia del usuario). Ocupa [fraction] del ancho de la
/// pantalla; el contenido scrollea encima y las imágenes de las cards
/// flotan sobre ella desbordando hacia el negro.
class SignatureStrip extends StatelessWidget {
  const SignatureStrip({required this.fraction, super.key});

  /// Fracción del ancho de pantalla — 0.4 (40%, decisión del usuario).
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        heightFactor: 1,
        child: ColoredBox(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
