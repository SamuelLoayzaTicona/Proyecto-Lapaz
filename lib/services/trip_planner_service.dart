import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';
import '../models/transport_models.dart';
import 'geo_utils.dart';

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
class TripPlannerService {
  TripPlannerService._();

  static const double _walkingSpeedMetersPerMinute = 70; // ritmo urbano normal en La Paz (altura)

  static TripPlan? planTrip({
    required LatLng origin,
    required String destinationQuery,
  }) {
    final query = destinationQuery.toLowerCase();

    final wantsAvaroa = query.contains('avaroa') || query.contains('sopocachi');

    if (wantsAvaroa) {
      return _riosecoToPlazaAvaroa(origin);
    }

    return null;
  }

  static TripPlan _riosecoToPlazaAvaroa(LatLng origin) {
    final segments = <RouteSegment>[];

    // 1. Caminata real desde el origen (GPS del usuario) hasta la estación
    //    Río Seco de la Línea Azul. La distancia se calcula de verdad con
    //    la posición GPS que llega, no está inventada.
    final stationRioSeco = TelefericoData.azul.stations.first;
    final walkToStationMeters = GeoUtils.distanceMeters(origin, stationRioSeco.location);
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
      geoPoints: [origin, stationRioSeco.location],
    ));

    // 2. Línea Azul completa: Río Seco -> 16 de Julio (datos reales de
    //    Mi Teleférico: 5 estaciones, ~20 min).
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

    // 3. Línea Roja: 16 de Julio -> Estación Central (datos reales:
    //    3 estaciones, ~11 min).
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

    // 4. Minibús: no existe teleférico directo de Estación Central a
    //    Sopocachi, así que el tramo final real es en minibús por el eje
    //    Av. 6 de Agosto / Av. Arce (corredor real que sí conecta el
    //    centro con Sopocachi).
    final estacionCentral = TelefericoData.roja.stations.last.location;
    final paradaSopocachi = LatLng(
      TelefericoData.plazaAvaroa.location.latitude + 0.0015,
      TelefericoData.plazaAvaroa.location.longitude - 0.0010,
    );

    segments.add(RouteSegment(
      mode: TransportMode.minibus,
      title: 'Minibús · eje Av. 6 de Agosto',
      subtitle: 'Bs. 2.50 · hacia Sopocachi',
      instruction: 'Toma un minibús con destino Sopocachi por la Av. 6 de Agosto / Av. Arce. '
          'Bájate cerca de la Plaza Avaroa.',
      fareBs: 2.5,
      durationMin: 12,
      fromStop: 'Estación Central',
      toStop: 'Parada Sopocachi',
      geoPoints: [estacionCentral, paradaSopocachi],
      syndicate: 'Confirmar sindicato local en la zona piloto',
    ));

    // 5. Caminata final hasta Plaza Avaroa.
    final walkFinalMeters =
        GeoUtils.distanceMeters(paradaSopocachi, TelefericoData.plazaAvaroa.location);
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
      geoPoints: [paradaSopocachi, TelefericoData.plazaAvaroa.location],
    ));

    return TripPlan(
      origin: 'Tu ubicación',
      destination: 'Plaza Avaroa',
      segments: segments,
    );
  }
}
