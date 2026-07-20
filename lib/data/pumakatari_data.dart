import 'package:latlong2/latlong.dart';
import '../models/place.dart';

class PumaKatariRoute {
  final String id;
  final String name;
  final List<Place> stops; // IDA
  final List<Place> returnStops; // VUELTA
  final List<int> times; // Tiempos estimados entre paradas (IDA)
  final List<int> returnTimes; // Tiempos estimados entre paradas (VUELTA)
  final double fare;
  final int frequencyMinutes; // Frecuencia de paso (aprox)

  const PumaKatariRoute({
    required this.id,
    required this.name,
    required this.stops,
    required this.returnStops,
    required this.times,
    required this.returnTimes,
    required this.fare,
    required this.frequencyMinutes,
  });
}

class PumaKatariData {
  PumaKatariData._();

  // ============================================================
  // RUTA 1: ACHUMANI - SAN PEDRO
  // ============================================================
  static const List<Place> _achumaniIda = [
    Place(name: 'Campo Verde', location: LatLng(-16.50740, -68.052452)),
    Place(name: 'Kellumani', location: LatLng(-16.507252, -68.051587)),
    Place(name: 'Calle 1', location: LatLng(-16.508911, -68.051684)),
    Place(name: 'Av. Strongest', location: LatLng(-16.509945, -68.051297)),
    Place(name: 'Calle 53', location: LatLng(-16.510874, -68.053807)),
    Place(name: 'Calle 49', location: LatLng(-16.511429, -68.055230)),
    Place(name: 'Unidad Educativa Achumani', location: LatLng(-16.512921, -68.057571)),
    Place(name: 'Calle 42', location: LatLng(-16.513534, -68.058465)),
    Place(name: 'Calle 36', location: LatLng(-16.515406, -68.060701)),
    Place(name: 'Complejo the Strongest', location: LatLng(-16.516957, -68.061683)),
    Place(name: 'Calle 31', location: LatLng(-16.518989, -68.062503)),
    Place(name: 'Achumani Calle 29', location: LatLng(-16.521066, -68.063720)),
    Place(name: 'Hogar San Ramon', location: LatLng(-16.523515, -68.066728)),
    Place(name: 'Parque Hernan Greiner', location: LatLng(-16.525193, -68.067709)),
    Place(name: 'Achumani Calle 22', location: LatLng(-16.528772, -68.071025)),
    Place(name: 'Plaza De La Amistad', location: LatLng(-16.531247, -68.070918)),
    Place(name: 'Achumani Calle 16', location: LatLng(-16.532352, -68.072630)),
    Place(name: 'Bicicross', location: LatLng(-16.532010, -68.073513)),
    Place(name: 'Calle 13', location: LatLng(-16.533188, -68.074430)),
    Place(name: 'Plaza Jaime Escalante', location: LatLng(-16.535600, -68.075570)),
    Place(name: 'Iglesia De San Miguel', location: LatLng(-16.539445, -68.077617)),
    Place(name: 'Calacoto Calle 19', location: LatLng(-16.539393, -68.079799)),
    Place(name: 'Calacoto Calle 17', location: LatLng(-16.539229, -68.079846)),
    Place(name: 'Calle 15', location: LatLng(-16.539203, -68.084537)),
    Place(name: 'Calle 12', location: LatLng(-16.539842, -68.086739)),
    Place(name: 'Calacoto Calle 8', location: LatLng(-16.541220, -68.091655)),
    Place(name: 'Pasarela Anapol', location: LatLng(-16.539809, -68.094386)),
    Place(name: 'Campo Ferial', location: LatLng(-16.537066, -68.095469)),
    Place(name: 'Pasarela Barrio Del Periodista', location: LatLng(-16.534070, -68.097057)),
    Place(name: 'Calle 17', location: LatLng(-16.529831, -68.101423)),
    Place(name: 'Calle 14', location: LatLng(-16.528783, -68.103364)),
    Place(name: 'Plaza De La Loba', location: LatLng(-16.527533, -68.105712)),
    Place(name: 'Calle 8', location: LatLng(-16.526300, -68.107915)),
    Place(name: 'Calle 4 De Obrajes', location: LatLng(-16.524566, -68.111065)),
    Place(name: 'Calle 2', location: LatLng(-16.523756, -68.112559)),
    Place(name: 'Avenida Del Libertador, 200', location: LatLng(-16.519669, -68.116337)),
    Place(name: 'Clavijo', location: LatLng(-16.513685, -68.120362)),
    Place(name: 'Campos', location: LatLng(-16.511743, -68.121972)),
    Place(name: 'Plaza Isabel La Católica', location: LatLng(-16.509600, -68.123907)),
    Place(name: 'Graderias Aspiazu', location: LatLng(-16.506004, -68.128786)),
    Place(name: 'Cañada Strongest, 1887', location: LatLng(-16.503853, -68.132227)),
    Place(name: 'Cañada Strongest, 1655', location: LatLng(-16.503286, -68.133849)),
    Place(name: 'Plaza San Pedro', location: LatLng(-16.501987, -68.134106)),
  ];

