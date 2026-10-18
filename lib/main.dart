import 'dart:async';
import 'package:flutter/material.dart';
import 'loading_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError =
        (d) => debugPrint('FlutterError: ${d.exceptionAsString()}');
    runApp(const DtxApp());
  }, (e, s) => debugPrint('ZoneError: $e'));
}

class DtxApp extends StatelessWidget {
  const DtxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DTX Kendang',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF05060A),
      ),
      home: const LoadingScreen(),
    );
  }
}
