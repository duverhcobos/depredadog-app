import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import 'product_image.dart';
import 'signature_strip.dart';

/// Promo mock de la fase presentación (§017 — provisional): el módulo
/// promotions alimenta contenido, endsAt real y destino.
class _MockPromo {
  const _MockPromo({
    required this.title,
    required this.endsIn,
    required this.imageAsset,
  });

  final String title;
  final String endsIn;
  final String imageAsset;
}

/// Carrusel de promociones activas (§017 — decisión del usuario):
/// varias promos conviven en un solo slot con **auto-avance en loop
/// infinito** (itemCount infinito arrancando en un múltiplo de la
/// cantidad → el deslizamiento nunca reinicia visiblemente) y puntos
/// indicadores. Cada slide es una card de la familia — a caballo del
/// límite mostaza/negro con la imagen flotando — que se diferencia de
/// las categorías por la bandera PROMO en la esquina.
class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  /// Todos los tipos de promo del negocio (§017 — para revisar cómo
  /// rinde cada uno en el slide): BOGO, item gratis, % OFF, envío
  /// gratis y combo a precio fijo.
  static const _mockPromos = <_MockPromo>[
    _MockPromo(
      title: '2×1 en El Cachorro',
      endsIn: 'Termina en 3h 42m',
      imageAsset: 'assets/images/products/perro_cachorro.png',
    ),
    _MockPromo(
      title: 'Papas gratis con El Depredador',
      endsIn: 'Termina en 1d 6h',
      imageAsset: 'assets/images/products/manada_papas.png',
    ),
    _MockPromo(
      title: '20% OFF en toda la carta',
      endsIn: 'Termina en 8h 15m',
      imageAsset: 'assets/images/products/perro_depredador.png',
    ),
    _MockPromo(
      title: 'Envío gratis desde \$20.000',
      endsIn: 'Termina en 2d 3h',
      imageAsset: 'assets/images/products/perro_trampa.png',
    ),
    _MockPromo(
      title: 'Depredador + bebida a \$28.000',
      endsIn: 'Termina en 5h 30m',
      imageAsset: 'assets/images/products/cat_combos.png',
    ),
  ];

  static const _autoAdvance = Duration(seconds: 4);
  static const _animDuration = Duration(milliseconds: 600);

  // Arranca en un múltiplo grande de la cantidad → loop infinito en
  // ambas direcciones sin salto visible.
  late final PageController _controller = PageController(
    initialPage: _mockPromos.length * 500,
  );
  Timer? _timer;
  int _page = _mockPromos.length * 500;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  /// Auto-avance cada [_autoAdvance]; se reinicia tras cada cambio de
  /// página para que un swipe manual pause el ciclo.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoAdvance, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(duration: _animDuration, curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 116,
      child: LayoutBuilder(
        builder: (context, c) {
          final strip = c.maxWidth * kSignatureStripFraction;
          return Stack(
            children: [
              PageView.builder(
                controller: _controller,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  _startTimer();
                },
                itemBuilder: (context, i) => _PromoSlide(
                  promo: _mockPromos[i % _mockPromos.length],
                  strip: strip,
                  width: c.maxWidth,
                  cardHeight: c.maxHeight,
                ),
              ),
              // Puntos indicadores — solo si hay más de una promo;
              // IgnorePointer deja pasar el tap al slide.
              if (_mockPromos.length > 1)
                Positioned(
                  left: strip * kCardStripInset,
                  right: blackZoneMargin(c.maxWidth),
                  bottom: 12,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _mockPromos.length; i++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page % _mockPromos.length
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Un slide del carrusel — misma cuna/posición que una card de
/// categoría: bandera PROMO + título + cuenta regresiva + chevron.
class _PromoSlide extends StatelessWidget {
  const _PromoSlide({
    required this.promo,
    required this.strip,
    required this.width,
    required this.cardHeight,
  });

  final _MockPromo promo;
  final double strip;
  final double width;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final imageSize = (cardHeight - 16) * 0.8;
    final imageLeft = strip * kCardStripInset - kFrameOverhang;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Positioned(
          left: strip * kCardStripInset,
          top: 8,
          bottom: 8,
          right: blackZoneMargin(width),
          child: Card(
            margin: EdgeInsets.zero,
            // Tono elevado — el mismo de la card hero "El de la casa"
            // (§017, decisión del usuario).
            color: colors.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                InkWell(
                  onTap: () => AppToast.info(context, l10n.comingSoon),
                  child: Padding(
                    // Texto anclado a la imagen — mismo eje que las
                    // cards de categoría (§017).
                    padding: EdgeInsets.only(
                      left: imageSize - kFrameOverhang + kFrameTextGap,
                      right: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                promo.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              // Cuenta regresiva (mock) — en
                              // integración se computa de endsAt y
                              // refresca por minuto.
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: colors.onSurface.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    promo.endsIn,
                                    style: text.labelSmall?.copyWith(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.55,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Bandera PROMO diagonal en la esquina superior
                // derecha — distingue la oferta de las categorías
                // (§017, variante escogida por el usuario).
                Positioned(
                  top: 13,
                  right: -34,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 110,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        color: colors.primary,
                        child: Text(
                          l10n.homePromoTag,
                          textAlign: TextAlign.center,
                          style: text.labelSmall?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: imageLeft,
          child: IgnorePointer(
            child: ProductImage(asset: promo.imageAsset, size: imageSize),
          ),
        ),
      ],
    );
  }
}
