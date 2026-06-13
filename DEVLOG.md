# DEVLOG — Mi Presupuesto

Bitácora técnica del proyecto. Una entrada por sesión de trabajo.

---

## 2026-06-09 — Reconstrucción del proyecto: del disco roto al primer build en el dispositivo

**Tiempo invertido:** aproximadamente 8 horas
**Fase:** Setup de entorno y reconstrucción del proyecto

### Objetivo

Recuperar el proyecto Mi Presupuesto después de la pérdida total del disco duro. Reconstruir el entorno de desarrollo desde cero, restaurar los archivos preservados de sesiones anteriores, aplicar las correcciones que ya estaban identificadas, y dejar una base limpia desde donde seguir.

### Trabajo realizado

1. Recuperé el contexto arquitectónico desde el documento de resumen maestro y los 37 archivos que sobrevivieron en una sesión alterna del chat.

2. Cerré tres decisiones arquitectónicas que estaban pendientes:
   - Deprecar `financial_engine` y establecer `MasterFinancialBrain` como única fuente de análisis.
   - Implementar invalidación de caché mediante un contador de versión a nivel `DatabaseHelper`, en lugar de llamadas manuales a `invalidarCache()` desde cada pantalla. Es más robusto porque no se puede olvidar: el contador se incrementa dentro de la única capa por la que pasan todas las escrituras.
   - `ChatIAScreen` recibirá el `MasterFinancialResult` completo en lugar de únicamente el string `contextoIA`. Esto es más consistente con el resto de la aplicación y provee mejores datos para el eventual conjunto de entrenamiento.

3. Decidí mover la API key de Claude a un archivo `.env` excluido de git, antes de hacer el repositorio público.

4. Instalé el entorno de desarrollo desde cero: Git 2.54, Flutter SDK 3.44.1, Android Studio con Android SDK 36.1, aceptación de licencias. Visual Studio Build Tools 2026 ya estaba presente de una instalación previa.

5. Configuré la depuración USB en el Motorola Edge 60 Fusion (Android 15) y verifiqué que aparece como dispositivo conectado a través de `flutter devices`.

6. Ejecuté `flutter create mi_presupuesto`, corrí `flutter run` y compilé la aplicación de ejemplo en el dispositivo. El primer build tardó 26 minutos por la descarga de Gradle y las dependencias Android sobre una conexión lenta. El pipeline end-to-end quedó confirmado.

7. Inicialicé git en el proyecto y creé la estructura de carpetas: `lib/db`, `lib/models`, `lib/services`, `lib/screens`, `lib/widgets`, `lib/helpers`.

8. Reconstruí la capa de base de datos. `database_helper.dart` ahora incluye un contador estático `dataVersion` que se incrementa en cada operación de escritura. `MasterFinancialBrain` comparará este contador contra su versión cacheada para detectar cambios automáticamente.

9. Reconstruí la capa de models con 18 archivos en `lib/models/`. Se corrigieron seis bugs reales:
   - `flujo_mensual.dart`: restauré el método `toMap()`, que tenía un literal de mapa colgando sin la firma del método y no compilaba.
   - `flujo_mensual.dart`: agregué `.toDouble()` a dos llamadas `.clamp()` para evitar el error "num cannot be assigned to double".
   - `deuda.dart`: agregué `.toDouble()` a una llamada `.clamp()` por la misma razón.
   - `meta_ahorro.dart`: agregué `.toDouble()` a dos llamadas `.clamp()`.
   - `financial_analysis.dart`: agregué `.toInt()` a una llamada `.clamp()` (mismo patrón, caso entero).
   - `plan_pago.dart`: corregí el path de import de `../models/deuda.dart` a `deuda.dart`, porque ambos archivos ahora viven en la misma carpeta.

### Lo que funcionó

