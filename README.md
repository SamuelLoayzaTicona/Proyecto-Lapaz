# Ruta Segura La Paz 🚌🚡🛡️

Prototipo Flutter de la idea "App de Viaje Inteligente y Seguro" para la
hackatón (Movilidad Urbana Sostenible / Movilidad autónoma y colaborativa).

Cubre el flujo completo del plan de demo del 21 de julio:

1. **Buscar viaje** (`HomeScreen`) — el usuario escribe origen/destino.
2. **Plan combinado** (`TripPlanScreen`) — muestra el itinerario paso a paso:
   caminar → minibús (Sindicato Litoral, Bs. 2.50) → Teleférico Línea Celeste
   → PumaKatari, con costo y tiempo total.
3. **Viaje en vivo** (`LiveTripScreen`) — un mapa simplificado (dibujado con
   `CustomPainter`, sin depender de Google Maps ni API keys) donde un
   marcador avanza simulando el GPS. Incluye el interruptor **Modo Seguro**
   y el botón **"Simular desvío"**, que dispara la alerta roja + notifica
   (simulado) a los familiares, tal como se describe en la idea original.
4. **Reportar trameaje** (`ReportScreen`) — formulario para reportar un
   sindicato/placa que no respeta su ruta.

## Cómo correrlo

```bash
cd ruta_segura_app
flutter pub get
flutter run
```

Funciona en emulador Android/iOS, Chrome (`flutter run -d chrome`) o
dispositivo físico. No requiere API keys ni conexión a internet: todos los
datos de la Zona Piloto (Río Seco → Calacoto) están en
`lib/data/pilot_zone_data.dart`.

## Estructura del proyecto

```
lib/
  main.dart                     # Punto de entrada
  theme/app_theme.dart          # Colores y estilos (verde PumaKatari, celeste Teleférico, rojo minibús/alerta)
  state/app_settings.dart       # Ajuste de tamaño de texto (accesibilidad)
  models/transport_models.dart  # TransportMode, RouteSegment, TripPlan, TrameajeReport
  data/pilot_zone_data.dart     # Datos mock de la Zona Piloto (reemplazar por datos reales de la Alcaldía)
  widgets/
    route_step_card.dart        # Tarjeta de cada tramo del itinerario
    route_map_painter.dart      # Mapa simplificado dibujado a mano
  screens/
    home_screen.dart            # Buscar origen/destino
    trip_plan_screen.dart       # Itinerario combinado
    live_trip_screen.dart       # Viaje en vivo + Modo Seguro + desvío
    report_screen.dart          # Reportar trameaje
```

## Qué es real y qué es simulado (para ser transparentes con el jurado)

- **Simulado para la demo:** la posición GPS (se anima con un
  `AnimationController`, no lee el GPS real todavía), el envío de alerta a
  familiares (solo muestra un `SnackBar`), y las rutas/tarifas de la Zona
  Piloto (son datos de ejemplo, no vienen de la Alcaldía aún).
- **Ya funcional / listo para conectar:** toda la navegación, el cálculo de
  costo y tiempo total, el formulario de reporte, el interruptor de Modo
  Seguro, y el ajuste de accesibilidad de tamaño de texto.

## Próximos pasos para que sea real (post-hackatón)

1. **GPS real:** agregar el paquete `geolocator` y reemplazar
   `_positionAtT` en `live_trip_screen.dart` por la posición real del
   usuario, comparándola contra el polígono de la ruta oficial para
   detectar el desvío automáticamente (en vez del botón "Simular desvío").
2. **Notificaciones reales:** integrar `url_launcher` (SMS) o una API de
   WhatsApp Business / Firebase Cloud Messaging para el aviso a
   familiares.
3. **Mapa real:** si la Alcaldía o el equipo consigue una API key, migrar
   `RouteMapPainter` a `google_maps_flutter` o `flutter_map` con datos de
   calles reales.
4. **Backend:** guardar los reportes de trameaje (`ReportScreen`) en una
   base de datos (Firebase/Supabase) en vez de la lista en memoria actual,
   para que la Alcaldía pueda verlos.
5. **Datos oficiales:** sustituir `pilot_zone_data.dart` por rutas reales
   de minibuses, Teleférico y PumaKatari que entregue la Alcaldía.

## Notas técnicas

- No usa paquetes externos más allá de `cupertino_icons` (ya incluido en
  cualquier proyecto Flutter nuevo), así que no depende de conexión a
  internet para compilar por primera vez, salvo la resolución normal de
  `flutter pub get`.
- Diseñado con Material 3.
- El tamaño de texto es ajustable desde el ícono de accesibilidad en la
  pantalla de inicio (cumple con el punto de "Accesibilidad" de la idea
  original).
