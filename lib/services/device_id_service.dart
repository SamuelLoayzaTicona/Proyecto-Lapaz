import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Genera un identificador único para este dispositivo/instalación y lo
/// guarda localmente. Como todavía no hay registro de usuario con login,
/// esto nos permite asociar datos (como el contacto de emergencia) a
/// "este teléfono" sin necesitar una cuenta.
class DeviceIdService {
  DeviceIdService._();

  static const _key = 'device_id';

  static Future<String> getId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null) {
      final random = Random();
      id = '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(999999)}';
      await prefs.setString(_key, id);
    }
    return id;
  }
}