- Reconstruir el proyecto capa por capa (base de datos, luego models simples, luego models complejos) en lugar de intentar todo a la vez. Cada capa puede validarse independientemente y los errores no se propagan.
- El contador de versión en `DatabaseHelper` es claramente más robusto que llamadas manuales a `invalidarCache()` por pantalla. No se puede olvidar porque vive en la única capa por la que pasan todas las escrituras.
- Validar el pipeline con la aplicación de ejemplo de Flutter antes de introducir código real. Cualquier falla futura se podrá atribuir al código de la aplicación y no al entorno.

### Lo que falló y cómo se resolvió

- La descarga del componente Android Emulator se interrumpió por conexión inestable durante el setup del SDK. Resuelto con Retry; funcionó al segundo intento.
- Un comando `move` de PowerShell falló porque el directorio de trabajo había vuelto a la carpeta home del usuario, y el path relativo `lib\models\` se resolvió contra la base incorrecta. Resuelto usando paths absolutos para comandos cross-directorio.
- Las descargas directas desde el chat de Claude no completaban consistentemente al disco. Los archivos presentados aparecían como enlaces pero no siempre llegaban a la carpeta Downloads. Workaround: copiar contenido desde el chat y pegar en VS Code, o descargar como archivo ZIP, que resultó más confiable que archivos `.dart` individuales.
- El PATH de Flutter no se refrescaba en la terminal integrada de VS Code aun cerrando y reabriendo el editor, porque procesos en segundo plano mantenían el entorno previo. Resuelto terminando todos los procesos `Code.exe` desde el Administrador de Tareas antes de reabrir.

### Lecciones aprendidas

- El método `.clamp()` de Dart está definido en la clase `num`, no en `double` ni en `int`. Aunque se llame sobre un `double` con argumentos `double`, el tipo estático de retorno sigue siendo `num`. Asignar el resultado a un campo `double` o `int` requiere un cast explícito con `.toDouble()` o `.toInt()`. Este patrón aparece en varios lugares del código.
- El primer `flutter run` toma tiempo considerable porque Gradle y sus dependencias se descargan en el primer uso, pero los builds siguientes son cuestión de segundos.
- La invalidación de caché es una decisión arquitectónica, no un detalle de implementación. Centralizada en la capa de datos es robusta; distribuida en las pantallas es frágil.

### Métricas

- Archivos creados o modificados: 19 (uno en la capa de base de datos, 18 en la capa de models)
- Bugs reales corregidos: 6 (uno de sintaxis, cinco de no coincidencia de tipos)
- Estado del entorno: Git, Flutter 3.44.1, Android SDK 36.1 y dispositivo conectado, todos verificados.
- Estado del proyecto: capas de base de datos y models reconstruidas. La aplicación aún no compila porque las dependencias no están declaradas en `pubspec.yaml` y la capa de servicios no está en su lugar.

### Próximos pasos

Capa de servicios. Migrar las tres dependencias de `financial_engine` (`meta_inteligente_engine`, `notification_service`, `claude_service`) para que consuman el brain en lugar de instanciar sus propios engines. Implementar la integración del contador de versión en `master_financial_brain`. Aplicar las tres correcciones de `.clamp()` pendientes que viven en la capa de servicios.

---

## 2026-06-10 — Capa Services completa, primer push público, cierre de la deuda arquitectónica

**Tiempo invertido:** aproximadamente 5 horas
**Fase:** Reconstrucción de Services + publicación + decisiones de producto

### Objetivo

Cerrar las dos piezas que quedaban pendientes para tener una base de proyecto profesional: completar la capa Services con todas sus migraciones, y publicar la primera versión del proyecto en GitHub.

### Trabajo realizado

1. **Push del repo a GitHub.** El proyecto pasó de ser un commit local en mi disco a un repo público en `github.com/juan-macias1/mi_presupuesto`. Autenticación vía Git Credential Manager con OAuth. El primer commit del día anterior (`9f5a5cd`) quedó publicado con el README renderizado como página principal.

2. **Capa Services completada en tres tandas** según riesgo y cantidad de cambio:
   - Tanda 1 (Grupo A — limpios): `distribution_engine`, `chart_engine`, `category_suggestion_service`, `deuda_engine`. Solo dos correcciones de `.clamp()` en `deuda_engine`.
   - Tanda 2 (Grupo C — el cerebro): `master_financial_brain` con la integración del contador de versión para invalidación automática de caché, más una corrección de `.clamp()` en la proyección, más tres limpiezas de `unnecessary_cast`.
   - Tanda 3 (Grupo B — migraciones): `meta_inteligente_engine`, `notification_service`, `claude_service`. Los tres dejaron de depender de `FinancialEngine` y ahora consumen `MasterFinancialResult` del brain.

3. **Cierre de la deuda arquitectónica.** `financial_engine.dart` no existe en el proyecto. Toda la lógica de análisis financiero pasa por una única ruta: el brain. Eliminada la posibilidad de inconsistencias entre dos calculadoras paralelas.

4. **Refactor de `ClaudeService`.** Se eliminó el método `_construirContextoFinanciero` por completo (cerca de 60 líneas) porque duplicaba el contexto que el brain ya genera en `_construirContextoIA`. La firma de `enviarMensaje` ahora recibe `MasterFinancialResult` en lugar de tres modelos sueltos. La API key se lee del archivo `.env` con `flutter_dotenv`, nunca hardcoded.

5. **Configuración de dependencias.** Se agregaron al `pubspec.yaml` las seis dependencias requeridas por los servicios: `sqflite`, `path`, `http`, `flutter_dotenv`, `flutter_local_notifications`, `timezone`. `flutter pub get` resolvió todas sin conflictos.

6. **Configuración de `main.dart` para dotenv.** Modificado para hacer `WidgetsFlutterBinding.ensureInitialized()` y `await dotenv.load(fileName: ".env")` antes de `runApp`. Esto permite que `dotenv.env['ANTHROPIC_API_KEY']` funcione en cualquier punto del código.

7. **Activación del Modo Desarrollador en Windows.** Necesario para que Flutter pueda crear symlinks de plugins sin permisos de admin. Trivial pero crítico para la siguiente sesión cuando corra `flutter run`.

8. **Conversación de producto sobre diseño de comportamiento.** Larga discusión sobre cómo cerrar la brecha intención-acción (knowing-doing gap). Se identificaron ocho principios concretos a incorporar a futuro (pre-commitment, loss framing, identidad sobre meta, fricción asimétrica, feedback inmediato, visualización del yo futuro, implementation intentions, rituales de cierre) y dos categorías a evitar (shame/guilt, falsa urgencia). Se acordó documentarlos en un futuro `BEHAVIOR_DESIGN.md`.

9. **Confirmación del foco "debt-first".** Se identificaron seis puntos donde la deuda debería pesar más en la experiencia del producto: dashboard en modo ataque visualmente urgente, cada movimiento muestra impacto en fecha de libertad, chat IA empieza recordando el modo, score ponderado por modo, notificaciones sesgadas a deuda en modo ataque, sección "velocidad de pago" con escenarios comparativos.

10. **Segundo commit del proyecto** (`7082432`) con la capa Services completa y push al repo público. Tercer commit en preparación para `LEARNING_PATH.md` y esta entrada del DEVLOG.

### Lo que funcionó

- La estrategia de tres tandas (limpios → cerebro → migraciones) para Services permitió mantener concentración: cada tanda tenía su propia lógica de cambio, sin mezclar fixes triviales con refactors estructurales.
- Usar un script Python para aplicar las cinco modificaciones al brain, en lugar de sed encadenados. Más legible, menos propenso a errores, fácil de verificar.
- Verificar los imports de los servicios antes de generar los archivos. Detecté que todos usaban `../db/` y `../models/`, lo cual confirmó que no había paths que arreglar al moverlos a `lib/services/`.
- El método auxiliar `_calcularCambioGastosMesAnterior` en `notification_service`. Decidí mantener este cálculo específico local al service en lugar de exponerlo en `MasterFinancialResult`. Aplicación práctica del principio de cohesión: si un dato lo necesita una sola pantalla, no lo expongas globalmente.

### Lo que falló y cómo se resolvió

- La integración del contador de versión en el brain requirió cinco modificaciones distintas en lugares específicos del archivo. Hacerlo con sed habría sido frágil. Lo resolví con un script Python con `assert` en cada reemplazo para garantizar que las búsquedas matchearan.
- Apareció un warning sobre symlinks de Windows después de `flutter pub get`. No bloqueaba el commit pero sí iba a bloquear el próximo `flutter run`. Resuelto activando el Modo Desarrollador en Configuración.

### Lecciones aprendidas

- **Niveles del analizador de Dart**: `error` (rojo, bloqueante), `warning` (amarillo, no bloqueante pero serio), `info` (sugerencia de estilo, opcional). Aprender a leer y filtrar cada categoría es parte del oficio. Hoy bajé de 20 issues a 17 limpiando solo los warnings, dejando los `info` de estilo para un commit separado tipo `chore:`.
- **Single source of truth no es teoría académica.** Cuando se cierra (como hoy con `financial_engine` eliminado), de pronto el código tiene menos lugares donde un bug puede esconderse. Es tangible.
- **El refactor más limpio elimina código en lugar de agregarlo.** `ClaudeService` bajó de 159 líneas a cerca de 110 al sacar `_construirContextoFinanciero`. Menos código de mantener, menos lugares donde algo puede divergir, misma funcionalidad.
- **Diseño de comportamiento no es manipulación.** La distinción ética importa. La primera es uno contratando una herramienta para cumplir lo que ya decidió. La segunda es alguien externo empujándolo contra sus intereses.
- **Externalizar conocimiento al repo es backup conceptual.** La conversación con Claude es ephemeral; los archivos del repo son durables. Cada decisión arquitectónica importante debería terminar materializada en código con comentarios, en un DEVLOG entry, o en un documento del repo.

### Métricas

- Archivos creados o modificados: 12 (8 servicios nuevos, brain reformado, `main.dart`, `pubspec.yaml`, `pubspec.lock`)
- Líneas insertadas en el segundo commit: 2,491
- Bugs corregidos: 4 (todos `.clamp()` mal tipados)
- Warnings cerrados: 3 (`unnecessary_cast`)
- Estado de `flutter analyze`: 0 errores, 0 warnings, 17 `info` (style-only)
- Estado del proyecto: capas DB, Models y Services reconstruidas y limpias. Repo público en GitHub con 2 commits. Aún no compila a un app funcional porque faltan las pantallas (capa Screens) y los widgets.
- Commits del día: `7082432` — `feat(services): complete services layer with brain as single source of truth`.

### Próximos pasos

- Capa Screens: migrar el `main.dart` original (1770 líneas) y reconstruir las pantallas. Tres faltan completamente del backup (`metas_screen`, `chat_ia_screen`) y dos widgets (`dashboard_score_card`, `dashboard_risk_chip`) más un helper (`export_helper`).
- Capa Widgets: `dashboard_charts_card`, `dashboard_section_card`, `meta_card`.
- Configuración Android para `flutter_local_notifications` (permisos en AndroidManifest).
- Activar la API key cuando se procese el pago de Anthropic.
- Implementar el principio "debt-first" cuando llegue la migración de screens.
- Documentar formalmente los principios de diseño de comportamiento en `BEHAVIOR_DESIGN.md`.
- Primer post en LinkedIn contando el arco del proyecto.

---

## 2026-06-11 — Capa UI completa, primer build real en el dispositivo

**Tiempo invertido:** aproximadamente 6 horas
**Fase:** Reconstrucción de Widgets + Screens + main.dart, primer `flutter run` exitoso

### Objetivo

Cerrar la capa de interfaz visual del app: widgets, pantallas, main.dart, helpers. Conectar todo lo construido en las capas previas a una UI funcional. Hacer correr el app por primera vez sobre el dispositivo físico, validando el pipeline completo de la arquitectura.

### Trabajo realizado

1. **Tanda Widgets (Grupo A — limpios):** 5 archivos colocados en `lib/widgets/`.
   - Migrados con cambios mínimos: `dashboard_charts_card.dart` (con un `.clamp()` corregido en el progress indicator), `dashboard_section_card.dart` (sin cambios), `meta_card.dart` (con un `.clamp()` corregido en el cálculo de progreso).
   - Reconstruidos desde cero: `dashboard_score_card.dart` (muestra el score 0-100 con cuatro rangos de color semánticos), `dashboard_risk_chip.dart` (renderiza un FinancialRisk como chip de Material con icono según severidad). Diseño base limpio, pensado para iterar en la fase de UX.

2. **Tanda Screens 1 — `deudas_screen.dart`:** migrado con dos correcciones. Un `.clamp()` agregado con `.toDouble()`. Eliminado el campo `_pagoDisponible` que estaba declarado pero nunca leído — dead state. Patrón ya conocido del DEVLOG anterior.

3. **Tanda Screens 2 — `chat_ia_screen.dart` y `metas_screen.dart` reconstruidos desde cero.**
   - `chat_ia_screen.dart` (~272 líneas): interfaz de chat con Fin, recibe `MasterFinancialResult`, lo pasa a `ClaudeService.enviarMensaje`. Burbujas asimétricas tipo WhatsApp (usuario azul a la derecha, asistente gris a la izquierda). Auto-scroll vía `WidgetsBinding.addPostFrameCallback`. Mensaje de bienvenida inicial. `if (!mounted) return;` después del `await` para evitar errores cross-async.
   - `metas_screen.dart` (~453 líneas): CRUD completo de metas. Carga del DB + consulta al brain para el análisis inteligente. Bottom sheet modal para crear/editar. Confirmación de dialog para eliminar. Empty state amigable. Header con resumen agregado. RefreshIndicator para pull-to-refresh.

4. **Tanda Screens 3 — `financial_dashboard_screen.dart`:** migrado con cuatro tipos de cambio.
   - Normalización de 20 imports de estilo `package:mi_presupuesto/...` a estilo relativo `../...`, consistente con el resto del proyecto.
   - Fix del path: `screens/deuda_screen.dart` (singular, typo del original) → `screens/deudas_screen.dart` (plural, nombre real del archivo).
   - Fix de API mismatch detectado por el compilador: `DashboardScoreCard(analysis: result.analysis)` → `DashboardScoreCard(score: result.scoreFinanciero)`. Mismo patrón con `DashboardRiskChip(nivel: ...)` → `DashboardRiskChip(risk: ...)`.
   - Fix de otra API mismatch: `ChatIAScreen(analysis:, distribucion:, proyeccion:)` (la firma vieja) → `ChatIAScreen(result: ...)` (la firma nueva tras el refactor del día anterior de ClaudeService).
   - Removidos dos imports no usados (`financial_analysis.dart`, `plan_pago.dart`) — consecuencia del refactor: el dashboard ya accede via `result.X` y no necesita los tipos directamente.

5. **Tanda Helpers — 2 stubs documentados.**
   - `helpers/export_helper.dart`: stub que no hace nada en runtime, pero su comentario de cabecera documenta los 5 pasos necesarios para implementarlo realmente (path_provider, query de DB, generar CSV, escribir archivo, retornar path).
   - `services/google_drive_service.dart`: stub similar, retorna un string informativo. Comentario documenta los 6 pasos: proyecto en Google Cloud Console, OAuth, paquetes googleapis, integración con ExportHelper, manejo de errores, mensajes reales.
   - Decisión consciente: no implementar estas funciones ahora. Drive en particular requiere ~4-6 horas solo de setup (OAuth, credenciales). Stage 1 no las necesita; Stage 2 las implementará.

6. **Migración de `main.dart` (1770 → 1767 líneas):**
   - Imports normalizados (paths relativos), fix del `screens/deuda_screen.dart`.
   - Agregado import de `flutter_dotenv` y `flutter_localizations`.
   - `main()` reescrito: ahora es `Future<void>`, envuelve `dotenv.load` en try/catch para no romper el arranque si el archivo falla, cambia el locale de `es_ES` a `es_CO` (España → Colombia), envuelve las notificaciones también en try/catch.
   - `MaterialApp` con `localizationsDelegates` (Material/Widgets/Cupertino), `supportedLocales` y `locale: Locale('es', 'CO')`. Sin esto, el DatePicker ignora el locale aunque le pasen `Locale('es', 'CO')`.
   - Removido método dead code `_mostrarOpcionesMovimiento` (37 líneas, nadie lo llamaba).
   - Tres `value:` deprecados en `DropdownButtonFormField` migrados a `initialValue:` (el primero será error en futuras versiones de Flutter).
   - Un `.clamp()` corregido con `.toDouble()`.

7. **Configuración Android — `android/app/build.gradle.kts`:**
   - Habilitado `isCoreLibraryDesugaringEnabled = true` en `compileOptions`.
   - Agregado bloque `dependencies` con `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
   - Necesario porque `flutter_local_notifications` usa APIs de Java 8+ (como `java.time`) que no existen nativamente en Android viejo. Gradle las traduce ("desugar") a equivalentes compatibles.

