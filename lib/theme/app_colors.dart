import 'package:flutter/material.dart';

/// AppColors — fuente única de verdad para los colores de Mi Presupuesto.
///
/// Antes los colores estaban dispersos y contradictorios (tres teals
/// distintos, el FAB definía un color en el theme pero usaba otro en el
/// código). Esta clase centraliza todo: el ThemeData y las pantallas
/// consumen de acá, nunca hex sueltos.
///
/// Regla del proyecto: si necesitás un color, primero buscalo acá. Si no
/// existe y es de marca o semántico, agregalo acá antes de usarlo. Nunca
/// hardcodees un hex nuevo en una pantalla.
class AppColors {
  AppColors._(); // no instanciable

  // ── Familia de marca (verde profundo) ──────────────────────
  /// Color primario de la app. Botones principales, acentos, FAB en estados activos.
  static const Color primary = Color(0xFF0F6E56);

  /// Verde más oscuro. Texto sobre fondos claros de marca, balance positivo.
  static const Color primaryDark = Color(0xFF2D6A4F);

  /// Verde medio. Estados intermedios, headers secundarios.
  static const Color primaryMedium = Color(0xFF52796F);

  /// Verde claro. Fondo del FAB, chips suaves.
  static const Color primaryLight = Color(0xFFB2DFDB);

  /// Verde muy pálido. Fondo del header, superficies de marca.
  static const Color surface = Color(0xFFF0F7F4);

  // ── Colores semánticos (significado fijo en toda la app) ────
  /// Ingresos. Siempre este verde, nunca Colors.green genérico.
  static const Color ingreso = Color(0xFF1D9E75);

  /// Gastos. Siempre este rojo.
  static const Color gasto = Color(0xFFE24B4A);

  /// Deudas. Naranja de advertencia — debt-first design.
  static const Color deuda = Color(0xFFE8943A);

  /// Acento secundario / modo noche.
  static const Color acento = Color(0xFF534AB7);

  // ── Estados de balance ──────────────────────────────────────
  /// Balance positivo (verde profundo legible).
  static const Color balancePositivo = Color(0xFF1B5E20);

  /// Balance negativo.
  static const Color balanceNegativo = Color(0xFFB71C1C);

  /// Balance neutro / equilibrado.
  static const Color balanceNeutro = Color(0xFF424242);

  // ── Neutros de apoyo ────────────────────────────────────────
  /// Fondo del header en modo noche (azul muy pálido, complementa el acento).
  static const Color surfaceNoche = Color(0xFFF0F4F7);
}
