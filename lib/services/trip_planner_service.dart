import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';
import '../data/pumakatari_data.dart';
import '../data/minibus_data.dart';
import '../models/place.dart';
import '../models/transport_models.dart';
import 'geo_utils.dart';
import 'routing_service.dart';

class TripPlannerService {
  TripPlannerService._();

  static const double _walkingSpeedMetersPerMinute = 70;
  static const double _maxWalkToStationMeters = 1800;
  static const double _maxWalkBetweenTransfers = 500;

  // ============================================================
  // PUNTO DE ENTRADA PRINCIPAL
  // ============================================================

  static Future<List<TripPlan>> planTrip({
    required LatLng origin,
    required LatLng destination,
    required String destinationLabel,
  }) async {
    final List<TripPlan> opciones = [];

    print('🟢 Planificando ruta desde (${origin.latitude}, ${origin.longitude})');
    print('🟢 Hasta: $destinationLabel (${destination.latitude}, ${destination.longitude})');

    // 1. Opción: Minibús directo (siempre disponible con OSRM)
    final minibusDirecto = await _buildMinibusDirecto(origin, destination, destinationLabel);
    if (minibusDirecto != null) opciones.add(minibusDirecto);

    // 2. Opción: Teleférico (si hay estaciones cercanas)
    final teleferico = await _buildTeleferico(origin, destination, destinationLabel);
    if (teleferico != null) opciones.add(teleferico);

    // 3. Opción: PumaKatari (si el destino está cerca de una parada)
    final puma = await _buildPuma(origin, destination, destinationLabel);
    if (puma != null) opciones.add(puma);

    // 4. Opción: Minibús → Teleférico
    final minibusTeleferico = await _buildMinibusTeleferico(origin, destination, destinationLabel);
    if (minibusTeleferico != null) opciones.add(minibusTeleferico);

    // 5. Opción: Teleférico → Minibús
    final telefericoMinibus = await _buildTelefericoMinibus(origin, destination, destinationLabel);
    if (telefericoMinibus != null) opciones.add(telefericoMinibus);

    // 6. Opción: Minibús → PumaKatari
    final minibusPuma = await _buildMinibusPuma(origin, destination, destinationLabel);
    if (minibusPuma != null) opciones.add(minibusPuma);

    // 7. Opción: PumaKatari → Teleférico
    final pumaTeleferico = await _buildPumaTeleferico(origin, destination, destinationLabel);
    if (pumaTeleferico != null) opciones.add(pumaTeleferico);

    // 8. Opción: Teleférico → PumaKatari
    final telefericoPuma = await _buildTelefericoPuma(origin, destination, destinationLabel);
    if (telefericoPuma != null) opciones.add(telefericoPuma);

    // 9. Opción: Minibús → Minibús (transbordo)
    final minibusMinibus = await _buildMinibusMinibus(origin, destination, destinationLabel);
    if (minibusMinibus != null) opciones.add(minibusMinibus);

    // 10. Caminata directa (si está cerca)
    final distanceDirect = GeoUtils.distanceMeters(origin, destination);
    if (distanceDirect <= 900) {
      final walkPlan = await _buildWalkPlan(origin, destination, destinationLabel);
      if (walkPlan != null) opciones.add(walkPlan);
    }

    // Ordenar por tiempo total (más rápido primero)
    opciones.sort((a, b) => a.totalDurationMin.compareTo(b.totalDurationMin));

    print('✅ Opciones encontradas: ${opciones.length}');
    if (opciones.isNotEmpty) {
      print('🏆 Mejor opción: ${opciones.first.totalDurationMin} min');
    }

    // Devolver solo las 5 mejores opciones
    return opciones.take(5).toList();
  }

  // ============================================================
  // 1. MINIBÚS DIRECTO (OSRM)
  // ============================================================

