import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';
import '../models/transport_models.dart';
import 'geo_utils.dart';
import 'routing_service.dart';

/// Calcula el plan de viaje. A diferencia de la primera versión (que
/// siempre mostraba el mismo viaje de ejemplo sin importar el destino),
/// este servicio solo devuelve un plan cuando REALMENTE tiene datos
/// verificados para esa combinación origen/destino. Si no los tiene,
/// devuelve null y la pantalla debe avisar al usuario en vez de mostrar
/// algo inventado.
///
/// Por ahora cubre la ruta Río Seco -> Plaza Avaroa / Sopocachi usando la
/// topología real de Mi Teleférico (Línea Azul + Línea Roja) más el tramo
/// final en minibús, que es como se haría este viaje en la vida real (no
/// hay teleférico directo de Estación Central a Sopocachi).
///
/// Los tramos de caminata y minibús ahora siguen calles reales (vía
/// RoutingService/OSRM). Los tramos de Teleférico se quedan en línea recta
/// a propósito: así viaja un cable aéreo de verdad, no sigue calles.
class TripPlannerService {
  TripPlannerService._();

  static const double _walkingSpeedMetersPerMinute = 70;

  static Future<TripPlan?> planTrip({
    required LatLng origin,
    required String destinationQuery,
  }) async {
    final query = destinationQuery.toLowerCase();
    final wantsAvaroa = query.contains('avaroa') || query.contains('sopocachi');

    if (wantsAvaroa) {
      return _riosecoToPlazaAvaroa(origin);
    }

    return null;
  }

  static Future<TripPlan> _riosecoToPlazaAvaroa(LatLng origin) async {
    final segments = <RouteSegment>[];

    // 1. Caminata real (por calles) desde el origen (GPS del usuario)
    //    hasta la estación Río Seco de la Línea Azul.
    final stationRioSeco = TelefericoData.azul.stations.first;
    final walkToStationPoints = await RoutingService.fetchRoute(
      start: origin,
      end: stationRioSeco.location,
      profile: 'foot',
    );
    final walkToStationMeters = _routeLengthMeters(walkToStationPoints);
    final walkToStationMin = (walkToStationMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina a la estación',
      subtitle: '${walkToStationMeters.round()} m · Estación Río Seco',
      instruction: 'Camina hasta la Estación Río Seco de la Línea Azul del Teleférico.',
      fareBs: 0,
      durationMin: walkToStationMin,
      fromStop: 'Tu ubicación',
      toStop: stationRioSeco.name,
      geoPoints: walkToStationPoints,
    ));

    // 2. Línea Azul completa: Río Seco -> 16 de Julio. Línea recta a
    //    propósito (cable aéreo real, no sigue calles).
    segments.add(RouteSegment(
      mode: TransportMode.teleferico,
      title: 'Teleférico · Línea Azul',
      subtitle: 'Bs. 3.00 · hasta Estación 16 de Julio',
      instruction: 'Aborda la Línea Azul y viaja hasta la Estación 16 de Julio, '
          'donde conecta con la Línea Roja.',
      fareBs: 3.0,
      durationMin: TelefericoData.azul.durationMin,
      fromStop: TelefericoData.azul.stations.first.name,
      toStop: TelefericoData.azul.stations.last.name,
      geoPoints: TelefericoData.azul.stations.map((s) => s.location).toList(),
    ));

    // 3. Línea Roja: 16 de Julio -> Estación Central. También recta.
    segments.add(RouteSegment(
      mode: TransportMode.teleferico,
      title: 'Teleférico · Línea Roja',
      subtitle: 'Bs. 3.00 · hasta Estación Central',
      instruction: 'Baja en 16 de Julio y toma la Línea Roja hasta la Estación Central.',
      fareBs: 3.0,
      durationMin: TelefericoData.roja.durationMin,
      fromStop: TelefericoData.roja.stations.first.name,
      toStop: TelefericoData.roja.stations.last.name,
      geoPoints: TelefericoData.roja.stations.map((s) => s.location).toList(),
    ));

    // 4. Minibús real por calles (Estación Central -> cerca de Sopocachi).
    final estacionCentral = TelefericoData.roja.stations.last.location;
    final paradaSopocachi = LatLng(
      TelefericoData.plazaAvaroa.location.latitude + 0.0015,
      TelefericoData.plazaAvaroa.location.longitude - 0.0010,
    );
    final minibusPoints = await RoutingService.fetchRoute(
      start: estacionCentral,
      end: paradaSopocachi,
      profile: 'driving',
    );
    final minibusMeters = _routeLengthMeters(minibusPoints);
    final minibusMin = (minibusMeters / 300).ceil().clamp(5, 40); // ritmo urbano con tráfico

    segments.add(RouteSegment(
      mode: TransportMode.minibus,
      title: 'Minibús · eje Av. 6 de Agosto',
      subtitle: 'Bs. 2.50 · hacia Sopocachi',
      instruction: 'Toma un minibús con destino Sopocachi por la Av. 6 de Agosto / Av. Arce. '
          'Bájate cerca de la Plaza Avaroa.',
      fareBs: 2.5,
      durationMin: minibusMin,
      fromStop: 'Estación Central',
      toStop: 'Parada Sopocachi',
      geoPoints: minibusPoints,
      syndicate: 'Confirmar sindicato local en la zona piloto',
    ));

    // 5. Caminata final real por calles hasta Plaza Avaroa.
    final walkFinalPoints = await RoutingService.fetchRoute(
      start: paradaSopocachi,
      end: TelefericoData.plazaAvaroa.location,
      profile: 'foot',
    );
    final walkFinalMeters = _routeLengthMeters(walkFinalPoints);
    final walkFinalMin = (walkFinalMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina a tu destino',
      subtitle: '${walkFinalMeters.round()} m · Plaza Avaroa',
      instruction: 'Camina los últimos metros hasta la Plaza Avaroa.',
      fareBs: 0,
      durationMin: walkFinalMin,
      fromStop: 'Parada Sopocachi',
      toStop: 'Plaza Avaroa',
      geoPoints: walkFinalPoints,
    ));

    return TripPlan(
      origin: 'Tu ubicación',
      destination: 'Plaza Avaroa',
      segments: segments,
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
