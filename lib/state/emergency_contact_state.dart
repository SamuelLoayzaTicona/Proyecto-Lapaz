import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/device_id_service.dart';

/// Contacto de emergencia registrado por el usuario.
///
/// Se guarda en DOS lugares con propósitos distintos:
/// 1. shared_preferences (local): para que la app funcione instantáneo y
///    hasta sin internet (el Modo Seguro no puede depender de que haya
///    señal en el momento exacto del desvío).
/// 2. Firestore, colección "emergency_contacts" (separada de
///    "trameaje_reports" y "trip_history"): para tener un respaldo
///    organizado en la nube, recuperable si cambias de teléfono.
class EmergencyContactState {
  EmergencyContactState._();

  static const _nameKey = 'emergency_contact_name';
  static const _phoneKey = 'emergency_contact_phone';

  static final ValueNotifier<String?> name = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> phone = ValueNotifier<String?>(null);

  static bool get isConfigured => phone.value != null && phone.value!.trim().isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name.value = prefs.getString(_nameKey);
    phone.value = prefs.getString(_phoneKey);
  }

  static Future<void> save({required String contactName, required String contactPhone}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, contactName);
    await prefs.setString(_phoneKey, contactPhone);
    name.value = contactName;
    phone.value = contactPhone;

    // Respaldo en Firestore, en su propia colección (no se mezcla con
    // reportes ni historial de viajes).
    try {
      final deviceId = await DeviceIdService.getId();
      await FirebaseFirestore.instance.collection('emergency_contacts').doc(deviceId).set({
        'name': contactName,
        'phone': contactPhone,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Si falla el respaldo en la nube (sin internet, por ejemplo), no
      // bloqueamos el guardado local - el Modo Seguro debe seguir
      // funcionando con lo que ya está en el teléfono.
    }
  }
}
