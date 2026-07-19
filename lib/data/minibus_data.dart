import 'package:latlong2/latlong.dart';
import '../models/place.dart';

class MinibusRoute {
  final String id;
  final String name;
  final String syndicate;
  final List<Place> stops;
  final List<int> times; // minutos desde la primera parada
  final double fare;

  const MinibusRoute({
    required this.id,
    required this.name,
    required this.syndicate,
    required this.stops,
    required this.times,
    required this.fare,
  });
}

class MinibusData {
  MinibusData._();

  static const List<MinibusRoute> allRoutes = [
    // Ruta 1: Río Seco → Plaza Avaroa (vía Irpavi, Obrajes, Sopocachi)
    MinibusRoute(
      id: 'MB1',
      name: 'Línea Litoral',
      syndicate: 'Sindicato Litoral',
      stops: [
        Place(name: 'Río Seco', location: LatLng(-16.4660, -68.1660)),
        Place(name: 'Irpavi', location: LatLng(-16.5330, -68.1080)),
        Place(name: 'Obrajes', location: LatLng(-16.5230, -68.1120)),
        Place(name: 'Sopocachi', location: LatLng(-16.5074, -68.1260)),
        Place(name: 'Plaza Avaroa', location: LatLng(-16.5080, -68.1230)),
      ],
      times: [0, 12, 18, 25, 28],
      fare: 3.50,
    ),
    // Ruta 2: Plaza Estudiante → Cota Cota (vía San Miguel, Calacoto)
    MinibusRoute(
      id: 'MB2',
      name: 'Línea 6 de Marzo',
      syndicate: 'Sindicato 6 de Marzo',
      stops: [
        Place(name: 'Plaza Estudiante', location: LatLng(-16.4970, -68.1300)),
        Place(name: 'San Miguel', location: LatLng(-16.5200, -68.0950)),
        Place(name: 'Calacoto', location: LatLng(-16.5280, -68.0850)),
        Place(name: 'Cota Cota Calle 14', location: LatLng(-16.5200, -68.0750)),
      ],
      times: [0, 10, 15, 20],
      fare: 3.50,
    ),
    // Ruta 3: Camacho → Lagunas de Hampaturi (vía San Pedro, Villa Fátima)
    MinibusRoute(
      id: 'MB3',
      name: 'Línea Kollasuyo',
      syndicate: 'Sindicato Kollasuyo',
      stops: [
        Place(name: 'Camacho', location: LatLng(-16.4950, -68.1350)),
        Place(name: 'San Pedro', location: LatLng(-16.4980, -68.1300)),
        Place(name: 'Villa Fátima', location: LatLng(-16.4800, -68.1450)),
        Place(name: 'Lagunas de Hampaturi', location: LatLng(-16.4600, -68.1700)),
      ],
      times: [0, 8, 16, 28],
      fare: 4.00,
    ),
    // Ruta 4: Pérez → Hospital Materno Infantil (vía Camacho, La Portada)
    MinibusRoute(
      id: 'MB4',
      name: 'Línea Bolívar',
      syndicate: 'Sindicato Bolívar',
      stops: [
        Place(name: 'Pérez', location: LatLng(-16.4930, -68.1330)),
        Place(name: 'Camacho', location: LatLng(-16.4950, -68.1350)),
        Place(name: 'La Portada', location: LatLng(-16.4850, -68.1420)),
        Place(name: 'Hospital Materno Infantil', location: LatLng(-16.4800, -68.1500)),
      ],
      times: [0, 6, 14, 20],
      fare: 4.00,
    ),
  ];

  static List<Place> get allStops {
    final stops = <Place>[];
    for (final route in allRoutes) {
      stops.addAll(route.stops);
    }
    return stops;
  }
}