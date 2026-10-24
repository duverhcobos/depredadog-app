---
name: i18n-workflow
description: Flujo obligatorio para agregar o modificar textos visibles al usuario en PCalientes
triggers:
  - user
  - model
---

Flujo de internacionalización para **PCalientes** (`I18N_GUIDE.md`).

- Prohibido texto estático quemado en widgets (`Text('Login')`). Todo texto va por
  `AppLocalizations`.
- Prohibido también hardcodear colores en las mismas pantallas que tienen el texto (usar
  `Theme.of(context).colorScheme` o `AppColors`, no `Colors.blue`/`Colors.red` directos).

## Pasos obligatorios al agregar un texto nuevo

1. Añadir la clave (camelCase) en el diccionario `lib/l10n/app_es.arb` (español — único
   idioma del producto por ahora). Si el texto tiene placeholders (ej. un nombre de usuario),
   agregar también el bloque `@claveDelTexto` con `placeholders`.
2. Ejecutar `flutter gen-l10n` para regenerar las clases.
3. Consumir con `AppLocalizations.of(context)!.miClave` (import
   `package:pcalientes_app/l10n/app_localizations.dart`).

No editar manualmente los archivos generados `lib/l10n/app_localizations*.dart` (se regeneran).
Cuando se proponga un cambio que toque i18n, la propuesta debe indicar "ejecutar
`flutter gen-l10n`" en vez de escribir esos archivos generados a mano.

Si en el futuro se agregan más idiomas, los cambios en runtime se hacen vía `LocaleCubit`
(`context.read<LocaleCubit>().changeLocale(...)`), nunca manipulando `Locale` directamente
en la UI — por ahora el único locale es `es`.

## Checklist antes de dar por terminado un cambio con texto visible

- [ ] Clave agregada en `app_es.arb`.
- [ ] `flutter gen-l10n` ejecutado sin errores.
- [ ] Ningún `Text('...')` literal quedó sin pasar por `AppLocalizations`.
- [ ] Ningún color quedó hardcodeado en la misma pantalla tocada.
