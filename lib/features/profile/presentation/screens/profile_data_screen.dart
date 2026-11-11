import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/profile_cubit.dart';

/// Sanitización de nombres — MISMA regla del registro (propuesta 009):
/// solo letras latinas (con tilde/ñ/ü), espacio y apóstrofe (recto y
/// tipográfico). Privada del archivo como la de register_step1_fields.
final _nameCharsOnly = FilteringTextInputFormatter.allow(
  RegExp(r"[A-Za-záéíóúÁÉÍÓÚñÑüÜ'’ ]"),
);

/// Celular colombiano — MISMA regla del registro/checkout: 10 dígitos
/// iniciando en 3 (3XX XXX XXXX). El campo filtra a solo dígitos, así
/// que la regla ve números planos; vacío = válido (opcional).
final _colombianMobile = RegExp(r'^3\d{9}$');

/// "Mis datos" (§030.1 — /profile/data, hija de la rama profile):
/// form pre-llenado del usuario mock — firstName*, secondName,
/// firstLastName*, secondLastName, phone + email visible pero
/// READ-ONLY (identidad de la cuenta; el endpoint futuro tampoco lo
/// cambiaría sin re-verificación — decisión de fase).
///
/// Estado LOCAL (controllers + flag de errores — sin cubit propio,
/// patrón del address form): guardar hace
/// `ProfileCubit.updateUser(user)` sobre el singleton que queda debajo
/// + toast + pop. En integración: PATCH /auth/me (pendiente backend).
class ProfileDataScreen extends StatefulWidget {
  const ProfileDataScreen({super.key});

  @override
  State<ProfileDataScreen> createState() => _ProfileDataScreenState();
}

