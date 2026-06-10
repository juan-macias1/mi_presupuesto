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