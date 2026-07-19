import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';
import '../data/pumakatari_data.dart';

/// Mapa real de La Paz/El Alto (tiles de OpenStreetMap).
/// Muestra las líneas de Teleférico y PumaKatari dibujadas con sus colores.
class RealCityMap extends StatelessWidget {
  final LatLng center;
  final LatLng? originMarker;
  final LatLng? destinationMarker;
  final void Function(LatLng)? onLongPressPick;
  final MapController? controller;

  final List<Polyline> extraPolylines;
  final List<Marker> extraMarkers;
  final bool showTelefericoNetwork;
  final bool showPumaNetwork;

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
    this.showPumaNetwork = true,
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

        // ============================================================
        // LÍNEAS DE TELEFÉRICO
        // ============================================================
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

        // ============================================================
        // LÍNEAS DE PUMAKATARI (NUEVO)
        // ============================================================
        if (showPumaNetwork)
          PolylineLayer(
            polylines: PumaKatariData.allRoutes
                .expand((route) => [
                      // Ruta IDA - línea sólida
                      Polyline(
                        points: route.stops.map((s) => s.location).toList(),
                        color: _getPumaColor(route.id, isReturn: false),
                        strokeWidth: 4,
                      ),
                      // Ruta VUELTA - línea más clara (sin punteado)
                      Polyline(
                        points: route.returnStops.map((s) => s.location).toList(),
                        color: _getPumaColor(route.id, isReturn: true),
                        strokeWidth: 3,
                      ),
                    ])
                .toList(),
          ),

        // ============================================================
        // POLILINEAS ADICIONALES
        // ============================================================
        if (extraPolylines.isNotEmpty) PolylineLayer(polylines: extraPolylines),

        // ============================================================
        // MARCADORES
        // ============================================================
        MarkerLayer(
          markers: [
            // Marcadores de Teleférico
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

            // Marcadores de PumaKatari (paradas principales)
            if (showPumaNetwork)
              for (final route in PumaKatariData.allRoutes)
                for (final stop in route.stops)
                  Marker(
                    point: stop.location,
                    width: 8,
                    height: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getPumaColor(route.id, isReturn: false),
                        border: Border.all(color: Colors.white, width: 1.0),
                      ),
                    ),
                  ),

            // Marcador de origen
            if (originMarker != null)
              Marker(
                point: originMarker!,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location_rounded, color: Colors.blue, size: 32),
              ),

            // Marcador de destino
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

        // ============================================================
        // LEYENDA
        // ============================================================
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

  Color _getPumaColor(String routeId, {required bool isReturn}) {
    switch (routeId) {
      case 'PK_ACHUMANI':
        return isReturn ? const Color(0xFF9C27B0) : const Color(0xFF7B1FA2); // Morado
      case 'PK_CHASQUIPAMPA':
        return isReturn ? const Color(0xFFFF6F00) : const Color(0xFFE65100); // Naranja
      default:
        return isReturn ? const Color(0xFF546E7A) : const Color(0xFF37474F); // Gris
    }
  }
}