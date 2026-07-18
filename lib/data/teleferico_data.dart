import 'package:latlong2/latlong.dart';
import '../models/place.dart';

/// Datos REALES de la red de Mi Teleférico (verificados con fuentes públicas:
/// sitio oficial miteleferico.bo, Wikipedia, prensa boliviana - julio 2026).
///
/// Las coordenadas son aproximadas (ubicación real del barrio/estación,
/// tomadas de referencias geográficas públicas). Para precisión exacta de
/// GPS de cada estación, lo ideal es que el equipo camine o revise el mapa
/// oficial https://sitservicios.lapaz.bo/sit/ods/mapas/ y ajuste estos
/// puntos - la estructura de datos ya está lista para eso, solo hay que
/// cambiar los números de lat/lng.
class TelefericoLine {
  final String name;
  final String colorHex;
  final List<Place> stations;
  final int durationMin;

  const TelefericoLine({
    required this.name,
    required this.colorHex,
    required this.stations,
    required this.durationMin,
  });
}

class TelefericoData {
  TelefericoData._();

  static const azul = TelefericoLine(
    name: 'Línea Azul',
    colorHex: '#1E5FCC',
    durationMin: 20,
    stations: [
      Place(name: 'Estación Río Seco', location: LatLng(-16.4660, -68.1660)),
      Place(name: 'Estación UPEA', location: LatLng(-16.4780, -68.1690)),
      Place(name: 'Estación Plaza La Paz', location: LatLng(-16.4900, -68.1680)),
      Place(name: 'Estación Libertad', location: LatLng(-16.4950, -68.1690)),
      Place(name: 'Estación 16 de Julio', location: LatLng(-16.4975, -68.1685)),
    ],
  );

  static const roja = TelefericoLine(
    name: 'Línea Roja',
    colorHex: '#CC0000',
    durationMin: 11,
    stations: [
      Place(name: 'Estación 16 de Julio', location: LatLng(-16.4975, -68.1685)),
      Place(name: 'Estación Cementerio', location: LatLng(-16.4930, -68.1450)),
      Place(name: 'Estación Central', location: LatLng(-16.4987, -68.1330)),
    ],
  );

  static const amarilla = TelefericoLine(
    name: 'Línea Amarilla',
    colorHex: '#F2C500',
    durationMin: 17,
    stations: [
      Place(name: 'Estación Mirador', location: LatLng(-16.5210, -68.1580)),
      Place(name: 'Estación Buenos Aires', location: LatLng(-16.5120, -68.1500)),
      Place(name: 'Estación Sopocachi', location: LatLng(-16.5074, -68.1260)),
      Place(name: 'Estación Libertador', location: LatLng(-16.5040, -68.1220)),
    ],
  );

  static const naranja = TelefericoLine(
    name: 'Línea Naranja',
    colorHex: '#FF8C00',
    durationMin: 11,
    stations: [
      Place(name: 'Estación Central', location: LatLng(-16.4987, -68.1330)),
      Place(name: 'Estación Armentia', location: LatLng(-16.4940, -68.1300)),
      Place(name: 'Estación Periférica', location: LatLng(-16.4900, -68.1270)),
      Place(name: 'Estación Plaza Villarroel', location: LatLng(-16.4870, -68.1230)),
    ],
  );

  static const verde = TelefericoLine(
    name: 'Línea Verde',
    colorHex: '#1E9E4A',
    durationMin: 16,
    stations: [
      Place(name: 'Estación Libertador', location: LatLng(-16.5040, -68.1220)),
      Place(name: 'Estación Alto Obrajes', location: LatLng(-16.5150, -68.1150)),
      Place(name: 'Estación Obrajes', location: LatLng(-16.5230, -68.1120)),
      Place(name: 'Estación Irpavi', location: LatLng(-16.5330, -68.1080)),
    ],
  );

  static const List<TelefericoLine> allLines = [azul, roja, amarilla, naranja, verde];

  /// Plaza Avaroa está en pleno Sopocachi, a un par de cuadras de la
  /// estación Sopocachi de la Línea Amarilla.
  static const plazaAvaroa = Place(name: 'Plaza Avaroa', location: LatLng(-16.5080, -68.1230));

  /// Zona de Miraflores, servida por la Línea Blanca (no incluida arriba
  /// por falta de dato verificado de coordenadas exactas; usamos el punto
  /// del barrio para la Ruta 2 de la demo).
  static const miraflores = Place(name: 'Miraflores', location: LatLng(-16.4940, -68.1180));

  static const rioSeco = Place(name: 'Río Seco', location: LatLng(-16.4660, -68.1660));
}
