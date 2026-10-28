import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../constants/hero_tags.dart';
import '../routes/auth_guard.dart';

/// Splash de marca: imagotipo centrado sobre el fondo del tema (positivo
/// en claro, negativo a color en oscuro) — continuidad visual con el
/// splash nativo y el login. Navega al login ~0.8s después de que el
/// imagotipo termina de decodificarse (precache: el login lo hereda del
/// ImageCache y pinta el header sin parpadeo). Cuando exista chequeo de
/// sesión esta pantalla decide login vs home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
    // Secuencial, no Future.wait: si el decode termina después del delay,
    // wait() resolvería en el mismo frame en que la imagen se pinta y la
    // marca no llegaría a verse. Decode primero → 800ms visibles garantizados.
    await precacheImage(
      AssetImage(_imagotypeAsset),
      context,
    ).catchError((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // PROVISIONAL: sin chequeo de sesión todavía — siempre al login. Cuando
    // exista sesión persistida, esta pantalla decide login vs home.
    if (mounted) {
      context.go(AuthGuard.loginRoute);
    }
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
