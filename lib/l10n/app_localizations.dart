import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appName.
  ///
  /// In es, this message translates to:
  /// **'Depredadog'**
  String get appName;

  /// No description provided for @loginHeadline.
  ///
  /// In es, this message translates to:
  /// **'VUELVE A LA MANADA'**
  String get loginHeadline;

  /// No description provided for @loginSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para pedir algo salvajemente bueno.'**
  String get loginSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailHint.
  ///
  /// In es, this message translates to:
  /// **'nombre@ejemplo.com'**
  String get loginEmailHint;

  /// No description provided for @loginEmailRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo'**
  String get loginEmailRequired;

  /// No description provided for @loginEmailError.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo válido'**
  String get loginEmailError;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: HotDog2024'**
  String get loginPasswordHint;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña'**
  String get loginPasswordRequired;

  /// No description provided for @loginPasswordError.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 6 caracteres'**
  String get loginPasswordError;

  /// No description provided for @loginFormInvalid.
  ///
  /// In es, this message translates to:
  /// **'Revisa los campos marcados'**
  String get loginFormInvalid;

  /// No description provided for @loginShowPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get loginHidePassword;

  /// No description provided for @loginForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get loginForgotPassword;

  /// No description provided for @loginRememberMe.
  ///
  /// In es, this message translates to:
  /// **'Recuérdame'**
  String get loginRememberMe;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginButton;

  /// No description provided for @loginOrContinueWith.
  ///
  /// In es, this message translates to:
  /// **'o continúa con'**
  String get loginOrContinueWith;

  /// No description provided for @loginGoogleButton.
  ///
  /// In es, this message translates to:
  /// **'Ingresar con Google'**
  String get loginGoogleButton;

  /// No description provided for @loginNoAccount.
  ///
  /// In es, this message translates to:
  /// **'¿No tienes cuenta? '**
  String get loginNoAccount;

  /// No description provided for @loginRegisterLink.
  ///
  /// In es, this message translates to:
  /// **'Regístrate'**
  String get loginRegisterLink;

  /// No description provided for @loginErrorInvalidCredentials.
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña incorrectos'**
  String get loginErrorInvalidCredentials;

  /// No description provided for @loginErrorEmailNotVerified.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo antes de iniciar sesión'**
  String get loginErrorEmailNotVerified;

  /// No description provided for @loginErrorAccountSuspended.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta está suspendida'**
  String get loginErrorAccountSuspended;

  /// No description provided for @loginErrorTooManyAttempts.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos — espera un momento'**
  String get loginErrorTooManyAttempts;

  /// No description provided for @loginErrorNoConnection.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet'**
  String get loginErrorNoConnection;

  /// No description provided for @loginErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar sesión, intenta de nuevo'**
  String get loginErrorGeneric;

  /// No description provided for @comingSoon.
  ///
  /// In es, this message translates to:
  /// **'Disponible próximamente'**
  String get comingSoon;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @verifyEmailHeadline.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo'**
  String get verifyEmailHeadline;

  /// No description provided for @verifyEmailSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Enviamos un código de 6 dígitos a {email}'**
  String verifyEmailSubtitle(String email);

  /// No description provided for @verifyEmailButton.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get verifyEmailButton;

  /// No description provided for @verifyEmailFormInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código de 6 dígitos'**
  String get verifyEmailFormInvalid;

  /// No description provided for @verifyEmailCodeSemantics.
  ///
  /// In es, this message translates to:
  /// **'Código de verificación, {filled} de 6 dígitos'**
  String verifyEmailCodeSemantics(int filled);

  /// No description provided for @verifyEmailResendQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿No recibiste el código? '**
  String get verifyEmailResendQuestion;

  /// No description provided for @verifyEmailResend.
  ///
  /// In es, this message translates to:
  /// **'Reenviar'**
  String get verifyEmailResend;

  /// No description provided for @verifyEmailResendIn.
  ///
  /// In es, this message translates to:
  /// **'Reenviar en {seconds}s'**
  String verifyEmailResendIn(int seconds);

  /// No description provided for @verifyEmailResendSuccess.
  ///
  /// In es, this message translates to:
  /// **'Código reenviado — revisa tu correo'**
  String get verifyEmailResendSuccess;

  /// No description provided for @verifyEmailErrorInvalidCode.
  ///
  /// In es, this message translates to:
  /// **'El código es incorrecto o ya expiró — pide uno nuevo.'**
  String get verifyEmailErrorInvalidCode;

  /// No description provided for @registerStepDataLabel.
  ///
  /// In es, this message translates to:
  /// **'Datos'**
  String get registerStepDataLabel;

  /// No description provided for @registerStepAccountLabel.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get registerStepAccountLabel;

  /// No description provided for @registerStepReviewLabel.
  ///
  /// In es, this message translates to:
  /// **'Revisión'**
  String get registerStepReviewLabel;

  /// No description provided for @registerStep1Title.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanos quién eres'**
  String get registerStep1Title;

  /// No description provided for @registerStep1Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Empecemos por tus datos personales.'**
  String get registerStep1Subtitle;

  /// No description provided for @registerStep2Title.
  ///
  /// In es, this message translates to:
  /// **'Tu correo y tu llave'**
  String get registerStep2Title;

  /// No description provided for @registerStep2Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Con estos datos entrarás a tu cuenta.'**
  String get registerStep2Subtitle;

  /// No description provided for @registerStep3Title.
  ///
  /// In es, this message translates to:
  /// **'Todo listo, {name}'**
  String registerStep3Title(String name);

  /// No description provided for @registerStep3Subtitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa que todo esté bien.'**
  String get registerStep3Subtitle;

  /// No description provided for @registerStepProgress.
  ///
  /// In es, this message translates to:
  /// **'Paso {current} de {total}'**
  String registerStepProgress(int current, int total);

  /// No description provided for @registerStepItemLabel.
  ///
  /// In es, this message translates to:
  /// **'Paso {number}: {label}, {status}'**
  String registerStepItemLabel(int number, String label, String status);

  /// No description provided for @registerStepStatusCompleted.
  ///
  /// In es, this message translates to:
  /// **'completado'**
  String get registerStepStatusCompleted;

  /// No description provided for @registerStepStatusCurrent.
  ///
  /// In es, this message translates to:
  /// **'actual'**
  String get registerStepStatusCurrent;

  /// No description provided for @registerStepStatusPending.
  ///
  /// In es, this message translates to:
  /// **'pendiente'**
  String get registerStepStatusPending;

  /// No description provided for @registerContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get registerContinue;

  /// No description provided for @registerBackStep.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get registerBackStep;

  /// No description provided for @registerReviewName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get registerReviewName;

  /// No description provided for @registerReviewEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get registerReviewEmail;

  /// No description provided for @registerReviewPhone.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get registerReviewPhone;

  /// No description provided for @registerReviewNoPhone.
  ///
  /// In es, this message translates to:
  /// **'Sin teléfono'**
  String get registerReviewNoPhone;

  /// No description provided for @registerFirstNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Primer nombre *'**
  String get registerFirstNameLabel;

  /// No description provided for @registerFirstNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Ana'**
  String get registerFirstNameHint;

  /// No description provided for @registerSecondNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Segundo nombre (opcional)'**
  String get registerSecondNameLabel;

  /// No description provided for @registerLastNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Primer apellido *'**
  String get registerLastNameLabel;

  /// No description provided for @registerLastNameHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: Pérez'**
  String get registerLastNameHint;

  /// No description provided for @registerSecondLastNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Segundo apellido (opcional)'**
  String get registerSecondLastNameLabel;

  /// No description provided for @registerEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico *'**
  String get registerEmailLabel;

  /// No description provided for @registerPhoneLabel.
  ///
  /// In es, this message translates to:
  /// **'Teléfono (opcional)'**
  String get registerPhoneLabel;

  /// No description provided for @registerPhoneHint.
  ///
  /// In es, this message translates to:
  /// **'Ej: 300 123 4567'**
  String get registerPhoneHint;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña *'**
  String get registerPasswordLabel;

  /// No description provided for @registerPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get registerPasswordHint;

  /// No description provided for @registerConfirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña *'**
  String get registerConfirmPasswordLabel;

  /// No description provided for @registerConfirmPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Repite tu contraseña'**
  String get registerConfirmPasswordHint;

  /// No description provided for @registerNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu nombre'**
  String get registerNameRequired;

  /// No description provided for @registerNameInvalid.
  ///
  /// In es, this message translates to:
  /// **'Nombre incorrecto'**
  String get registerNameInvalid;

  /// No description provided for @registerLastNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu apellido'**
  String get registerLastNameRequired;

  /// No description provided for @registerLastNameInvalid.
  ///
  /// In es, this message translates to:
  /// **'Apellido incorrecto'**
  String get registerLastNameInvalid;

  /// No description provided for @registerPhoneInvalid.
  ///
  /// In es, this message translates to:
  /// **'Teléfono incorrecto'**
  String get registerPhoneInvalid;

  /// No description provided for @registerEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Correo incorrecto'**
  String get registerEmailInvalid;

  /// No description provided for @registerPasswordRequired.
  ///
  /// In es, this message translates to:
  /// **'Ingresa una contraseña'**
  String get registerPasswordRequired;

  /// No description provided for @registerPasswordInvalid.
  ///
  /// In es, this message translates to:
  /// **'Contraseña incorrecta'**
  String get registerPasswordInvalid;

  /// No description provided for @registerConfirmRequired.
  ///
  /// In es, this message translates to:
  /// **'Confirma tu contraseña'**
  String get registerConfirmRequired;

  /// No description provided for @registerConfirmMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden'**
  String get registerConfirmMismatch;

  /// No description provided for @registerButton.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get registerButton;

  /// No description provided for @registerHasAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta? '**
  String get registerHasAccount;

  /// No description provided for @registerLoginLink.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get registerLoginLink;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
