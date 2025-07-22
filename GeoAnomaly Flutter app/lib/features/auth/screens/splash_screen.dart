import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.go('/login'); // ✅ Používa go() namiesto push()
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo alebo ikona
            Icon(
              Icons.location_on,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'GeoAnomaly',
              style: GameTextStyles.clockTime.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 10),
            Text(
              'Discover the Unknown',
              style: GameTextStyles.clockLabel,
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
