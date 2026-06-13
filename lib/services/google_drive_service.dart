import 'package:flutter/foundation.dart';

/// GoogleDriveService — sube backups del usuario a su propio Google Drive.
///
/// STUB EN STAGE 1: la integración con Google Drive requiere OAuth,
/// configuración en Google Cloud Console, los paquetes `googleapis` y
/// `google_sign_in`, y manejo de tokens. Eso son varias horas de setup
/// que no aportan valor en esta fase del proyecto.
///
/// Por ahora retorna un string informativo que el UI muestra al usuario.
///
/// PARA IMPLEMENTAR EN UNA FASE FUTURA:
///   1. Crear un proyecto en Google Cloud Console y habilitar Drive API.
///   2. Configurar credenciales OAuth 2.0 para Android e iOS.
///   3. Agregar al pubspec: `google_sign_in`, `googleapis`,
///      `googleapis_auth`, `http`.
///   4. Implementar el flujo: signIn -> authHeaders -> DriveApi.files.create
///      con el CSV generado por ExportHelper.
///   5. Manejar errores: usuario no logueado, sin internet, cuota llena.
///   6. Retornar mensaje real del éxito ("Backup subido: archivo.csv") o
///      del error específico.
class GoogleDriveService {
  Future<String> uploadCSV() async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[GoogleDriveService] STUB: uploadCSV() — '
          'función pendiente de implementación en una fase futura del proyecto.');
    }
    return 'La exportación a Google Drive estará disponible próximamente.';
  }
}
