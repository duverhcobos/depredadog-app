# Contexto y Rol
Actúa como un **Arquitecto de Software Senior y Tech Lead** especializado en Flutter y Dart. Tu objetivo es diseñar e implementar la estructura de directorios y el código base para una nueva funcionalidad (feature) de la aplicación. 

Toda tu propuesta debe basarse estrictamente en tres pilares fundamentales:

1. **Clean Architecture (Robert C. Martin):** Separación rigurosa de responsabilidades en capas (`Domain`, `Data`, `Presentation`).
2. **Principios S.O.L.I.D.:** Diseño modular, alta cohesión y bajo acoplamiento, garantizando que el código sea escalable, mantenible y altamente testeable.
3. **Clean Code:** Código legible, auto-documentado, funciones pequeñas de única responsabilidad, sin variables "mágicas", uso intensivo de `const` y tipado estricto (cero uso de `dynamic`).

---

# Descripción de la Funcionalidad a Implementar
**Desarrollar la pantalla (vista) de Login de la aplicación.** 
Esta funcionalidad debe incluir:
* Un formulario con campos para el clásico ingreso de `Email` y `Contraseña` (con validación de formato de correo y longitud de contraseña).
* Botón de *"Iniciar Sesión"*.
* Botón o acceso para *"Iniciar sesión con Google"*.
* Un enlace o botón ligero para *"¿Olvidaste tu contraseña?"*.
* Indicadores visuales de carga (Loading spinners) cuando se está procesando el login.
* Manejo de errores visuales atractivos (por ejemplo una *SnackBar* o diálogo) en caso de fallo (credenciales incorrectas, fallo de red, etc.).
* Y una vez que la autenticación sea exitosa, deberá persistir el token o la sesión y disparar la navegación hacia el Home de la app.

---

# Requisitos Arquitectónicos y Técnicos Estrictos (Nivel Enterprise)

Se debe estructurar bajo un enfoque **Feature-First**. Todo debe residir dentro de `lib/features/[nombre_feature]/`.

## 1. Capa de DOMINIO (Domain Layer - El Núcleo)
Es el corazón de la lógica de negocio. **Prohibido importar Flutter o librerías externas que no sean puras de Dart (ej. `dartz`, `equatable`), ni siquiera librerías de UI.**
*   **Entities:** Clases Dart puras que representen los modelos de negocio. Se recomienda usar `equatable` para la comparación por valor.
*   **Value Objects (Objetos de Valor):** Toda validación de entrada de usuario (Ej: formato de Email, longitud de contraseña) debe estar fuertemente tipada y encapsulada mediante Modelado de Dominio (se recomienda usar librerías como `formz`). La UI jamás debe contener Expresiones Regulares ni cálculos matemáticos de validez.
*   **Repositories (Interfaces):** Clases abstractas que definan los contratos. Aplica estricto **DIP** (Dependency Inversion Principle).
*   **Use Cases:** Un caso de uso por cada acción específica. Aplica estricto **SRP** (Single Responsibility Principle).

## 2. Capa de DATOS (Data Layer - Implementación e Infraestructura)
Responsable de coordinar APIs, Caché y Bases de Datos locales. Las clases aquí solo "saben" de infraestructuras y externalidades, no de UI.
*   **Models:** Clases que extiendan o implementen las Entities de Domain. Exclusivas para lógica de serialización (`fromJson`, `toJson`).
*   **DataSources (Interfaces e Implementaciones):** Separar contratos de implementaciones de orígenes de datos.
*   **Repository Implementation:** Orquesta los DataSources. **Punto crítico:** Debe inyectar y verificar validadores de conectividad (`NetworkInfo`) antes de ejecutar lógicas remotas y capturar las `Exceptions` para mapearlas a `Failures` (errores controlados).

## 3. Capa de PRESENTACIÓN (Presentation Layer - UI Reactiva Pura)
Responsable única de la interfaz de usuario. Al implementar Value Objects, la UI se convierte en una "Vista Tonta" (Dumb View).
*   **Segregación de Estado (SRP e ISP):** No mezclar el estado global de la aplicación (Ej: estatus general de Sesión) con el estado efímero del usuario tecleando en una pantalla. Se deben instanciar Blocs/Cubits de Presentación Locales puramente para manejar el formulario en curso.
*   **Formularios Stateless:** Cero tolerancia al uso de `GlobalKey<FormState>` y manipulación imperativa de `TextEditingController` para validación. La UI usará constructores `const` y reaccionará ("Redibujará" botones, labels de error) escuchando de forma inmutable los estados emitidos por el Cubit local bajo demanda (por cadencia `onChanged`).
*   **Efectos Secundarios (Side Effects):** Toda acción como un *SnackBar*, diálogos o navegación *push* debe ocurrir escuchando pasivamente (`BlocListener`), sin mezclar UI condicional.

## 4. Enrutamiento Inteligente (Routing S.O.L.I.D.)
*   **Guards Aislados (SRP):** La clase principal de ruteo (Ej: `AppRouter` / GoRouter) se limita a declarar pantallas y transiciones animadas. Toda lógica algorítmica y de seguridad/redirecciones para proteger rutas se delega obligatoriamente a una entidad aislada externa (Ej: `AuthGuard`).
*   **Escalabilidad (OCP):** Las reglas de los "Guards" jamás deben depender de validaciones encadenadas (`if/else` directos a la ruta). Deben implementar listas abiertas (Ej: Array dinámico `publicRoutes`) evaluadas por pertenencia (`contains`).

## 5. Reglas Estrictas y Clean Code
1.  **Tipado fuerte y Null Safety:** Cero tolerancia al uso de `dynamic`. Usar tipos nulos solo de manera deliberada.
2.  **Manejo Funcional de Errores:** Usa estructuras como `Either<Failure, SuccessType>` desde el caso de uso hasta la UI.
3.  **Inyección de Dependencias Estratégica:** Separar estrictamente el ciclo de vida de los controladores injectados (`GetIt` u otro): Instanciar como `LazySingleton` aquello que gobierne memoria persistente, y usar `Factory` para los Cubits Locales (ViewModels de pantalla temporal), garantizando su destrucción inherente al abandonar la vista.

---

# Formato de Respuesta
1.  **Análisis Arquitectónico Inicial:** Genera un análisis rápido de la funcionalidad propuesta.
2.  **Estructura del Proyecto:** Muestra en formato árbol (`tree`) la jerarquía de carpetas resultante.
3.  **Implementación del Código:** Genera **TODO el código completo** ordenado por archivos individuales.
    *   Indica sobre cada bloque de código su ruta jerárquica exacta (`lib/features/...`).
    *   No dejes métodos en blanco o a medias (`// TODO`); completa la lógica esencial para que compile y funcione bajo una base sólida.
    *   **CRÍTICO - Explicación S.O.L.I.D. en código:** Añade comentarios explícitos en el código generado (ej. `// SOLID (SRP): Esta clase solo tiene una razón para cambiar...`) explicando brevemente cómo y por qué se aplica un principio SOLID en esas clases, interfaces o métodos específicos. Esto es obligatorio para mi aprendizaje.