8. **Configuración `pubspec.yaml`:**
   - Agregadas dependencias `fl_chart: ^0.69.0` e `intl: ^0.19.0`.
   - Conflict detectado al hacer `flutter pub get`: `flutter_localizations` exige `intl 0.20.2` exacto. Resuelto bumpeando nuestro pin a `intl: ^0.20.2`.
   - Agregada dependencia `flutter_localizations: sdk: flutter`.

9. **Primer `flutter run` exitoso en el dispositivo.** El app boot, navega entre pantallas, muestra empty states correctos. Estados verificados visualmente:
   - Pantalla principal con balance "0 $" y empty state del buzón.
   - Mis Metas con empty state y CTA verde.
   - Mis Deudas con empty state, FAB rojo y CTA rojo — **el "debt-first design" emergiendo naturalmente sin haberlo programado todavía**.
   - Dashboard en modo `sinDatos` (el MasterFinancialBrain detectó la ausencia de movimientos).
   - Chat con Fin saludando con el mensaje inicial pre-programado.

### Lo que funcionó

- La estrategia de tandas por nivel de dependencia: widgets primero (sin deps internas), luego screens simples, después screens complejos, helpers, main al final. Cada tanda compila independiente.
- Verificar los imports antes de mover archivos: detectar el typo de `deuda_screen` y el API mismatch del chat ANTES de tirar `flutter run` ahorró tiempo de debugging downstream.
- Usar Python para los refactors complejos en el main.dart en lugar de sed encadenados.
- Stubs documentados en lugar de implementación incompleta. El comentario de cabecera de cada stub vale más que el código actual: dice exactamente qué hacer cuando llegue el momento.

