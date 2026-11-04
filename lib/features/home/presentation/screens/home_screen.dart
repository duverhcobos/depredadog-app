import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/catalog_cubit.dart';
import '../cubit/catalog_state.dart';
import '../widgets/catalog_states.dart';
import '../widgets/category_card.dart';
import '../widgets/promo_banner.dart';
import '../widgets/signature_strip.dart';

/// Home — selector de categorías (§017 + integración §019). Firma de la
/// referencia del usuario: franja MOSTAZA al 40% del ancho; las cards de
/// categoría y la promo nacen dentro de ella y desbordan hacia el
/// negro. Las categorías ahora son DINÁMICAS del backend (decisión del
/// usuario) — una nueva aparece sola sin release.
///
/// Datos: CatalogCubit compartido del shell. Al entrar dispara
/// refresh() silencioso — el menú visible no parpadea; la primera carga
/// muestra loading/error con retry.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CatalogCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<CatalogCubit, CatalogState>(
            builder: (context, state) {
              if (state.categories.isEmpty) {
                if (state.status == CatalogStatus.error) {
                  return CatalogErrorView(
                    onRetry: () => context.read<CatalogCubit>().refresh(),
                  );
                }
                return const CatalogLoadingView();
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // El aire que ocupaba la franja de estado — el
                  // carrusel respira bajo el header (§017).
                  const SizedBox(height: 36),
                  const PromoBanner(),
                  const SizedBox(height: 8),
                  for (final category in state.categories)
                    CategoryCard(category: category),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
