import 'package:geolocator/geolocator.dart';

/// Tipos de error posibles al intentar obtener la ubicación del usuario.
enum AppLocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unknown,
}

/// Excepción propia de la app (con nombre distinto a las clases internas
/// de geolocator, para evitar choques de nombres al importar ambos paquetes).
class AppLocationException implements Exception {
  final AppLocationErrorType type;
  const AppLocationException(this.type);
}

/// Encapsula todo el flujo de "pedir permiso -> obtener posición -> convertir
/// a dirección legible" para que las pantallas no tengan que preocuparse
/// por los detalles de geolocator/geocoding.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const AppLocationException(AppLocationErrorType.serviceDisabled);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const AppLocationException(AppLocationErrorType.permissionDenied);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const AppLocationException(AppLocationErrorType.permissionDeniedForever);
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Convierte coordenadas en un texto legible para mostrar como origen.
  /// (De momento mostramos las coordenadas directamente: el paquete de
  /// geocodificación inversa todavía no tiene soporte estable en web/Chrome.
  /// Cuando compiles para Android/iOS podemos agregar `geocoding` de vuelta
  /// para mostrar la dirección con nombre de calle.)
  Future<String> addressFromPosition(Position position) async {
    return 'Mi ubicación (${position.latitude.toStringAsFixed(4)}, '
        '${position.longitude.toStringAsFixed(4)})';
  }
}