  static const List<Place> _achumaniVuelta = [
    Place(name: 'Mexico, 1638', location: LatLng(-16.502411, -68.133060)),
    Place(name: 'Av.20 De Octubre, 2095', location: LatLng(-16.507209, -68.129335)),
    Place(name: 'Avenida Sanchéz Lima, 2246', location: LatLng(-16.509201, -68.129079)),
    Place(name: 'Plaza Avaroa', location: LatLng(-16.510850, -68.127303)),
    Place(name: 'Sanchez Lima, 2592', location: LatLng(-16.512486, -68.125537)),
    Place(name: 'Obrajes Calle 0', location: LatLng(-16.521979, -68.115410)),
    Place(name: 'Calle 2', location: LatLng(-16.524065, -68.113411)),
    Place(name: 'Obrajes Calle 5', location: LatLng(-16.525440, -68.111009)),
    Place(name: 'Señor De Exaltacion', location: LatLng(-16.526917, -68.108350)),
    Place(name: 'Plaza De La Loba', location: LatLng(-16.527390, -68.105956)),
    Place(name: 'Calle 14', location: LatLng(-16.528433, -68.104083)),
    Place(name: 'Calle 17', location: LatLng(-16.530059, -68.101164)),
    Place(name: 'Pasarela Barrio Del Periodista', location: LatLng(-16.533462, -68.097677)),
    Place(name: 'Campo Ferial', location: LatLng(-16.536529, -68.095827)),
    Place(name: 'Pasarela Anapol', location: LatLng(-16.539329, -68.094665)),
    Place(name: 'Calle 8 De Calacoto, 21', location: LatLng(-16.541478, -68.092006)),
    Place(name: 'Calacoto Calle 13', location: LatLng(-16.540687, -68.086463)),
    Place(name: 'Calacoto Calle 15', location: LatLng(-16.540116, -68.084147)),
    Place(name: 'Calacoto Calle 18', location: LatLng(-16.539175, -68.080680)),
    Place(name: 'Iglesia De San Miguel', location: LatLng(-16.539049, -68.077570)),
    Place(name: 'Plaza Jaime Escalante', location: LatLng(-16.535510, -68.075469)),
    Place(name: 'Calle 13', location: LatLng(-16.533048, -68.074440)),
    Place(name: 'Calle 16', location: LatLng(-16.531377, -68.073096)),
    Place(name: 'Plaza De La Amistad', location: LatLng(-16.530350, -68.071433)),
    Place(name: 'Calle 22', location: LatLng(-16.528570, -68.071045)),
    Place(name: 'Parque Hernan Greiner', location: LatLng(-16.525317, -68.067755)),
    Place(name: 'Hogar San Ramon', location: LatLng(-16.523446, -68.066733)),
    Place(name: 'Achumani Calle 29', location: LatLng(-16.521486, -68.063783)),
    Place(name: 'Achumani Calle 31', location: LatLng(-16.519377, -68.062517)),
    Place(name: 'Complejo the Strongest', location: LatLng(-16.517462, -68.061961)),
    Place(name: 'Calle 36', location: LatLng(-16.515511, -68.060812)),
    Place(name: 'Calle 42a', location: LatLng(-16.513281, -68.058101)),
    Place(name: 'Calle 40', location: LatLng(-16.512697, -68.057229)),
    Place(name: 'Calle 49', location: LatLng(-16.511322, -68.054949)),
    Place(name: 'Calle 57', location: LatLng(-16.509952, -68.051297)),
    Place(name: 'Huayllani', location: LatLng(-16.508868, -68.051844)),
    Place(name: 'Calle 5', location: LatLng(-16.508868, -68.051844)),
    Place(name: 'Campo Verde', location: LatLng(-16.507679, -68.052781)),
  ];

  static const List<int> _achumaniTimes = [
    0, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 47, 49, 51, 53, 55, 57, 59, 61, 63, 65, 67, 69, 71, 73, 75, 77, 79, 81, 83
  ];

  static const List<int> _achumaniReturnTimes = [
    0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62, 64, 66, 68, 70, 72, 74
  ];

