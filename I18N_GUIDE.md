# Guía de Internacionalización Nativa (i18n)

¡Bienvenido! Nuestra aplicación implementa el sistema de Traducción Nativo de Flutter (`flutter_localizations`) que es 100% compatible con los estándares de **Arquitectura Limpia y S.O.L.I.D**. 

Nunca almacenes texto estático ni en español ni en inglés en los Widgets (`Text('Login')`). Todo el texto de la app debe inyectarse puramente en tiempo de renderizado basándose en diccionarios externos.

---

## 1. Archivos Clave del Motor

1. **`l10n.yaml` (Raíz)**: Le indica al Motor Generador de Dart de dónde leer los diccionarios y dónde depositar las clases auto-generadas.
2. **`lib/l10n/`**: La fortaleza de idiomas. Cada archivo con terminación `.arb` (Application Resource Bundle) equivale a un idioma nativo. Hoy el producto tiene **un solo idioma: español** (`app_es.arb`); cada idioma futuro será un `.arb` nuevo en la misma carpeta.
3. **`LocaleCubit` (Core, cuando haya más de un idioma)**: Nuestro State Management de Responsabilidad Única (`SRP`) alojado en `setup_di.dart`, encargado de mantener el idioma "forzado" si el usuario elige manualmente cambiarlo.

---

## 2. Flujo de Trabajo: ¿Cómo agrego un  texto nuevo?

Si estás construyendo una pantalla nueva (ej: *"Mi Perfil"*) y necesitas un botón de *"Cerrar Sesión"*, sigue estos tres estrictos pasos:

### Paso 1: Edita el Diccionario (.arb)
Abre `lib/l10n/app_es.arb` y añade la variable respetando el modelo JSON (`camelCase`):

```json
"logoutButton": "Cerrar Sesión"
```

*(La app hoy tiene un solo idioma — español. Si en el futuro se agregan `app_en.arb`, `app_pt.arb` u otros, la misma clave se añade en TODOS los diccionarios.)*

### Paso 2: El Comando Mágico
Flutter no sabrá mágicamente que modificaste esos JSON. Tienes que ordenarle que construya los Traductores Nativos en Lenguaje Dart.
Cada vez que toques un archivo `.arb`, tu deber es correr en terminal:

```bash
flutter gen-l10n
```
*(Tip: Puedes usar la consola del VS Code o tu terminal preferida)*

### Paso 3: Consúmelo en el Widget Reactivamente
Ve a tu Widget donde pretendes usar tu nuevo botón.
Añade la clase generada en tus importaciones en la parte superior del archivo:
```dart
import 'package:pcalientes_app/l10n/app_localizations.dart';
```

Extrae el texto dinámico dentro del método `build`:
```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context); // <--- El Motor entra en Acción

  return ElevatedButton(
    onPressed: () {},
    child: Text(l10n.logoutButton), // <--- Adiós quemado manual, bienvenido Polimorfismo
  );
}
```

---

## 3. ¿Varios idiomas?

Hoy la app es **mono-idioma (español)**: el `MaterialApp` solo registra `Locale('es')` y no hay selector de idioma.

Si el producto agrega idiomas en el futuro, el cambio en runtime se centraliza en la clase `LocaleCubit`:

```dart
context.read<LocaleCubit>().changeLocale(const Locale('en'));
```

El Cubit avisará al gestor raíz y re-construirá sin parpadeos cada `AppLocalizations` de cada pantalla existente.
