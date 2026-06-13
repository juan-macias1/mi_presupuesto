import 'package:flutter/foundation.dart';

/// ExportHelper — exporta movimientos a archivos locales (CSV/PDF/etc).
///
/// STUB EN STAGE 1: la exportación a archivos locales no está implementada
/// todavía. Esta clase devuelve early sin hacer nada, lo cual permite que
/// el flujo de "backup" del main.dart compile y corra sin romperse.
///
/// PARA IMPLEMENTAR EN UNA FASE FUTURA:
///   1. Agregar la dependencia `path_provider` al pubspec.yaml.
///   2. Consultar `DatabaseHelper.instance.obtenerMovimientos()`.
///   3. Construir un string CSV con cabeceras: id, fecha, tipo, categoria,
///      descripcion, valor, es_fijo, es_deuda, acreedor.
///   4. Escribir el archivo en `getApplicationDocumentsDirectory()` con
///      nombre como `mi_presupuesto_movimientos_YYYY-MM-DD.csv`.
///   5. Retornar el path absoluto del archivo generado (cambiar la firma
///      a `Future<String>` cuando se implemente).
class ExportHelper {
  static Future<void> exportarMovimientosLocal() async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[ExportHelper] STUB: exportarMovimientosLocal() — '
          'función pendiente de implementación en una fase futura del proyecto.');
    }
    // No-op intencional. Cuando se implemente, este return desaparece.
    return;
  }
}
