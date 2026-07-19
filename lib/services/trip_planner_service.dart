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
  static const double _maxWalkDistance = 3000; // 3 km maximo para caminar

  static Future<TripPlan?> planTrip({
    required LatLng origin,
    required String destinationQuery,
  }) async {
    final query = destinationQuery.toLowerCase().trim();

    // 1. Buscar el destino en todas las paradas conocidas
    final destinationPlace = _findDestination(query);
    if (destinationPlace == null) {
      print('Destino no encontrado: "$destinationQuery"');
      return null;
    }

    print('Destino encontrado: ${destinationPlace.name}');
    print('Origen: (${origin.latitude}, ${origin.longitude})');

    // 2. Recolectar TODAS las opciones de ruta posibles
    final List<TripPlan> opciones = [];

    // 2a. Ruta usando Teleferico (si el destino es una estacion)
    final telefericoRoutes = _findTelefericoRoutes(destinationPlace.name);
    for (final line in telefericoRoutes) {
      final plan = await _buildTelefericoTrip(origin, destinationPlace, line);
      if (plan != null) opciones.add(plan);
    }

    // 2b. Ruta usando PumaKatari (si el destino es una parada de Puma)
    final pumaRoutes = _findPumaRoutes(destinationPlace.name);
    for (final route in pumaRoutes) {
      final plan = await _buildPumaTrip(origin, destinationPlace, route);
      if (plan != null) opciones.add(plan);
    }

    // 2c. Ruta combinada: Teleferico + Minibus (para Plaza Avaroa)
    final originalRoute = await _buildOriginalRoute(origin, destinationPlace);
    if (originalRoute != null) opciones.add(originalRoute);

    // 2d. Ruta combinada: Puma + Teleferico (conexion en Curva de Holguin)
    final combinedRoute = await _findCombinedRoute(origin, destinationPlace);
    if (combinedRoute != null) opciones.add(combinedRoute);

    if (opciones.isEmpty) {
      print('No se encontraron rutas para: ${destinationPlace.name}');
      return null;
    }

    // 3. Filtrar rutas invalidas
    opciones.removeWhere((plan) {
      if (plan.segments.isEmpty) return true;
      if (plan.segments.length == 1 && plan.segments.first.durationMin < 2) return true;
      return false;
    });

    if (opciones.isEmpty) {
      print('Todas las rutas encontradas son invalidas');
      return null;
    }

    // 4. Elegir la mejor opcion (menos trasbordos, luego mas rapida)
    opciones.sort((a, b) {
      final segmentDiff = a.segments.length.compareTo(b.segments.length);
      if (segmentDiff != 0) return segmentDiff;
      return a.totalDurationMin.compareTo(b.totalDurationMin);
    });

    final mejorRuta = opciones.first;

    print('Mejor ruta elegida: ${mejorRuta.segments.length} segmentos, '
        '${mejorRuta.totalDurationMin} min, Bs. ${mejorRuta.totalFareBs}');

    return mejorRuta;
  }

  // ============================================================
  // 1. BUSQUEDA DE DESTINO
  // ============================================================

  static Place? _findDestination(String query) {
    // Buscar en Teleferico
    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        if (station.name.toLowerCase().contains(query)) return station;
      }
    }

    // Buscar en PumaKatari
    for (final route in PumaKatariData.allRoutes) {
      for (final stop in route.stops) {
        if (stop.name.toLowerCase().contains(query)) return stop;
      }
      for (final stop in route.returnStops) {
        if (stop.name.toLowerCase().contains(query)) return stop;
      }
    }

    // Buscar en lugares conocidos
    final knownPlaces = [
      TelefericoData.plazaAvaroa,
      TelefericoData.miraflores,
      TelefericoData.rioSeco,
    ];
    for (final place in knownPlaces) {
      if (place.name.toLowerCase().contains(query)) return place;
    }

    return null;
  }

  // ============================================================
  // 2. RUTAS DE TELEFERICO
  // ============================================================

  static List<TelefericoLine> _findTelefericoRoutes(String destination) {
    final result = <TelefericoLine>[];
    for (final line in TelefericoData.allLines) {
      final hasStation = line.stations.any((s) => s.name == destination);
      if (hasStation) result.add(line);
    }
    return result;
  }

  static Future<TripPlan?> _buildTelefericoTrip(
    LatLng origin,
    Place destination,
    TelefericoLine line,
  ) async {
    try {
      final segments = <RouteSegment>[];
      final destIndex = line.stations.indexWhere((s) => s.name == destination.name);

      if (destIndex == -1 || destIndex == 0) return null;

      // 1. Encontrar la estacion mas cercana al origen
      final nearestStation = _findNearestStation(origin, line);
      if (nearestStation == null) return null;

      final nearestIndex = line.stations.indexWhere((s) => s.name == nearestStation.name);
      if (nearestIndex == -1) return null;

      // 2. Caminata desde el origen hasta la estacion mas cercana
      final walkToStation = _buildWalkSegment(
        origin,
        nearestStation.location,
        'Camina a la estacion: ${nearestStation.name}',
        nearestStation.name,
      );
      if (walkToStation != null) segments.add(walkToStation);

      // 3. Viaje en Teleferico desde la estacion mas cercana hasta el destino
      final destStation = line.stations[destIndex];
      final travelTime = _calculateTelefericoTime(line, nearestIndex, destIndex);

      if (travelTime > 0) {
        segments.add(RouteSegment(
          mode: TransportMode.teleferico,
          title: 'Teleferico · ${line.name}',
          subtitle: 'Bs. 3.00 · ${travelTime} min',
          instruction: 'Aborda el Teleferico ${line.name} en ${nearestStation.name} y viaja hasta ${destStation.name}.',
          fareBs: 3.0,
          durationMin: travelTime,
          fromStop: nearestStation.name,
          toStop: destStation.name,
          geoPoints: line.stations
              .skip(nearestIndex)
              .take(destIndex - nearestIndex + 1)
              .map((s) => s.location)
              .toList(),
        ));
      }

      if (segments.isEmpty) return null;

      return TripPlan(
        origin: 'Tu ubicacion',
        destination: destination.name,
        segments: segments,
      );
    } catch (e) {
      print('Error en _buildTelefericoTrip: $e');
      return null;
    }
  }

  static Place? _findNearestStation(LatLng origin, TelefericoLine line) {
    Place? nearest;
    double minDistance = double.infinity;

    for (final station in line.stations) {
      final distance = GeoUtils.distanceMeters(origin, station.location);
      if (distance < minDistance && distance < _maxWalkDistance) {
        minDistance = distance;
        nearest = station;
      }
    }

    return nearest;
  }

  static int _calculateTelefericoTime(TelefericoLine line, int fromIndex, int toIndex) {
    if (fromIndex >= toIndex) return 0;
    final totalStations = line.stations.length;
    final totalTime = line.durationMin;
    // Tiempo proporcional a la cantidad de estaciones
    final timePerStation = totalTime / (totalStations - 1);
    return ((toIndex - fromIndex) * timePerStation).ceil();
  }

  // ============================================================
  // 3. RUTAS DE PUMAKATARI
  // ============================================================

  static List<PumaKatariRoute> _findPumaRoutes(String destination) {
    final result = <PumaKatariRoute>[];
    for (final route in PumaKatariData.allRoutes) {
      final hasDestinationIda = route.stops.any((s) => s.name == destination);
      final hasDestinationVuelta = route.returnStops.any((s) => s.name == destination);
      if (hasDestinationIda || hasDestinationVuelta) {
        result.add(route);
      }
    }
    return result;
  }

  static Future<TripPlan?> _buildPumaTrip(
    LatLng origin,
    Place destination,
    PumaKatariRoute route,
  ) async {
    try {
      final segments = <RouteSegment>[];

      // Determinar si el destino esta en IDA o VUELTA
      final isReturn = route.returnStops.any((s) => s.name == destination.name);
      final stops = isReturn ? route.returnStops : route.stops;
      final times = isReturn ? route.returnTimes : route.times;

      final destIndex = stops.indexWhere((s) => s.name == destination.name);
      if (destIndex == -1 || destIndex == 0) return null;

      // 1. Encontrar la parada de Puma mas cercana al origen
      final nearestStop = _findNearestPumaStop(origin, stops);
      if (nearestStop == null) return null;

      final nearestIndex = stops.indexWhere((s) => s.name == nearestStop.name);
      if (nearestIndex == -1 || nearestIndex >= destIndex) return null;

      // 2. Caminata desde el origen hasta la parada mas cercana
      final walkToPuma = _buildWalkSegment(
        origin,
        nearestStop.location,
        'Camina a la parada: ${nearestStop.name}',
        nearestStop.name,
      );
      if (walkToPuma != null) segments.add(walkToPuma);

      // 3. Viaje en Puma desde la parada mas cercana hasta el destino
      final destStop = stops[destIndex];
      final travelTime = times[destIndex] - times[nearestIndex];

      if (travelTime > 0) {
        segments.add(RouteSegment(
          mode: TransportMode.pumakatari,
          title: 'PumaKatari · ${route.name}',
          subtitle: 'Bs. ${route.fare.toStringAsFixed(2)} · ${travelTime} min',
          instruction: 'Aborda el PumaKatari en ${nearestStop.name} y viaja hasta ${destStop.name}.',
          fareBs: route.fare,
          durationMin: travelTime,
          fromStop: nearestStop.name,
          toStop: destStop.name,
          geoPoints: stops
              .skip(nearestIndex)
              .take(destIndex - nearestIndex + 1)
              .map((s) => s.location)
              .toList(),
          syndicate: 'PumaKatari',
        ));
      }

      if (segments.isEmpty) return null;

      return TripPlan(
        origin: 'Tu ubicacion',
        destination: destination.name,
        segments: segments,
      );
    } catch (e) {
      print('Error en _buildPumaTrip: $e');
      return null;
    }
  }

  static Place? _findNearestPumaStop(LatLng origin, List<Place> stops) {
    Place? nearest;
    double minDistance = double.infinity;

    for (final stop in stops) {
      final distance = GeoUtils.distanceMeters(origin, stop.location);
      if (distance < minDistance && distance < _maxWalkDistance) {
        minDistance = distance;
        nearest = stop;
      }
    }

    return nearest;
  }

  // ============================================================
  // 4. RUTA ORIGINAL (Teleferico + Minibus para Plaza Avaroa)
  // ============================================================

  static Future<TripPlan?> _buildOriginalRoute(LatLng origin, Place destination) async {
    try {
      if (destination.name != 'Plaza Avaroa') return null;

      final segments = <RouteSegment>[];

      // 1. Encontrar la estacion de Teleferico mas cercana al origen
      final teleLine = TelefericoData.azul;
      final nearestStation = _findNearestStation(origin, teleLine);
      if (nearestStation == null) return null;

      final nearestIndex = teleLine.stations.indexWhere((s) => s.name == nearestStation.name);
      if (nearestIndex == -1) return null;

      // 2. Caminata a la estacion mas cercana
      final walkToStation = _buildWalkSegment(
        origin,
        nearestStation.location,
        'Camina a la estacion: ${nearestStation.name}',
        nearestStation.name,
      );
      if (walkToStation != null) segments.add(walkToStation);

      // 3. Viaje en Teleferico hasta 16 de Julio (Linea Azul)
      final station16Julio = teleLine.stations.last;
      final timeTo16Julio = _calculateTelefericoTime(teleLine, nearestIndex, teleLine.stations.length - 1);

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
          geoPoints: teleLine.stations
              .skip(nearestIndex)
              .map((s) => s.location)
              .toList(),
        ));
      }

      // 4. Linea Roja: 16 de Julio -> Estacion Central
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

      // 5. Minibus desde Estacion Central hasta Sopocachi
      final paradaSopocachi = LatLng(
        TelefericoData.plazaAvaroa.location.latitude + 0.0015,
        TelefericoData.plazaAvaroa.location.longitude - 0.0010,
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
        instruction: 'Toma un minibus con destino Sopocachi por la Av. 6 de Agosto. Bajate cerca de la Plaza Avaroa.',
        fareBs: 2.5,
        durationMin: minibusMin,
        fromStop: 'Estacion Central',
        toStop: 'Parada Sopocachi',
        geoPoints: minibusPoints,
        syndicate: 'Sindicato Local',
      ));

      // 6. Caminata final
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
      print('Error en _buildOriginalRoute: $e');
      return null;
    }
  }

  // ============================================================
  // 5. COMBINACION: PUMA + TELEFERICO
  // ============================================================

  static Future<TripPlan?> _findCombinedRoute(LatLng origin, Place destination) async {
    try {
      final pumaRoutes = _findPumaRoutes(destination.name);
      if (pumaRoutes.isEmpty) return null;

      const telefericoConnection = 'CURVA DE HOLGUIN';

      for (final pumaRoute in pumaRoutes) {
        final stops = pumaRoute.stops;
        final destIndex = stops.indexWhere((s) => s.name == destination.name);
        if (destIndex == -1 || destIndex == 0) continue;

        // Encontrar Curva de Holguin en la ruta
        final connIndex = stops.indexWhere((s) => s.name.toUpperCase() == telefericoConnection);
        if (connIndex == -1 || connIndex >= destIndex) continue;

        // Encontrar la parada mas cercana al origen
        final nearestStop = _findNearestPumaStop(origin, stops);
        if (nearestStop == null) continue;

        final nearestIndex = stops.indexWhere((s) => s.name == nearestStop.name);
        if (nearestIndex == -1 || nearestIndex > connIndex) continue;

        final segments = <RouteSegment>[];

        // Caminata a la parada mas cercana
        final walkToPuma = _buildWalkSegment(
          origin,
          nearestStop.location,
          'Camina a la parada: ${nearestStop.name}',
          nearestStop.name,
        );
        if (walkToPuma != null) segments.add(walkToPuma);

        // Puma hasta Curva de Holguin
        final connectionStop = stops[connIndex];
        final pumaTime = pumaRoute.times[connIndex] - pumaRoute.times[nearestIndex];

        if (pumaTime > 0) {
          segments.add(RouteSegment(
            mode: TransportMode.pumakatari,
            title: 'PumaKatari · ${pumaRoute.name}',
            subtitle: 'Bs. ${pumaRoute.fare.toStringAsFixed(2)} · ${pumaTime} min',
            instruction: 'Aborda el PumaKatari en ${nearestStop.name} y viaja hasta ${connectionStop.name}.',
            fareBs: pumaRoute.fare,
            durationMin: pumaTime,
            fromStop: nearestStop.name,
            toStop: connectionStop.name,
            geoPoints: stops
                .skip(nearestIndex)
                .take(connIndex - nearestIndex + 1)
                .map((s) => s.location)
                .toList(),
            syndicate: 'PumaKatari',
          ));
        }

        // Teleferico desde Curva de Holguin hasta destino
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
      print('Error en _findCombinedRoute: $e');
      return null;
    }
  }

  // ============================================================
  // 6. UTILIDADES
  // ============================================================

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