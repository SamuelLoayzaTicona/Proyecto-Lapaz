import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/transport_models.dart';
import '../services/alert_service.dart';
import '../services/geo_utils.dart';
import '../services/location_service.dart';
import '../state/emergency_contact_state.dart';
import '../widgets/real_city_map.dart';
import 'report_screen.dart';

/// Distancia (en metros) a partir de la cual consideramos que el vehículo
/// se desvió de la ruta planificada. 500 m como pediste.
const double _deviationThresholdMeters = 500;

class LiveTripScreen extends StatefulWidget {
  final TripPlan plan;
  const LiveTripScreen({super.key, required this.plan});

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen> {
  bool _safeModeOn = true;
  bool _isDeviating = false;
  bool _alertSent = false;
  LatLng? _currentPosition;
  double _distanceToRouteMeters = 0;
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _simulatedDeviationPoint;

  late final List<LatLng> _routePoints = widget.plan.fullRoutePoints;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    try {
      // Posición inicial real.
      final position = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
      _evaluatePosition(LatLng(position.latitude, position.longitude));

      // Suscripción a cambios de posición REALES del GPS. Esto es lo que
      // hace que el desvío se detecte automáticamente si de verdad te
      // alejas de la ruta - no depende de que aprietes ningún botón.
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15, // recalcula cada ~15 m de movimiento real
        ),
      ).listen((pos) {
        if (!mounted) return;
        final point = LatLng(pos.latitude, pos.longitude);
        setState(() => _currentPosition = point);
        _evaluatePosition(point);
      });
    } catch (_) {
      // Sin GPS disponible: la pantalla sigue funcionando, pero solo con
      // el botón de simulación manual.
    }
  }

  void _evaluatePosition(LatLng point) {
    final distance = GeoUtils.minDistanceToRouteMeters(point, _routePoints);
    setState(() => _distanceToRouteMeters = distance);

    if (!_safeModeOn) return;

    if (distance > _deviationThresholdMeters && !_isDeviating) {
      _triggerDeviation(point);
    } else if (distance <= _deviationThresholdMeters && _isDeviating && _simulatedDeviationPoint == null) {
      // Volvió a la ruta real (y no hay una simulación manual activa).
      setState(() => _isDeviating = false);
    }
  }

  Future<void> _triggerDeviation(LatLng atPoint) async {
    setState(() {
      _isDeviating = true;
      _alertSent = false;
    });
    HapticFeedback.heavyImpact();

    if (!EmergencyContactState.isConfigured) {
      if (!mounted) return;
      _showNoContactDialog();
      return;
    }

    final sent = await AlertService.sendDeviationAlert(
      phone: EmergencyContactState.phone.value!,
      currentPosition: atPoint,
    );
    if (!mounted) return;
    setState(() => _alertSent = sent);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: sent ? Colors.red : Colors.orange,
        content: Text(
          sent
              ? '🚨 Alerta enviada por WhatsApp a ${EmergencyContactState.name.value ?? 'tu contacto'}.'
              : 'No se pudo abrir WhatsApp. Verifica el número del contacto.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showNoContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sin contacto de emergencia'),
        content: const Text(
          'Detectamos un desvío, pero no tienes un contacto de emergencia registrado. '
          'Agrégalo para que la próxima alerta se envíe automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showEmergencyContactSheet();
            },
            child: const Text('Agregar contacto'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContactSheet() {
    final nameController = TextEditingController(text: EmergencyContactState.name.value ?? '');
    final phoneController = TextEditingController(text: EmergencyContactState.phone.value ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contacto de emergencia', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(
                'Si el transporte se desvía, le enviaremos su ubicación por WhatsApp automáticamente.',
                style: TextStyle(color: Colors.black54, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Número (con código de país)',
                  hintText: 'Ej: 59171234567',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await EmergencyContactState.save(
                    contactName: nameController.text.trim(),
                    contactPhone: phoneController.text.trim(),
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contacto de emergencia guardado.')),
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Simula un desvío sin necesitar moverte de tu casa: mueve un punto
  /// "falso" lejos de la ruta y lo mete por el mismo camino de detección
  /// real, así se prueba exactamente la misma lógica que se usaría con un
  /// desvío de verdad.
  void _simulateDeviation() {
    final base = _currentPosition ?? _routePoints.first;
    final fakePoint = LatLng(base.latitude + 0.008, base.longitude + 0.006); // ~800-900 m
    setState(() => _simulatedDeviationPoint = fakePoint);
    _evaluatePosition(fakePoint);
  }

  void _resumeTrip() {
    setState(() {
      _isDeviating = false;
      _alertSent = false;
      _simulatedDeviationPoint = null;
    });
    if (_currentPosition != null) _evaluatePosition(_currentPosition!);
  }

  @override
  Widget build(BuildContext context) {
    final displayPosition = _simulatedDeviationPoint ?? _currentPosition;
    final currentSegment = _currentSegmentGuess();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viaje en curso'),
        actions: [
          IconButton(
            tooltip: 'Contacto de emergencia',
            icon: Icon(
              EmergencyContactState.isConfigured ? Icons.contact_phone_rounded : Icons.person_add_alt_1_rounded,
            ),
            onPressed: _showEmergencyContactSheet,
          ),
          Row(
            children: [
              const Icon(Icons.shield_rounded, size: 20),
              Switch(
                value: _safeModeOn,
                onChanged: (v) => setState(() => _safeModeOn = v),
                activeColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isDeviating)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _alertSent
                              ? 'Desvío detectado. Alerta enviada a tu contacto.'
                              : 'Desvío detectado (${_distanceToRouteMeters.round()} m de la ruta).',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                          ),
                          onPressed: _resumeTrip,
                          child: const Text('Todo bien, continuar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReportScreen(
                                  prefilledSyndicate: currentSegment?.syndicate,
                                ),
                              ),
                            );
                          },
                          child: const Text('Reportar trameaje'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: RealCityMap(
              center: displayPosition ?? _routePoints.first,
              showTelefericoNetwork: false,
              extraPolylines: [
                for (final segment in widget.plan.segments)
                  Polyline(
                    points: segment.geoPoints,
                    color: segment.mode.color,
                    strokeWidth: segment.mode == TransportMode.teleferico ? 4 : 6,
                  ),
              ],
              extraMarkers: [
                if (displayPosition != null)
                  Marker(
                    point: displayPosition,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isDeviating ? Colors.red : Colors.blue,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentSegment != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: currentSegment.mode.color,
                        child: Icon(currentSegment.mode.icon, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          currentSegment.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  _currentPosition == null
                      ? 'Obteniendo tu ubicación GPS...'
                      : 'Distancia a la ruta: ${_distanceToRouteMeters.round()} m '
                          '(se avisa automáticamente sobre los ${_deviationThresholdMeters.round()} m).',
                  style: const TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
                const Text(
                  'Nota: el Teleférico se dibuja en línea recta a propósito (es un cable '
                  'aéreo real). Caminata y minibús sí siguen calles.',
                  style: TextStyle(color: Colors.black38, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportScreen(prefilledSyndicate: currentSegment?.syndicate),
                            ),
                          );
                        },
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text('Reportar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isDeviating ? null : _simulateDeviation,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        icon: const Icon(Icons.bug_report_rounded),
                        label: const Text('Simular (prueba)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  RouteSegment? _currentSegmentGuess() {
    final point = _simulatedDeviationPoint ?? _currentPosition;
    if (point == null) return null;
    RouteSegment? closest;
    double best = double.infinity;
    for (final segment in widget.plan.segments) {
      final d = GeoUtils.minDistanceToRouteMeters(point, segment.geoPoints);
      if (d < best) {
        best = d;
        closest = segment;
      }
    }
    return closest;
  }
}
