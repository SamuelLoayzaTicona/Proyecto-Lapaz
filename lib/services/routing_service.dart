import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Calcula rutas que siguen calles reales (caminata y vehículo) usando el
/// servicio público de OSRM sobre datos de OpenStreetMap. No necesita API
/// key. Si no hay internet o el servicio no responde, cae de vuelta a una
/// línea recta entre los dos puntos, para que la demo nunca se rompa por
/// completo aunque el ruteo real falle.
///
/// Nota importante: el Teleférico NO usa este servicio a propósito - es un
/// cable aéreo, viaja en línea recta entre estaciones de verdad (no sigue
/// calles), así que esos tramos siguen dibujándose rectos porque así es
/// la realidad, no por un error.
class RoutingService {
  RoutingService._();

  static final http.Client _client = http.Client();

  /// profile: 'foot' para caminata, 'driving' para minibús/vehículo.
  static Future<List<LatLng>> fetchRoute({
    required LatLng start,
    required LatLng end,
    required String profile,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$profile/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await _client.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final coords = routes.first['geometry']['coordinates'] as List;
          return coords
              .map((c) => LatLng((c as List)[1] as double, c[0] as double))
              .toList();
        }
      }
    } catch (_) {
      // Sin internet o el servicio público falló: seguimos con la línea
      // recta como respaldo en vez de romper el cálculo de ruta completo.
    }
    return [start, end];
  }
}
