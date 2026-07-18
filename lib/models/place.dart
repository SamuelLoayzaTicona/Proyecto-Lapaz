import 'package:latlong2/latlong.dart';

/// Un lugar conocido de La Paz/El Alto con su nombre y coordenadas reales,
/// usado para las sugerencias de búsqueda y para centrar el mapa.
class Place {
  final String name;
  final LatLng location;

  const Place({required this.name, required this.location});
}
