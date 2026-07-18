import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'state/app_settings.dart';

void main() {
  runApp(const RutaSeguraApp());
}

class RutaSeguraApp extends StatelessWidget {
  const RutaSeguraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruta Segura La Paz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (context, child) {
        return ValueListenableBuilder<double>(
          valueListenable: AppSettings.textScale,
          builder: (context, scale, _) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
        );
      },
      home: const HomeScreen(),
    );
  }
}