  // ============================================================
  // RUTA 2: CHASQUIPAMPA - PLAZA CAMACHO
  // ============================================================
  static const List<Place> _chasquipampaIda = [
    Place(name: 'CHASQUIPAMPA CALLE 63', location: LatLng(-16.533789, -68.036875)),
    Place(name: 'CHASQUIPAMPA CALLE 60', location: LatLng(-16.534401, -68.040931)),
    Place(name: 'VIRGEN DE LA MERCED', location: LatLng(-16.534401, -68.040931)),
    Place(name: 'LOMAS DE KUPILLANI', location: LatLng(-16.537283, -68.043578)),
    Place(name: 'CHASQUIPAMPA CALLE 53', location: LatLng(-16.537687, -68.045783)),
    Place(name: 'CHASQUIPAMPA CALLE 46', location: LatLng(-16.538430, -68.050478)),
    Place(name: 'CHASQUIPAMPA CALLE 37', location: LatLng(-16.538430, -68.050478)),
    Place(name: 'CHASQUIPAMPA CALLE 35', location: LatLng(-16.541019, -68.057522)),
    Place(name: 'LAGUNA COTA COTA', location: LatLng(-16.541891, -68.062226)),
    Place(name: 'CAMPUS UMSA', location: LatLng(-16.541157, -68.065386)),
    Place(name: 'COTA COTA CALLE 28', location: LatLng(-16.542495, -68.065794)),
    Place(name: 'LOS PINOS CALLE 28', location: LatLng(-16.545388, -68.064598)),
    Place(name: 'LOS PINOS CALLE 27', location: LatLng(-16.544741, -68.066955)),
    Place(name: 'LOS PINOS CALLE 25', location: LatLng(-16.545408, -68.071153)),
    Place(name: 'LOS PINOS CALLE 3', location: LatLng(-16.545221, -68.073430)),
    Place(name: 'FINAL CALLE 21', location: LatLng(-16.544983, -68.076206)),
    Place(name: 'PASAJE CORDERO', location: LatLng(-16.544983, -68.076206)), // Estimado
    Place(name: 'IGLESIA DE SAN MIGUEL', location: LatLng(-16.539445, -68.077617)), // Reutilizado de Achumani
    Place(name: 'CALACOTO CALLE 18', location: LatLng(-16.538839, -68.081066)), // Reutilizado de Achumani
    Place(name: 'ROTONDA CALLE 15', location: LatLng(-16.540116, -68.084147)), // Estimado
    Place(name: 'CALACOTO FINAL CALLE 15', location: LatLng(-16.540116, -68.084147)),
    Place(name: 'LOS NARDOS', location: LatLng(-16.543892, -68.086355)),
    Place(name: 'LOS SAUCES', location: LatLng(-16.545089, -68.090627)),
    Place(name: 'ADESU', location: LatLng(-16.531134, -68.100221)),
    Place(name: 'MERCADO 16 DE JULIO', location: LatLng(-16.529536, -68.103138)),
    Place(name: 'PLAZA LA LOBA', location: LatLng(-16.528101, -68.106090)),
    Place(name: 'SEÑOR DE EXALTACIÓN', location: LatLng(-16.526917, -68.108350)),
    Place(name: 'OBRAJES CALLE 4', location: LatLng(-16.524571, -68.111080)),
    Place(name: 'OBRAJES CALLE 2', location: LatLng(-16.523621, -68.112820)),
    Place(name: 'CURVA DE HOLGUÍN', location: LatLng(-16.519293, -68.116185)),
    Place(name: 'AV. DEL POETA', location: LatLng(-16.509648, -68.121660)),
    Place(name: 'UMSA', location: LatLng(-16.503948, -68.128413)),
    Place(name: 'PLAZA CAMACHO', location: LatLng(-16.500273, -68.132084)),
  ];

