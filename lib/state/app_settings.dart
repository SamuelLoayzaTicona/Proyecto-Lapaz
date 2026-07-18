import 'package:flutter/foundation.dart';

/// Ajustes de accesibilidad compartidos por toda la app (texto grande, etc).
/// Se usan ValueNotifier simples para no depender de paquetes externos.
class AppSettings {
  AppSettings._();

  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);
}
