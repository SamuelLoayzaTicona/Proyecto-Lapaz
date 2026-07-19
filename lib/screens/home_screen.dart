import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';
import '../data/pumakatari_data.dart';
import '../models/place.dart';
import '../models/transport_models.dart'; // ← IMPORTANTE: para TripPlan
import '../services/location_service.dart';
import '../services/trip_planner_service.dart';
import '../services/voice_input_service.dart';
import '../state/app_settings.dart';
import '../widgets/real_city_map.dart';
import 'trip_plan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _destinationController = TextEditingController();
  final _mapController = MapController();
  final _voiceService = VoiceInputService();

  LatLng _origin = TelefericoData.rioSeco.location;
  LatLng? _destination;
  String _destinationLabel = '';
  bool _isLocating = true;
  bool _isListening = false;
  bool _isCalculatingRoute = false;
  List<Place> _suggestions = [];

  late final List<Place> _allPlaces = [
    TelefericoData.plazaAvaroa,
    TelefericoData.miraflores,
    TelefericoData.rioSeco,
    for (final line in TelefericoData.allLines) ...line.stations,
    ...PumaKatariData.allStops,
  ];

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      final position = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _origin = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });
      _mapController.move(_origin, 14);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLocating = false);
    }
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _suggestions = _allPlaces
          .where((p) => p.name.toLowerCase().contains(lower))
          .take(5)
          .toList();
    });
  }

  Place? _resolvePlaceFromText(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return null;
    for (final place in _allPlaces) {
      if (place.name.toLowerCase() == lower) return place;
    }
    for (final place in _allPlaces) {
      if (place.name.toLowerCase().contains(lower) || lower.contains(place.name.toLowerCase())) {
        return place;
      }
    }
    return null;
  }

  void _pickPlace(Place place) {
    setState(() {
      _destination = place.location;
      _destinationLabel = place.name;
      _destinationController.text = place.name;
      _suggestions = [];
    });
    _mapController.move(place.location, 14);
  }

  void _pickOnMap(LatLng point) {
    setState(() {
      _destination = point;
      _destinationLabel =
          'Punto en el mapa (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      _destinationController.text = _destinationLabel;
      _suggestions = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Destino elegido en el mapa.'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }
    final available = await _voiceService.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El micrófono no está disponible. Revisa los permisos o escribe tu destino.'),
        ),
      );
      return;
    }
    setState(() => _isListening = true);
    await _voiceService.startListening(
      onResult: (text) {
        setState(() => _isListening = false);
        if (text.trim().isEmpty) return;
        _destinationController.text = text;
        final match = _resolvePlaceFromText(text);
        if (match != null) {
          _pickPlace(match);
        } else {
          setState(() {
            _destinationLabel = text.trim();
            _destination = null;
            _suggestions = [];
          });
        }
      },
    );
  }

  Future<void> _continue() async {
    if (_destinationLabel.isEmpty) {
      final match = _resolvePlaceFromText(_destinationController.text);
      if (match != null) {
        _pickPlace(match);
      } else if (_destinationController.text.trim().isNotEmpty) {
        _destinationLabel = _destinationController.text.trim();
      }
    }

    if (_destinationLabel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige un destino: escribe, usa el micrófono o toca el mapa.')),
      );
      return;
    }

    setState(() => _isCalculatingRoute = true);

    final opciones = await TripPlannerService.planTripOptions(
      origin: _origin,
      destinationQuery: _destinationLabel,
    );

    if (!mounted) return;
    setState(() => _isCalculatingRoute = false);

    if (opciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No encontramos una ruta para "$_destinationLabel". '
            'Prueba con "Campo Verde", "Plaza Camacho" o "Plaza Avaroa".',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (opciones.length == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripPlanScreen(plan: opciones.first)),
      );
      return;
    }

    _showRouteOptionsDialog(context, opciones);
  }

  void _showRouteOptionsDialog(BuildContext context, List<TripPlan> opciones) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elige tu ruta preferida',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona una de las ${opciones.length} opciones disponibles',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: opciones.length,
                  itemBuilder: (context, index) {
                    final plan = opciones[index];
                    return _RouteOptionCard(
                      plan: plan,
                      index: index + 1,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TripPlanScreen(plan: plan)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RealCityMap(
            controller: _mapController,
            center: _origin,
            originMarker: _origin,
            destinationMarker: _destination,
            onLongPressPick: _pickOnMap,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.accessibility_new_rounded, color: Colors.black87),
                      tooltip: 'Accesibilidad',
                      onPressed: () => _showAccessibilitySheet(context),
                    ),
                  ),
                  const Spacer(),
                  FloatingActionButton.small(
                    heroTag: 'locate',
                    onPressed: _detectLocation,
                    backgroundColor: Colors.white,
                    child: _isLocating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿A dónde quieres ir?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Escribe, usa el micrófono o mantén presionado un punto del mapa.',
                      style: TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _destinationController,
                            onChanged: _onSearchChanged,
                            onSubmitted: (text) {
                              final match = _resolvePlaceFromText(text);
                              if (match != null) _pickPlace(match);
                            },
                            decoration: InputDecoration(
                              hintText: 'Ej: Campo Verde, Plaza Camacho...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: const Color(0xFFF2F4F3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
                            tooltip: 'Decir el destino por voz',
                            onPressed: _toggleVoiceInput,
                          ),
                        ),
                      ],
                    ),
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final place = _suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(place.name),
                              onTap: () => _pickPlace(place),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isCalculatingRoute ? null : _continue,
                      icon: _isCalculatingRoute
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.route_rounded),
                      label: Text(_isCalculatingRoute ? 'Calculando por calles reales...' : 'Calcular ruta'),
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

  void _showAccessibilitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accesibilidad', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('Tamaño de texto'),
              ValueListenableBuilder<double>(
                valueListenable: AppSettings.textScale,
                builder: (context, value, _) {
                  return Slider(
                    value: value,
                    min: 0.85,
                    max: 1.6,
                    divisions: 6,
                    label: '${(value * 100).round()}%',
                    onChanged: (v) => AppSettings.textScale.value = v,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  final TripPlan plan;
  final int index;
  final VoidCallback onTap;

  const _RouteOptionCard({
    required this.plan,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text('$index', style: const TextStyle(color: Colors.white)),
        ),
        title: Text('${plan.totalDurationMin} min · Bs. ${plan.totalFareBs.toStringAsFixed(2)}'),
        subtitle: Text('${plan.segments.length} tramos'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}