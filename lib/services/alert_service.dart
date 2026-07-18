import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

/// Envía la alerta real de "Modo Seguro" abriendo WhatsApp con un mensaje
/// pre-armado (incluye la ubicación en un link de Google Maps) hacia el
/// número de emergencia registrado. No necesita backend ni API de SMS: usa
/// el link oficial de WhatsApp (wa.me), que si el contacto tiene WhatsApp
/// instalado, abre la conversación lista para enviar.
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

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