### Lo que falló y cómo se resolvió

- **Refactor cross-file incompleto del día anterior:** el dashboard llamaba a `ChatIAScreen` con la API vieja (3 modelos separados) cuando yo había migrado el chat a recibir un `MasterFinancialResult`. El compilador lo detectó como 4 errores rojos. Resuelto actualizando una línea del dashboard.
- **Conflict de versiones `flutter_localizations` vs `intl`:** el SDK de Flutter pinea `intl 0.20.2` exacto. Nuestro `^0.19.0` no satisfacía. Resuelto bumpeando a `^0.20.2`.
- **Core library desugaring no habilitado:** `flutter run` fallaba con un error de AAR metadata pidiendo desugaring. Resuelto agregando 2 cambios en `android/app/build.gradle.kts`.

### Lecciones aprendidas

- **Refactor cross-file requiere actualizar TODOS los consumidores.** Si dejás uno desactualizado, el compilador te lo encuentra — gracias a tipos fuertes. Argumento clásico a favor de lenguajes tipados frente a dinámicos: en Python o JavaScript sin tipos, este error solo aparecería al EJECUTAR la pantalla del chat, mucho más tarde y más caro.
- **Cuando una dependencia restringe el rango de otra que ya tenés, el resolver de Dart es muy claro.** El mensaje "Try `flutter pub add intl:^0.20.2`" indicó exactamente la solución. Aprender a leer los mensajes del resolver es parte del oficio.
- **Configuración nativa de Android es real.** `flutter_local_notifications` requiere desugaring; otros paquetes pueden requerir permisos en AndroidManifest, claves API, etc. Estos no son bugs del proyecto — son requisitos del ecosistema. Hay que aprender a googlearlos rápido cuando aparecen.
- **El "debt-first design" emergió solo en la pantalla de deudas.** El rojo del FAB y del CTA contrastan con el verde del resto del app, y eso ya transmite la urgencia que quiero. Buen recordatorio: los principios de diseño no requieren toneladas de código, a veces se aplican con un solo color elegido bien.

