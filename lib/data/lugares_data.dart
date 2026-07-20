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

  /// Busca un lugar por su nombre. Es ESTRICTO a propósito: solo acepta
  /// una coincidencia parcial cuando es ÚNICA - así evitamos que "Cota
  /// Cota" termine sugiriendo un lugar de "La Ceja" sin relación real.
  static Place? buscarLugar(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return null;

    for (final place in todosLosLugares) {
      if (place.name.toLowerCase() == lower) return place;
    }

    final startsWithMatches =
        todosLosLugares.where((p) => p.name.toLowerCase().startsWith(lower)).toList();
    if (startsWithMatches.length == 1) return startsWithMatches.first;

    final containsMatches =
        todosLosLugares.where((p) => p.name.toLowerCase().contains(lower)).toList();
    if (containsMatches.length == 1) return containsMatches.first;

    return null;
  }

  /// Obtiene TODOS los lugares para el buscador (sugerencias)
  static List<Place> get allPlaces => todosLosLugares;

  /// Obtiene los nombres de todos los lugares
  static List<String> get allNames =>
      todosLosLugares.map((p) => p.name).toList();
}