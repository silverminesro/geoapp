import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_client.dart';
import 'features/auth/services/auth_service.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize API client
  ApiClient.initialize();

  // ✅ Initialize auth (load JWT token)
  await AuthService().initializeAuth();

  // ✅ Start app - FIX: Správny názov class
  runApp(const ProviderScope(child: GeoAnomalyApp()));
}