  static Future<TripPlan?> _buildMinibusDirecto(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      final segments = <RouteSegment>[];

      final points = await RoutingService.fetchRoute(
        start: origin,
        end: destination,
        profile: 'driving',
      );

      final meters = _routeLengthMeters(points);
      final min = (meters / 300).ceil().clamp(5, 60);

      segments.add(RouteSegment(
        mode: TransportMode.minibus,
        title: 'Minibús directo',
        subtitle: 'Bs. 2.50 · ${min} min',
        instruction: 'Toma un minibús con destino a $destinationLabel.',
        fareBs: 2.5,
        durationMin: min,
        fromStop: 'Tu ubicación',
        toStop: destinationLabel,
        geoPoints: points,
        syndicate: 'Cualquier sindicato',
      ));

      return TripPlan(
        origin: 'Tu ubicación',
        destination: destinationLabel,
        segments: segments,
      );
    } catch (e) {
      print('❌ Error en Minibús directo: $e');
      return null;
    }
  }

  // ============================================================
  // 2. TELEFÉRICO
  // ============================================================

  static Future<TripPlan?> _buildTeleferico(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      final entryStation = TelefericoNetwork.nearestStation(origin);
      final exitStation = TelefericoNetwork.nearestStation(destination);

      final distanceToEntry = GeoUtils.distanceMeters(origin, entryStation.location);
      final distanceToExit = GeoUtils.distanceMeters(destination, exitStation.location);

      // Solo si ambas estaciones están cerca
      if (distanceToEntry > _maxWalkToStationMeters || distanceToExit > _maxWalkToStationMeters) {
        return null;
      }

      final segments = <RouteSegment>[];

      // Caminata a la estación de entrada
      final walkToEntryPoints = await RoutingService.fetchRoute(
        start: origin,
        end: entryStation.location,
        profile: 'foot',
      );
      final walkToEntryMeters = _routeLengthMeters(walkToEntryPoints);
      final walkToEntryMin = (walkToEntryMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a la estación',
        subtitle: '${walkToEntryMeters.round()} m · ${entryStation.name}',
        instruction: 'Camina hasta la estación ${entryStation.name}.',
        fareBs: 0,
        durationMin: walkToEntryMin,
        fromStop: 'Tu ubicación',
        toStop: entryStation.name,
        geoPoints: walkToEntryPoints,
      ));

      // Viaje en Teleférico
      final path = TelefericoNetwork.findPath(entryStation.name, exitStation.name);
      if (path != null) {
        for (final step in path) {
          final duration = ((step.line.durationMin / (step.line.stations.length - 1)) *
                  (step.stations.length - 1))
              .ceil()
              .clamp(2, step.line.durationMin);

          segments.add(RouteSegment(
            mode: TransportMode.teleferico,
            title: 'Teleférico · ${step.line.name}',
            subtitle: 'Bs. 3.00 · ${duration} min',
            instruction: 'Aborda la ${step.line.name} desde ${step.stations.first.name} hasta ${step.stations.last.name}.',
            fareBs: 3.0,
            durationMin: duration,
            fromStop: step.stations.first.name,
            toStop: step.stations.last.name,
            geoPoints: step.stations.map((s) => s.location).toList(),
          ));
        }
      }

      // Último tramo
      final lastLegMeters = GeoUtils.distanceMeters(exitStation.location, destination);
      if (lastLegMeters > 700) {
        final minibusPoints = await RoutingService.fetchRoute(
          start: exitStation.location,
          end: destination,
          profile: 'driving',
        );
        final minibusMeters = _routeLengthMeters(minibusPoints);
        final minibusMin = (minibusMeters / 300).ceil().clamp(5, 40);

        segments.add(RouteSegment(
          mode: TransportMode.minibus,
          title: 'Minibús',
          subtitle: 'Bs. 2.50 · ${minibusMin} min',
          instruction: 'Toma un minibús con destino a $destinationLabel.',
          fareBs: 2.5,
          durationMin: minibusMin,
          fromStop: exitStation.name,
          toStop: destinationLabel,
          geoPoints: minibusPoints,
          syndicate: 'Por confirmar',
        ));
      } else {
        final walkToDestPoints = await RoutingService.fetchRoute(
          start: exitStation.location,
          end: destination,
          profile: 'foot',
        );
        final walkToDestMeters = _routeLengthMeters(walkToDestPoints);
        final walkToDestMin = (walkToDestMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

        segments.add(RouteSegment(
          mode: TransportMode.walk,
          title: 'Camina a tu destino',
          subtitle: '${walkToDestMeters.round()} m',
          instruction: 'Camina hasta $destinationLabel.',
          fareBs: 0,
          durationMin: walkToDestMin,
          fromStop: exitStation.name,
          toStop: destinationLabel,
          geoPoints: walkToDestPoints,
        ));
      }

      return TripPlan(
        origin: 'Tu ubicación',
        destination: destinationLabel,
        segments: segments,
      );
    } catch (e) {
      print('❌ Error en Teleférico: $e');
      return null;
    }
  }

  // ============================================================
  // 3. PUMAKATARI
  // ============================================================

  static Future<TripPlan?> _buildPuma(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      for (final route in PumaKatariData.allRoutes) {
        // Buscar en IDA
        for (final stop in route.stops) {
          final distance = GeoUtils.distanceMeters(destination, stop.location);
          if (distance < 500) {
            return await _buildPumaRoute(origin, destination, destinationLabel, route, stop, false);
          }
        }

        // Buscar en VUELTA
        for (final stop in route.returnStops) {
          final distance = GeoUtils.distanceMeters(destination, stop.location);
          if (distance < 500) {
            return await _buildPumaRoute(origin, destination, destinationLabel, route, stop, true);
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error en Puma: $e');
      return null;
    }
  }

  static Future<TripPlan> _buildPumaRoute(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
    PumaKatariRoute route,
    Place destStop,
    bool isReturn,
  ) async {
    final segments = <RouteSegment>[];
    final stops = isReturn ? route.returnStops : route.stops;
    final times = isReturn ? route.returnTimes : route.times;

    // Encontrar parada más cercana al origen
    Place? nearestOriginStop;
    double minOriginDist = double.infinity;

    for (final s in stops) {
      final d = GeoUtils.distanceMeters(origin, s.location);
      if (d < minOriginDist) {
        minOriginDist = d;
        nearestOriginStop = s;
      }
    }

    if (nearestOriginStop == null) {
      return await _buildMinibusDirecto(origin, destination, destinationLabel) ??
          TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: []);
    }

    final originIndex = stops.indexWhere((s) => s.name == nearestOriginStop!.name);
    final destIndex = stops.indexWhere((s) => s.name == destStop.name);

    if (originIndex == -1 || destIndex == -1 || originIndex >= destIndex) {
      return await _buildMinibusDirecto(origin, destination, destinationLabel) ??
          TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: []);
    }

    // Caminata a la parada de origen
    if (minOriginDist > 50) {
      final walkPoints = await RoutingService.fetchRoute(
        start: origin,
        end: nearestOriginStop.location,
        profile: 'foot',
      );
      final walkMeters = _routeLengthMeters(walkPoints);
      final walkMin = (walkMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a la parada',
        subtitle: '${walkMeters.round()} m · ${nearestOriginStop.name}',
        instruction: 'Camina hasta la parada ${nearestOriginStop.name}.',
        fareBs: 0,
        durationMin: walkMin,
        fromStop: 'Tu ubicación',
        toStop: nearestOriginStop.name,
        geoPoints: walkPoints,
      ));
    }

    // Viaje en Puma
    final travelTime = times[destIndex] - times[originIndex];
    final pumaPoints = await _buildPumaRoutePoints(
      stops.sublist(originIndex, destIndex + 1),
    );

    segments.add(RouteSegment(
      mode: TransportMode.pumakatari,
      title: 'PumaKatari · ${route.name}',
      subtitle: 'Bs. ${route.fare.toStringAsFixed(2)} · ${travelTime} min',
      instruction: 'Aborda el PumaKatari en ${nearestOriginStop.name} y viaja hasta ${destStop.name}.',
      fareBs: route.fare,
      durationMin: travelTime,
      fromStop: nearestOriginStop.name,
      toStop: destStop.name,
      geoPoints: pumaPoints,
      syndicate: 'PumaKatari',
    ));

    // Caminata final
    final distanceToDest = GeoUtils.distanceMeters(destStop.location, destination);
    if (distanceToDest > 50) {
      final walkFinalPoints = await RoutingService.fetchRoute(
        start: destStop.location,
        end: destination,
        profile: 'foot',
      );
      final walkFinalMeters = _routeLengthMeters(walkFinalPoints);
      final walkFinalMin = (walkFinalMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a tu destino',
        subtitle: '${walkFinalMeters.round()} m',
        instruction: 'Camina hasta $destinationLabel.',
        fareBs: 0,
        durationMin: walkFinalMin,
        fromStop: destStop.name,
        toStop: destinationLabel,
        geoPoints: walkFinalPoints,
      ));
    }

    return TripPlan(
      origin: 'Tu ubicación',
      destination: destinationLabel,
      segments: segments,
    );
  }

  // ============================================================
  // 4. MINIBÚS → TELEFÉRICO
  // ============================================================

  static Future<TripPlan?> _buildMinibusTeleferico(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      // Encontrar un minibús cercano al origen
      final minibusRoute = MinibusData.findNearestRoute(origin);
      if (minibusRoute == null) return null;

      final minibusStartPoint = MinibusData.findNearestPointOnRoute(origin, minibusRoute);

      // Encontrar una estación de teleférico cercana a la ruta del minibús
      for (final line in TelefericoData.allLines) {
        for (final station in line.stations) {
          final distanceToStation = GeoUtils.distanceMeters(minibusStartPoint, station.location);
          if (distanceToStation < _maxWalkBetweenTransfers) {
            // El minibús te deja cerca de una estación de teleférico
            // Verificar si el teleférico te acerca al destino
            final exitStation = TelefericoNetwork.nearestStation(destination);
            final distanceExit = GeoUtils.distanceMeters(destination, exitStation.location);

            if (distanceExit <= _maxWalkToStationMeters) {
              return await _buildMinibusTelefericoRoute(
                origin,
                destination,
                destinationLabel,
                minibusRoute,
                minibusStartPoint,
                station,
                exitStation,
              );
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error en Minibús → Teleférico: $e');
      return null;
    }
  }

  static Future<TripPlan> _buildMinibusTelefericoRoute(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
    MinibusRoute minibusRoute,
    LatLng minibusStartPoint,
    Place teleStation,
    Place exitStation,
  ) async {
    final segments = <RouteSegment>[];

    // Caminata al punto de subida del minibús
    final walkToMinibusPoints = await RoutingService.fetchRoute(
      start: origin,
      end: minibusStartPoint,
      profile: 'foot',
    );
    final walkToMinibusMeters = _routeLengthMeters(walkToMinibusPoints);
    final walkToMinibusMin = (walkToMinibusMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al minibús',
      subtitle: '${walkToMinibusMeters.round()} m',
      instruction: 'Camina al punto de subida del minibús.',
      fareBs: 0,
      durationMin: walkToMinibusMin,
      fromStop: 'Tu ubicación',
      toStop: 'Punto de subida',
      geoPoints: walkToMinibusPoints,
    ));

    // Viaje en minibús hasta la estación de teleférico
    final minibusPoints = await RoutingService.fetchRoute(
      start: minibusStartPoint,
      end: teleStation.location,
      profile: 'driving',
    );
    final minibusMeters = _routeLengthMeters(minibusPoints);
    final minibusMin = (minibusMeters / 300).ceil().clamp(5, 40);

    segments.add(RouteSegment(
      mode: TransportMode.minibus,
      title: 'Minibús · ${minibusRoute.name}',
      subtitle: 'Bs. ${minibusRoute.fare.toStringAsFixed(2)} · ${minibusMin} min',
      instruction: 'Toma el minibús ${minibusRoute.name} hasta ${teleStation.name}.',
      fareBs: minibusRoute.fare,
      durationMin: minibusMin,
      fromStop: 'Punto de subida',
      toStop: teleStation.name,
      geoPoints: minibusPoints,
      syndicate: minibusRoute.syndicate,
    ));

    // Caminata a la estación de teleférico
    final walkToTelePoints = await RoutingService.fetchRoute(
      start: teleStation.location,
      end: teleStation.location, // Ya estás en la estación
      profile: 'foot',
    );

    // Viaje en teleférico
    final path = TelefericoNetwork.findPath(teleStation.name, exitStation.name);
    if (path != null) {
      for (final step in path) {
        final duration = ((step.line.durationMin / (step.line.stations.length - 1)) *
                (step.stations.length - 1))
            .ceil()
            .clamp(2, step.line.durationMin);

        segments.add(RouteSegment(
          mode: TransportMode.teleferico,
          title: 'Teleférico · ${step.line.name}',
          subtitle: 'Bs. 3.00 · ${duration} min',
          instruction: 'Aborda la ${step.line.name} desde ${step.stations.first.name} hasta ${step.stations.last.name}.',
          fareBs: 3.0,
          durationMin: duration,
          fromStop: step.stations.first.name,
          toStop: step.stations.last.name,
          geoPoints: step.stations.map((s) => s.location).toList(),
        ));
      }
    }

    // Último tramo al destino
    final lastLegMeters = GeoUtils.distanceMeters(exitStation.location, destination);
    if (lastLegMeters > 700) {
      final minibusFinalPoints = await RoutingService.fetchRoute(
        start: exitStation.location,
        end: destination,
        profile: 'driving',
      );
      final minibusFinalMeters = _routeLengthMeters(minibusFinalPoints);
      final minibusFinalMin = (minibusFinalMeters / 300).ceil().clamp(5, 40);

      segments.add(RouteSegment(
        mode: TransportMode.minibus,
        title: 'Minibús final',
        subtitle: 'Bs. 2.50 · ${minibusFinalMin} min',
        instruction: 'Toma un minibús hasta $destinationLabel.',
        fareBs: 2.5,
        durationMin: minibusFinalMin,
        fromStop: exitStation.name,
        toStop: destinationLabel,
        geoPoints: minibusFinalPoints,
        syndicate: 'Por confirmar',
      ));
    } else {
      final walkFinalPoints = await RoutingService.fetchRoute(
        start: exitStation.location,
        end: destination,
        profile: 'foot',
      );
      final walkFinalMeters = _routeLengthMeters(walkFinalPoints);
      final walkFinalMin = (walkFinalMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a tu destino',
        subtitle: '${walkFinalMeters.round()} m',
        instruction: 'Camina hasta $destinationLabel.',
        fareBs: 0,
        durationMin: walkFinalMin,
        fromStop: exitStation.name,
        toStop: destinationLabel,
        geoPoints: walkFinalPoints,
      ));
    }

    return TripPlan(
      origin: 'Tu ubicación',
      destination: destinationLabel,
      segments: segments,
    );
  }

  // ============================================================
  // 5. TELEFÉRICO → MINIBÚS
  // ============================================================

  static Future<TripPlan?> _buildTelefericoMinibus(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      // Encontrar estación de teleférico cercana al origen
      final entryStation = TelefericoNetwork.nearestStation(origin);
      final distanceEntry = GeoUtils.distanceMeters(origin, entryStation.location);

      if (distanceEntry > _maxWalkToStationMeters) return null;

      // Encontrar un minibús cercano al destino
      final minibusRoute = MinibusData.findNearestRoute(destination);
      if (minibusRoute == null) return null;

      final minibusEndPoint = MinibusData.findNearestPointOnRoute(destination, minibusRoute);

      // Encontrar una estación de teleférico cercana a la ruta del minibús
      for (final line in TelefericoData.allLines) {
        for (final station in line.stations) {
          final distanceToStation = GeoUtils.distanceMeters(minibusEndPoint, station.location);
          if (distanceToStation < _maxWalkBetweenTransfers) {
            // El minibús pasa cerca de una estación de teleférico
            final path = TelefericoNetwork.findPath(entryStation.name, station.name);
            if (path != null) {
              return await _buildTelefericoMinibusRoute(
                origin,
                destination,
                destinationLabel,
                entryStation,
                station,
                minibusRoute,
                minibusEndPoint,
              );
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error en Teleférico → Minibús: $e');
      return null;
    }
  }

  static Future<TripPlan> _buildTelefericoMinibusRoute(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
    Place entryStation,
    Place transferStation,
    MinibusRoute minibusRoute,
    LatLng minibusEndPoint,
  ) async {
    final segments = <RouteSegment>[];

    // Caminata a la estación de teleférico
    final walkToTelePoints = await RoutingService.fetchRoute(
      start: origin,
      end: entryStation.location,
      profile: 'foot',
    );
    final walkToTeleMeters = _routeLengthMeters(walkToTelePoints);
    final walkToTeleMin = (walkToTeleMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al teleférico',
      subtitle: '${walkToTeleMeters.round()} m · ${entryStation.name}',
      instruction: 'Camina hasta la estación ${entryStation.name}.',
      fareBs: 0,
      durationMin: walkToTeleMin,
      fromStop: 'Tu ubicación',
      toStop: entryStation.name,
      geoPoints: walkToTelePoints,
    ));

    // Viaje en teleférico
    final path = TelefericoNetwork.findPath(entryStation.name, transferStation.name);
    if (path != null) {
      for (final step in path) {
        final duration = ((step.line.durationMin / (step.line.stations.length - 1)) *
                (step.stations.length - 1))
            .ceil()
            .clamp(2, step.line.durationMin);

        segments.add(RouteSegment(
          mode: TransportMode.teleferico,
          title: 'Teleférico · ${step.line.name}',
          subtitle: 'Bs. 3.00 · ${duration} min',
          instruction: 'Aborda la ${step.line.name} desde ${step.stations.first.name} hasta ${step.stations.last.name}.',
          fareBs: 3.0,
          durationMin: duration,
          fromStop: step.stations.first.name,
          toStop: step.stations.last.name,
          geoPoints: step.stations.map((s) => s.location).toList(),
        ));
      }
    }

    // Caminata al punto de bajada del minibús
    final walkToMinibusPoints = await RoutingService.fetchRoute(
      start: transferStation.location,
      end: minibusEndPoint,
      profile: 'foot',
    );
    final walkToMinibusMeters = _routeLengthMeters(walkToMinibusPoints);
    final walkToMinibusMin = (walkToMinibusMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al minibús',
      subtitle: '${walkToMinibusMeters.round()} m',
      instruction: 'Camina al punto de bajada del minibús.',
      fareBs: 0,
      durationMin: walkToMinibusMin,
      fromStop: transferStation.name,
      toStop: 'Punto de bajada',
      geoPoints: walkToMinibusPoints,
    ));

    // Viaje en minibús
    final minibusPoints = await RoutingService.fetchRoute(
      start: minibusEndPoint,
      end: destination,
      profile: 'driving',
    );
    final minibusMeters = _routeLengthMeters(minibusPoints);
    final minibusMin = (minibusMeters / 300).ceil().clamp(5, 40);

    segments.add(RouteSegment(
      mode: TransportMode.minibus,
      title: 'Minibús · ${minibusRoute.name}',
      subtitle: 'Bs. ${minibusRoute.fare.toStringAsFixed(2)} · ${minibusMin} min',
      instruction: 'Toma el minibús ${minibusRoute.name} hasta $destinationLabel.',
      fareBs: minibusRoute.fare,
      durationMin: minibusMin,
      fromStop: 'Punto de bajada',
      toStop: destinationLabel,
      geoPoints: minibusPoints,
      syndicate: minibusRoute.syndicate,
    ));

    return TripPlan(
      origin: 'Tu ubicación',
      destination: destinationLabel,
      segments: segments,
    );
  }

  // ============================================================
  // 6. MINIBÚS → PUMAKATARI
  // ============================================================

  static Future<TripPlan?> _buildMinibusPuma(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      final minibusRoute = MinibusData.findNearestRoute(origin);
      if (minibusRoute == null) return null;

      final minibusStartPoint = MinibusData.findNearestPointOnRoute(origin, minibusRoute);

      // Buscar una parada de Puma cerca de la ruta del minibús
      for (final route in PumaKatariData.allRoutes) {
        for (final stop in route.stops) {
          final distanceToStop = GeoUtils.distanceMeters(minibusStartPoint, stop.location);
          if (distanceToStop < _maxWalkBetweenTransfers) {
            // Verificar si el Puma te acerca al destino
            for (final destStop in route.stops) {
              final distanceToDest = GeoUtils.distanceMeters(destination, destStop.location);
              if (distanceToDest < 500) {
                return await _buildMinibusPumaRoute(
                  origin,
                  destination,
                  destinationLabel,
                  minibusRoute,
                  minibusStartPoint,
                  route,
                  stop,
                  destStop,
                  false,
                );
              }
            }
            for (final destStop in route.returnStops) {
              final distanceToDest = GeoUtils.distanceMeters(destination, destStop.location);
              if (distanceToDest < 500) {
                return await _buildMinibusPumaRoute(
                  origin,
                  destination,
                  destinationLabel,
                  minibusRoute,
                  minibusStartPoint,
                  route,
                  stop,
                  destStop,
                  true,
                );
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error en Minibús → Puma: $e');
      return null;
    }
  }

  static Future<TripPlan> _buildMinibusPumaRoute(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
    MinibusRoute minibusRoute,
    LatLng minibusStartPoint,
    PumaKatariRoute pumaRoute,
    Place pumaStartStop,
    Place pumaDestStop,
    bool isReturn,
  ) async {
    final segments = <RouteSegment>[];
    final stops = isReturn ? pumaRoute.returnStops : pumaRoute.stops;
    final times = isReturn ? pumaRoute.returnTimes : pumaRoute.times;

    final startIndex = stops.indexWhere((s) => s.name == pumaStartStop.name);
    final destIndex = stops.indexWhere((s) => s.name == pumaDestStop.name);

    if (startIndex == -1 || destIndex == -1 || startIndex >= destIndex) {
      return await _buildMinibusDirecto(origin, destination, destinationLabel) ??
          TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: []);
    }

    // Caminata al minibús
    final walkToMinibusPoints = await RoutingService.fetchRoute(
      start: origin,
      end: minibusStartPoint,
      profile: 'foot',
    );
    final walkToMinibusMeters = _routeLengthMeters(walkToMinibusPoints);
    final walkToMinibusMin = (walkToMinibusMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al minibús',
      subtitle: '${walkToMinibusMeters.round()} m',
      instruction: 'Camina al punto de subida del minibús.',
      fareBs: 0,
      durationMin: walkToMinibusMin,
      fromStop: 'Tu ubicación',
      toStop: 'Punto de subida',
      geoPoints: walkToMinibusPoints,
    ));

    // Minibús hasta la parada de Puma
    final minibusPoints = await RoutingService.fetchRoute(
      start: minibusStartPoint,
      end: pumaStartStop.location,
      profile: 'driving',
    );
    final minibusMeters = _routeLengthMeters(minibusPoints);
    final minibusMin = (minibusMeters / 300).ceil().clamp(5, 40);

    segments.add(RouteSegment(
      mode: TransportMode.minibus,
      title: 'Minibús · ${minibusRoute.name}',
      subtitle: 'Bs. ${minibusRoute.fare.toStringAsFixed(2)} · ${minibusMin} min',
      instruction: 'Toma el minibús ${minibusRoute.name} hasta ${pumaStartStop.name}.',
      fareBs: minibusRoute.fare,
      durationMin: minibusMin,
      fromStop: 'Punto de subida',
      toStop: pumaStartStop.name,
      geoPoints: minibusPoints,
      syndicate: minibusRoute.syndicate,
    ));

    // PumaKatari
    final travelTime = times[destIndex] - times[startIndex];
    final pumaPoints = await _buildPumaRoutePoints(
      stops.sublist(startIndex, destIndex + 1),
    );

    segments.add(RouteSegment(
      mode: TransportMode.pumakatari,
      title: 'PumaKatari · ${pumaRoute.name}',
      subtitle: 'Bs. ${pumaRoute.fare.toStringAsFixed(2)} · ${travelTime} min',
      instruction: 'Aborda el PumaKatari en ${pumaStartStop.name} y viaja hasta ${pumaDestStop.name}.',
      fareBs: pumaRoute.fare,
      durationMin: travelTime,
      fromStop: pumaStartStop.name,
      toStop: pumaDestStop.name,
      geoPoints: pumaPoints,
      syndicate: 'PumaKatari',
    ));

    // Caminata al destino
    final distanceToDest = GeoUtils.distanceMeters(pumaDestStop.location, destination);
    if (distanceToDest > 50) {
      final walkFinalPoints = await RoutingService.fetchRoute(
        start: pumaDestStop.location,
        end: destination,
        profile: 'foot',
      );
      final walkFinalMeters = _routeLengthMeters(walkFinalPoints);
      final walkFinalMin = (walkFinalMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a tu destino',
        subtitle: '${walkFinalMeters.round()} m',
        instruction: 'Camina hasta $destinationLabel.',
        fareBs: 0,
        durationMin: walkFinalMin,
        fromStop: pumaDestStop.name,
        toStop: destinationLabel,
        geoPoints: walkFinalPoints,
      ));
    }

    return TripPlan(
      origin: 'Tu ubicación',
      destination: destinationLabel,
      segments: segments,
    );
  }

  // ============================================================
  // 7. PUMAKATARI → TELEFÉRICO
  // ============================================================

  static Future<TripPlan?> _buildPumaTeleferico(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      // Encontrar una parada de Puma cercana al origen
      for (final route in PumaKatariData.allRoutes) {
        for (final stop in route.stops) {
          final distanceToStop = GeoUtils.distanceMeters(origin, stop.location);
          if (distanceToStop < 500) {
            // Encontrar una estación de teleférico cerca de la ruta del Puma
            for (final line in TelefericoData.allLines) {
              for (final station in line.stations) {
                final distanceToStation = GeoUtils.distanceMeters(stop.location, station.location);
                if (distanceToStation < _maxWalkBetweenTransfers) {
                  final exitStation = TelefericoNetwork.nearestStation(destination);
                  final distanceExit = GeoUtils.distanceMeters(destination, exitStation.location);

                  if (distanceExit <= _maxWalkToStationMeters) {
                    return await _buildPumaTelefericoRoute(
                      origin,
                      destination,
                      destinationLabel,
                      route,
                      stop,
                      station,
                      exitStation,
                      false,
                    );
                  }
                }
              }
            }
          }
        }
        for (final stop in route.returnStops) {
          final distanceToStop = GeoUtils.distanceMeters(origin, stop.location);
          if (distanceToStop < 500) {
            for (final line in TelefericoData.allLines) {
              for (final station in line.stations) {
                final distanceToStation = GeoUtils.distanceMeters(stop.location, station.location);
                if (distanceToStation < _maxWalkBetweenTransfers) {
                  final exitStation = TelefericoNetwork.nearestStation(destination);
                  final distanceExit = GeoUtils.distanceMeters(destination, exitStation.location);

                  if (distanceExit <= _maxWalkToStationMeters) {
                    return await _buildPumaTelefericoRoute(
                      origin,
                      destination,
                      destinationLabel,
                      route,
                      stop,
                      station,
                      exitStation,
                      true,
                    );
                  }
                }
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error en Puma → Teleférico: $e');
      return null;
    }
  }

  static Future<TripPlan> _buildPumaTelefericoRoute(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
    PumaKatariRoute pumaRoute,
    Place pumaStartStop,
    Place teleStation,
    Place exitStation,
    bool isReturn,
  ) async {
    final segments = <RouteSegment>[];
    final stops = isReturn ? pumaRoute.returnStops : pumaRoute.stops;
    final times = isReturn ? pumaRoute.returnTimes : pumaRoute.times;

    // Encontrar la parada de Puma más cercana al origen
    Place? nearestOriginStop;
    double minOriginDist = double.infinity;

    for (final s in stops) {
      final d = GeoUtils.distanceMeters(origin, s.location);
      if (d < minOriginDist) {
        minOriginDist = d;
        nearestOriginStop = s;
      }
    }

    if (nearestOriginStop == null) {
      return await _buildMinibusDirecto(origin, destination, destinationLabel) ??
          TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: []);
    }

    final startIndex = stops.indexWhere((s) => s.name == nearestOriginStop!.name);
    final destIndex = stops.indexWhere((s) => s.name == pumaStartStop.name);

    if (startIndex == -1 || destIndex == -1 || startIndex >= destIndex) {
      return await _buildMinibusDirecto(origin, destination, destinationLabel) ??
          TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: []);
    }

    // Caminata a la parada de Puma
    if (minOriginDist > 50) {
      final walkPoints = await RoutingService.fetchRoute(
        start: origin,
        end: nearestOriginStop.location,
        profile: 'foot',
      );
      final walkMeters = _routeLengthMeters(walkPoints);
      final walkMin = (walkMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a la parada',
        subtitle: '${walkMeters.round()} m · ${nearestOriginStop.name}',
        instruction: 'Camina hasta la parada ${nearestOriginStop.name}.',
        fareBs: 0,
        durationMin: walkMin,
        fromStop: 'Tu ubicación',
        toStop: nearestOriginStop.name,
        geoPoints: walkPoints,
      ));
    }

    // PumaKatari
    final travelTime = times[destIndex] - times[startIndex];
    final pumaPoints = await _buildPumaRoutePoints(
      stops.sublist(startIndex, destIndex + 1),
    );

    segments.add(RouteSegment(
      mode: TransportMode.pumakatari,
      title: 'PumaKatari · ${pumaRoute.name}',
      subtitle: 'Bs. ${pumaRoute.fare.toStringAsFixed(2)} · ${travelTime} min',
      instruction: 'Aborda el PumaKatari en ${nearestOriginStop.name} y viaja hasta ${pumaStartStop.name}.',
      fareBs: pumaRoute.fare,
      durationMin: travelTime,
      fromStop: nearestOriginStop.name,
      toStop: pumaStartStop.name,
      geoPoints: pumaPoints,
      syndicate: 'PumaKatari',
    ));

    // Caminata al teleférico
    final walkToTelePoints = await RoutingService.fetchRoute(
      start: pumaStartStop.location,
      end: teleStation.location,
      profile: 'foot',
    );
    final walkToTeleMeters = _routeLengthMeters(walkToTelePoints);
    final walkToTeleMin = (walkToTeleMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al teleférico',
      subtitle: '${walkToTeleMeters.round()} m',
      instruction: 'Camina hasta la estación ${teleStation.name}.',
      fareBs: 0,
      durationMin: walkToTeleMin,
      fromStop: pumaStartStop.name,
      toStop: teleStation.name,
      geoPoints: walkToTelePoints,
    ));

    // Teleférico
    final path = TelefericoNetwork.findPath(teleStation.name, exitStation.name);
    if (path != null) {
      for (final step in path) {
        final duration = ((step.line.durationMin / (step.line.stations.length - 1)) *
                (step.stations.length - 1))
            .ceil()
            .clamp(2, step.line.durationMin);

        segments.add(RouteSegment(
          mode: TransportMode.teleferico,
          title: 'Teleférico · ${step.line.name}',
          subtitle: 'Bs. 3.00 · ${duration} min',
          instruction: 'Aborda la ${step.line.name} desde ${step.stations.first.name} hasta ${step.stations.last.name}.',
          fareBs: 3.0,
          durationMin: duration,
          fromStop: step.stations.first.name,
          toStop: step.stations.last.name,
          geoPoints: step.stations.map((s) => s.location).toList(),
        ));
      }
    }

    // Último tramo al destino
    final lastLegMeters = GeoUtils.distanceMeters(exitStation.location, destination);
    if (lastLegMeters > 700) {
      final minibusFinalPoints = await RoutingService.fetchRoute(
        start: exitStation.location,
        end: destination,
        profile: 'driving',
      );
      final minibusFinalMeters = _routeLengthMeters(minibusFinalPoints);
      final minibusFinalMin = (minibusFinalMeters / 300).ceil().clamp(5, 40);

      segments.add(RouteSegment(
        mode: TransportMode.minibus,
        title: 'Minibús final',
        subtitle: 'Bs. 2.50 · ${minibusFinalMin} min',
        instruction: 'Toma un minibús hasta $destinationLabel.',
        fareBs: 2.5,
        durationMin: minibusFinalMin,
        fromStop: exitStation.name,
        toStop: destinationLabel,
        geoPoints: minibusFinalPoints,
        syndicate: 'Por confirmar',
      ));
    } else {
      final walkFinalPoints = await RoutingService.fetchRoute(
        start: exitStation.location,
        end: destination,
        profile: 'foot',
      );
      final walkFinalMeters = _routeLengthMeters(walkFinalPoints);
      final walkFinalMin = (walkFinalMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a tu destino',
        subtitle: '${walkFinalMeters.round()} m',
        instruction: 'Camina hasta $destinationLabel.',
        fareBs: 0,
        durationMin: walkFinalMin,
        fromStop: exitStation.name,
        toStop: destinationLabel,
        geoPoints: walkFinalPoints,
      ));
    }

    return TripPlan(
      origin: 'Tu ubicación',
      destination: destinationLabel,
      segments: segments,
    );
  }

  // ============================================================
  // 8. TELEFÉRICO → PUMAKATARI
  // ============================================================

  static Future<TripPlan?> _buildTelefericoPuma(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      final entryStation = TelefericoNetwork.nearestStation(origin);
      final distanceEntry = GeoUtils.distanceMeters(origin, entryStation.location);

      if (distanceEntry > _maxWalkToStationMeters) return null;

      // Encontrar una parada de Puma cerca del destino
      for (final route in PumaKatariData.allRoutes) {
        for (final stop in route.stops) {
          final distanceToDest = GeoUtils.distanceMeters(destination, stop.location);
          if (distanceToDest < 500) {
            // Encontrar una estación de teleférico cerca de la ruta del Puma
            for (final line in TelefericoData.allLines) {
              for (final station in line.stations) {
                final distanceToStation = GeoUtils.distanceMeters(stop.location, station.location);
                if (distanceToStation < _maxWalkBetweenTransfers) {
                  final path = TelefericoNetwork.findPath(entryStation.name, station.name);
                  if (path != null) {
                    return await _buildTelefericoPumaRoute(
                      origin,
                      destination,
                      destinationLabel,
                      entryStation,
                      station,
                      route,
                      stop,
                      false,
                    );
                  }
                }
              }
            }
          }
        }
        for (final stop in route.returnStops) {
          final distanceToDest = GeoUtils.distanceMeters(destination, stop.location);
          if (distanceToDest < 500) {
            for (final line in TelefericoData.allLines) {
              for (final station in line.stations) {
                final distanceToStation = GeoUtils.distanceMeters(stop.location, station.location);
                if (distanceToStation < _maxWalkBetweenTransfers) {
                  final path = TelefericoNetwork.findPath(entryStation.name, station.name);
                  if (path != null) {
                    return await _buildTelefericoPumaRoute(
                      origin,
                      destination,
                      destinationLabel,
                      entryStation,
                      station,
                      route,
                      stop,
                      true,
                    );
                  }
                }
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error en Teleférico → Puma: $e');
      return null;
    }
  }

  static Future<TripPlan> _buildTelefericoPumaRoute(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
    Place entryStation,
    Place transferStation,
    PumaKatariRoute pumaRoute,
    Place pumaDestStop,
    bool isReturn,
  ) async {
    final segments = <RouteSegment>[];
    final stops = isReturn ? pumaRoute.returnStops : pumaRoute.stops;
    final times = isReturn ? pumaRoute.returnTimes : pumaRoute.times;

    // Encontrar la parada de Puma más cercana al origen
    Place? nearestOriginStop;
    double minOriginDist = double.infinity;

    for (final s in stops) {
      final d = GeoUtils.distanceMeters(origin, s.location);
      if (d < minOriginDist) {
        minOriginDist = d;
        nearestOriginStop = s;
      }
    }

    if (nearestOriginStop == null) {
      return await _buildMinibusDirecto(origin, destination, destinationLabel) ??
          TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: []);
    }

    final startIndex = stops.indexWhere((s) => s.name == nearestOriginStop!.name);
    final destIndex = stops.indexWhere((s) => s.name == pumaDestStop.name);

    if (startIndex == -1 || destIndex == -1 || startIndex >= destIndex) {
      return await _buildMinibusDirecto(origin, destination, destinationLabel) ??
          TripPlan(origin: 'Tu ubicación', destination: destinationLabel, segments: []);
    }

    // Caminata al teleférico
    final walkToTelePoints = await RoutingService.fetchRoute(
      start: origin,
      end: entryStation.location,
      profile: 'foot',
    );
    final walkToTeleMeters = _routeLengthMeters(walkToTelePoints);
    final walkToTeleMin = (walkToTeleMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al teleférico',
      subtitle: '${walkToTeleMeters.round()} m · ${entryStation.name}',
      instruction: 'Camina hasta la estación ${entryStation.name}.',
      fareBs: 0,
      durationMin: walkToTeleMin,
      fromStop: 'Tu ubicación',
      toStop: entryStation.name,
      geoPoints: walkToTelePoints,
    ));

    // Teleférico
    final path = TelefericoNetwork.findPath(entryStation.name, transferStation.name);
    if (path != null) {
      for (final step in path) {
        final duration = ((step.line.durationMin / (step.line.stations.length - 1)) *
                (step.stations.length - 1))
            .ceil()
            .clamp(2, step.line.durationMin);

        segments.add(RouteSegment(
          mode: TransportMode.teleferico,
          title: 'Teleférico · ${step.line.name}',
          subtitle: 'Bs. 3.00 · ${duration} min',
          instruction: 'Aborda la ${step.line.name} desde ${step.stations.first.name} hasta ${step.stations.last.name}.',
          fareBs: 3.0,
          durationMin: duration,
          fromStop: step.stations.first.name,
          toStop: step.stations.last.name,
          geoPoints: step.stations.map((s) => s.location).toList(),
        ));
      }
    }

    // Caminata al Puma
    final walkToPumaPoints = await RoutingService.fetchRoute(
      start: transferStation.location,
      end: nearestOriginStop.location,
      profile: 'foot',
    );
    final walkToPumaMeters = _routeLengthMeters(walkToPumaPoints);
    final walkToPumaMin = (walkToPumaMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al Puma',
      subtitle: '${walkToPumaMeters.round()} m',
      instruction: 'Camina hasta la parada ${nearestOriginStop.name}.',
      fareBs: 0,
      durationMin: walkToPumaMin,
      fromStop: transferStation.name,
      toStop: nearestOriginStop.name,
      geoPoints: walkToPumaPoints,
    ));

    // PumaKatari
    final travelTime = times[destIndex] - times[startIndex];
    final pumaPoints = await _buildPumaRoutePoints(
      stops.sublist(startIndex, destIndex + 1),
    );

    segments.add(RouteSegment(
      mode: TransportMode.pumakatari,
      title: 'PumaKatari · ${pumaRoute.name}',
      subtitle: 'Bs. ${pumaRoute.fare.toStringAsFixed(2)} · ${travelTime} min',
      instruction: 'Aborda el PumaKatari en ${nearestOriginStop.name} y viaja hasta ${pumaDestStop.name}.',
      fareBs: pumaRoute.fare,
      durationMin: travelTime,
      fromStop: nearestOriginStop.name,
      toStop: pumaDestStop.name,
      geoPoints: pumaPoints,
      syndicate: 'PumaKatari',
    ));

    // Caminata al destino
    final distanceToDest = GeoUtils.distanceMeters(pumaDestStop.location, destination);
    if (distanceToDest > 50) {
      final walkFinalPoints = await RoutingService.fetchRoute(
        start: pumaDestStop.location,
        end: destination,
        profile: 'foot',
      );
      final walkFinalMeters = _routeLengthMeters(walkFinalPoints);
      final walkFinalMin = (walkFinalMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a tu destino',
        subtitle: '${walkFinalMeters.round()} m',
        instruction: 'Camina hasta $destinationLabel.',
        fareBs: 0,
        durationMin: walkFinalMin,
        fromStop: pumaDestStop.name,
        toStop: destinationLabel,
        geoPoints: walkFinalPoints,
      ));
    }

    return TripPlan(
      origin: 'Tu ubicación',
      destination: destinationLabel,
      segments: segments,
    );
  }

  // ============================================================
  // 9. MINIBÚS → MINIBÚS (transbordo)
  // ============================================================

  static Future<TripPlan?> _buildMinibusMinibus(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      final firstRoute = MinibusData.findNearestRoute(origin);
      if (firstRoute == null) return null;

      final startPoint = MinibusData.findNearestPointOnRoute(origin, firstRoute);

      // Encontrar otra ruta de minibús que pase cerca
      for (final secondRoute in MinibusData.allRoutes) {
        if (secondRoute.id == firstRoute.id) continue;

        final endPoint = MinibusData.findNearestPointOnRoute(destination, secondRoute);
        if (endPoint == null) continue;

        // Verificar si las rutas se cruzan cerca
        for (final point1 in firstRoute.points) {
          for (final point2 in secondRoute.points) {
            final distance = GeoUtils.distanceMeters(point1, point2);
            if (distance < _maxWalkBetweenTransfers) {
              // Las rutas se cruzan cerca
              final minibusFinalMeters = GeoUtils.distanceMeters(endPoint, destination);
              if (minibusFinalMeters < 500) {
                return await _buildMinibusMinibusRoute(
                  origin,
                  destination,
                  destinationLabel,
                  firstRoute,
                  secondRoute,
                  startPoint,
                  point1,
                  point2,
                  endPoint,
                );
              }
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error en Minibús → Minibús: $e');
      return null;
    }
  }

  static Future<TripPlan> _buildMinibusMinibusRoute(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
    MinibusRoute firstRoute,
    MinibusRoute secondRoute,
    LatLng startPoint,
    LatLng transferPoint1,
    LatLng transferPoint2,
    LatLng endPoint,
  ) async {
    final segments = <RouteSegment>[];

    // Caminata al primer minibús
    final walkToFirstPoints = await RoutingService.fetchRoute(
      start: origin,
      end: startPoint,
      profile: 'foot',
    );
    final walkToFirstMeters = _routeLengthMeters(walkToFirstPoints);
    final walkToFirstMin = (walkToFirstMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al minibús',
      subtitle: '${walkToFirstMeters.round()} m',
      instruction: 'Camina al punto de subida del minibús ${firstRoute.name}.',
      fareBs: 0,
      durationMin: walkToFirstMin,
      fromStop: 'Tu ubicación',
      toStop: 'Punto de subida',
      geoPoints: walkToFirstPoints,
    ));

    // Primer minibús
    final firstMinibusPoints = await RoutingService.fetchRoute(
      start: startPoint,
      end: transferPoint1,
      profile: 'driving',
    );
    final firstMinibusMeters = _routeLengthMeters(firstMinibusPoints);
    final firstMinibusMin = (firstMinibusMeters / 300).ceil().clamp(5, 40);

    segments.add(RouteSegment(
      mode: TransportMode.minibus,
      title: 'Minibús · ${firstRoute.name}',
      subtitle: 'Bs. ${firstRoute.fare.toStringAsFixed(2)} · ${firstMinibusMin} min',
      instruction: 'Toma el minibús ${firstRoute.name} hasta el punto de transbordo.',
      fareBs: firstRoute.fare,
      durationMin: firstMinibusMin,
      fromStop: 'Punto de subida',
      toStop: 'Transbordo',
      geoPoints: firstMinibusPoints,
      syndicate: firstRoute.syndicate,
    ));

    // Caminata al segundo minibús
    final walkToSecondPoints = await RoutingService.fetchRoute(
      start: transferPoint1,
      end: transferPoint2,
      profile: 'foot',
    );
    final walkToSecondMeters = _routeLengthMeters(walkToSecondPoints);
    final walkToSecondMin = (walkToSecondMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

    segments.add(RouteSegment(
      mode: TransportMode.walk,
      title: 'Camina al otro minibús',
      subtitle: '${walkToSecondMeters.round()} m',
      instruction: 'Camina al punto de subida del minibús ${secondRoute.name}.',
      fareBs: 0,
      durationMin: walkToSecondMin,
      fromStop: 'Transbordo',
      toStop: 'Punto de subida 2',
      geoPoints: walkToSecondPoints,
    ));

    // Segundo minibús
    final secondMinibusPoints = await RoutingService.fetchRoute(
      start: transferPoint2,
      end: endPoint,
      profile: 'driving',
    );
    final secondMinibusMeters = _routeLengthMeters(secondMinibusPoints);
    final secondMinibusMin = (secondMinibusMeters / 300).ceil().clamp(5, 40);

    segments.add(RouteSegment(
      mode: TransportMode.minibus,
      title: 'Minibús · ${secondRoute.name}',
      subtitle: 'Bs. ${secondRoute.fare.toStringAsFixed(2)} · ${secondMinibusMin} min',
      instruction: 'Toma el minibús ${secondRoute.name} hasta $destinationLabel.',
      fareBs: secondRoute.fare,
      durationMin: secondMinibusMin,
      fromStop: 'Punto de subida 2',
      toStop: destinationLabel,
      geoPoints: secondMinibusPoints,
      syndicate: secondRoute.syndicate,
    ));

    // Caminata al destino (si es necesario)
    final distanceToDest = GeoUtils.distanceMeters(endPoint, destination);
    if (distanceToDest > 50) {
      final walkFinalPoints = await RoutingService.fetchRoute(
        start: endPoint,
        end: destination,
        profile: 'foot',
      );
      final walkFinalMeters = _routeLengthMeters(walkFinalPoints);
      final walkFinalMin = (walkFinalMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a tu destino',
        subtitle: '${walkFinalMeters.round()} m',
        instruction: 'Camina hasta $destinationLabel.',
        fareBs: 0,
        durationMin: walkFinalMin,
        fromStop: 'Punto de bajada',
        toStop: destinationLabel,
        geoPoints: walkFinalPoints,
      ));
    }

    return TripPlan(
      origin: 'Tu ubicación',
      destination: destinationLabel,
      segments: segments,
    );
  }

  // ============================================================
  // 10. CAMINATA DIRECTA
  // ============================================================

  static Future<TripPlan?> _buildWalkPlan(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      final segments = <RouteSegment>[];

      final walkPoints = await RoutingService.fetchRoute(
        start: origin,
        end: destination,
        profile: 'foot',
      );
      final walkMeters = _routeLengthMeters(walkPoints);
      final walkMin = (walkMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a tu destino',
        subtitle: '${walkMeters.round()} m · ${walkMin} min',
        instruction: 'Camina hasta $destinationLabel.',
        fareBs: 0,
        durationMin: walkMin,
        fromStop: 'Tu ubicación',
        toStop: destinationLabel,
        geoPoints: walkPoints,
      ));

      return TripPlan(
        origin: 'Tu ubicación',
        destination: destinationLabel,
        segments: segments,
      );
    } catch (e) {
      print('❌ Error en Caminata: $e');
      return null;
    }
  }

  // ============================================================
  // FUNCIONES AUXILIARES
  // ============================================================

  static Future<List<LatLng>> _buildPumaRoutePoints(
    List<Place> stops,
  ) async {
    if (stops.length < 2) {
      return stops.map((s) => s.location).toList();
    }

    final allPoints = <LatLng>[];

    for (var i = 0; i < stops.length - 1; i++) {
      final start = stops[i].location;
      final end = stops[i + 1].location;

      try {
        final routePoints = await RoutingService.fetchRoute(
          start: start,
          end: end,
          profile: 'driving',
        );

        if (routePoints.isNotEmpty) {
          allPoints.addAll(routePoints);
        } else {
          allPoints.add(start);
          allPoints.add(end);
        }
      } catch (_) {
        allPoints.add(start);
        allPoints.add(end);
      }
    }

    return allPoints;
  }

  static double _routeLengthMeters(List<LatLng> points) {
    double total = 0;
    for (var i = 0; i < points.length - 1; i++) {
      total += GeoUtils.distanceMeters(points[i], points[i + 1]);
    }
    return total;
  }
}

// ============================================================
// CLASE AUXILIAR: RED DE TELEFÉRICO
// ============================================================

class TelefericoNetwork {
  static Place nearestStation(LatLng point) {
    Place? nearest;
    double minDistance = double.infinity;

    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        final distance = GeoUtils.distanceMeters(point, station.location);
        if (distance < minDistance) {
          minDistance = distance;
          nearest = station;
        }
      }
    }

    return nearest!;
  }

  static double distanceToNearestStation(LatLng point) {
    double minDistance = double.infinity;

    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        final distance = GeoUtils.distanceMeters(point, station.location);
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }

    return minDistance;
  }

  static List<_TelefericoPathStep>? findPath(String from, String to) {
    for (final line in TelefericoData.allLines) {
      final stations = line.stations;
      final fromIndex = stations.indexWhere((s) => s.name == from);
      final toIndex = stations.indexWhere((s) => s.name == to);

      if (fromIndex != -1 && toIndex != -1) {
        final start = fromIndex < toIndex ? fromIndex : toIndex;
        final end = fromIndex < toIndex ? toIndex : fromIndex;

        return [
          _TelefericoPathStep(
            line: line,
            stations: stations.sublist(start, end + 1),
          ),
        ];
      }
    }

    // Buscar transbordo
    for (final line1 in TelefericoData.allLines) {
      for (final line2 in TelefericoData.allLines) {
        if (line1.name == line2.name) continue;

        final sharedStations = line1.stations
            .where((s) => line2.stations.any((s2) => s2.name == s.name))
            .toList();

        if (sharedStations.isNotEmpty) {
          final shared = sharedStations.first;

          final fromIndex1 = line1.stations.indexWhere((s) => s.name == from);
          final toIndex1 = line1.stations.indexWhere((s) => s.name == shared.name);

          final fromIndex2 = line2.stations.indexWhere((s) => s.name == shared.name);
          final toIndex2 = line2.stations.indexWhere((s) => s.name == to);

          if (fromIndex1 != -1 && toIndex1 != -1 && fromIndex2 != -1 && toIndex2 != -1) {
            final start1 = fromIndex1 < toIndex1 ? fromIndex1 : toIndex1;
            final end1 = fromIndex1 < toIndex1 ? toIndex1 : fromIndex1;
            final start2 = fromIndex2 < toIndex2 ? fromIndex2 : toIndex2;
            final end2 = fromIndex2 < toIndex2 ? toIndex2 : fromIndex2;

            return [
              _TelefericoPathStep(
                line: line1,
                stations: line1.stations.sublist(start1, end1 + 1),
              ),
              _TelefericoPathStep(
                line: line2,
                stations: line2.stations.sublist(start2, end2 + 1),
              ),
            ];
          }
        }
      }
    }

    return null;
  }
}

class _TelefericoPathStep {
  final TelefericoLine line;
  final List<Place> stations;

  _TelefericoPathStep({required this.line, required this.stations});
}