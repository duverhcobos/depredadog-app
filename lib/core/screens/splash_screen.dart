import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../routes/auth_guard.dart';
import '../theme/app_colors.dart';
import '../widgets/app_backdrop.dart';

/// Splash de marca: flama + nombre + tagline. Tras ~1.2s navega según el
/// estado de sesión (el guard decide — sin sesión cae en /welcome).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) context.go(AuthGuard.welcomeRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          const AppBackdrop(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppBrandMark(),
                const SizedBox(height: 16),
                Text(
                  l10n.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.onBrandGradient,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.splashTagline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onBrandGradient.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
