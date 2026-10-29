---
name: emulator-health
description: Diagnóstico y recuperación del emulador lento/congelado (Pixel_8) — chequeo de RAM del host, procesos tragones (daemon Gradle), aceleración WHPX y cold boot sin snapshot. Usar cuando el usuario reporte "el emulador está lento", "no levanta la app" o adb no responda.
---

# Emulator Health — diagnóstico y recuperación del emulador

Máquina de referencia: Windows, **16 GB RAM total**, AVD único `Pixel_8`
(API 34, `hw.ramSize=2048` para el guest), qemu con aceleración **WHPX**
(ya verificada usable — no re-verificar salvo que cambie el hardware/Windows).

## Síntomas que disparan esta skill

- "El emulador está muy lento" / "no puedo levantar la app" / "se bugueó"
- `adb shell <cmd>` se cuelga sin responder
- El guest arranca pero nunca termina de responder
- **La pantalla muestra artefactos**: rectángulos blancos, UI escalada/duplicada
  ("wrap-around" de columnas), pantalla toda blanca/negra con `adb` respondiendo

## Diagnóstico (en este orden)

### 1. RAM libre del host — la causa #1 histórica

```powershell
Get-CimInstance Win32_OperatingSystem |
  Select-Object @{N='RAMLibre_GB';E={[math]::Round($_.FreePhysicalMemory/1MB,2)}}
```

- **< 1 GB libre → el host está paginando a disco** y el guest se ahoga.
  Este fue el caso real (0.4 GB libres → emulador congelado).
- Ver los 15 procesos más pesados para ubicar al culpable:

```powershell
Get-Process | Sort-Object WorkingSet64 -Descending |
  Select-Object -First 15 ProcessName,
    @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB)}}
```

### 2. Presupuesto de RAM de esta máquina (~16 GB)

| Proceso | RAM típica | ¿Se puede matar? |
|---------|-----------|------------------|
| `qemu-system-x86_64` | ~4 GB (guest 2 GB + overhead) | Solo para cold boot (paso 3) |
| `java` (Gradle daemon) | ~1.3–1.5 GB | **SÍ — culpable habitual.** Queda vivo ~3h tras cada `flutter build` |
| `dartaotruntime` (frontend_server) | ~800 MB | NO — pertenece al `flutter run` del usuario |
| `dart language-server` | ~350 MB | NO — análisis del IDE |
| `dart development-service` / `devtools` / `tooling-daemon` | ~200 MB | NO — sesión `flutter run` del usuario |
| `node` (nest watch + app) | ~450 MB | NO si el backend debe seguir corriendo |

### 3. Aceleración por hardware (verificar solo si la RAM está OK)

```bash
"C:/Users/Usuario/AppData/Local/Android/Sdk/emulator/emulator.exe" -accel-check
```

Debe decir `WHPX(...) is installed and usable`. Si dijera TCG/no usable,
el problema es de virtualización (revisar Hyper-V/WHPX en Windows Features)
y no de RAM.

### 4. ¿El guest responde?

```bash
"C:/Users/Usuario/AppData/Local/Android/Sdk/platform-tools/adb.exe" -s emulator-5554 shell getprop sys.boot_completed
```

- Devuelve `1` rápido → guest responde; puede ser problema de la app **o
  corrupción del compositor GL** (ver 2c) — capturar pantalla para decidir:
  `adb -s emulator-5554 exec-out screencap -p > emu.png` y leer la imagen.
- Se cuelga → guest degradado (normalmente post-paginación): cold boot (2b).

### 4b. Compositor GL corrupto (guest vivo, pantalla rota)

Síntomas ya vistos en esta máquina (GPU host **Intel UHD 730** vía
"Android Emulator OpenGL ES Translator" — punto de falla conocido en iGPUs
Intel):

- Rectángulo blanco cubriendo parte de la pantalla (ventana del teclado/IME
  pegada a media animación).
- Pantalla toda blanca con `adb` y procesos vivos (`ps -A` muestra la app,
  `dumpsys` confirma actividad resumed) → framebuffer muerto.
- UI "envuelta": fragmentos del borde derecho reaparecen en el izquierdo,
  contenido escalado ~2x → **stride/pitch del framebuffer inconsistente**.

Diagnóstico útil: `dumpsys window windows | grep InputMethod`,
`dumpsys activity activities | grep Resumed`,
`dumpsys SurfaceFlinger | grep GLES` (confirma qué backend GL usa).

