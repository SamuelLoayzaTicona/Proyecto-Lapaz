import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

/// Envía la alerta real de "Modo Seguro" al contacto de emergencia. Intenta
/// primero el esquema directo de la app de WhatsApp (whatsapp://), que es
/// más confiable en Android que el link web, y si no está disponible cae
/// al link web (wa.me), que funciona igual pasando por el navegador.
class AlertService {
  AlertService._();

  static Future<bool> sendDeviationAlert({
    required String phone,
    required LatLng currentPosition,
  }) async {
    final mapsLink =
        'https://maps.google.com/?q=${currentPosition.latitude},${currentPosition.longitude}';
    final message = '🚨 AYUDA. El transporte en el que viajo se desvió de la ruta '
        'planificada. Esta es mi ubicación actual: $mapsLink';
    final encodedMessage = Uri.encodeComponent(message);
    final cleanPhone = _normalizePhone(phone);

    // Intento 1: esquema directo de la app WhatsApp.
    final appUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMessage');
    if (await canLaunchUrl(appUri)) {
      final launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    }

    // Intento 2: link web (wa.me), funciona aunque el esquema anterior falle.
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');
    if (await canLaunchUrl(webUri)) {
      return launchUrl(webUri, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  /// Limpia el número y, si parece un número boliviano local (8 dígitos,
  /// empieza con 6 o 7, sin código de país), le agrega el 591 automático.
  /// wa.me EXIGE el código de país - sin él, el link simplemente no abre
  /// ninguna conversación válida.
  static String _normalizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final looksLocalBolivian =
        digits.length == 8 && (digits.startsWith('6') || digits.startsWith('7'));
    if (looksLocalBolivian) {
      digits = '591$digits';
    }
    return digits;
  }
}
