import 'package:flutter/material.dart';

import '../data/catalog_mock.dart';
import '../widgets/category_card.dart';
import '../widgets/promo_banner.dart';
import '../widgets/signature_strip.dart';

/// Home — selector de categorías (§017, fase presentación). Firma de la
/// referencia del usuario: franja MOSTAZA al 40% del ancho; las cards de
/// categoría y la promo nacen dentro de ella y desbordan hacia el
/// negro, con la imagen del producto flotando sobre el límite. El
/// estado del local vive en el header del shell (chip junto a la
/// campana).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Franja firma 40% — las cards la cruzan.
          const SignatureStrip(fraction: kSignatureStripFraction),
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: const [
              // El aire que ocupaba la franja de estado — el carrusel
              // respira bajo el header (§017).
              SizedBox(height: 36),
              // Ancho completo — la promo se posiciona sola a caballo
              // del límite como las cards de categoría (§017).
              PromoBanner(),
              SizedBox(height: 8),
              CategoryCard(category: CatalogCategory.dogs),
              CategoryCard(category: CatalogCategory.more),
              CategoryCard(category: CatalogCategory.drinks),
              CategoryCard(category: CatalogCategory.combos),
            ],
          ),
        ],
      ),
    );
  }
}
