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
  String get loginErrorInvalidCredentials => 'Correo o contraseña incorrectos';

  @override
  String get loginErrorEmailNotVerified =>
      'Verifica tu correo antes de iniciar sesión';

  @override
  String get loginErrorAccountSuspended => 'Tu cuenta está suspendida';

  @override
  String get loginErrorTooManyAttempts =>
      'Demasiados intentos — espera un momento';

  @override
  String get loginErrorNoConnection => 'Sin conexión a internet';

  @override
  String get loginErrorGeneric => 'No se pudo iniciar sesión, intenta de nuevo';

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
  String get verifyEmailErrorInvalidCode =>
      'El código es incorrecto o ya expiró — pide uno nuevo.';

  @override
  String get registerStepDataLabel => 'Datos';

  @override
  String get registerStepAccountLabel => 'Cuenta';

  @override
  String get registerStepReviewLabel => 'Revisión';

  @override
  String get registerStep1Title => 'Cuéntanos quién eres';

  @override
  String get registerStep1Subtitle => 'Empecemos por tus datos personales.';

  @override
  String get registerStep2Title => 'Tu correo y tu llave';

  @override
  String get registerStep2Subtitle => 'Con estos datos entrarás a tu cuenta.';

  @override
  String registerStep3Title(String name) {
    return 'Todo listo, $name';
  }

  @override
  String get registerStep3Subtitle => 'Revisa que todo esté bien.';

  @override
  String registerStepProgress(int current, int total) {
    return 'Paso $current de $total';
  }

  @override
  String registerStepItemLabel(int number, String label, String status) {
    return 'Paso $number: $label, $status';
  }

  @override
  String get registerStepStatusCompleted => 'completado';

  @override
  String get registerStepStatusCurrent => 'actual';

  @override
  String get registerStepStatusPending => 'pendiente';

  @override
  String get registerContinue => 'Continuar';

  @override
  String get registerBackStep => 'Atrás';

  @override
  String get registerReviewName => 'Nombre';

  @override
  String get registerReviewEmail => 'Correo';

  @override
  String get registerReviewPhone => 'Teléfono';

  @override
  String get registerReviewNoPhone => 'Sin teléfono';

  @override
  String get registerFirstNameLabel => 'Primer nombre *';

  @override
  String get registerFirstNameHint => 'Ej: Ana';

  @override
  String get registerSecondNameLabel => 'Segundo nombre (opcional)';

  @override
  String get registerLastNameLabel => 'Primer apellido *';

  @override
  String get registerLastNameHint => 'Ej: Pérez';

  @override
  String get registerSecondLastNameLabel => 'Segundo apellido (opcional)';

  @override
  String get registerEmailLabel => 'Correo electrónico *';

  @override
  String get registerPhoneLabel => 'Teléfono (opcional)';

  @override
  String get registerPhoneHint => 'Ej: 300 123 4567';

  @override
  String get registerPasswordLabel => 'Contraseña *';

  @override
  String get registerPasswordHint => 'Mínimo 8 caracteres';

  @override
  String get registerConfirmPasswordLabel => 'Confirmar contraseña *';

  @override
  String get registerConfirmPasswordHint => 'Repite tu contraseña';

  @override
  String get registerNameRequired => 'Ingresa tu nombre';

  @override
  String get registerNameInvalid => 'Nombre incorrecto';

  @override
  String get registerLastNameRequired => 'Ingresa tu apellido';

  @override
  String get registerLastNameInvalid => 'Apellido incorrecto';

  @override
  String get registerPhoneInvalid => 'Teléfono incorrecto';

  @override
  String get registerEmailInvalid => 'Correo incorrecto';

  @override
  String get registerEmailTaken => 'Este correo ya tiene cuenta';

  @override
  String get registerErrorGeneric =>
      'No se pudo crear la cuenta, intenta de nuevo';

  @override
  String get registerPasswordRequired => 'Ingresa una contraseña';

  @override
  String get registerPasswordInvalid => 'Contraseña incorrecta';

  @override
  String get registerConfirmRequired => 'Confirma tu contraseña';

  @override
  String get registerConfirmMismatch => 'Las contraseñas no coinciden';

  @override
  String get registerButton => 'Crear cuenta';

  @override
  String get registerHasAccount => '¿Ya tienes cuenta? ';

  @override
  String get registerLoginLink => 'Inicia sesión';
}
