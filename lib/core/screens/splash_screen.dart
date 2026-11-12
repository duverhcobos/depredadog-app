import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/splash_cubit.dart';
import '../../l10n/app_localizations.dart';
import '../constants/hero_tags.dart';
import '../di/setup_di.dart';
import '../routes/auth_guard.dart';

/// Splash de marca: imagotipo centrado sobre el fondo del tema (positivo
/// en claro, negativo a color en oscuro) — continuidad visual con el
/// splash nativo y el login. Tras la marca mínima (~0.8s) navega SIEMPRE
/// a /home (§031 — la carta es el destino default, no el login);
/// SplashCubit.restoreSession sigue corriendo para dejar la sesión
/// marcada si el token era válido (los muros de los tabs la leen solos).
/// Patrón dos clases: `SplashScreen` provee el cubit vía locator,
/// `_SplashView` renderiza y orquesta la navegación.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SplashCubit>(
      create: (context) => locator<SplashCubit>(),
      child: const _SplashView(),
    );
  }
}

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView> {
  late final String _imagotypeAsset;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    _imagotypeAsset = Theme.of(context).brightness == Brightness.dark
        ? 'assets/images/imagotipo_depredadog_dark.png'
        : 'assets/images/imagotipo_depredadog.png';
    _goNext();
  }

  Future<void> _goNext() async {
    final cubit = context.read<SplashCubit>();
    // Fire-and-remember: el restore arranca YA en paralelo con la marca —
    // se espera al final para navegar en max(800ms, respuesta del server).
    final restore = cubit.restoreSession();
    // Secuencial, no Future.wait: si el decode termina después del delay,
    // wait() resolvería en el mismo frame en que la imagen se pinta y la
    // marca no llegaría a verse. Decode primero → 800ms visibles garantizados.
    await precacheImage(
      AssetImage(_imagotypeAsset),
      context,
    ).catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await restore;
    if (!mounted) return;
    // §031 — éxito o invitado, el destino es la carta: la sesión
    // restaurada (si hubo) ya quedó marcada en AuthSession.
    context.go(AuthGuard.homeRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Hero(
          tag: HeroTags.brandImagotipo,
          child: Image.asset(
            _imagotypeAsset,
            height: 220,
            fit: BoxFit.contain,
            semanticLabel: AppLocalizations.of(context)!.appName,
          ),
        ),
      ),
    );
  }
}
