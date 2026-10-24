# Guía de Entornos y Configuración Dinámica (Flavors)

¡Bienvenido al proyecto! Este aplicativo ha sido orquestado bajo los rigurosos estándares de **Clean Architecture y los Principios S.O.L.I.D.** 

Por razones de seguridad y abstracción, **NUNCA guardamos URLs de APIs, contraseñas, o Tokens quemados (hardcoded) explícitamente en el código de nuestros Repositorios.** Todo se inyecta dinámicamente en tiempo de compilación.

---

## 1. El Emisor: `environment.dart`
Toda la recepción de variables se centraliza en un único archivo:
`lib/core/constants/environment/environment.dart`

Si necesitas que la app aprenda una nueva variable secreta (Ej: Llave de Google Maps), debes abrir ese archivo y agregarla utilizando estrictamente `String.fromEnvironment`. 

El código fuente de toda la aplicación consume las constantes generadas en esa clase. Ningún archivo está autorizado a adivinar manualmente la configuración del entorno.

---

## 2. Cómo compilar y ejecutar (Vía Terminal)
Si estás operando o diagnosticando la aplicación desde la terminal, jamás ejecutes un simple `flutter run`. Dependiendo hacia qué base de datos quieras apuntar, debes inyectar el entorno explícitamente:

- **Desarrollo (backend NestJS local):**
  `flutter run --dart-define=ENV=dev`
  - Emulador Android: sin más — `API_BASE_URL` default `http://10.0.2.2:3000` apunta al localhost del host (`pcalientes_backend` corre en `:3000`).
  - Dispositivo físico: `--dart-define=API_BASE_URL=http://<ip-lan-del-pc>:3000` (el backend NestJS debe ser accesible en la LAN — `app.listen` ya bindea a `0.0.0.0`; revisar firewall de Windows).

- **Pruebas y QA (Staging):**
  `flutter run --dart-define=ENV=stg --dart-define=API_TOKEN=<tu-token-stg>`

- **Generar Instalador Final Absoluto (Producción):**
  `flutter build appbundle --dart-define=ENV=prod --dart-define=API_TOKEN=<tu-token-prod>`

**Por qué se hace así (y no con `.env` ni valores en archivos del repo):**

1. El token real **nunca toca un archivo versionado** → es imposible commitearlo por accidente.
2. No se usa `.env` porque viaja como texto plano dentro del APK/IPA y además es el archivo que más se filtra a git por descuido (este repo lo ignora preventivamente en `.gitignore`).
3. Renovar un token = cambiar el valor en el comando o en el vault de CI; ningún archivo versionado cambia, así que `git status` jamás muestra un secreto en diff.
4. El mismo patrón escala a CI/CD sin cambios: el pipeline inyecta los valores desde su vault de secretos directo en el comando `flutter build` — ningún archivo intermedio.

---

## 3. Beneficios Arquitectónicos de esta decisión
1. **Open/Closed Principle (OCP):** Puedes crear 20 entornos nuevos u 80 variables secretas extra en tu máquina, y la lógica de enrutamiento o repositorios jamás sufrirá alteraciones. La inyección es agnóstica a la arquitectura.
2. **Seguridad mejorada (con límites conocidos):** a diferencia de archivos texto plano `.env`, los valores `--dart-define` viajan compilados dentro del binario. ⚠️ Ojo: igualmente son **extraíbles del APK/IPA** con herramientas de ingeniería inversa — son más difíciles de leer que un `.env`, no imposibles. Por eso `API_TOKEN` solo debe usarse para keys **no sensibles** (IDs de cliente, keys públicas acotadas); ningún secreto real puede vivir en el cliente, y la autorización fuerte siempre la da el JWT por usuario desde el secure storage.
