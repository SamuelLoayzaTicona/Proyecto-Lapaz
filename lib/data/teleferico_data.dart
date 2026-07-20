import 'package:latlong2/latlong.dart';
import '../models/place.dart';

/// Datos ACTUALIZADOS de la red de Mi Teleférico (verificados con fuentes públicas:
/// sitio oficial miteleferico.bo, Wikipedia, prensa boliviana - julio 2026).
///
/// INCLUYE:
/// - Línea Azul (Río Seco → 16 de Julio)
/// - Línea Roja (16 de Julio → Central)
/// - Línea Amarilla (Mirador → Libertador)
/// - Línea Naranja (Central → Plaza Villarroel)
/// - Línea Verde (Libertador → Irpavi)
/// - Línea Blanca (Central → Miraflores) - ¡NUEVA!
/// - Línea Celeste (Prado → El Alto) - ¡NUEVA!
/// - Línea Morada (Obelisco → El Alto) - ¡NUEVA!
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

  // ============================================================
  // LÍNEA AZUL: Río Seco ↔ 16 de Julio
  // ============================================================
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

  // ============================================================
  // LÍNEA ROJA: 16 de Julio ↔ Central
  // ============================================================
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

  // ============================================================
  // LÍNEA AMARILLA: Mirador ↔ Libertador
  // ============================================================
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

  // ============================================================
  // LÍNEA NARANJA: Central ↔ Plaza Villarroel
  // ============================================================
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

  // ============================================================
  // LÍNEA VERDE: Libertador ↔ Irpavi
  // ============================================================
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

  // ============================================================
  // LÍNEA BLANCA: Central ↔ Miraflores
  // ============================================================
  static const blanca = TelefericoLine(
    name: 'Línea Blanca',
    colorHex: '#E0E0E0', // Blanco/gris claro
    durationMin: 12,
    stations: [
      Place(name: 'Estación Central', location: LatLng(-16.4987, -68.1330)),
      Place(name: 'Estación Armentia', location: LatLng(-16.4940, -68.1300)),
      Place(name: 'Estación Miraflores', location: LatLng(-16.4900, -68.1270)),
      Place(name: 'Estación Plaza Villarroel', location: LatLng(-16.4870, -68.1230)),
    ],
  );

  // ============================================================
  // LÍNEA CELESTE: Prado ↔ El Alto
  // ============================================================
  static const celeste = TelefericoLine(
    name: 'Línea Celeste',
    colorHex: '#00BCD4',
    durationMin: 15,
    stations: [
      Place(name: 'Estación Prado', location: LatLng(-16.5009, -68.1334)),
      Place(name: 'Estación Obelisco', location: LatLng(-16.4996, -68.1345)),
      Place(name: 'Estación 6 de Marzo', location: LatLng(-16.5224, -68.1689)),
      Place(name: 'Estación El Alto', location: LatLng(-16.5300, -68.1700)),
    ],
  );

  // ============================================================
  // LÍNEA MORADA: Obelisco ↔ El Alto
  // ============================================================
  static const morada = TelefericoLine(
    name: 'Línea Morada',
    colorHex: '#9C27B0',
    durationMin: 18,
    stations: [
      Place(name: 'Estación Obelisco', location: LatLng(-16.4996, -68.1345)),
      Place(name: 'Estación 6 de Marzo', location: LatLng(-16.5224, -68.1689)),
      Place(name: 'Estación El Alto', location: LatLng(-16.5300, -68.1700)),
    ],
  );

  // ============================================================
  // LISTA DE TODAS LAS LÍNEAS
  // ============================================================
  static const List<TelefericoLine> allLines = [
    azul,
    roja,
    amarilla,
    naranja,
    verde,
    blanca,
    celeste,
    morada,
  ];

  // ============================================================
  // LUGARES ADICIONALES
  // ============================================================

  /// Plaza Avaroa está en pleno Sopocachi, a un par de cuadras de la
  /// estación Sopocachi de la Línea Amarilla.
  static const plazaAvaroa = Place(name: 'Plaza Avaroa', location: LatLng(-16.5080, -68.1230));

  /// Zona de Miraflores (referencia)
  static const miraflores = Place(name: 'Miraflores', location: LatLng(-16.4940, -68.1180));

  /// Río Seco (inicio de la Línea Azul)
  static const rioSeco = Place(name: 'Río Seco', location: LatLng(-16.4660, -68.1660));

  /// El Alto (punto de conexión)
  static const elAlto = Place(name: 'El Alto', location: LatLng(-16.5300, -68.1700));

  /// Obrajes (conexión con Línea Verde)
  static const obrajes = Place(name: 'Obrajes', location: LatLng(-16.5230, -68.1120));

  /// Irpavi (final de Línea Verde)
  static const irpavi = Place(name: 'Irpavi', location: LatLng(-16.5330, -68.1080));
}