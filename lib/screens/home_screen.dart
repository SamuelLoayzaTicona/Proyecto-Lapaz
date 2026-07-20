import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/teleferico_data.dart';
import '../data/pumakatari_data.dart';
import '../data/lugares_data.dart';
import '../models/place.dart';
import '../models/transport_models.dart';
import '../services/location_service.dart';
import '../services/trip_planner_service.dart';
import '../services/voice_input_service.dart';
import '../services/geocoding_service.dart';
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
  bool _mostrarConfirmacion = false;
  Place? _destinoPendiente;
  bool _esperandoToqueEnMapa = false;
  List<Place> _suggestions = [];

  // ============================================================
  // ESTADO DE CAPAS DEL MAPA
  // ============================================================
  bool _showTeleferico = true;
  bool _showPuma = true;
  bool _showMinibus = true;

  late final List<Place> _allPlaces = LugaresData.allPlaces;

  // ============================================================
  // MÉTODOS DE FILTRO DE CAPAS
  // ============================================================
  void _toggleTeleferico() {
    setState(() {
      _showTeleferico = !_showTeleferico;
    });
  }

  void _togglePuma() {
    setState(() {
      _showPuma = !_showPuma;
    });
  }

  void _toggleMinibus() {
    setState(() {
      _showMinibus = !_showMinibus;
    });
  }

  void _showAllLayers() {
    setState(() {
      _showTeleferico = true;
      _showPuma = true;
      _showMinibus = true;
    });
  }

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

  String _normalize(String text) {
    return text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U');
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final lower = query.toLowerCase().trim();
    final normalized = _normalize(lower);
    setState(() {
      _suggestions = _allPlaces
          .where((p) {
            final nameLower = p.name.toLowerCase();
            final nameNormalized = _normalize(nameLower);
            return nameLower.contains(lower) || nameNormalized.contains(normalized);
          })
          .take(5)
          .toList();
    });
  }

  Place? _resolvePlaceFromText(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return null;
    final normalized = _normalize(lower);

    final result = LugaresData.buscarLugar(text);
    if (result != null) return result;

    for (final place in _allPlaces) {
      final nameLower = place.name.toLowerCase();
      final nameNormalized = _normalize(nameLower);
      if (nameLower == lower || nameNormalized == normalized) {
        return place;
      }
    }

    for (final place in _allPlaces) {
      final nameLower = place.name.toLowerCase();
      final nameNormalized = _normalize(nameLower);
      if (nameLower.contains(lower) || nameNormalized.contains(normalized)) {
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
      _destinoPendiente = place;
      _mostrarConfirmacion = true;
      _esperandoToqueEnMapa = false;
    });
    _mapController.move(place.location, 14);
  }

  void _pickOnMap(LatLng point) {
    if (_esperandoToqueEnMapa) {
      final tempPlace = Place(
        name: 'Punto en el mapa',
        location: point,
      );
      setState(() {
        _destination = point;
        _destinationLabel = 'Punto en el mapa';
        _destinationController.text = 'Punto en el mapa';
        _suggestions = [];
        _destinoPendiente = tempPlace;
        _mostrarConfirmacion = true;
        _esperandoToqueEnMapa = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Destino marcado. Confirma si es correcto.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_mostrarConfirmacion) return;

    final tempPlace = Place(
      name: 'Punto en el mapa',
      location: point,
    );
    setState(() {
      _destination = point;
      _destinationLabel = 'Punto en el mapa';
      _destinationController.text = 'Punto en el mapa';
      _suggestions = [];
      _destinoPendiente = tempPlace;
      _mostrarConfirmacion = true;
    });
    _mapController.move(point, 14);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📍 Destino marcado. Confirma si es correcto.'),
        duration: Duration(seconds: 2),
      ),
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
          _buscarConGeocoding(text.trim());
        }
      },
    );
  }

  Future<void> _buscarConGeocoding(String query) async {
    setState(() => _isCalculatingRoute = true);
    final coords = await GeocodingService.obtenerCoordenadas(query);
    if (!mounted) return;
    setState(() => _isCalculatingRoute = false);

    if (coords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos encontrar "$query". Prueba con otro nombre o toca el mapa.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final place = Place(name: query, location: coords);
    setState(() {
      _destination = coords;
      _destinationLabel = query;
      _destinationController.text = query;
      _destinoPendiente = place;
      _mostrarConfirmacion = true;
      _suggestions = [];
      _esperandoToqueEnMapa = false;
    });
    _mapController.move(coords, 14);
  }

  void _confirmarDestino() {
    if (_destinoPendiente == null) return;
    setState(() {
      _destination = _destinoPendiente!.location;
      _destinationLabel = _destinoPendiente!.name;
      _mostrarConfirmacion = false;
      _esperandoToqueEnMapa = false;
    });
    _calcularRuta();
  }

  void _cancelarConfirmacion() {
    setState(() {
      _mostrarConfirmacion = false;
      _destinoPendiente = null;
      _esperandoToqueEnMapa = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('👆 Mantén presionado el mapa para elegir tu destino manualmente.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _continue() async {
    if (_mostrarConfirmacion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirma o cancela el destino antes de continuar.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_destinationLabel.isEmpty) {
      final match = _resolvePlaceFromText(_destinationController.text);
      if (match != null) {
        _pickPlace(match);
        return;
      } else if (_destinationController.text.trim().isNotEmpty) {
        await _buscarConGeocoding(_destinationController.text.trim());
        return;
      }
    }

    if (_destinationLabel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige un destino: escribe, usa el micrófono o toca el mapa.')),
      );
      return;
    }

    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un lugar válido en el mapa o en la búsqueda.')),
      );
      return;
    }

    _calcularRuta();
  }

  void _calcularRuta() async {
    setState(() => _isCalculatingRoute = true);

    final opciones = await TripPlannerService.planTrip(
      origin: _origin,
      destination: _destination!,
      destinationLabel: _destinationLabel,
    );

    if (!mounted) return;
    setState(() => _isCalculatingRoute = false);

    if (opciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No encontramos una ruta para "$_destinationLabel". '
            'Prueba con otro destino o intenta más tarde.',
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
          height: MediaQuery.of(context).size.height * 0.65,
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
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfirmDialog() {
    if (!_mostrarConfirmacion || _destinoPendiente == null) return const SizedBox.shrink();

    return Positioned(
      top: 130, // Ajustado para que no se superponga con los botones
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¿Ir a "${_destinoPendiente!.name}"?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '(${_destinoPendiente!.location.latitude.toStringAsFixed(4)}, ${_destinoPendiente!.location.longitude.toStringAsFixed(4)})',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelarConfirmacion,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('❌ No, corregir'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmarDestino,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('✅ Sí, ir aquí'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? (color ?? Colors.blue).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? (color ?? Colors.blue) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? (color ?? Colors.blue) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
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
            showTelefericoNetwork: _showTeleferico,
            showPumaNetwork: _showPuma,
            showMinibusNetwork: _showMinibus,
          ),
          // ============================================================
          // BARRA DE FILTROS DE CAPAS
          // ============================================================
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton(
                    icon: Icons.layers,
                    label: 'Todos',
                    isActive: _showTeleferico && _showPuma && _showMinibus,
                    onTap: _showAllLayers,
                    color: Colors.black87,
                  ),
                  _buildFilterButton(
                    icon: Icons.cable,
                    label: 'Teleférico',
                    isActive: _showTeleferico,
                    onTap: _toggleTeleferico,
                    color: Colors.blue,
                  ),
                  _buildFilterButton(
                    icon: Icons.directions_bus,
                    label: 'Puma',
                    isActive: _showPuma,
                    onTap: _togglePuma,
                    color: Colors.purple,
                  ),
                  _buildFilterButton(
                    icon: Icons.airport_shuttle,
                    label: 'Minibús',
                    isActive: _showMinibus,
                    onTap: _toggleMinibus,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          _buildConfirmDialog(),
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
                              if (match != null) {
                                _pickPlace(match);
                              } else if (text.trim().isNotEmpty) {
                                _buscarConGeocoding(text.trim());
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Ej: Plaza Avaroa, Río Seco, Calle 15...',
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
                      onPressed: (_isCalculatingRoute || _mostrarConfirmacion) ? null : _continue,
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
        subtitle: Text('${plan.segments.length} tramos · ${plan.totalDurationMin} min'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}