import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transport_models.dart';
import 'device_id_service.dart';

/// Guarda cada viaje que el usuario inicia con Modo Seguro, en su propia
/// colección "trip_history" (separada de "trameaje_reports" y de
/// "emergency_contacts" - cada tipo de dato vive en su propia colección,
/// no todo mezclado).
class TripHistoryRepository {
  TripHistoryRepository._();
  static final TripHistoryRepository instance = TripHistoryRepository._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('trip_history');

  Future<void> saveTrip(TripPlan plan) async {
    final deviceId = await DeviceIdService.getId();
    await _collection.add({
      'deviceId': deviceId,
      'origin': plan.origin,
      'destination': plan.destination,
      'totalFareBs': plan.totalFareBs,
      'totalDurationMin': plan.totalDurationMin,
      'segmentCount': plan.segments.length,
      'startedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Historial solo de este dispositivo (no de todos los usuarios).
  Stream<List<Map<String, dynamic>>> watchMyHistory() {
    return DeviceIdService.getId().asStream().asyncExpand((deviceId) {
      return _collection
          .where('deviceId', isEqualTo: deviceId)
          .orderBy('startedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).toList());
    });
  }
}
