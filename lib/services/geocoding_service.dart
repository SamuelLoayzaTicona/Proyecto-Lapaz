import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Servicio de geocodificación que convierte texto en coordenadas
/// usando Nominatim (OpenStreetMap).
///
/// Límite: 1 solicitud por segundo (para la demo es suficiente).
/// Para producción, se recomienda Google Maps Geocoding API o self-hosted Nominatim.
class GeocodingService {
  GeocodingService._();

  static final http.Client _client = http.Client();

  /// Convierte un texto en coordenadas (lat, lng)
  /// Ejemplo: "Plaza Avaroa, La Paz" → LatLng(-16.5080, -68.1230)
  static Future<LatLng?> obtenerCoordenadas(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}, La Paz, Bolivia'
        '&format=json&limit=1',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        print('❌ Geocoding error: status ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as List;

      if (data.isEmpty) {
        print('❌ Geocoding error: no results for "$query"');
        return null;
      }

      final lat = double.parse(data[0]['lat'].toString());
      final lng = double.parse(data[0]['lon'].toString());

      print('✅ Geocoding success: "$query" → ($lat, $lng)');
      return LatLng(lat, lng);
    } catch (e) {
      print('❌ Geocoding error: $e');
      return null;
    }
  }

  /// Convierte coordenadas en un nombre de lugar (geocodificación inversa)
  static Future<String?> obtenerNombre(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=${point.latitude}&lon=${point.longitude}'
        '&format=json&zoom=18',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final displayName = data['display_name'] as String?;
      if (displayName != null && displayName.isNotEmpty) {
        return displayName.split(',').first.trim();
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}