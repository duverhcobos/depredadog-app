import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../../home/presentation/widgets/signature_strip.dart';

/// Mínimo de la contraseña nueva — la MISMA regla del registro
/// (`RegisterPasswordInput.minLength` / backend `RegisterDto`:
/// @MinLength(8) @MaxLength(72)).
const _kPasswordMinLength = 8;

/// "Cambiar contraseña" (§030.1 — /profile/password, hija de la rama
/// profile): 3 campos obscure — actual, nueva (min 8, regla del
/// registro) y confirmar (debe coincidir) — con toggles de visibilidad
/// y validación inline.
///
/// Estado LOCAL (controllers + flags — sin cubit propio, patrón del
/// address form). Guardar es MOCK de fase 1: toast + pop — el endpoint
/// `POST /auth/change-password` {currentPassword, newPassword} es
/// pendiente del backend (pendientes/013).
class ProfilePasswordScreen extends StatefulWidget {
  const ProfilePasswordScreen({super.key});

  @override
  State<ProfilePasswordScreen> createState() => _ProfilePasswordScreenState();
}

class _ProfilePasswordScreenState extends State<ProfilePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _currentFocus = FocusNode();
  final _nextFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;
  bool _showErrors = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _currentFocus.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// Toggle de visibilidad — mismo patrón del login/registro (ojo +
  /// tooltip l10n según el estado actual).
  Widget _visibilityToggle({
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: obscure ? l10n.loginShowPassword : l10n.loginHidePassword,
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
      onPressed: onToggle,
    );
  }

  /// Errores inline por campo (solo tras el primer "Guardar" fallido;
  /// se limpian en vivo al teclear vía onChanged → setState).
  String? _currentError(AppLocalizations l10n) =>
      _showErrors && _current.text.isEmpty
      ? l10n.profilePasswordCurrentRequired
      : null;

  String? _nextError(AppLocalizations l10n) {
    if (!_showErrors) return null;
    if (_next.text.isEmpty) return l10n.registerPasswordRequired;
    if (_next.text.length < _kPasswordMinLength) {
      return l10n.registerPasswordInvalid;
    }
    return null;
  }

  String? _confirmError(AppLocalizations l10n) {
    if (!_showErrors) return null;
    if (_confirm.text.isEmpty) return l10n.registerConfirmRequired;
    if (_confirm.text != _next.text) return l10n.registerConfirmMismatch;
    return null;
  }

  /// Mock de fase 1: valida y cierra con toast — el POST real
  /// ({currentPassword, newPassword} → 204 / 400 si la actual no es)
  /// llega en el ciclo de integración (pendiente backend 013).
  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final currentEmpty = _current.text.isEmpty;
    final nextInvalid =
        _next.text.isEmpty || _next.text.length < _kPasswordMinLength;
    final confirmInvalid = _confirm.text.isEmpty || _confirm.text != _next.text;
    if (currentEmpty || nextInvalid || confirmInvalid) {
      setState(() => _showErrors = true);
      // Foco al primer inválido — mismo patrón de login/checkout.
      (currentEmpty
              ? _currentFocus
              : nextInvalid
              ? _nextFocus
              : _confirmFocus)
          .requestFocus();
      return;
    }
    AppToast.success(context, l10n.profilePasswordSavedToast);
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
                    const _PasswordTitle(),
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
                                    label: l10n.profilePasswordCurrentLabel,
                                    controller: _current,
                                    focusNode: _currentFocus,
                                    hintText: l10n.profilePasswordCurrentHint,
                                    obscureText: _obscureCurrent,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: _visibilityToggle(
                                      obscure: _obscureCurrent,
                                      onToggle: () => setState(
                                        () =>
                                            _obscureCurrent = !_obscureCurrent,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    errorText: _currentError(l10n),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  CustomTextField(
                                    label: l10n.forgotNewPasswordLabel,
                                    controller: _next,
                                    focusNode: _nextFocus,
                                    hintText: l10n.registerPasswordHint,
                                    obscureText: _obscureNext,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: _visibilityToggle(
                                      obscure: _obscureNext,
                                      onToggle: () => setState(
                                        () => _obscureNext = !_obscureNext,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    errorText: _nextError(l10n),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  CustomTextField(
                                    label: l10n.registerConfirmPasswordLabel,
                                    controller: _confirm,
                                    focusNode: _confirmFocus,
                                    hintText: l10n.registerConfirmPasswordHint,
                                    obscureText: _obscureConfirm,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: _visibilityToggle(
                                      obscure: _obscureConfirm,
                                      onToggle: () => setState(
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    errorText: _confirmError(l10n),
                                    onChanged: (_) => setState(() {}),
                                    onFieldSubmitted: (_) => _save(),
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
                        child: Text(l10n.forgotSubmit),
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

/// Título "Cambiar contraseña" naciendo de la franja — patrón
/// scrolling_title (PRIMER hijo del ListView).
class _PasswordTitle extends StatelessWidget {
  const _PasswordTitle();

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
              l10n.profilePasswordTitle,
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
