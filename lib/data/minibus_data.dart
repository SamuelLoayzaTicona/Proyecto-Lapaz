import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../services/geo_utils.dart'; // ← IMPORTANTE: para GeoUtils.distanceMeters()

class MinibusRoute {
  final String id;
  final String name;
  final String syndicate;
  final List<LatLng> points; // Coordenadas de la ruta (ida y vuelta es la misma)
  final List<Place> stops; // Puntos de referencia (donde la gente sube/baja)
  final double fare;
  final int estimatedDurationMin;

  const MinibusRoute({
    required this.id,
    required this.name,
    required this.syndicate,
    required this.points,
    required this.stops,
    required this.fare,
    required this.estimatedDurationMin,
  });
}

class MinibusData {
  MinibusData._();

  // ============================================================
  // RUTA 1: RÍO SECO → CEJA (y viceversa)
  // ============================================================
  static const List<LatLng> _rioSecoCejaPoints = [
    LatLng(-16.489583, -68.209691),
    LatLng(-16.490853, -68.203613),
    LatLng(-16.491312, -68.201118),
    LatLng(-16.494027, -68.194865),
    LatLng(-16.497403, -68.184660),
    LatLng(-16.499854, -68.174961),
    LatLng(-16.497403, -68.184660),
    LatLng(-16.503041, -68.163784),
  ];

  static const List<Place> _rioSecoCejaStops = [
    Place(name: 'Teleférico Río Seco', location: LatLng(-16.489583, -68.209691)),
    Place(name: 'Multicine', location: LatLng(-16.490853, -68.203613)),
    Place(name: 'Puente Río Seco', location: LatLng(-16.491312, -68.201118)),
    Place(name: 'UPEA', location: LatLng(-16.494027, -68.194865)),
    Place(name: 'Avenida La Paz', location: LatLng(-16.497403, -68.184660)),
    Place(name: 'Chacaltaya', location: LatLng(-16.499854, -68.174961)),
    Place(name: 'Ballivián', location: LatLng(-16.497403, -68.184660)),
    Place(name: 'La Ceja', location: LatLng(-16.503041, -68.163784)),
  ];

  // ============================================================
  // RUTA 2: CEJA → 6 DE AGOSTO (y viceversa)
  // ============================================================
  static const List<LatLng> _cejaSeisAgostoPoints = [
    LatLng(-16.503041, -68.163784),
    LatLng(-16.501962, -68.162513),
    LatLng(-16.495258, -68.165961),
    LatLng(-16.486048, -68.166108),
    LatLng(-16.482260, -68.160314),
    LatLng(-16.470618, -68.157908),
    LatLng(-16.463785, -68.153657),
    LatLng(-16.470918, -68.152298),
    LatLng(-16.481014, -68.148381),
    LatLng(-16.489264, -68.143295),
    LatLng(-16.489788, -68.142436),
    LatLng(-16.495585, -68.136890),
    LatLng(-16.498393, -68.135482),
    LatLng(-16.499637, -68.134527),
    LatLng(-16.500881, -68.133424),
    LatLng(-16.503849, -68.131273),
    LatLng(-16.504414, -68.131210),
    LatLng(-16.504407, -68.131113),
    LatLng(-16.505844, -68.129385),
    LatLng(-16.506331, -68.128878),
    LatLng(-16.510083, -68.125217),
    LatLng(-16.515244, -68.119627),
  ];