### Métricas

- Archivos creados o modificados: 16
- Líneas insertadas (commit): 5,781
- Líneas eliminadas (commit): 88
- Bugs corregidos: 8 (4 errores reales del API mismatch del dashboard, 3 `value:` deprecados a `initialValue:`, 1 dead code removido)
- Warnings cerrados: 1 (unused element `_mostrarOpcionesMovimiento`)
- Estado de `flutter analyze` al cierre: 0 errores, 0 warnings, 33 `info` (style-only)
- Primer build end-to-end exitoso en dispositivo físico

### Próximos pasos

- Fix del permiso de `requestExactAlarmsPermission` innecesario en `notification_service`.
- Validar el flujo de creación de movimientos con datos reales.
- Documentar formalmente los principios de diseño de comportamiento en `BEHAVIOR_DESIGN.md`.
- Eventualmente: probar Fin con la API key activa de Anthropic cuando se procese el pago.

---

## 2026-06-12 — Fix de notificaciones, decisión estratégica sobre alcance, cierre del commit grande

**Tiempo invertido:** aproximadamente 3 horas
**Fase:** Pulido + conversación de producto + cierre del trabajo de ayer

### Objetivo

Resolver un issue de UX detectado al usar el app en el dispositivo (Android pide un permiso de alarmas exactas innecesariamente), tomar una decisión estratégica sobre el alcance del producto que apareció caminando, y cerrar el trabajo del día anterior con un commit consolidado y su push.

