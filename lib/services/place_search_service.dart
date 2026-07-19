import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/place.dart';

/// Busca direcciones reales de La Paz/El Alto usando Nominatim (el motor
/// de búsqueda gratuito de OpenStreetMap, sin API key). Esto permite que
/// el usuario escriba CUALQUIER dirección o barrio, no solo los que están
/// en nuestra lista fija de estaciones/plazas conocidas.
class PlaceSearchService {
  PlaceSearchService._();

  static final http.Client _client = http.Client();

  // Caja aproximada que cubre La Paz + El Alto, para que los resultados no
  // se vayan a otra ciudad con nombre parecido.
  static const _viewBox = '-68.22,-16.44,-68.05,-16.58';

  static Future<List<Place>> search(String query) async {
    if (query.trim().length < 3) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent('$query, La Paz, Bolivia')}'
        '&format=json&limit=5&viewbox=$_viewBox&bounded=1',
      );
      final response = await _client.get(
        url,
        headers: {'User-Agent': 'RutaSeguraLaPaz/1.0 (hackathon prototype)'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List;
      return data.map((item) {
        final displayName = item['display_name'] as String;
        final shortName = displayName.split(',').first.trim();
        return Place(
          name: shortName,
          location: LatLng(
            double.parse(item['lat'] as String),
            double.parse(item['lon'] as String),
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