  static const List<Place> _cejaSeisAgostoStops = [
    Place(name: 'La Ceja', location: LatLng(-16.503041, -68.163784)),
    Place(name: 'Zona Autopista', location: LatLng(-16.501962, -68.162513)),
    Place(name: 'Cervecería', location: LatLng(-16.489264, -68.143295)),
    Place(name: 'Terminal de Buses', location: LatLng(-16.489788, -68.142436)),
    Place(name: 'Pérez / San Francisco', location: LatLng(-16.495585, -68.136890)),
    Place(name: 'Facultad Ingeniería UMSA', location: LatLng(-16.498393, -68.135482)),
    Place(name: 'Teleférico Morado Obelisco', location: LatLng(-16.499637, -68.134527)),
    Place(name: 'Teleférico Celeste Prado', location: LatLng(-16.500881, -68.133424)),
    Place(name: 'Final Prado', location: LatLng(-16.503849, -68.131273)),
    Place(name: 'Plaza del Estudiante', location: LatLng(-16.504414, -68.131210)),
    Place(name: 'UMSA Monoblock', location: LatLng(-16.504407, -68.131113)),
    Place(name: 'Casa Montes UMSA', location: LatLng(-16.506331, -68.128878)),
    Place(name: 'Plaza Isabel la Católica / Plaza Avaroa', location: LatLng(-16.510083, -68.125217)),
    Place(name: 'Final 6 de Agosto', location: LatLng(-16.515244, -68.119627)),
  ];

  // ============================================================
  // RUTA 3: PÉREZ → COTA COTA (y viceversa)
  // ============================================================
  static const List<LatLng> _perezCotaCotaPoints = [
    LatLng(-16.495620, -68.136930),
    LatLng(-16.498393, -68.135482),
    LatLng(-16.499637, -68.134527),
    LatLng(-16.500881, -68.133424),
    LatLng(-16.503849, -68.131273),
    LatLng(-16.504414, -68.131210),
    LatLng(-16.504407, -68.131113),
    LatLng(-16.505844, -68.129385),
    LatLng(-16.506331, -68.128878),
    LatLng(-16.510083, -68.125217),
    LatLng(-16.515244, -68.119627),
    LatLng(-16.516378, -68.118727),
    LatLng(-16.512487, -68.119639),
    LatLng(-16.519862, -68.114837),
    LatLng(-16.523453, -68.113073),
    LatLng(-16.528717, -68.103528),
    LatLng(-16.541488, -68.092322),
    LatLng(-16.539839, -68.086424),
    LatLng(-16.539006, -68.078017),
    LatLng(-16.540535, -68.068386),
    LatLng(-16.540637, -68.065352),
  ];

  static const List<Place> _perezCotaCotaStops = [
    Place(name: 'Pérez / San Francisco', location: LatLng(-16.495620, -68.136930)),
    Place(name: 'Facultad Ingeniería UMSA', location: LatLng(-16.498393, -68.135482)),
    Place(name: 'Teleférico Morado Obelisco', location: LatLng(-16.499637, -68.134527)),
    Place(name: 'Teleférico Celeste Prado', location: LatLng(-16.500881, -68.133424)),
    Place(name: 'Final Prado', location: LatLng(-16.503849, -68.131273)),
    Place(name: 'Plaza del Estudiante', location: LatLng(-16.504414, -68.131210)),
    Place(name: 'UMSA Monoblock', location: LatLng(-16.504407, -68.131113)),
    Place(name: 'Casa Montes UMSA', location: LatLng(-16.506331, -68.128878)),
    Place(name: 'Plaza Isabel la Católica / Plaza Avaroa', location: LatLng(-16.510083, -68.125217)),
    Place(name: 'Final 6 de Agosto', location: LatLng(-16.515244, -68.119627)),
    Place(name: 'Puentes Trillizos', location: LatLng(-16.516378, -68.118727)),
    Place(name: 'Teleférico Celeste', location: LatLng(-16.512487, -68.119639)),
    Place(name: 'Universidad de Los Andes', location: LatLng(-16.519862, -68.114837)),
    Place(name: 'Universidad Católica', location: LatLng(-16.523453, -68.113073)),
    Place(name: 'Hipermaxi', location: LatLng(-16.528717, -68.103528)),
    Place(name: 'Jardín Japonés', location: LatLng(-16.541488, -68.092322)),
    Place(name: 'Teleférico Línea Verde Irpavi', location: LatLng(-16.539839, -68.086424)),
    Place(name: 'Parroquia San Miguel Arcángel', location: LatLng(-16.539006, -68.078017)),
    Place(name: 'Cota Cota UMSA', location: LatLng(-16.540535, -68.068386)),
    Place(name: 'Laguna Cota Cota', location: LatLng(-16.540637, -68.065352)),
  ];

