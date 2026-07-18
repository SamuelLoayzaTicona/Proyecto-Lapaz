import 'package:flutter/material.dart';
import '../models/transport_models.dart';
import '../widgets/route_step_card.dart';
import 'live_trip_screen.dart';

class TripPlanScreen extends StatelessWidget {
  final TripPlan plan;

  const TripPlanScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu viaje')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryStat(Icons.payments_rounded, 'Bs. ${plan.totalFareBs.toStringAsFixed(2)}'),
                _summaryStat(Icons.schedule_rounded, '${plan.totalDurationMin} min'),
                _summaryStat(Icons.alt_route_rounded, '${plan.segments.length} tramos'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plan.segments.length,
              itemBuilder: (context, index) {
                return RouteStepCard(
                  segment: plan.segments[index],
                  isLast: index == plan.segments.length - 1,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LiveTripScreen(plan: plan)),
                );
              },
              icon: const Icon(Icons.shield_rounded),
              label: const Text('Iniciar viaje con Modo Seguro'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
