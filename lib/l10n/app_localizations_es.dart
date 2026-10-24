// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Depredadog';

  @override
  String get splashTagline => 'Perros calientes que muerden de vuelta';

  @override
  String get welcomeTitle => 'Bienvenido a Depredadog';

  @override
  String get welcomeBody =>
      'La autenticación llega en la próxima iteración. Esta pantalla es temporal.';

  @override
  String get welcomeAuthPending => 'Acceso disponible muy pronto';
}