### Trabajo realizado

1. **Diagnóstico del prompt de Android "Allow setting alarms and reminders".** Al arrancar el app por primera vez, el sistema operativo abre una pantalla de configuración pidiendo permiso para alarmas exactas. Análisis: el método `inicializar()` de `NotificationService` llama a `requestExactAlarmsPermission()`, pero la única notificación programada (el recordatorio diario) usa `AndroidScheduleMode.inexact`. Permiso solicitado innecesariamente.

2. **Fix de una línea.** Removida `await androidPlugin?.requestExactAlarmsPermission();` de `notification_service.dart`. Al próximo arranque del app, Android ya no abre esa pantalla. Si en el futuro se necesitan alarmas exactas (ej. notificación a las 8pm en punto), se vuelve a agregar.

3. **Conversación estratégica sobre alcance del producto: ¿wallet o coach?** Llegó la pregunta inevitable: ¿debería Mi Presupuesto evolucionar hacia ser una wallet tipo Nequi/Daviplata, no solo trackear plata sino moverla? Análisis honesto de los costos reales de cada camino:
   - **Wallet completa (SEDPE en Colombia):** capital mínimo de ~5,200 millones COP (~1.2M USD), licencia de la Superintendencia Financiera, compliance con SFC y UIAF, KYC robusto, auditorías SOC 2 / ISO 27001 / PCI-DSS, equipo legal y de seguridad, soporte 24/7, pólizas FOGAFIN. Es construir un banco. No es viable para un proyecto solitario.
   - **Camino intermedio (Open Banking via Belvo/Finerio en Stage 2):** lectura automática de movimientos del banco con consentimiento del usuario. Requiere ser persona jurídica (SAS), contratos con el aggregator, manejo serio de datos sensibles. Viable cuando haya validación de usuarios reales.
   - **Decisión:** NO ir por wallet. El valor único de Mi Presupuesto es ser **coach inteligente personalizado**, no commodity wallet. Wallet es categoría saturada con bancos peleando entre sí; coach inteligente con foco colombiano es categoría con espacio. Mejor único en algo escaso que mediocre en algo abundante.

