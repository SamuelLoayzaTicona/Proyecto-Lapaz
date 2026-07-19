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
  static const double _maxWalkDistance = 50000; // 50 KM

  static Future<List<TripPlan>> planTripOptions({
    required LatLng origin,
    required String destinationQuery,
  }) async {
    final List<TripPlan> opciones = [];

    // 1. Buscar el destino
    final destinationPlace = _findDestination(destinationQuery);
    if (destinationPlace == null) {
      print('Destino no encontrado: "$destinationQuery"');
      return [];
    }

    print('Destino encontrado: ${destinationPlace.name}');

    // 2. Buscar paradas cercanas
    var paradasCercanas = _findNearbyStops(origin);
    print('Paradas cercanas encontradas: ${paradasCercanas.length}');

    if (paradasCercanas.isEmpty) {
      paradasCercanas = _findNearestStopUnlimited(origin);
      print('Paradas mas cercanas (sin limite): ${paradasCercanas.length}');
    }

    // 3. Buscar PumaKatari en TODAS las rutas
    for (final route in PumaKatariData.allRoutes) {
      final plan = await _buildPumaRouteFromAnyRoute(origin, destinationPlace, route);
      if (plan != null) {
        print('Ruta PumaKatari encontrada: ${route.name}');
        opciones.add(plan);
      }
    }

    // 4. Buscar Teleferico
    for (final parada in paradasCercanas) {
      if (parada.tipo == 'teleferico') {
        final plan = await _buildTelefericoRoute(origin, destinationPlace, parada);
        if (plan != null) {
          print('Ruta Teleferico encontrada');
          opciones.add(plan);
        }
      }
    }

    // 5. Ruta combinada
    final combinedRoute = await _buildCombinedRoute(origin, destinationPlace);
    if (combinedRoute != null) {
      print('Ruta combinada encontrada');
      opciones.add(combinedRoute);
    }

    // 6. Solo si el destino es Plaza Avaroa
    if (destinationPlace.name == 'Plaza Avaroa') {
      final avaroaRoute = await _buildPlazaAvaroaRoute(origin);
      if (avaroaRoute != null) {
        print('Ruta Plaza Avaroa encontrada');
        opciones.add(avaroaRoute);
      }
    }

    if (opciones.isEmpty) {
      final directRoute = await _buildDirectRoute(origin, destinationPlace);
      if (directRoute != null) opciones.add(directRoute);
    }

    opciones.removeWhere((plan) => plan.segments.isEmpty);

    print('Total opciones: ${opciones.length}');

    opciones.sort((a, b) {
      final walkA = a.segments.where((s) => s.mode == TransportMode.walk).fold(0, (sum, s) => sum + s.durationMin);
      final walkB = b.segments.where((s) => s.mode == TransportMode.walk).fold(0, (sum, s) => sum + s.durationMin);
      if (walkA != walkB) return walkA.compareTo(walkB);
      if (a.segments.length != b.segments.length) return a.segments.length.compareTo(b.segments.length);
      return a.totalDurationMin.compareTo(b.totalDurationMin);
    });

    return opciones;
  }

  // ============================================================
  // BUSQUEDA DE DESTINO
  // ============================================================

  static Place? _findDestination(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return null;

    print('Buscando destino: "$query"');

    // Teleferico
    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        if (station.name.toLowerCase() == lower) {
          print('Coincidencia exacta en Teleferico: ${station.name}');
          return station;
        }
      }
    }

    // PumaKatari
    for (final route in PumaKatariData.allRoutes) {
      for (final stop in route.stops) {
        if (stop.name.toLowerCase() == lower) {
          print('Coincidencia exacta en Puma: ${stop.name}');
          return stop;
        }
      }
      for (final stop in route.returnStops) {
        if (stop.name.toLowerCase() == lower) {
          print('Coincidencia exacta en Puma: ${stop.name}');
          return stop;
        }
      }
    }

    // Coincidencia parcial
    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        if (station.name.toLowerCase().contains(lower)) {
          print('Coincidencia parcial en Teleferico: ${station.name}');
          return station;
        }
      }
    }

    for (final route in PumaKatariData.allRoutes) {
      for (final stop in route.stops) {
        if (stop.name.toLowerCase().contains(lower)) {
          print('Coincidencia parcial en Puma: ${stop.name}');
          return stop;
        }
      }
      for (final stop in route.returnStops) {
        if (stop.name.toLowerCase().contains(lower)) {
          print('Coincidencia parcial en Puma: ${stop.name}');
          return stop;
        }
      }
    }

    final knownPlaces = [
      TelefericoData.plazaAvaroa,
      TelefericoData.miraflores,
      TelefericoData.rioSeco,
    ];
    for (final place in knownPlaces) {
      if (place.name.toLowerCase().contains(lower)) {
        print('Coincidencia en lugares conocidos: ${place.name}');
        return place;
      }
    }

    print('No se encontro coincidencia para: "$query"');
    return null;
  }

  // ============================================================
  // BUSCAR PARADAS CERCANAS
  // ============================================================

  static List<_NearbyStop> _findNearbyStops(LatLng origin) {
    final result = <_NearbyStop>[];

    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        final distance = GeoUtils.distanceMeters(origin, station.location);
        if (distance < _maxWalkDistance) {
          result.add(_NearbyStop(
            nombre: station.name,
            ubicacion: station.location,
            tipo: 'teleferico',
            distancia: distance,
            linea: line,
          ));
        }
      }
    }

    for (final route in PumaKatariData.allRoutes) {
      for (final stop in route.stops) {
        final distance = GeoUtils.distanceMeters(origin, stop.location);
        if (distance < _maxWalkDistance) {
          result.add(_NearbyStop(
            nombre: stop.name,
            ubicacion: stop.location,
            tipo: 'pumakatari',
            distancia: distance,
            ruta: route,
          ));
        }
      }
      for (final stop in route.returnStops) {
        final distance = GeoUtils.distanceMeters(origin, stop.location);
        if (distance < _maxWalkDistance) {
          result.add(_NearbyStop(
            nombre: stop.name,
            ubicacion: stop.location,
            tipo: 'pumakatari',
            distancia: distance,
            ruta: route,
          ));
        }
      }
    }

    result.sort((a, b) => a.distancia.compareTo(b.distancia));
    return result;
  }

  static List<_NearbyStop> _findNearestStopUnlimited(LatLng origin) {
    final result = <_NearbyStop>[];
    double minDistTele = double.infinity;
    _NearbyStop? nearestTele;
    double minDistPuma = double.infinity;
    _NearbyStop? nearestPuma;

    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        final distance = GeoUtils.distanceMeters(origin, station.location);
        if (distance < minDistTele) {
          minDistTele = distance;
          nearestTele = _NearbyStop(
            nombre: station.name,
            ubicacion: station.location,
            tipo: 'teleferico',
            distancia: distance,
            linea: line,
          );
        }
      }
    }

    for (final route in PumaKatariData.allRoutes) {
      for (final stop in route.stops) {
        final distance = GeoUtils.distanceMeters(origin, stop.location);
        if (distance < minDistPuma) {
          minDistPuma = distance;
          nearestPuma = _NearbyStop(
            nombre: stop.name,
            ubicacion: stop.location,
            tipo: 'pumakatari',
            distancia: distance,
            ruta: route,
          );
        }
      }
      for (final stop in route.returnStops) {
        final distance = GeoUtils.distanceMeters(origin, stop.location);
        if (distance < minDistPuma) {
          minDistPuma = distance;
          nearestPuma = _NearbyStop(
            nombre: stop.name,
            ubicacion: stop.location,
            tipo: 'pumakatari',
            distancia: distance,
            ruta: route,
          );
        }
      }
    }

    if (nearestTele != null) {
      print('Teleferico mas cercano: ${nearestTele.nombre} (${nearestTele.distancia.round()}m)');
      result.add(nearestTele);
    }
    if (nearestPuma != null) {
      print('Puma mas cercano: ${nearestPuma.nombre} (${nearestPuma.distancia.round()}m)');
      result.add(nearestPuma);
    }

    result.sort((a, b) => a.distancia.compareTo(b.distancia));
    return result;
  }

  // ============================================================
  // RUTA EN TELEFERICO
  // ============================================================

  static Future<TripPlan?> _buildTelefericoRoute(
    LatLng origin,
    Place destination,
    _NearbyStop parada,
  ) async {
    try {
      final segments = <RouteSegment>[];
      final line = parada.linea as TelefericoLine;
      final destIndex = line.stations.indexWhere((s) => s.name == destination.name);
      if (destIndex == -1) return null;

      final startIndex = line.stations.indexWhere((s) => s.name == parada.nombre);
      if (startIndex == -1 || startIndex >= destIndex) return null;

      final walkToStation = _buildWalkSegment(
        origin,
        parada.ubicacion,
        'Camina a la estacion: ${parada.nombre}',
        parada.nombre,
      );
      if (walkToStation != null) segments.add(walkToStation);

      final destStation = line.stations[destIndex];
      final travelTime = _calculateTelefericoTime(line, startIndex, destIndex);

      segments.add(RouteSegment(
        mode: TransportMode.teleferico,
        title: 'Teleferico · ${line.name}',
        subtitle: 'Bs. 3.00 · ${travelTime} min',
        instruction: 'Aborda el Teleferico ${line.name} en ${parada.nombre} y viaja hasta ${destStation.name}.',
        fareBs: 3.0,
        durationMin: travelTime,
        fromStop: parada.nombre,
        toStop: destStation.name,
        geoPoints: line.stations
            .skip(startIndex)
            .take(destIndex - startIndex + 1)
            .map((s) => s.location)
            .toList(),
      ));

      return TripPlan(
        origin: 'Tu ubicacion',
        destination: destination.name,
        segments: segments,
      );
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // RUTA EN PUMAKATARI (BUSCA EN TODAS LAS RUTAS)
  // ============================================================

  static Future<TripPlan?> _buildPumaRouteFromAnyRoute(
    LatLng origin,
    Place destination,
    PumaKatariRoute route,
  ) async {
    try {
      // Verificar si el destino está en esta ruta (IDA o VUELTA)
      final isReturn = route.returnStops.any((s) => s.name == destination.name);
      final stops = isReturn ? route.returnStops : route.stops;
      final times = isReturn ? route.returnTimes : route.times;

      final destIndex = stops.indexWhere((s) => s.name == destination.name);
      if (destIndex == -1) {
        print('Destino ${destination.name} no encontrado en ruta ${route.name}');
        return null;
      }

      // Encontrar la parada mas cercana al origen en ESTA ruta
      Place? nearestStopInRoute;
      double minDistance = double.infinity;

      for (final stop in stops) {
        final distance = GeoUtils.distanceMeters(origin, stop.location);
        if (distance < minDistance) {
          minDistance = distance;
          nearestStopInRoute = stop;
        }
      }

      if (nearestStopInRoute == null) {
        print('No se encontraron paradas en la ruta ${route.name}');
        return null;
      }

      final startIndex = stops.indexWhere((s) => s.name == nearestStopInRoute!.name);
      if (startIndex == -1 || startIndex >= destIndex) {
        print('La parada mas cercana esta despues del destino en ${route.name}');
        return null;
      }

      // Construir ruta
      final segments = <RouteSegment>[];

      // Si la distancia es muy grande (>5km), mostrar advertencia
      if (minDistance > 5000) {
        print('⚠️ La parada mas cercana esta a ${minDistance.round()}m de tu ubicacion');
      }

      final walkToStop = _buildWalkSegment(
        origin,
        nearestStopInRoute.location,
        'Camina a la parada: ${nearestStopInRoute.name}',
        nearestStopInRoute.name,
      );
      if (walkToStop != null) segments.add(walkToStop);

      final destStop = stops[destIndex];
      final travelTime = times[destIndex] - times[startIndex];

      segments.add(RouteSegment(
        mode: TransportMode.pumakatari,
        title: 'PumaKatari · ${route.name}',
        subtitle: 'Bs. ${route.fare.toStringAsFixed(2)} · ${travelTime} min',
        instruction: 'Aborda el PumaKatari en ${nearestStopInRoute.name} y viaja hasta ${destStop.name}.',
        fareBs: route.fare,
        durationMin: travelTime,
        fromStop: nearestStopInRoute.name,
        toStop: destStop.name,
        geoPoints: stops
            .skip(startIndex)
            .take(destIndex - startIndex + 1)
            .map((s) => s.location)
            .toList(),
        syndicate: 'PumaKatari',
      ));

      return TripPlan(
        origin: 'Tu ubicacion',
        destination: destination.name,
        segments: segments,
      );
    } catch (e) {
      print('Error en Puma (${route.name}): $e');
      return null;
    }
  }

  // ============================================================
  // RUTA COMBINADA
  // ============================================================

  static Future<TripPlan?> _buildCombinedRoute(LatLng origin, Place destination) async {
    try {
      final segments = <RouteSegment>[];

      for (final route in PumaKatariData.allRoutes) {
        final stops = route.stops;
        final destIndex = stops.indexWhere((s) => s.name == destination.name);
        if (destIndex == -1 || destIndex == 0) continue;

        final connIndex = stops.indexWhere((s) => s.name.toUpperCase() == 'CURVA DE HOLGUIN');
        if (connIndex == -1 || connIndex >= destIndex) continue;

        Place? nearestStop;
        double minDistance = double.infinity;

        for (final stop in stops) {
          final distance = GeoUtils.distanceMeters(origin, stop.location);
          if (distance < minDistance) {
            minDistance = distance;
            nearestStop = stop;
          }
        }

        if (nearestStop == null) continue;

        final startIndex = stops.indexWhere((s) => s.name == nearestStop!.name);
        if (startIndex == -1 || startIndex > connIndex) continue;

        final walkToPuma = _buildWalkSegment(
          origin,
          nearestStop.location,
          'Camina a la parada: ${nearestStop.name}',
          nearestStop.name,
        );
        if (walkToPuma != null) segments.add(walkToPuma);

        final connectionStop = stops[connIndex];
        final pumaTime = route.times[connIndex] - route.times[startIndex];

        if (pumaTime > 0) {
          segments.add(RouteSegment(
            mode: TransportMode.pumakatari,
            title: 'PumaKatari · ${route.name}',
            subtitle: 'Bs. ${route.fare.toStringAsFixed(2)} · ${pumaTime} min',
            instruction: 'Aborda el PumaKatari en ${nearestStop.name} y viaja hasta ${connectionStop.name}.',
            fareBs: route.fare,
            durationMin: pumaTime,
            fromStop: nearestStop.name,
            toStop: connectionStop.name,
            geoPoints: stops
                .skip(startIndex)
                .take(connIndex - startIndex + 1)
                .map((s) => s.location)
                .toList(),
            syndicate: 'PumaKatari',
          ));
        }

        final teleLine = TelefericoData.amarilla;
        final destTeleIndex = teleLine.stations.indexWhere((s) => s.name == destination.name);

        if (destTeleIndex != -1 && destTeleIndex > 0) {
          final teleTime = _calculateTelefericoTime(teleLine, 0, destTeleIndex);
          segments.add(RouteSegment(
            mode: TransportMode.teleferico,
            title: 'Teleferico · ${teleLine.name}',
            subtitle: 'Bs. 3.00 · ${teleTime} min',
            instruction: 'Aborda el Teleferico ${teleLine.name} en ${connectionStop.name} y viaja hasta ${destination.name}.',
            fareBs: 3.0,
            durationMin: teleTime,
            fromStop: connectionStop.name,
            toStop: destination.name,
            geoPoints: teleLine.stations
                .take(destTeleIndex + 1)
                .map((s) => s.location)
                .toList(),
          ));
        }

        if (segments.isNotEmpty) {
          return TripPlan(
            origin: 'Tu ubicacion',
            destination: destination.name,
            segments: segments,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // RUTA PLAZA AVAROA
  // ============================================================

  static Future<TripPlan?> _buildPlazaAvaroaRoute(LatLng origin) async {
    try {
      final destination = TelefericoData.plazaAvaroa;
      final segments = <RouteSegment>[];

      final teleLine = TelefericoData.azul;
      Place? nearestStation;
      double minDistance = double.infinity;

      for (final station in teleLine.stations) {
        final distance = GeoUtils.distanceMeters(origin, station.location);
        if (distance < minDistance) {
          minDistance = distance;
          nearestStation = station;
        }
      }

      if (nearestStation == null) return null;

      final startIndex = teleLine.stations.indexWhere((s) => s.name == nearestStation!.name);
      if (startIndex == -1) return null;

      final walkToStation = _buildWalkSegment(
        origin,
        nearestStation.location,
        'Camina a la estacion: ${nearestStation.name}',
        nearestStation.name,
      );
      if (walkToStation != null) segments.add(walkToStation);

      final station16Julio = teleLine.stations.last;
      final timeTo16Julio = _calculateTelefericoTime(teleLine, startIndex, teleLine.stations.length - 1);

      if (timeTo16Julio > 0) {
        segments.add(RouteSegment(
          mode: TransportMode.teleferico,
          title: 'Teleferico · Linea Azul',
          subtitle: 'Bs. 3.00 · ${timeTo16Julio} min',
          instruction: 'Aborda el Teleferico Linea Azul en ${nearestStation.name} y viaja hasta Estacion 16 de Julio.',
          fareBs: 3.0,
          durationMin: timeTo16Julio,
          fromStop: nearestStation.name,
          toStop: 'Estacion 16 de Julio',
          geoPoints: teleLine.stations.skip(startIndex).map((s) => s.location).toList(),
        ));
      }

      final roja = TelefericoData.roja;
      final estacionCentral = roja.stations.last;

      segments.add(RouteSegment(
        mode: TransportMode.teleferico,
        title: 'Teleferico · Linea Roja',
        subtitle: 'Bs. 3.00 · ${roja.durationMin} min',
        instruction: 'Baja en 16 de Julio y toma la Linea Roja hasta Estacion Central.',
        fareBs: 3.0,
        durationMin: roja.durationMin,
        fromStop: roja.stations.first.name,
        toStop: roja.stations.last.name,
        geoPoints: roja.stations.map((s) => s.location).toList(),
      ));

      final paradaSopocachi = LatLng(
        destination.location.latitude + 0.0015,
        destination.location.longitude - 0.0010,
      );
      final minibusPoints = await RoutingService.fetchRoute(
        start: estacionCentral.location,
        end: paradaSopocachi,
        profile: 'driving',
      );
      final minibusMeters = _routeLengthMeters(minibusPoints);
      final minibusMin = (minibusMeters / 300).ceil().clamp(5, 40);

      segments.add(RouteSegment(
        mode: TransportMode.minibus,
        title: 'Minibus · Av. 6 de Agosto',
        subtitle: 'Bs. 2.50 · ${minibusMin} min',
        instruction: 'Toma un minibus con destino Sopocachi por la Av. 6 de Agosto.',
        fareBs: 2.5,
        durationMin: minibusMin,
        fromStop: 'Estacion Central',
        toStop: 'Parada Sopocachi',
        geoPoints: minibusPoints,
        syndicate: 'Sindicato Local',
      ));

      final walkFinalPoints = await RoutingService.fetchRoute(
        start: paradaSopocachi,
        end: destination.location,
        profile: 'foot',
      );
      final walkFinalMeters = _routeLengthMeters(walkFinalPoints);
      final walkFinalMin = (walkFinalMeters / _walkingSpeedMetersPerMinute).ceil().clamp(1, 30);

      segments.add(RouteSegment(
        mode: TransportMode.walk,
        title: 'Camina a tu destino',
        subtitle: '${walkFinalMeters.round()} m · Plaza Avaroa',
        instruction: 'Camina los ultimos metros hasta la Plaza Avaroa.',
        fareBs: 0,
        durationMin: walkFinalMin,
        fromStop: 'Parada Sopocachi',
        toStop: 'Plaza Avaroa',
        geoPoints: walkFinalPoints,
      ));

      return TripPlan(
        origin: 'Tu ubicacion',
        destination: 'Plaza Avaroa',
        segments: segments,
      );
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // RUTA DIRECTA (FALLBACK)
  // ============================================================

  static Future<TripPlan?> _buildDirectRoute(LatLng origin, Place destination) async {
    try {
      final segments = <RouteSegment>[];

      final walkToDest = _buildWalkSegment(
        origin,
        destination.location,
        'Camina a tu destino: ${destination.name}',
        destination.name,
      );
      if (walkToDest != null) segments.add(walkToDest);

      if (segments.isEmpty) return null;

      return TripPlan(
        origin: 'Tu ubicacion',
        destination: destination.name,
        segments: segments,
      );
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // UTILIDADES
  // ============================================================

  static int _calculateTelefericoTime(TelefericoLine line, int fromIndex, int toIndex) {
    if (fromIndex >= toIndex) return 0;
    final totalStations = line.stations.length;
    final totalTime = line.durationMin;
    final timePerStation = totalTime / (totalStations - 1);
    return ((toIndex - fromIndex) * timePerStation).ceil();
  }

  static RouteSegment? _buildWalkSegment(
    LatLng from,
    LatLng to,
    String title,
    String toStop,
  ) {
    final distance = GeoUtils.distanceMeters(from, to);
    if (distance < 10) return null;
    if (distance > _maxWalkDistance) return null;

    final duration = (distance / _walkingSpeedMetersPerMinute).ceil().clamp(1, 60);

    return RouteSegment(
      mode: TransportMode.walk,
      title: title,
      subtitle: '${distance.round()} m · ${duration} min',
      instruction: 'Camina hasta la parada.',
      fareBs: 0,
      durationMin: duration,
      fromStop: 'Tu ubicacion',
      toStop: toStop,
      geoPoints: [from, to],
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

class _NearbyStop {
  final String nombre;
  final LatLng ubicacion;
  final String tipo;
  final double distancia;
  final dynamic linea;
  final dynamic ruta;

  _NearbyStop({
    required this.nombre,
    required this.ubicacion,
    required this.tipo,
    required this.distancia,
    this.linea,
    this.ruta,
  });
}