class _ProfileDataScreenState extends State<ProfileDataScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _secondName;
  late final TextEditingController _firstLastName;
  late final TextEditingController _secondLastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final FocusNode _firstNameFocus = FocusNode();
  late final FocusNode _secondNameFocus = FocusNode();
  late final FocusNode _firstLastNameFocus = FocusNode();
  late final FocusNode _secondLastNameFocus = FocusNode();
  late final FocusNode _phoneFocus = FocusNode();
  late final FocusNode _emailFocus = FocusNode();
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    // Prefill del usuario mock — el cubit de la madre es el mismo
    // singleton (BlocProvider.value de la ruta).
    final user = context.read<ProfileCubit>().state.user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _secondName = TextEditingController(text: user?.secondName ?? '');
    _firstLastName = TextEditingController(text: user?.firstLastName ?? '');
    _secondLastName = TextEditingController(text: user?.secondLastName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _secondName.dispose();
    _firstLastName.dispose();
    _secondLastName.dispose();
    _phone.dispose();
    _email.dispose();
    _firstNameFocus.dispose();
    _secondNameFocus.dispose();
    _firstLastNameFocus.dispose();
    _secondLastNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  /// Valida inline (nombre y primer apellido requeridos; teléfono con
  /// regla de celular colombiano si se diligencia) y escribe sobre el
  /// ProfileCubit — la entidad User no tiene copyWith: se reconstruye
  /// conservando id/email/role/status (el email NO viaja al form, es
  /// read-only de la cuenta).
  void _save() {
    final firstName = _firstName.text.trim();
    final firstLastName = _firstLastName.text.trim();
    final phone = _phone.text.trim();
    final firstNameEmpty = firstName.isEmpty;
    final lastNameEmpty = firstLastName.isEmpty;
    final phoneInvalid = phone.isNotEmpty && !_colombianMobile.hasMatch(phone);
    if (firstNameEmpty || lastNameEmpty || phoneInvalid) {
      setState(() => _showErrors = true);
      // Foco al primer inválido — mismo patrón de login/checkout.
      (firstNameEmpty
              ? _firstNameFocus
              : lastNameEmpty
              ? _firstLastNameFocus
              : _phoneFocus)
          .requestFocus();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ProfileCubit>();
    final current = cubit.state.user;
    if (current == null) {
      // Defensivo — fase 1 siempre tiene el mock; sin usuario no hay
      // nada que fusionar y el form no debió abrirse.
      context.pop();
      return;
    }
    final secondName = _secondName.text.trim();
    final secondLastName = _secondLastName.text.trim();
    cubit.updateUser(
      User(
        id: current.id,
        email: current.email,
        firstName: firstName,
        secondName: secondName.isEmpty ? null : secondName,
        firstLastName: firstLastName,
        secondLastName: secondLastName.isEmpty ? null : secondLastName,
        phone: phone.isEmpty ? null : phone,
        role: current.role,
        status: current.status,
      ),
    );
    AppToast.success(context, l10n.profileDataSavedToast);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    const _DataTitle(),
                    // Card straddle de la familia — misma cuna que el
                    // form de dirección.
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: LayoutBuilder(
                        builder: (context, c) => Padding(
                          padding: EdgeInsets.only(
                            left:
                                c.maxWidth *
                                kSignatureStripFraction *
                                kCardStripInset,
                            right: blackZoneMargin(c.maxWidth),
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            color: colors.surfaceContainerLow,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomTextField(
                                    label: l10n.registerFirstNameLabel,
                                    controller: _firstName,
                                    focusNode: _firstNameFocus,
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    keyboardType: TextInputType.name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [_nameCharsOnly],
                                    errorText:
                                        _showErrors &&
                                            _firstName.text.trim().isEmpty
                                        ? l10n.registerNameRequired
                                        : null,
                                    // Rebuild al teclear: el error se
                                    // limpia en vivo (patrón del form).
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  CustomTextField(
                                    label: l10n.registerSecondNameLabel,
                                    controller: _secondName,
                                    focusNode: _secondNameFocus,
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    keyboardType: TextInputType.name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [_nameCharsOnly],
                                    onChanged: (_) {},
                                  ),
                                  CustomTextField(
                                    label: l10n.registerLastNameLabel,
                                    controller: _firstLastName,
                                    focusNode: _firstLastNameFocus,
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    keyboardType: TextInputType.name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [_nameCharsOnly],
                                    errorText:
                                        _showErrors &&
                                            _firstLastName.text.trim().isEmpty
                                        ? l10n.registerLastNameRequired
                                        : null,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  CustomTextField(
                                    label: l10n.registerSecondLastNameLabel,
                                    controller: _secondLastName,
                                    focusNode: _secondLastNameFocus,
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    keyboardType: TextInputType.name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [_nameCharsOnly],
                                    onChanged: (_) {},
                                  ),
                                  CustomTextField(
                                    label: l10n.registerPhoneLabel,
                                    controller: _phone,
                                    focusNode: _phoneFocus,
                                    hintText: l10n.registerPhoneHint,
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                    ),
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    errorText:
                                        _showErrors &&
                                            _phone.text.trim().isNotEmpty &&
                                            !_colombianMobile.hasMatch(
                                              _phone.text.trim(),
                                            )
                                        ? l10n.profileDataPhoneInvalid
                                        : null,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  // Email: visible pero NO editable —
                                  // la identidad de la cuenta no se
                                  // cambia sin re-verificación (decisión
                                  // de fase); el helper explica el
                                  // bloqueo en su línea reservada.
                                  CustomTextField(
                                    label: l10n.profileDataEmailLabel,
                                    controller: _email,
                                    focusNode: _emailFocus,
                                    enabled: false,
                                    prefixIcon: const Icon(Icons.mail_outline),
                                    helperText: l10n.profileDataEmailHelper,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Footer fijo del CTA primario — misma convención de
              // cart/checkout/address form (fondo opaco + SafeArea).
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        child: Text(l10n.addressFormSave),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 4,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colors.onPrimary),
              tooltip: l10n.catalogBackTooltip,
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Título "Mis datos" naciendo de la franja — patrón scrolling_title
/// (PRIMER hijo del ListView).
class _DataTitle extends StatelessWidget {
  const _DataTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.602,
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.profileDataTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
