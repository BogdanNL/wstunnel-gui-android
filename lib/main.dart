import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const WstunnelApp());
}

class WstunnelApp extends StatelessWidget {
  const WstunnelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wstunnel GUI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
