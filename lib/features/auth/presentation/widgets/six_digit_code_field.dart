import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const int _kCodeLength = 6;
const double _kCellWidth = 48;
const double _kCellHeight = 56;
const double _kCellGap = 8;
// Ancho mínimo útil por casilla — debajo de esto el dígito titleLarge
// ya no respira (viewport < 376dp causa overflow si no se escala).
const double _kMinCellWidth = 36;

/// Campo OTP de 6 casillas (extraído de `VerifyEmailFormFields` en la
/// propuesta 011 para compartirlo con /forgot-password). Casillas
/// separadas implementadas a mano: un TextField invisible cubre la fila y
/// captura el teclado; las casillas son puro render. `pinput` se descartó
/// porque v7 exige un ancestro `Material` del paquete material_ui
/// (Material desacoplado), incompatible con el Scaffold clásico del
/// proyecto (decisión del usuario).
///
/// Es agnóstico del cubit: el caller posee [controller]/[focusNode],
/// computa [hasError] desde su state y decide qué hacen [onChanged]/
/// [onSubmitted]. El rebuild interno cuelga de los propios listenables
/// (controller = dígitos, focusNode = casilla activa) — no hace falta un
/// BlocBuilder externo para repintar el texto.
class SixDigitCodeField extends StatelessWidget {
  const SixDigitCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
    required this.semanticsLabel,
    this.autofocus = false,
  });

  /// Controller del TextField oculto — su texto es lo que pintan las
  /// casillas. El caller lo sincroniza si el estado cambia por fuera del
  /// tipeo (ej. un reenvío que limpia el código).
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Pinta TODAS las casillas en rojo — lo decide el caller (validación
  /// local fallida o backend rechazando el código).
  final bool hasError;

  /// Cada cambio del texto (ya limitado a 6 dígitos por el formatter).
  final ValueChanged<String> onChanged;

  /// Acción "done" del teclado.
  final VoidCallback onSubmitted;

  /// Semántica del grupo para TalkBack ("código de verificación, X de 6")
  /// — función porque depende de cuántos dígitos van llenos.
  final String Function(int filled) semanticsLabel;

  /// verify-email entra con el teclado abierto (pantalla dedicada);
  /// /forgot-password lo pasa en false — el wizard nunca abre el teclado
  /// al cambiar de paso (decisión del usuario, propuesta 011).
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // El borde "activo" de la casilla depende del foco y los dígitos del
    // controller — ambos son ChangeNotifier: rebuild sin tocar el state
    // del cubit (hasError llega por rebuild del padre).
    return LayoutBuilder(
      builder: (context, constraints) {
        // Escala defensiva: en viewports angostos (<376dp) 6×48 + gaps
        // desbordan — la casilla se encoge hasta un piso de 36dp en
        // vez de partir la fila (revisor-ui MENOR).
        final fit =
            (constraints.maxWidth - _kCellGap * (_kCodeLength - 1)) /
            _kCodeLength;
        final cellWidth = fit < _kCellWidth
            ? fit.clamp(_kMinCellWidth, _kCellWidth)
            : _kCellWidth;
        return ListenableBuilder(
          listenable: Listenable.merge([controller, focusNode]),
          builder: (context, _) {
            final code = controller.text;
            final isFocused = focusNode.hasFocus;
            return SizedBox(
              height: _kCellHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Semántica para TalkBack: el grupo se anuncia como
                  // "código de X, N de 6" — las casillas solas no dicen
                  // nada. El texto lo decide el caller (verificación en
                  // verify-email, restablecimiento en forgot).
                  Semantics(
                    label: semanticsLabel(code.length),
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_kCodeLength, (i) {
                          final isActive =
                              isFocused &&
                              i == code.length.clamp(0, _kCodeLength - 1);
                          return Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 0 : _kCellGap,
                            ),
                            child: _PinCell(
                              digit: i < code.length ? code[i] : '',
                              isActive: isActive,
                              hasError: hasError,
                              theme: theme,
                              width: cellWidth,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    // TextField invisible: captura teclado/autofill; el
                    // texto transparente no se pinta — las casillas hacen
                    // el render.
                    // OJO: el inputDecorationTheme global trae filled+
                    // bordes por estado — hay que anularlos EXPLÍCITAMENTE
                    // o pinta una barra encima de las casillas
                    // (InputBorder.none solo en `border` no basta; bug
                    // encontrado por revisor-ui).
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: autofocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_kCodeLength),
                      ],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      showCursor: false,
                      // enableInteractiveSelection queda en true
                      // (default): el menú contextual permite PEGAR un
                      // código copiado — el formatter igual lo limita a
                      // 6 dígitos (revisor-ui).
                      style: const TextStyle(color: Colors.transparent),
                      decoration: const InputDecoration(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmitted(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Una casilla del código — puro render (estado vacío/activo/error).
class _PinCell extends StatelessWidget {
  const _PinCell({
    required this.digit,
    required this.isActive,
    required this.hasError,
    required this.theme,
    required this.width,
  });

  final String digit;
  final bool isActive;
  final bool hasError;
  final ThemeData theme;

  /// Ancho resuelto por el LayoutBuilder del padre (48dp estándar,
  /// encogido en viewports angostos).
  final double width;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? theme.colorScheme.error
        : isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: _kCellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        // 14 = radius del sistema (inputs/botones) — no 12 (revisor-ui).
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isActive || hasError ? 1.6 : 1.0,
        ),
      ),
      child: Text(
        digit,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
