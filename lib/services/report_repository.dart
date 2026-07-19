import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transport_models.dart';

/// Guarda y lee los reportes de trameaje en Firestore, en la colección
/// "trameaje_reports". A diferencia de la lista en memoria de antes, esto
/// es compartido: cualquier usuario (y en el futuro, la Alcaldía) puede
/// ver todos los reportes, y quedan guardados aunque cierres la app.
class ReportRepository {
  ReportRepository._();
  static final ReportRepository instance = ReportRepository._();

  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('trameaje_reports');

  Future<void> submitReport(TrameajeReport report) async {
    await _collection.add(report.toMap());
  }

  /// Stream en tiempo real: si otro usuario (o la Alcaldía) cambia el
  /// estado de un reporte, la lista se actualiza sola sin recargar.
  Stream<List<TrameajeReport>> watchReports() {
    return _collection
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrameajeReport.fromMap(doc.id, doc.data()))
            .toList());
  }
}
