import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/setup_di.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

/// Raíz de la app: MaterialApp.router con tema M3.
/// MVP: solo tema oscuro (decisión del usuario) — ThemeMode.dark fijo,
/// ignora el tema del sistema. AppTheme.light()/AppColors *Light siguen
/// en el repo sin usarse por si se reactiva el soporte claro más adelante.
class DepredadogApp extends StatelessWidget {
  const DepredadogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Depredadog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: locator<AppRouter>().router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
    );
  }
}