**Escalera de recuperación (de más barata a más cara):**

1. `adb -s emulator-5554 reboot` — reinicia el Android dentro del mismo
   qemu (~40 s). Revive SurfaceFlinger; funcionó para la pantalla blanca.
2. `am force-stop com.depredadog.app` + relanzar — recrea la surface de la app.
3. `settings put system user_rotation 1` y volver a `0` — fuerza re-layout
   de todas las surfaces (no funcionó en el caso real, pero es barato).
4. **Cold boot con `-gpu swiftshader`** — si los artefactos reaparecen
   al abrir la app, el traductor Intel OpenGL→host está corrupto.
   SwiftShader renderiza GLES por CPU: más lento (primer frame y
   animaciones menos fluidas) pero elimina TODO el driver GL del host.
   Es el fix que resolvió el caso real:

```bash
# matar qemu (paso 2b) y relanzar:
emulator.exe -avd Pixel_8 -no-snapshot -gpu swiftshader -no-boot-anim
```

> **OJO — modos GPU válidos en este emulador (v37.x, backend gfxstream):**
> solo `host`, `swiftshader` y `swangle` (ANGLE sobre SwiftShader).
> **`angle_indirect` NO existe** — un modo inválido cae en fallback
> silencioso a `auto`→`host`→traductor Intel (el que falla). Pasó en el
> caso real: parecía "arreglado" pero era solo el cold boot, y el glitch
> volvió a los minutos. Verificar el backend activo con
> `dumpsys SurfaceFlinger | grep GLES` → debe decir
> `(Google SwiftShader)`, NO `(Intel(R) UHD Graphics ...)`.
>
> **Modo GPU persistente:** el `-gpu` de línea de comandos solo aplica a
> ese arranque. Para fijarlo en el AVD (incluye arranques desde Android
> Studio): `hw.gpu.mode = swiftshader` en
> `~/.android/avd/Pixel_8.avd/config.ini` — ya aplicado en esta máquina.
> Si se quiere volver a hardware: `hw.gpu.mode = host` (aceptando el
> riesgo del traductor Intel) o `swangle` (intermedio).

## Recuperación

### 2a. Liberar RAM del host

El daemon de Gradle es el candidato seguro (se recrea solo en el próximo
build). `gradlew --stop` necesita JAVA_HOME (no está en PATH — usar el JBR
de Android Studio):

```bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
cd "C:/Users/Usuario/Documents/DHC30/PCALIENTES/pcalientes_app/android"
./gradlew --stop   # → "1 Daemon stopped", libera ~1.5 GB
```

Alternativas si no alcanza: sugerir al usuario cerrar navegadores/apps
pesadas. **No matar** los procesos marcados NO en la tabla.

### 2b. Cold boot del emulador (guest congelado)

El `adb emu kill` suele colgar igual que `adb shell` en este estado —
matar el proceso directo:

```powershell
Get-Process qemu-system-x86_64, emulator -ErrorAction SilentlyContinue |
  Stop-Process -Force
```

Relanzar **sin snapshot** (`-no-snapshot`): el snapshot de quick-boot
guarda el estado degradado y lo restauraría.

```bash
"C:/Users/Usuario/AppData/Local/Android/Sdk/emulator/emulator.exe" -avd Pixel_8 -no-snapshot &
```

Esperar ~40 s y verificar:

```bash
adb devices                                    # debe listar emulator-5554
adb -s emulator-5554 shell getprop sys.boot_completed   # → 1
```

La app **sigue instalada** (userdata persiste; solo `-wipe-data` la borra):
`adb shell pm list packages | grep depredadog` y relanzar con monkey.

## Post-recuperación — avisar al usuario

- Si tenía un `flutter run` activo (frontend_server/DDS/DevTools), quedó
  **huérfano** al matar el emulador: que lo relance (`flutter run` o el
  botón de Run del IDE).
- Backend en `:3000` no se ve afectado.

## Prevención (máquina de 16 GB)

- Después de cada `flutter build` (APK/AAB), el daemon Gradle queda ~1.5 GB
  en RAM — `gradlew --stop` si no se va a compilar en un rato.
- Guest de 2 GB es justo para Android 14: mantener el host holgado
  (~2+ GB libres) es lo que más pesa en fluidez.
- No lanzar builds y el emulador simultáneamente si la RAM libre está < 2 GB.
