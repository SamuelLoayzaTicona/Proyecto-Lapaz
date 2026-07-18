import 'package:flutter/material.dart';
import '../models/transport_models.dart';

/// Tarjeta que muestra un tramo del viaje combinado, con línea de tiempo
/// vertical (como en apps de itinerarios) conectando los pasos.
class RouteStepCard extends StatelessWidget {
  final RouteSegment segment;
  final bool isLast;

  const RouteStepCard({
    super.key,
    required this.segment,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = segment.mode.color;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: Icon(segment.mode.icon, color: Colors.white, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: color.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      segment.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      segment.subtitle,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(segment.instruction),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (segment.fareBs > 0)
                          Chip(label: Text('Bs. ${segment.fareBs.toStringAsFixed(2)}')),
                        Chip(label: Text('${segment.durationMin} min')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
