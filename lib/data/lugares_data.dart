import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import 'teleferico_data.dart';
import 'pumakatari_data.dart';
import 'minibus_data.dart';

/// Unifica TODOS los lugares conocidos en un solo lugar
/// para facilitar la búsqueda y geocodificación.
class LugaresData {
  LugaresData._();

  /// TODOS los lugares conocidos con sus coordenadas
  static final List<Place> todosLosLugares = [
    // ============================================================
    // LUGARES DE TELEFÉRICO
    // ============================================================
    for (final line in TelefericoData.allLines)
      ...line.stations,

    // ============================================================
    // LUGARES DE PUMAKATARI
    // ============================================================
    ...PumaKatariData.allStops,

    // ============================================================
    // LUGARES DE MINIBÚS (puntos de referencia)
    // ============================================================
    ...MinibusData.allStops,

    // ============================================================
    // LUGARES ADICIONALES (puntos clave de la ciudad)
    // ============================================================
    TelefericoData.plazaAvaroa,
    TelefericoData.miraflores,
    TelefericoData.rioSeco,
  ];

  /// Busca un lugar por su nombre (coincidencia exacta primero, luego parcial)
  static Place? buscarLugar(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return null;

    // 1. Coincidencia exacta
    for (final place in todosLosLugares) {
      if (place.name.toLowerCase() == lower) return place;
    }

    // 2. Coincidencia parcial (que contenga la consulta)
    for (final place in todosLosLugares) {
      if (place.name.toLowerCase().contains(lower)) return place;
    }

    // 3. Coincidencia parcial inversa (que la consulta contenga el nombre)
    for (final place in todosLosLugares) {
      if (lower.contains(place.name.toLowerCase())) return place;
    }

    return null;
  }

  /// Obtiene TODOS los lugares para el buscador (sugerencias)
  static List<Place> get allPlaces => todosLosLugares;

  /// Obtiene los nombres de todos los lugares
  static List<String> get allNames =>
      todosLosLugares.map((p) => p.name).toList();
}