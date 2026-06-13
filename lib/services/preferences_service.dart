import 'package:shared_preferences/shared_preferences.dart';

/// PreferencesService — almacenamiento clave-valor para configuración ligera.
///
/// Usa SharedPreferences (el almacenamiento de preferencias nativo de cada
/// plataforma). Ideal para datos pequeños y simples como el nombre del usuario,
/// flags de onboarding, etc. NO es para datos financieros — esos viven en
/// SQLite a través de DatabaseHelper.
///
/// Patrón singleton para acceso global consistente.
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const String _kNombreUsuario = 'nombre_usuario';

  SharedPreferences? _prefs;

  /// Inicializa el acceso a SharedPreferences. Llamar una vez en main()
  /// antes de runApp para que las lecturas posteriores sean síncronas.
  Future<void> inicializar() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Nombre del usuario, o null si nunca se configuró.
  /// Lectura síncrona — requiere que inicializar() ya se haya llamado.
  String? get nombreUsuario {
    final nombre = _prefs?.getString(_kNombreUsuario);
    if (nombre == null || nombre.trim().isEmpty) return null;
    return nombre.trim();
  }

  /// true si el usuario ya configuró su nombre (sirve para decidir si
  /// mostrar el diálogo de bienvenida en el primer arranque).
  bool get tieneNombre => nombreUsuario != null;

  /// Guarda el nombre del usuario.
  Future<void> guardarNombre(String nombre) async {
    await _prefs?.setString(_kNombreUsuario, nombre.trim());
  }
}
