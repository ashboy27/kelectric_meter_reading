import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/meter_provider.dart';
import 'package:frontend/screens/dashboard_screen.dart';


void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => MeterProvider()..loadSummary(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meter App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const DashboardScreen(),
    );
  }
}
