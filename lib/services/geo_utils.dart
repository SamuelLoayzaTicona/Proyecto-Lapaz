import 'package:latlong2/latlong.dart';

/// Funciones de geometría usadas por el Modo Seguro para saber qué tan
/// lejos está el usuario de la ruta planificada.
class GeoUtils {
  GeoUtils._();

  static final Distance _distance = const Distance();

  /// Convierte una lista de puntos "de esquina a esquina" en una lista más
  /// densa, interpolando puntos intermedios. Esto hace que la comparación
  /// contra el GPS real sea más precisa (si solo comparáramos contra las
  /// estaciones, alguien a mitad de camino parecería "desviado" aunque
  /// esté justo sobre la ruta).
  static List<LatLng> densify(List<LatLng> points, {int stepsPerSegment = 12}) {
    if (points.length < 2) return points;
    final dense = <LatLng>[];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      for (var step = 0; step < stepsPerSegment; step++) {
        final t = step / stepsPerSegment;
        dense.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    dense.add(points.last);
    return dense;
  }

  /// Distancia mínima (en metros) entre un punto y una ruta completa.
  static double minDistanceToRouteMeters(LatLng point, List<LatLng> route) {
    if (route.isEmpty) return double.infinity;
    final dense = densify(route);
    double minMeters = double.infinity;
    for (final routePoint in dense) {
      final meters = _distance.as(LengthUnit.Meter, point, routePoint);
      if (meters < minMeters) minMeters = meters;
    }
    return minMeters;
  }

  static double distanceMeters(LatLng a, LatLng b) {
    return _distance.as(LengthUnit.Meter, a, b);
  }
}
