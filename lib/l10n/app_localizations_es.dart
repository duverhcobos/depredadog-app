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
  String get loginHeadline => 'VUELVE A LA MANADA';

  @override
  String get loginSubtitle =>
      'Inicia sesión para pedir algo salvajemente bueno.';

  @override
  String get loginEmailLabel => 'Correo electrónico';

  @override
  String get loginEmailHint => 'nombre@ejemplo.com';

  @override
  String get loginEmailRequired => 'Ingresa tu correo';

  @override
  String get loginEmailError => 'Ingresa un correo válido';

  @override
  String get loginPasswordLabel => 'Contraseña';

  @override
  String get loginPasswordHint => 'Ej: HotDog2024';

  @override
  String get loginPasswordRequired => 'Ingresa tu contraseña';

  @override
  String get loginPasswordError => 'Mínimo 6 caracteres';

  @override
  String get loginFormInvalid => 'Revisa los campos marcados';

  @override
  String get loginShowPassword => 'Mostrar contraseña';

  @override
  String get loginHidePassword => 'Ocultar contraseña';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginRememberMe => 'Recuérdame';

  @override
  String get loginButton => 'Iniciar sesión';

  @override
  String get loginOrContinueWith => 'o continúa con';

  @override
  String get loginGoogleButton => 'Ingresar con Google';

  @override
  String get loginNoAccount => '¿No tienes cuenta? ';

  @override
  String get loginRegisterLink => 'Regístrate';

  @override
  String get loginDemoSuccess =>
      'Inicio de sesión simulado — sin backend todavía';

  @override
  String get comingSoon => 'Disponible próximamente';

  @override
  String get commonBack => 'Volver';

  @override
  String get verifyEmailHeadline => 'Verifica tu correo';

  @override
  String verifyEmailSubtitle(String email) {
    return 'Enviamos un código de 6 dígitos a $email';
  }

  @override
  String get verifyEmailButton => 'Verificar';

  @override
  String get verifyEmailFormInvalid => 'Ingresa el código de 6 dígitos';

  @override
  String verifyEmailCodeSemantics(int filled) {
    return 'Código de verificación, $filled de 6 dígitos';
  }

  @override
  String get verifyEmailResendQuestion => '¿No recibiste el código? ';

  @override
  String get verifyEmailResend => 'Reenviar';

  @override
  String verifyEmailResendIn(int seconds) {
    return 'Reenviar en ${seconds}s';
  }

  @override
  String get verifyEmailResendSuccess => 'Código reenviado — revisa tu correo';

  @override
  String get verifyEmailDemoSuccess =>
      'Verificación simulada — sin backend todavía';
}
