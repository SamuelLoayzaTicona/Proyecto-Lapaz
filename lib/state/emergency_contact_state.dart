import 'package:flutter/foundation.dart';

/// Contacto de emergencia registrado por el usuario. Vive en memoria por
/// ahora (se pierde al cerrar la app); cuando conectemos Firebase esto
/// pasa a guardarse en el perfil del usuario.
class EmergencyContactState {
  EmergencyContactState._();

  static final ValueNotifier<String?> name = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> phone = ValueNotifier<String?>(null);

  static bool get isConfigured => phone.value != null && phone.value!.trim().isNotEmpty;
}
