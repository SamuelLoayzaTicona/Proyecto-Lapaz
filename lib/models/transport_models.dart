import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Los modos de transporte que combina la app.
enum TransportMode { walk, minibus, teleferico, pumakatari }

extension TransportModeX on TransportMode {
  String get label {
    switch (this) {
      case TransportMode.walk:
        return 'Caminando';
      case TransportMode.minibus:
        return 'Minibús';
      case TransportMode.teleferico:
        return 'Teleférico';
      case TransportMode.pumakatari:
        return 'PumaKatari';
    }
  }

  IconData get icon {
    switch (this) {
      case TransportMode.walk:
        return Icons.directions_walk_rounded;
      case TransportMode.minibus:
        return Icons.airport_shuttle_rounded;
      case TransportMode.teleferico:
        return Icons.cable_rounded;
      case TransportMode.pumakatari:
        return Icons.directions_bus_filled_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TransportMode.walk:
        return const Color(0xFF7C8B9A);
      case TransportMode.minibus:
        return const Color(0xFFE0463F);
      case TransportMode.teleferico:
        return const Color(0xFF1FB6D6);
      case TransportMode.pumakatari:
        return const Color(0xFF2E9E5B);
    }
  }
}

/// Un tramo del viaje, con coordenadas GPS REALES (no posiciones inventadas)
/// para poder dibujarlo en el mapa real y comparar la ruta en vivo contra
/// la ubicación GPS del usuario en el Modo Seguro.
class RouteSegment {
  final TransportMode mode;
  final String title;
  final String subtitle;
  final String instruction;
  final double fareBs;
  final int durationMin;
  final String fromStop;
  final String toStop;

  /// Coordenadas reales del tramo, en orden, usadas para dibujar la línea
  /// en el mapa y para detectar desvíos comparando contra el GPS real.
  final List<LatLng> geoPoints;

  final String? syndicate;
  final String? plate;

  const RouteSegment({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.instruction,
    required this.fareBs,
    required this.durationMin,
    required this.fromStop,
    required this.toStop,
    required this.geoPoints,
    this.syndicate,
    this.plate,
  });
}

/// El viaje completo combinado, de origen a destino.
class TripPlan {
  final String origin;
  final String destination;
  final List<RouteSegment> segments;

  const TripPlan({
    required this.origin,
    required this.destination,
    required this.segments,
  });

  double get totalFareBs => segments.fold(0.0, (sum, s) => sum + s.fareBs);
  int get totalDurationMin => segments.fold(0, (sum, s) => sum + s.durationMin);

  /// Todos los puntos de la ruta en un solo camino continuo (útil para
  /// dibujar la ruta completa y para el chequeo de desvío del Modo Seguro).
  List<LatLng> get fullRoutePoints => segments.expand((s) => s.geoPoints).toList();
}

/// Reporte de "trameaje" (cuando un minibús no respeta su ruta/tarifa).
class TrameajeReport {
  final String? id;
  final String syndicate;
  final String plate;
  final String description;
  final DateTime reportedAt;
  final String status; // 'Recibido' | 'En revisión' | 'Atendido'

  const TrameajeReport({
    this.id,
    required this.syndicate,
    required this.plate,
    required this.description,
    required this.reportedAt,
    this.status = 'Recibido',
  });

  Map<String, dynamic> toMap() {
    return {
      'syndicate': syndicate,
      'plate': plate,
      'description': description,
      'reportedAt': reportedAt.toIso8601String(),
      'status': status,
    };
  }

  factory TrameajeReport.fromMap(String id, Map<String, dynamic> map) {
    return TrameajeReport(
      id: id,
      syndicate: map['syndicate'] as String? ?? 'Desconocido',
      plate: map['plate'] as String? ?? '',
      description: map['description'] as String? ?? '',
      reportedAt: DateTime.tryParse(map['reportedAt'] as String? ?? '') ?? DateTime.now(),
      status: map['status'] as String? ?? 'Recibido',
    );
  }
}
