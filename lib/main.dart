import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'core/services/api_service.dart';
import 'features/inventory/services/inventory_service.dart';

void main() {
  runApp(const GeoAnomalyApp());
}

class GeoAnomalyApp extends StatelessWidget {
  const GeoAnomalyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),
        ProxyProvider<ApiService, InventoryService>(
          update: (_, apiService, __) => InventoryService(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'GeoAnomaly',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F1F1F),
            elevation: 4,
          ),
        ),
        home: const InventoryScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}