  // ============================================================
  // RUTA 4: CEJA → TELEFÉRICO (y viceversa)
  // ============================================================
  static const List<LatLng> _cejaTelefericoPoints = [
    LatLng(-16.503260, -68.163520),
    LatLng(-16.506228, -68.163488),
    LatLng(-16.514098, -68.166119),
    LatLng(-16.522393, -68.168908),
  ];

  static const List<Place> _cejaTelefericoStops = [
    Place(name: 'La Ceja', location: LatLng(-16.503260, -68.163520)),
    Place(name: 'Calle 2', location: LatLng(-16.506228, -68.163488)),
    Place(name: 'Aeropuerto El Alto', location: LatLng(-16.514098, -68.166119)),
    Place(name: 'Teleférico Morado 6 de Marzo', location: LatLng(-16.522393, -68.168908)),
  ];

  // ============================================================
  // LISTA DE TODAS LAS RUTAS
  // ============================================================
  static const List<MinibusRoute> allRoutes = [
    MinibusRoute(
      id: 'MB_RIOSECO_CEJA',
      name: 'Río Seco - Ceja',
      syndicate: 'Sindicato Illimani',
      points: _rioSecoCejaPoints,
      stops: _rioSecoCejaStops,
      fare: 2.50,
      estimatedDurationMin: 25,
    ),
    MinibusRoute(
      id: 'MB_CEJA_6AGOSTO',
      name: 'Ceja - 6 de Agosto',
      syndicate: 'Sindicato Cotranstur',
      points: _cejaSeisAgostoPoints,
      stops: _cejaSeisAgostoStops,
      fare: 4.00,
      estimatedDurationMin: 30,
    ),
    MinibusRoute(
      id: 'MB_PEREZ_COTACOTA',
      name: 'Pérez - Cota Cota',
      syndicate: 'Sindicato Señora de La Paz',
      points: _perezCotaCotaPoints,
      stops: _perezCotaCotaStops,
      fare: 4.00,
      estimatedDurationMin: 35,
    ),
    MinibusRoute(
      id: 'MB_CEJA_TELEFERICO',
      name: 'Ceja - Teleférico',
      syndicate: 'Sindicato Minaza',
      points: _cejaTelefericoPoints,
      stops: _cejaTelefericoStops,
      fare: 2.00,
      estimatedDurationMin: 12,
    ),
  ];

  /// Obtiene todas las paradas de minibús (puntos de referencia)
  static List<Place> get allStops {
    final stops = <Place>[];
    for (final route in allRoutes) {
      stops.addAll(route.stops);
    }
    return stops;
  }

  /// Encuentra la ruta de minibús más cercana a un punto
  static MinibusRoute? findNearestRoute(LatLng point, {double maxDistance = 500}) {
    MinibusRoute? nearest;
    double minDistance = double.infinity;

    for (final route in allRoutes) {
      for (final routePoint in route.points) {
        final distance = GeoUtils.distanceMeters(point, routePoint);
        if (distance < minDistance && distance < maxDistance) {
          minDistance = distance;
          nearest = route;
        }
      }
    }

    return nearest;
  }

  /// Encuentra el punto más cercano de una ruta a un punto dado
  static LatLng findNearestPointOnRoute(LatLng point, MinibusRoute route) {
    LatLng nearestPoint = route.points.first;
    double minDistance = double.infinity;

    for (final routePoint in route.points) {
      final distance = GeoUtils.distanceMeters(point, routePoint);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = routePoint;
      }
    }

    return nearestPoint;
  }
}