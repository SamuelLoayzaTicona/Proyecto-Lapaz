import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';
import '../models/place.dart';

/// Un paso dentro de la red de Teleférico: viajar por una línea desde una
/// estación hasta otra (pueden ser varias estaciones de la misma línea).
class TelefericoPathStep {
  final TelefericoLine line;
  final List<Place> stations; // en orden, incluye la primera y la última

  const TelefericoPathStep({required this.line, required this.stations});
}

/// Construye la red completa de Teleférico como un grafo (todas las
/// estaciones de todas las líneas) y encuentra el mejor camino entre dos
/// estaciones cualesquiera, incluyendo transbordos donde dos líneas
/// comparten una estación con el mismo nombre (ej: "Estación 16 de Julio"
/// existe en la Línea Azul y en la Línea Roja - ahí se puede transbordar).
class TelefericoNetwork {
  TelefericoNetwork._();

  /// Todas las estaciones de todas las líneas, sin duplicar por nombre.
  static List<Place> get allStations {
    final seen = <String>{};
    final result = <Place>[];
    for (final line in TelefericoData.allLines) {
      for (final station in line.stations) {
        if (seen.add(station.name)) result.add(station);
      }
    }
    return result;
  }

  /// La estación real (de cualquier línea) más cercana a un punto dado.
  static Place nearestStation(LatLng point) {
    final distance = const Distance();
    Place best = allStations.first;
    double bestMeters = double.infinity;
    for (final station in allStations) {
      final meters = distance.as(LengthUnit.Meter, point, station.location);
      if (meters < bestMeters) {
        bestMeters = meters;
        best = station;
      }
    }
    return best;
  }

  static double distanceToNearestStation(LatLng point) {
    final distance = const Distance();
    final station = nearestStation(point);
    return distance.as(LengthUnit.Meter, point, station.location);
  }

  /// Busca el mejor camino (menor tiempo) entre dos estaciones por nombre,
  /// pudiendo cruzar varias líneas. Devuelve una lista de "tramos por
  /// línea" en orden. Null si no hay camino (no debería pasar con la red
  /// actual, todas las líneas están conectadas entre sí).
  static List<TelefericoPathStep>? findPath(String fromStationName, String toStationName) {
    if (fromStationName == toStationName) return [];

    // Dijkstra simple sobre estaciones (nodos = nombres de estación).
    final distances = <String, double>{fromStationName: 0};
    final previous = <String, _Edge>{};
    final visited = <String>{};
    final queue = <String>{fromStationName};

    while (queue.isNotEmpty) {
      final current = queue.reduce((a, b) => (distances[a] ?? double.infinity) < (distances[b] ?? double.infinity) ? a : b);
      queue.remove(current);
      if (!visited.add(current)) continue;
      if (current == toStationName) break;

      for (final edge in _edgesFrom(current)) {
        final newDist = (distances[current] ?? double.infinity) + edge.weightMinutes;
        if (newDist < (distances[edge.toStationName] ?? double.infinity)) {
          distances[edge.toStationName] = newDist;
          previous[edge.toStationName] = edge;
          queue.add(edge.toStationName);
        }
      }
    }

    if (!distances.containsKey(toStationName)) return null;

    // Reconstruir camino de estaciones.
    final stationPath = <String>[toStationName];
    var cursor = toStationName;
    final edgesUsed = <_Edge>[];
    while (cursor != fromStationName) {
      final edge = previous[cursor];
      if (edge == null) return null;
      edgesUsed.add(edge);
      cursor = edge.fromStationName;
      stationPath.add(cursor);
    }
    edgesUsed.reversed.toList();

    // Agrupar los tramos consecutivos que van por la misma línea en un
    // solo TelefericoPathStep con varias estaciones.
    final steps = <TelefericoPathStep>[];
    for (final edge in edgesUsed.reversed) {
      if (steps.isNotEmpty && steps.last.line.name == edge.line.name) {
        steps.last.stations.add(_stationByName(edge.toStationName));
      } else {
        steps.add(TelefericoPathStep(
          line: edge.line,
          stations: [_stationByName(edge.fromStationName), _stationByName(edge.toStationName)],
        ));
      }
    }
    return steps;
  }

  static Place _stationByName(String name) {
    return allStations.firstWhere((s) => s.name == name);
  }

  static List<_Edge> _edgesFrom(String stationName) {
    final edges = <_Edge>[];
    for (final line in TelefericoData.allLines) {
      final index = line.stations.indexWhere((s) => s.name == stationName);
      if (index == -1) continue;
      final minutesPerHop = line.durationMin / (line.stations.length - 1);
      if (index > 0) {
        edges.add(_Edge(
          fromStationName: stationName,
          toStationName: line.stations[index - 1].name,
          line: line,
          weightMinutes: minutesPerHop,
        ));
      }
      if (index < line.stations.length - 1) {
        edges.add(_Edge(
          fromStationName: stationName,
          toStationName: line.stations[index + 1].name,
          line: line,
          weightMinutes: minutesPerHop,
        ));
      }
    }
    return edges;
  }
}

class _Edge {
  final String fromStationName;
  final String toStationName;
  final TelefericoLine line;
  final double weightMinutes;

  _Edge({
    required this.fromStationName,
    required this.toStationName,
    required this.line,
    required this.weightMinutes,
  });
}