  static const List<Place> _chasquipampaVuelta = [
    Place(name: 'PLAZA CAMACHO', location: LatLng(-16.500273, -68.132084)),
    Place(name: 'CANCHA ZAPATA', location: LatLng(-16.500273, -68.132084)),
    Place(name: 'AV. DEL POETA', location: LatLng(-16.509648, -68.121660)),
    Place(name: 'CURVA DE HOLGUÍN', location: LatLng(-16.519293, -68.116185)),
    Place(name: 'OBRAJES CALLE 2', location: LatLng(-16.523621, -68.112820)),
    Place(name: 'OBRAJES CALLE 4', location: LatLng(-16.524571, -68.111080)),
    Place(name: 'SEÑOR DE EXALTACIÓN', location: LatLng(-16.526917, -68.108350)),
    Place(name: 'PLAZA DE LA LOBA', location: LatLng(-16.528101, -68.106090)),
    Place(name: 'MERCADO 16 DE JULIO', location: LatLng(-16.529536, -68.103138)),
    Place(name: 'ADESU', location: LatLng(-16.533264, -68.098265)),
    Place(name: 'CAMPO FERIAL', location: LatLng(-16.537936, -68.095693)),
    Place(name: 'CALLE ESTHER BALLUVIÁN', location: LatLng(-16.542025, -68.093981)),
    Place(name: 'LOS ALAMOS', location: LatLng(-16.545778, -68.090912)),
    Place(name: 'LOS NARDOS', location: LatLng(-16.543988, -68.086027)),
    Place(name: 'CALACOTO FINAL CALLE 15', location: LatLng(-16.543988, -68.086027)),
    Place(name: 'CALACOTO CALLE 15', location: LatLng(-16.540049, -68.083985)),
    Place(name: 'CALACOTO CALLE 16', location: LatLng(-16.538928, -68.083184)),
    Place(name: 'CALACOTO CALLE 18', location: LatLng(-16.538839, -68.081067)),
    Place(name: 'IGLESIA DE SAN MIGUEL', location: LatLng(-16.539286, -68.077966)),
    Place(name: 'PANCARA', location: LatLng(-16.542225, -68.077497)),
    Place(name: 'FINAL CALLE 21', location: LatLng(-16.544969, -68.076212)),
    Place(name: 'LOS PINOS CALLE 3', location: LatLng(-16.545194, -68.073847)),
    Place(name: 'LOS PINOS CALLE 25', location: LatLng(-16.545383, -68.070454)),
    Place(name: 'LOS PINOS CALLE 27', location: LatLng(-16.545195, -68.065340)),
    Place(name: 'LOS PINOS CALLE 28', location: LatLng(-16.545332, -68.063875)),
    Place(name: 'COTA COTA CALLE 28', location: LatLng(-16.542173, -68.066054)),
    Place(name: 'CAMPUS UMSA', location: LatLng(-16.541390, -68.067223)),
    Place(name: 'COTA COTA CALLE 30', location: LatLng(-16.540813, -68.063438)),
    Place(name: 'LAGUNA COTA COTA', location: LatLng(-16.541934, -68.063018)),
    Place(name: 'CHASQUIPAMPA CALLE 35', location: LatLng(-16.539875, -68.057536)),
    Place(name: 'CHASQUIPAMPA CALLE 37', location: LatLng(-16.540130, -68.054469)),
    Place(name: 'CHASQUIPAMPA CALLE 46', location: LatLng(-16.538498, -68.051122)),
    Place(name: 'CHASQUIPAMPA CALLE 53', location: LatLng(-16.536908, -68.046901)),
    Place(name: 'LOMAS DE KUPILLANI', location: LatLng(-16.537244, -68.043598)),
    Place(name: 'VIRGEN DE LA MERCED', location: LatLng(-16.535730, -68.042970)),
    Place(name: 'CHASQUIPAMPA CALLE 60', location: LatLng(-16.534463, -68.040828)),
    Place(name: 'CHASQUIPAMPA CALLE 63', location: LatLng(-16.533695, -68.036910)),
  ];

  static const List<int> _chasquipampaTimes = [
    0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62, 64
  ];

  static const List<int> _chasquipampaReturnTimes = [
    0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62, 64, 66, 68, 70, 72
  ];

  // ============================================================
  // LISTA DE TODAS LAS RUTAS
  // ============================================================
  static const List<PumaKatariRoute> allRoutes = [
    PumaKatariRoute(
      id: 'PK_ACHUMANI',
      name: 'Achumani - San Pedro',
      stops: _achumaniIda,
      returnStops: _achumaniVuelta,
      times: _achumaniTimes,
      returnTimes: _achumaniReturnTimes,
      fare: 2.00,
      frequencyMinutes: 10,
    ),
    PumaKatariRoute(
      id: 'PK_CHASQUIPAMPA',
      name: 'Chasquipampa - Plaza Camacho',
      stops: _chasquipampaIda,
      returnStops: _chasquipampaVuelta,
      times: _chasquipampaTimes,
      returnTimes: _chasquipampaReturnTimes,
      fare: 2.00,
      frequencyMinutes: 10,
    ),
  ];

  // ============================================================
  // UTILIDADES
  // ============================================================
  static List<Place> get allStops {
    final stops = <Place>[];
    for (final route in allRoutes) {
      stops.addAll(route.stops);
      stops.addAll(route.returnStops);
    }
    return stops;
  }

  /// Encuentra una ruta por su ID
  static PumaKatariRoute? findRouteById(String id) {
    try {
      return allRoutes.firstWhere((route) => route.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Encuentra rutas que pasan por una parada (ida o vuelta)
  static List<PumaKatariRoute> findRoutesByStop(String stopName) {
    final result = <PumaKatariRoute>[];
    for (final route in allRoutes) {
      final inStops = route.stops.any((s) => s.name == stopName);
      final inReturn = route.returnStops.any((s) => s.name == stopName);
      if (inStops || inReturn) {
        result.add(route);
      }
    }
    return result;
  }
}