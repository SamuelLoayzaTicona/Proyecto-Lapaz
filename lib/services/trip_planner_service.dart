import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../models/transport_models.dart';
import 'geo_utils.dart';
import 'routing_service.dart';
import 'teleferico_network.dart';

/// Calcula un plan de viaje entre CUALQUIER origen y destino que tengan
/// coordenadas (ya sea porque el usuario tocó el mapa, eligió un lugar
/// conocido, o escribió una dirección que encontramos por búsqueda).
///
/// No son datos "inventados": la ruta usa la red real de Mi Teleférico
/// (líneas, estaciones y duraciones reales) más ruteo real por calles para
/// los tramos de caminata/minibús (vía OSRM). Eso sí, como la red de
/// Teleférico solo cubre ciertas zonas, para destinos lejos de cualquier
/// estación esto es una aproximación razonable, no una réplica exacta de
/// cómo se movería alguien - eso se puede seguir afinando con más datos.
class TripPlannerService {
  TripPlannerService._();

  static const double _walkingSpeedMetersPerMinute = 70;

  /// Si caminar hasta la estación más cercana (en cualquiera de los dos
  /// extremos) tomaría más de esto, mejor no forzar el Teleférico: se arma
  /// un viaje directo en minibús/caminata en su lugar.
  static const double _maxWalkToStationMeters = 1800;

  static Future<TripPlan?> planTrip({
    required LatLng origin,
    required LatLng destination,
    required String destinationLabel,
  }) async {
    final distanceToNearestFromOrigin = TelefericoNetwork.distanceToNearestStation(origin);
    final distanceToNearestFromDestination = TelefericoNetwork.distanceToNearestStation(destination);

    final telefericoViable = distanceToNearestFromOrigin <= _maxWalkToStationMeters &&
        distanceToNearestFromDestination <= _maxWalkToStationMeters;

    if (telefericoViable) {
      final plan = await _planViaTeleferico(origin, destination, destinationLabel);
      if (plan != null) return plan;
    }

    // Sin Teleférico cerca de alguno de los dos extremos: viaje directo en
    // minibús (o caminando, si la distancia es corta) por calles reales.
    return _planDirectTrip(origin, destination, destinationLabel);
  }

  static Future<TripPlan?> _planViaTeleferico(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    final entryStation = TelefericoNetwork.nearestStation(origin);
    final exitStation = TelefericoNetwork.nearestStation(destination);

    final segments = <RouteSegment>[];

    if (entryStation.name != exitStation.name) {
      final path = TelefericoNetwork.findPath(entryStation.name, exitStation.name);
      if (path == null) return null; // no debería pasar, pero por seguridad

      // Caminata real hasta la primera estación.
      segments.add(await _walkSegment(
        from: origin,
        to: entryStation.location,
        title: 'Camina a la estación',
        toStopName: entryStation.name,
        fromStopName: 'Tu ubicación',
      ));

      // Un tramo de Teleférico por cada línea que se usa (rectos a
      // propósito: así viaja un cable aéreo real).
      for (final step in path) {
        segments.add(RouteSegment(
          mode: TransportMode.teleferico,
          title: 'Teleférico · ${step.line.name}',
          subtitle: 'Bs. 3.00 · hasta ${step.stations.last.name}',
          instruction: 'Aborda la ${step.line.name} desde ${step.stations.first.name} '
              'hasta ${step.stations.last.name}.',
          fareBs: 3.0,
          durationMin: (step.line.durationMin * (step.stations.length - 1) /
                  (step.line.stations.length - 1))
              .ceil()
              .clamp(2, step.line.durationMin),
          fromStop: step.stations.first.name,
          toStop: step.stations.last.name,
          geoPoints: step.stations.map((s) => s.location).toList(),
        ));
      }
    }

    // Último tramo: de la estación de salida al destino real. Si está
    // cerca, caminando; si está algo lejos, en minibús por calles reales.
    final lastLegMeters = GeoUtils.distanceMeters(exitStation.location, destination);
    if (lastLegMeters > 700) {
      segments.add(await _minibusSegment(
        from: exitStation.location,
        to: destination,
        fromStopName: exitStation.name,
        toStopName: destinationLabel,
      ));
    } else {
      segments.add(await _walkSegment(
        from: exitStation.location,
        to: destination,
        title: 'Camina a tu destino',
        fromStopName: exitStation.name,
        toStopName: destinationLabel,
      ));
    }

    return TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: segments);
  }

  static Future<TripPlan> _planDirectTrip(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    final distanceMeters = GeoUtils.distanceMeters(origin, destination);
    final segments = <RouteSegment>[];

    if (distanceMeters <= 900) {
      segments.add(await _walkSegment(
        from: origin,
        to: destination,
        title: 'Camina a tu destino',
        fromStopName: 'Tu ubicación',
        toStopName: destinationLabel,
      ));
    } else {
      segments.add(await _minibusSegment(
        from: origin,
        to: destination,
        fromStopName: 'Tu ubicación',
        toStopName: destinationLabel,
      ));
    }

    return TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: segments);
  }

  static Future<RouteSegment> _walkSegment({
    required LatLng from,
    required LatLng to,
    required String title,
    required String fromStopName,
    required String toStopName,
  }) async {
    final points = await RoutingService.fetchRoute(start: from, end: to, profile: 'foot');
    final meters = _routeLengthMeters(points);
    final min = (meters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);
    return RouteSegment(
      mode: TransportMode.walk,
      title: title,
      subtitle: '${meters.round()} m',
      instruction: 'Camina desde $fromStopName hasta $toStopName.',
      fareBs: 0,
      durationMin: min,
      fromStop: fromStopName,
      toStop: toStopName,
      geoPoints: points,
    );
  }

  static Future<RouteSegment> _minibusSegment({
    required LatLng from,
    required LatLng to,
    required String fromStopName,
    required String toStopName,
  }) async {
    final points = await RoutingService.fetchRoute(start: from, end: to, profile: 'driving');
    final meters = _routeLengthMeters(points);
    final min = (meters / 300).ceil().clamp(5, 60);
    return RouteSegment(
      mode: TransportMode.minibus,
      title: 'Minibús',
      subtitle: 'Bs. 2.50 (referencial) · hacia $toStopName',
      instruction: 'Toma un minibús con destino a $toStopName. '
          'La tarifa y el sindicato exacto todavía no están verificados para esta zona.',
      fareBs: 2.5,
      durationMin: min,
      fromStop: fromStopName,
      toStop: toStopName,
      geoPoints: points,
      syndicate: 'Por confirmar',
    );
  }

  static double _routeLengthMeters(List<LatLng> points) {
    double total = 0;
    for (var i = 0; i < points.length - 1; i++) {
      total += GeoUtils.distanceMeters(points[i], points[i + 1]);
    }
    return total;
  }
}
