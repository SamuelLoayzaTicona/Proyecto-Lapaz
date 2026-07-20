import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';
import '../data/pumakatari_data.dart';
import '../models/place.dart';
import '../models/transport_models.dart';
import 'geo_utils.dart';
import 'routing_service.dart';

class TripPlannerService {
  TripPlannerService._();

  static const double _walkingSpeedMetersPerMinute = 70;
  static const double _maxWalkToStationMeters = 1800;

  // ============================================================
  // PUNTO DE ENTRADA PRINCIPAL
  // ============================================================

  static Future<TripPlan?> planTrip({
    required LatLng origin,
    required LatLng destination,
    required String destinationLabel,
  }) async {
    final List<TripPlan> opciones = [];

    // 1. Opción: Teleférico (si hay estaciones cercanas)
    final entryStation = TelefericoNetwork.nearestStation(origin);
    final exitStation = TelefericoNetwork.nearestStation(destination);

    final distanceToEntry = GeoUtils.distanceMeters(origin, entryStation.location);
    final distanceToExit = GeoUtils.distanceMeters(destination, exitStation.location);

    if (distanceToEntry <= _maxWalkToStationMeters && distanceToExit <= _maxWalkToStationMeters) {
      final telefericoPlan = await _buildTelefericoPlan(origin, destination, destinationLabel);
      if (telefericoPlan != null) opciones.add(telefericoPlan);
    }

    // 2. Opción: Minibús directo (siempre disponible)
    final minibusPlan = await _buildMinibusPlan(origin, destination, destinationLabel);
    if (minibusPlan != null) opciones.add(minibusPlan);

    // 3. Opción: PumaKatari (si el destino está en una ruta de Puma)
    final pumaPlan = await _buildPumaPlan(origin, destination, destinationLabel);
    if (pumaPlan != null) opciones.add(pumaPlan);

    // 4. Opción: Caminata directa (si está cerca)
    final distanceDirect = GeoUtils.distanceMeters(origin, destination);
    if (distanceDirect <= 900) {
      final walkPlan = await _buildWalkPlan(origin, destination, destinationLabel);
      if (walkPlan != null) opciones.add(walkPlan);
    }

    // 5. Ordenar por tiempo total (más rápido primero)
    opciones.sort((a, b) => a.totalDurationMin.compareTo(b.totalDurationMin));

    print('Opciones encontradas: ${opciones.length}');
    if (opciones.isNotEmpty) {
      print('Mejor opción: ${opciones.first.totalDurationMin} min');
    }

    return opciones.isNotEmpty ? opciones.first : null;
  }

  // ============================================================
  // PLAN: TELEFÉRICO
  // ============================================================

  static Future<TripPlan?> _buildTelefericoPlan(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      final segments = <RouteSegment>[];

      final entryStation = TelefericoNetwork.nearestStation(origin);
      final exitStation = TelefericoNetwork.nearestStation(destination);

      // Caminata a la estación de entrada (sigue calles)
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

      // Viaje en Teleférico (línea recta - cable aéreo)
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

      // Último tramo: de la estación de salida al destino
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
      print('Error en Teleférico: $e');
      return null;
    }
  }

  // ============================================================
  // PLAN: MINIBÚS DIRECTO
  // ============================================================

  static Future<TripPlan?> _buildMinibusPlan(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      final segments = <RouteSegment>[];

      final minibusPoints = await RoutingService.fetchRoute(
        start: origin,
        end: destination,
        profile: 'driving',
      );

      final minibusMeters = _routeLengthMeters(minibusPoints);
      final minibusMin = (minibusMeters / 300).ceil().clamp(5, 60);

      segments.add(RouteSegment(
        mode: TransportMode.minibus,
        title: 'Minibús directo',
        subtitle: 'Bs. 2.50 · ${minibusMin} min',
        instruction: 'Toma un minibús con destino a $destinationLabel.',
        fareBs: 2.5,
        durationMin: minibusMin,
        fromStop: 'Tu ubicación',
        toStop: destinationLabel,
        geoPoints: minibusPoints,
        syndicate: 'Por confirmar',
      ));

      return TripPlan(
        origin: 'Tu ubicación',
        destination: destinationLabel,
        segments: segments,
      );
    } catch (e) {
      print('Error en Minibús: $e');
      return null;
    }
  }

  // ============================================================
  // PLAN: PUMAKATARI
  // ============================================================

  static Future<TripPlan?> _buildPumaPlan(
    LatLng origin,
    LatLng destination,
    String destinationLabel,
  ) async {
    try {
      // Buscar una ruta de Puma que tenga una parada cercana al destino
      for (final route in PumaKatariData.allRoutes) {
        // Buscar en IDA
        for (final stop in route.stops) {
          final distance = GeoUtils.distanceMeters(destination, stop.location);
          if (distance < 500) {
            // El destino está cerca de una parada de Puma
            final segments = <RouteSegment>[];

            // Encontrar la parada de Puma más cercana al origen
            Place? nearestOriginStop;
            double minOriginDist = double.infinity;

            for (final s in route.stops) {
              final d = GeoUtils.distanceMeters(origin, s.location);
              if (d < minOriginDist) {
                minOriginDist = d;
                nearestOriginStop = s;
              }
            }

            if (nearestOriginStop == null) continue;

            final originIndex = route.stops.indexWhere((s) => s.name == nearestOriginStop!.name);
            final destIndex = route.stops.indexWhere((s) => s.name == stop.name);

            if (originIndex == -1 || destIndex == -1 || originIndex >= destIndex) continue;

            // Caminata a la parada de origen (sigue calles)
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

            // Viaje en PumaKatari (sigue calles reales)
            final destStop = route.stops[destIndex];
            final travelTime = route.times[destIndex] - route.times[originIndex];

            // Obtener la ruta por calles entre paradas
            final pumaPoints = await _buildPumaRoutePoints(
              route.stops.sublist(originIndex, destIndex + 1),
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

            // Caminata final al destino (sigue calles)
            if (distance > 50) {
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
        }

        // Buscar en VUELTA (misma lógica)
        for (final stop in route.returnStops) {
          final distance = GeoUtils.distanceMeters(destination, stop.location);
          if (distance < 500) {
            final segments = <RouteSegment>[];

            Place? nearestOriginStop;
            double minOriginDist = double.infinity;

            for (final s in route.returnStops) {
              final d = GeoUtils.distanceMeters(origin, s.location);
              if (d < minOriginDist) {
                minOriginDist = d;
                nearestOriginStop = s;
              }
            }

            if (nearestOriginStop == null) continue;

            final originIndex = route.returnStops.indexWhere((s) => s.name == nearestOriginStop!.name);
            final destIndex = route.returnStops.indexWhere((s) => s.name == stop.name);

            if (originIndex == -1 || destIndex == -1 || originIndex >= destIndex) continue;

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

            final destStop = route.returnStops[destIndex];
            final travelTime = route.returnTimes[destIndex] - route.returnTimes[originIndex];

            final pumaPoints = await _buildPumaRoutePoints(
              route.returnStops.sublist(originIndex, destIndex + 1),
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

            if (distance > 50) {
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
        }
      }

      return null;
    } catch (e) {
      print('Error en Puma: $e');
      return null;
    }
  }

  // ============================================================
  // PLAN: CAMINATA DIRECTA
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
    final allStations = <Place>[];
    final allLines = <TelefericoLine>[];

    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        allStations.add(station);
        allLines.add(line);
      }
    }

    // Buscar la línea que contiene ambas estaciones
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

    // Si no están en la misma línea, buscar conexión (transbordo)
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