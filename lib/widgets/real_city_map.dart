import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';

/// Mapa real de La Paz/El Alto (tiles de OpenStreetMap, sin necesidad de
/// API key de Google). Muestra las líneas de Teleférico dibujadas con sus
/// colores reales y permite tocar-y-mantener para elegir el destino, igual
/// que en la referencia "Ahora seleccione su destino... presionando por
/// unos segundos".
class RealCityMap extends StatelessWidget {
  final LatLng center;
  final LatLng? originMarker;
  final LatLng? destinationMarker;
  final void Function(LatLng)? onLongPressPick;
  final MapController? controller;

  /// Rutas adicionales a dibujar encima del mapa base (ej: la ruta del
  /// viaje calculado, o la ruta con el tramo de desvío en rojo).
  final List<Polyline> extraPolylines;

  /// Marcadores adicionales (ej: la posición GPS en vivo del usuario).
  final List<Marker> extraMarkers;

  /// Si es false, no dibuja las líneas de Teleférico de fondo (útil en la
  /// pantalla de viaje en vivo para no saturar el mapa).
  final bool showTelefericoNetwork;

  const RealCityMap({
    super.key,
    required this.center,
    this.onLongPressPick,
    this.originMarker,
    this.destinationMarker,
    this.controller,
    this.extraPolylines = const [],
    this.extraMarkers = const [],
    this.showTelefericoNetwork = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        onLongPress: onLongPressPick == null
            ? null
            : (tapPosition, point) => onLongPressPick!(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'bo.lapaz.rutasegura',
          maxZoom: 19,
        ),
        // Líneas de Teleférico dibujadas con sus colores reales.
        if (showTelefericoNetwork)
          PolylineLayer(
            polylines: TelefericoData.allLines
                .map(
                  (line) => Polyline(
                    points: line.stations.map((s) => s.location).toList(),
                    color: _colorFromHex(line.colorHex),
                    strokeWidth: 4,
                  ),
                )
                .toList(),
          ),
        if (extraPolylines.isNotEmpty) PolylineLayer(polylines: extraPolylines),
        MarkerLayer(
          markers: [
            if (showTelefericoNetwork)
              for (final line in TelefericoData.allLines)
                for (final station in line.stations)
                  Marker(
                    point: station.location,
                    width: 10,
                    height: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorFromHex(line.colorHex),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
            if (originMarker != null)
              Marker(
                point: originMarker!,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location_rounded, color: Colors.blue, size: 32),
              ),
            if (destinationMarker != null)
              Marker(
                point: destinationMarker!,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 40),
              ),
            ...extraMarkers,
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Color _colorFromHex(String hex) {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  }
}