4. **Commit grande consolidando el trabajo del 11 de junio + el fix de notificaciones de hoy** (`bcdb1e5`): 16 archivos, 5,781 inserciones, 88 deleciones. Push exitoso a GitHub. El repo ahora tiene cuatro commits que cuentan el arco completo del Stage 1.

### Lo que funcionó

- **Reservar el commit para después de descansar y volver al día siguiente.** Revisión más limpia, mejor mensaje de commit, decisiones más claras. Lección de cadencia: no comitear en caliente al cierre de una sesión larga.
- **Tener la conversación de producto antes de comitear, no después.** La decisión de no ir por wallet queda documentada en este DEVLOG y en `BEHAVIOR_DESIGN.md`, no perdida en una conversación efímera.

### Lo que falló y cómo se resolvió

- **El prompt de Android era confuso desde el lado del usuario:** ¿por qué una app de presupuesto pide permiso de alarmas exactas? Esa confusión es la señal de que estábamos pidiendo más de lo necesario. Bueno detectarlo en el primer uso real, antes de que llegue a manos de cualquier otra persona.

### Lecciones aprendidas

- **Pedir permisos que no usás es UX pobre.** Los usuarios desarrollan fatiga de permisos y rechazan todo. Solo pedir lo que se va a usar realmente, cuando se va a usar.
- **La diferencia entre trackear plata y mover plata es regulatoriamente enorme.** No existe el punto intermedio "casi una wallet": o sos plataforma de información, o sos institución financiera. Conviene entenderlo antes de tomar la decisión.
- **Externalizar decisiones estratégicas al repo es seguro.** Esta conversación de "wallet vs coach" podría perderse en cualquier chat. Materializada en `BEHAVIOR_DESIGN.md` y en este DEVLOG, sobrevive a todo. La conversación es catalizador; los artefactos son legado.
- **El roadmap del proyecto tiene capa técnica y capa de producto.** Las técnicas son qué construyo. Las de producto son por qué y para qué. Ambas necesitan documentarse o se pierden.

### Métricas

- Archivos modificados directamente hoy: 1 (`notification_service.dart`)
- Líneas eliminadas hoy: 1
- Commit del día: `bcdb1e5` (consolidando todo el trabajo del 11 + el fix de hoy)
- Total de commits en el repo: 4
- Decisiones de producto formalizadas hoy: 2 (no-wallet, debt-first design como principio rector)

### Próximos pasos

- `BEHAVIOR_DESIGN.md` (siguiente commit, mismo día): documento formal con los 8 principios + debt-first.
- Quinto commit del día: docs con esta entrada del DEVLOG y el `BEHAVIOR_DESIGN.md`.
- `chore:` commit en algún momento limpiando los 33 `info` de estilo que arrastra `flutter analyze` (curly braces, build_context_synchronously, etc.). No es urgente.
- Usar la app con datos reales: registrar mis propios ingresos y gastos del mes para validar el flujo end-to-end de usuario.
- Cuando se active la API key de Anthropic: testear Fin con preguntas reales sobre mi situación financiera.
- Configurar `AndroidManifest.xml` con `POST_NOTIFICATIONS` permission para Android 13+ si aparece como necesario en pruebas.

---
