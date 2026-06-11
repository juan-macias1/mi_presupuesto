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
